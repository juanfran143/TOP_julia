using Random, Distributions, Combinatorics, DataStructures, Dates, Plots, Base.Threads

include("structs.jl")
include("get_edges.jl")
include("rl_dictionary.jl")


function reorder_saving_list(savings::OrderedDict{Tuple{Int, Int}, Float64}, beta::Float16)
    aux = OrderedDict{Tuple{Int, Int}, Float64}()
    keys_list = collect(keys(savings))
    while !isempty(savings)
        position = Int(floor((log(rand()) / log(1 - beta))) % length(savings)) + 1
        key = keys_list[position]
        aux[key] = pop!(savings, key)
        deleteat!(keys_list, position)
    end
    return aux    
end

function add_routes(Node2::Node, edges::Dict{Int8, Dict{Int8, Float64}}, route, max_distance::Float64, 
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, parameters)

    # Fusionar las rutas excluyendo el nodo final de la primera ruta y el nodo de inicio de la segunda ruta
    merged_route_nodes = vcat(route.route[1:end-1], Node2, route.route[end])
    new_route = [i.id for i in merged_route_nodes]

        # Aprendizaje en el merge: Si es una mierda, entonces no las juntamos
    join = true
    if haskey(rl_dic, new_route)
        # TODO Pensar un poco esto
        if (rl_dic[new_route][2] == parameters["num_simulations_per_merge"] && rl_dic[new_route][3] >= parameters["max_reliability_to_merge_routes"])
            join = false
        end
    end

    # 1-2-3-5 (route1)
    # 4 (Node2)
    # S_34 => 1-2-3-4-5  
    # Calcular distancia:
    # 1.- edges(1, 2) +  edges(2, 3) + .... edges(4, 5)
    # 2.- route1.distance + - edges(3, 5) + edges(3, 4) + edges(4, 5)
    if join
        merged_route_distance = route.dist + edge_dist(edges, route.route[end-1].id, Node2.id) + edge_dist(edges, Node2.id, route.route[end].id) - edge_dist(edges, route.route[end-1].id, route.route[end].id)
  
        # Verificar si la distancia total de la nueva ruta fusionada está dentro del límite de distancia máximo
        if merged_route_distance <= max_distance
            merged_route_reward = route.reward + Node2.reward
            route = Route(merged_route_nodes, merged_route_distance, merged_route_reward)
                
            if merged_route_distance >= parameters["capacity"]*parameters["max_percentaje_of_distance_to_do_simulations"]
                reward_input, n_simulations_completed, fails_input = update_dict(edges, rl_dic, new_route, merged_route_reward, parameters)

                rl_dic[new_route] = [reward_input, n_simulations_completed, fails_input, merged_route_distance, merged_route_reward]
            end
            return route, true
        end
    end
    return route, false
end

function constructive_with_BR_destructive(route, edges::Dict{Int8, Dict{Int8, Float64}}, beta, savings, 
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, parameters, restricted_nodes)
    savings = reorder_saving_list(savings, beta)
    #TODO coger aquellos savings vinculados únicamente con el nodo de la ruta
    # Route: 1-2-3-4-5      - 12, coger los savings vinculados con el 5

    key = collect(keys(savings)) 
    i=1
    while i <= length(key)
        if haskey(parameters["nodes"], key[i][2]) && !(key[i][2] in restricted_nodes) && route.route[end-1].id == key[i][1]
            NodeY = parameters["nodes"][key[i][2]]
            route, merge = add_routes(NodeY, edges, route, parameters["capacity"], rl_dic, parameters)
            if merge
                push!(restricted_nodes, NodeY.id)
                i = 0
            end
        end
        i += 1
    end
    #sorted_routes = sort(route, by = x -> x.reward, rev = true)

    return route
end

function destroysolution(route::Route, edges, n_destroy_nodes::Int64)
    sum = 0
    non_reward = 0
    for i = 0:n_destroy_nodes
        #route.route[1:end-n_destroy_nodes]
        non_reward += route.route[end-(i+1)].reward
        sum += edge_dist(edges, route.route[end-i].id, route.route[end-(i+1)].id)
    end
    sum -= edge_dist(edges, route.route[end-(n_destroy_nodes+1)].id, route.route[end].id)
    non_reward -= route.route[end-(n_destroy_nodes+1)].reward 

    return Route(vcat(route.route[1:end-(n_destroy_nodes+1)], route.route[end]), route.dist - sum, route.reward-non_reward)
end

function destruction(sol::Vector{Route}, edges, beta, original_savings, rl_dic, parameters)
    restricted_nodes = []
    for i = 1:length(sol)
        restricted_nodes  = vcat(restricted_nodes, [j.id for j in sol[i].route])
    end
    best_list_sol = []
    for i = 1:length(sol)
        detroysol = deepcopy(sol[i])
        best_sol = deepcopy(sol[i])

        nRoutesDestroy = floor(Int, length(detroysol.route)*parameters["p"])
        destroysol = destroysolution(detroysol, edges, nRoutesDestroy)
        
        #TODO Meter el 50 como parámetro
        for _ in 1:parameters["NumIterBrInLS"]
            savings = copy(original_savings)
            route = constructive_with_BR_destructive(destroysol, edges, beta, savings, rl_dic, parameters, restricted_nodes)
            if best_sol.reward < route.reward
                best_sol = deepcopy(route)
            end
        end
        push!(best_list_sol, best_sol)
    end

    return best_list_sol
end



