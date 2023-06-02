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
    sorted_savings_dict = Dict(kv[1] => kv[2] for kv in sorted_savings_dict)
    return sorted_savings_dict
end

function merge_routes(Node1::Node, Node2::Node, edges::Dict{Int8, Dict{Int8, Float64}}, routes::Dict{Int, Route}, max_distance::Float64, 
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}})
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
            if (rl_dic[new_route][2] >= 300 && rl_dic[new_route][3] >=0.3) || (rl_dic[new_route][2] >= 150 && rl_dic[new_route][3] >= 0.5)
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
                
                if merged_route_distance >= max_distance/2
                    reward_input, n_simulations_completed, fails_input = update_dict(edges, max_distance, rl_dic, new_route, merged_route_reward)

                    #TODO Eliminar las últimas dos componentes (distancia determinista y reward determinista)
                    rl_dic[new_route] = [reward_input, n_simulations_completed, fails_input, merged_route_distance, merged_route_reward]
                end
            end
        end
        
        
    end
end


function reorder_saving_list(savings::Dict{Tuple{Int, Int}, Float64}, beta::Float16)
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

function heuristic_with_BR(n_vehicles, nodes, edges::Dict{Int8, Dict{Int8, Float64}}, capacity, alpha, beta, savings, rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, last_node::Int64)
    routes = dummy_solution(nodes, edges, capacity, last_node)
    savings = reorder_saving_list(savings, beta)
    for key in keys(savings)
        if haskey(nodes, key[1]) && haskey(nodes, key[2])
            NodeX = nodes[key[1]]
            NodeY = nodes[key[2]]
            merge_routes(NodeX, NodeY, edges, routes, capacity, rl_dic)
        end
    end
    sorted_routes = sort(collect(routes), by = x -> x[2].reward, rev = true)
    sorted_routes = Dict(kv[1] => kv[2] for kv in sorted_routes)

    return get_reward_and_route(sorted_routes, n_vehicles)
end

function main()
    alpha = Float16(0.7)
    beta = Float16(0.6)

    #return n_nodes, n_vehicles, capacity, nodes
    n_vehicles, capacity, nodes = parse_txt("C:/Users/jfg14/OneDrive/Documentos/GitHub/TOP_julia/Instances/Set_64_234/p6.2.n.txt")
    start_node = 1
    end_node = length(nodes)
    println(capacity)
    """
    nodes = Dict{Int64, Node}(5 => Node(5, 10.0, 10.0, 0.0, 0), 4 => Node(4, 5.0, 3.0, 8.0, 0), 
                              2 => Node(2, 5.0, 6.0, 8.0, 0), 3 => Node(3, 2.0, 2.0, 4.0, 0), 1 => Node(1, 0.0, 0.0, 0.0, 0))
    """
    edges = precalculate_distances(nodes::Dict{Int64, Node})
    original_savings = calculate_savings_dict(nodes, edges, alpha)
    best_reward = 0
    best_route = Route[]
    last_node = length(nodes)
    rl_dic = Dict{Array{Int64,1}, Array{Float64,1}}()
    for iter in 1:100
        println(iter)
        savings = copy(original_savings)
        reward, routes = heuristic_with_BR(n_vehicles, nodes, edges, capacity, alpha, beta, savings, rl_dic, last_node)
        
        """        
        println("\n")
        println(rl_dic)
        rl_dic_sorted = sort(collect(rl_dic), by = x -> x[2][1], rev = true)
        for kv in rl_dic_sorted
            println("Key: ", kv[1], ", Value: ", kv[2])
        end
        """
        if reward > best_reward
            best_reward = reward
            best_route = copy(routes)
        end
    end
    
    rl_dic_sorted = sort(collect(rl_dic), by = x -> x[2][1], rev = true)
    rl_dic_sorted = OrderedDict(rl_dic_sorted)
    stochastic_solution = get_stochastic_solution(rl_dic_sorted, n_vehicles)
    println(sum([v[2][1] for v in stochastic_solution]))
    for kv in stochastic_solution
        println("Key: ", kv[1], ", Value: ", kv[2])
    end

    #println("Best routes: ", best_route)
end

main()
