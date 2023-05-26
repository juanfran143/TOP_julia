using Random, Distributions, Combinatorics
#using Combinatorics
mutable struct Node
    id:: Int8
    x::Float64
    y::Float64
    reward:: Float64
    route_id:: Int
end

struct Route
    route::Vector{Node}
    dist::Float64
    reward::Float64
end

function Base.copy(s::Route)
    return Route(s.route, s.dist, s.reward)
end

function edge_dist(edge::Dict{Int8, Dict{Int8, Float64}}, i::Int8, j::Int8)
    if i>j
        return edge[j][i]
    end
    return edge[i][j]
end

function distance(NodeX::Node, NodeY::Node)
    return sqrt((NodeX.x-NodeY.x)^2+(NodeX.y-NodeY.y)^2)
end

function parse_txt(file_path::String)
    open(file_path, "r") do file
        lines = readlines(file)

        n_nodes = parse(Int, split(lines[1])[2])
        n_vehicles = parse(Int, split(lines[2])[2])
        capacity = parse(Float64, split(lines[3])[2])

        nodes = Dict{Int64, Node}()
        for i in 4:length(lines)
            line = split(lines[i])
            x, y, reward = parse(Float64, line[1]), parse(Float64, line[2]), parse(Float64, line[3])
            node_id = i - 3
            nodes[node_id] = Node(node_id, x, y, reward, 0)
        end
        
        return n_vehicles, capacity, nodes
    end
end

function modify_value_lognormal(mean::Float64, variance::Float64)
    mu = log(mean^2 / sqrt(mean^2 + variance))
    sigma = sqrt(log(1 + (variance / mean^2)))
    lognormal_dist = LogNormal(mu, sigma)
    return rand(lognormal_dist)
end

function simulation(edges::Dict{Int8, Dict{Int8, Float64}}, num_simulations::Int, capacity::Float64, routes::Array{Route,1})
    avg_reward = []
    for _ in 1:num_simulations
        reward_route = []
        for route in routes
            dist = 0
            first_node = route.route[1]
            for next_node in route.route[2:end]
                dist += modify_value_lognormal(edge_dist(edges, first_node.id, next_node.id), 0.2)
                first_node = next_node
            end

            reward = route.reward
            if dist > capacity
                reward = 0
            end
            push!(reward_route, reward)
        end
        push!(avg_reward, sum(reward_route))
    end

    return mean(avg_reward)
end



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

        # Calcular la distancia y la recompensa total de la nueva ruta fusionada

        # 1-2-3-5 (route1)
        # 1-4-5 (route2)
        # S_34 => 1-2-3-4-5  
        # Calcular distancia:
        # 1.- edges(1, 2) +  edges(2, 3) + .... edges(4, 5)
        # 2.- route1.distance + route2.distance - edges(3, 5) - edges(1, 4) + edges(3, 4) 1-2-3//5 1//4-5    3-4 
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
            new_route = [i.id for i in merged_route_nodes]
            rl_dic[new_route] = update_dict(edges, max_distance, rl_dic, new_route, merged_route_reward)
        end
    end
end

function update_dict(edges::Dict{Int8, Dict{Int8, Float64}}, max_distance::Float64, 
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, new_route::Array{Int8,1}, route_reward::Float64)
    # rl_dic va a tener los siguientes atributos guardados por ruta
    #   - Reward medio
    #   - Número de simulaciones ejecutadas
    #   - % de fallo de la ruta (reliability)
    run_simulation = true
    n_simulations_completed = 0
    n_fails = 0
    avg_reward = 0

    # Meter como parámetro: Número de simulaciones que hagamos cada vez que ejecutaremos (num_simulations) y número máximo de simulaciones para
    # no simular mas (max_simulations)
    num_simulations = 10
    max_simulations = 30

    if haskey(rl_dic, new_route)
        if rl_dic[new_route][2] >= max_simulations
            run_simulation = false
        else
            n_simulations_completed = rl_dic[new_route][2]
            n_fails = rl_dic[new_route][3]
            avg_reward = rl_dic[new_route][1]
        end
    end

    if run_simulation
        reward, fails = simulation_dict(edges, num_simulations, max_distance, new_route, route_reward)
        reward_input = (avg_reward*n_simulations_completed+reward*num_simulations)/(num_simulations+n_simulations_completed)
        fails_input = (n_fails*n_simulations_completed+fails*num_simulations)/(num_simulations+n_simulations_completed)
        rl_dic[new_route] = [reward_input, num_simulations+n_simulations_completed, fails_input]
    end
    
end


function simulation_dict(edges::Dict{Int8, Dict{Int8, Float64}}, num_simulations::Int, capacity::Float64, route::Array{Int8,1},
    route_reward::Float64)
    avg_reward = []
    n_fails = 0
    for _ in 1:num_simulations
        dist = 0
        first_node = route[1]
        for next_node in route[2:end]
            dist += modify_value_lognormal(edge_dist(edges, first_node, next_node), 0.2)
            first_node = next_node
        end

        reward = route_reward
        if dist > capacity
            reward = 0
            n_fails += 1
        end
        push!(avg_reward, reward)
    end

    return (mean(avg_reward), n_fails/num_simulations)
end

function reorder_saving_list(savings::Dict{Tuple{Int, Int}, Float64}, beta::Float16)
    aux = Dict{Tuple{Int, Int}, Float64}()
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


function create_dic_to_rl(nodes::Dict{Int64, Node}, max_distance::Float64, start_node, end_node)
    routes = Dict{Vector{Int64}, Float64}()
    intermediate_nodes = [key for key in keys(nodes) if key != start_node && key != end_node] # nodes that are not depots

    # Generate all permutations of length 1 to n for the intermediate nodes
    for n in 1:length(intermediate_nodes)
        for perm in permutations(intermediate_nodes, n)
            route = vcat([start_node], perm, [end_node])  # add depots to the start and end
            total_distance = sum(distance(nodes[route[i]], nodes[route[i+1]]) for i in 1:length(route)-1)
            if total_distance <= max_distance
                reward = sum(nodes[node].reward for node in route)
                routes[route] = reward
            end
        end
    end

    return routes
end


function precalculate_distances(nodes::Dict{Int64, Node})
    edges = Dict{Int8, Dict{Int8, Float64}}()
    for i in keys(nodes)
        edges[i] = Dict{Int64, Float64}() 
        for j in keys(nodes)
            edges[i][j] = distance(nodes[i], nodes[j])
        end
    end
    return edges
end

function main()
    alpha = Float16(0.7)
    beta = Float16(0.7)

    #return n_nodes, n_vehicles, capacity, nodes
    n_vehicles, capacity, nodes = parse_txt("C:/Users/jfg14/OneDrive/Documentos/GitHub/TOP_julia/Instances/Set_64_234/p6.2.d.txt")
    start_node = 1
    end_node = length(nodes)
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
        print(iter)
        savings = copy(original_savings)
        reward, routes = heuristic_with_BR(n_vehicles, nodes, edges, capacity, alpha, beta, savings, rl_dic, last_node)
        
        #avg_reg = simulation(edges, 100, capacity, routes)
        #println(avg_reg, " ", [route.reward for route in routes])

        if reward > best_reward
            best_reward = reward
            best_route = copy(routes)
        end
    end

    println("Best routes: ", best_route)
end

main()
#parse_txt("C:/Users/jfg14/OneDrive/Documentos/GitHub/TOP_julia/Instances/Set_64_234/p6.2.a.txt")
