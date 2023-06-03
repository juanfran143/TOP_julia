using Random, Distributions, Combinatorics, DataStructures

include("structs.jl")
include("parse.jl")
include("get_edges.jl")
include("simulation.jl")
include("rl_dictionary.jl")

function dummy_solution(nodes::Dict{Int, Node}, edges::Dict{Int8, Dict{Int8, Float64}}, capacity, last_node)
    routes = Dict{Int, Route}()
    for (id, node) in pairs(nodes)
        if id == 1 || id == last_node  # Ignora el primer y el último nodo
            continue
        end
        
        distances = edge_dist(edges, nodes[1].id, node.id) + edge_dist(edges, node.id, nodes[last_node].id)
    
        if distances <= capacity
            node_list = [nodes[1], node, nodes[last_node]]
            routes[id-1] = Route(node_list, distances, node.reward)
            node.route_id = id-1
        else
            delete!(nodes, id)
        end
    end
    
    return routes
end

function calculate_savings_dict(nodes::Dict{Int, Node}, edges::Dict{Int8, Dict{Int8, Float64}}, alpha:: Float16)
    savings_dict = Dict{Tuple{Int, Int}, Float64}()

    depot = nodes[1]
    n = length(nodes)

    for i in 2:n-1
        for j in 2:n-1
            if i != j
                saving = edge_dist(edges, depot.id, nodes[j].id) + edge_dist(edges, nodes[i].id, nodes[length(nodes)].id) - edge_dist(edges, nodes[i].id, nodes[j].id)
                savings_dict[(i, j)] = saving*alpha+(1-alpha)*(nodes[i].reward+nodes[j].reward)
            end
        end
    end
    sorted_savings_dict = sort(collect(savings_dict), by = x -> x[2], rev = true)
    sorted_savings_dict = OrderedDict(kv[1] => kv[2] for kv in sorted_savings_dict)
    return sorted_savings_dict
end

function merge_routes(Node1::Node, Node2::Node, edges::Dict{Int8, Dict{Int8, Float64}}, routes::Dict{Int, Route}, max_distance::Float64, 
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, parameters)
    route1 = routes[Node1.route_id]
    route2 = routes[Node2.route_id]

    if Node1.route_id != Node2.route_id && route1.route[end-1].id == Node1.id && route2.route[2].id == Node2.id
        # Fusionar las rutas excluyendo el nodo final de la primera ruta y el nodo de inicio de la segunda ruta
        merged_route_nodes = vcat(route1.route[1:end-1], route2.route[2:end])
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
        # 1-4-5 (route2)
        # S_34 => 1-2-3-4-5  
        # Calcular distancia:
        # 1.- edges(1, 2) +  edges(2, 3) + .... edges(4, 5)
        # 2.- route1.distance + route2.distance - edges(3, 5) - edges(1, 4) + edges(3, 4) 1-2-3//5 1//4-5    3-4 
        if join
            merged_route_distance = route1.dist + route2.dist - edge_dist(edges, route1.route[end-1].id, route1.route[end].id) - edge_dist(edges, route2.route[1].id, route2.route[2].id) + edge_dist(edges, Node1.id, Node2.id)
  
            # Verificar si la distancia total de la nueva ruta fusionada está dentro del límite de distancia máximo
            if merged_route_distance <= max_distance
                merged_route_reward = route1.reward + route2.reward
                routes[Node1.route_id] = Route(merged_route_nodes, merged_route_distance, merged_route_reward)
                        
                original_route_id = Node2.route_id
                for r in routes[original_route_id].route
                    r.route_id = Node1.route_id
                end
                delete!(routes, original_route_id)

                #Algoritmo Juanfran y Antonio contienen el siguiente cacho de código en común
                
                if merged_route_distance >= parameters["capacity"]*parameters["max_percentaje_of_distance_to_do_simulations"]
                    reward_input, n_simulations_completed, fails_input = update_dict(edges, rl_dic, new_route, merged_route_reward, parameters)

                    rl_dic[new_route] = [reward_input, n_simulations_completed, fails_input, merged_route_distance, merged_route_reward]
                end
            end
        end
        
        
    end
end

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

function get_reward_and_route(sorted_routes::Dict{Int64, Route}, n_vehicles::Int)
    reward = 0
    routes = Route[]
    keys_list = collect(keys(sorted_routes))
    for i in 1:n_vehicles
        push!(routes, sorted_routes[keys_list[i]])
        reward += sorted_routes[keys_list[i]].reward
    end
    return (reward, routes)
end

function heuristic_with_BR(edges::Dict{Int8, Dict{Int8, Float64}}, beta, savings, rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, parameters)
    routes = dummy_solution(parameters["nodes"], edges, parameters["capacity"], parameters["last_node"])
    savings = reorder_saving_list(savings, beta)
    for key in keys(savings)
        if haskey(parameters["nodes"], key[1]) && haskey(parameters["nodes"], key[2])
            NodeX = parameters["nodes"][key[1]]
            NodeY = parameters["nodes"][key[2]]
            merge_routes(NodeX, NodeY, edges, routes, parameters["capacity"], rl_dic, parameters)
        end
    end
    sorted_routes = sort(collect(routes), by = x -> x[2].reward, rev = true)
    sorted_routes = Dict(kv[1] => kv[2] for kv in sorted_routes)

    return get_reward_and_route(sorted_routes, parameters["n_vehicles"])
end

function main()
    alpha = Float16(0.3)
    beta = Float16(0.1)

    #return n_nodes, n_vehicles, capacity, nodes
    n_vehicles, capacity, nodes = parse_txt("C:/Users/jfg14/OneDrive/Documentos/GitHub/TOP_julia/Instances/Set_64_234/p6.3.g.txt")

    parameters = Dict(
        # Problem
        "start_node" => 1,
        "last_node" => length(nodes),
        "n_vehicles" => n_vehicles,
        "capacity" => capacity,
        "nodes" => nodes,
        
        # simulations
        "var_lognormal" => 0.05,
        "large_simulation_simulations" => 1000,

        # RL_DICT
        "num_simulations_per_merge" => 100,
        "max_simulations_per_route" => 200,
        "max_reliability_to_merge_routes" => 0.3,
        "max_percentaje_of_distance_to_do_simulations" => 4/5,

        # Stochastic solution
        "num_iterations_stochastic_solution" => 50,
        "beta_stochastic_solution" => 0.4
        )

    edges = precalculate_distances(nodes::Dict{Int64, Node})
    original_savings = calculate_savings_dict(nodes, edges, alpha)

    best_reward = 0
    best_route = Route[]
    rl_dic = Dict{Array{Int64,1}, Array{Float64,1}}()
    
    @time begin 
        for _ in 1:30000
            savings = copy(original_savings)
            reward, routes = heuristic_with_BR(edges, beta, savings, rl_dic, parameters)
            
            if reward > best_reward
                best_reward = reward
                best_route = copy(routes)
            end
        end
        
        rl_dic_sorted = OrderedDict(sort(collect(rl_dic), by = x -> x[2][1], rev = true))
        stochastic_solution = get_stochastic_solution_br(rl_dic_sorted, parameters)
    end

    println("El reward estocástico es: ",sum([v[2][1] for v in stochastic_solution]))
    println("El reward real es: ", large_simulation(edges, parameters["large_simulation_simulations"], parameters["capacity"], stochastic_solution))

    #println("Best deterministic routes reward: ", [reward.reward for reward in best_route])
end

main()
