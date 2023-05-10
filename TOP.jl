using Random, Distributions

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





function modify_value_lognormal(mean::Float64, variance::Float64)
    mu = log(mean^2 / sqrt(mean^2 + variance))
    sigma = sqrt(log(1 + (variance / mean^2)))
    lognormal_dist = LogNormal(mu, sigma)
    return rand(lognormal_dist)
end

function simulation(edges::Dict{Int8, Dict{Int8, Float64}}, num_simulations::Int8, capacity::Int8, routes::Route[])
    avg_reward = []
    for _ in 1:num_simulations
        reward_route = []
        for route in routes
            dist = 0
            first_node = route[1]
            for next_node in route[1:end]
                dist += modify_value_lognormal(edge_dist(edges, first_node.id, next_node.id))
            end

            reward = route.reward
            if dist > capacity
                reward = 0
            end
            push!(reward_route, reward)
        end
        push!(avg_reward, sum(reward_route))
    end
end






function dummy_solution(nodes::Dict{Int, Node}, edges::Dict{Int8, Dict{Int8, Float64}}, capacity)
    routes = Dict{Int, Route}()
    for i in 2:length(nodes)-1
        distances =  edge_dist(edges, nodes[1].id, nodes[i].id) + edge_dist(edges, nodes[i].id, nodes[length(nodes)].id)

        if distances <= capacity
            node_list = [nodes[1], nodes[i], nodes[length(nodes)]]
            routes[i-1] = Route(node_list, distances, nodes[i].reward)
            nodes[i].route_id = i-1
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
            if i != j && nodes[i].route_id != 0 && nodes[j].route_id != 0
                saving = edge_dist(edges, depot.id, nodes[j].id) + edge_dist(edges, nodes[i].id, nodes[length(nodes)].id) - edge_dist(edges, nodes[i].id, nodes[j].id)
                savings_dict[(i, j)] = saving*alpha+(1-alpha)*(nodes[i].reward+nodes[j].reward)
            end
        end
    end
    sorted_savings_dict = sort(collect(savings_dict), by = x -> x[2], rev = true)
    sorted_savings_dict = Dict(kv[1] => kv[2] for kv in sorted_savings_dict)
    return sorted_savings_dict
end

function merge_routes(Node1::Node, Node2::Node, edges::Dict{Int8, Dict{Int8, Float64}}, routes::Dict{Int, Route}, max_distance::Float64)
    route1 = routes[Node1.route_id]
    route2 = routes[Node2.route_id]

    if Node1.route_id != Node2.route_id && route1.route[end-1].id == Node1.id && route2.route[2].id == Node2.id
        # Fusionar las rutas excluyendo el nodo final de la primera ruta y el nodo de inicio de la segunda ruta
        merged_route_nodes = vcat(route1.route[1:end-1], route2.route[2:end])

        # Calcular la distancia y la recompensa total de la nueva ruta fusionada
        merged_route_distance = route1.dist + route2.dist - edge_dist(edges, route1.route[end-1].id, route1.route[end].id) - edge_dist(edges, route2.route[1].id, route2.route[2].id) + edge_dist(edges, Node1.id, Node2.id)

        merged_route_reward = route1.reward + route2.reward
        # Verificar si la distancia total de la nueva ruta fusionada está dentro del límite de distancia máximo
        if merged_route_distance <= max_distance
            routes[Node1.route_id] = Route(merged_route_nodes, merged_route_distance, merged_route_reward)
            
            original_route_id = Node2.route_id
            for r in routes[original_route_id].route
                r.route_id = Node1.route_id
            end
            delete!(routes, original_route_id)
        end
    end
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

function heuristic_with_BR(n_vehicles, nodes, edges::Dict{Int8, Dict{Int8, Float64}}, capacity, alpha, beta)
    routes = dummy_solution(nodes, edges, capacity)
    savings = calculate_savings_dict(nodes, edges, alpha)
    savings = reorder_saving_list(savings, beta)
    for key in keys(savings)
        NodeX = nodes[key[1]]
        NodeY = nodes[key[2]]
        merge_routes(NodeX, NodeY, edges, routes, capacity)
    end
    sorted_routes = sort(collect(routes), by = x -> x[2].reward, rev = true)
    sorted_routes = Dict(kv[1] => kv[2] for kv in sorted_routes)

    return get_reward_and_route(sorted_routes, n_vehicles)
end

function main()
    n_vehicles = 2
    capacity = 15.0
    alpha = Float16(0.7)
    beta = Float16(0.7)
    nodes = Dict{Int64, Node}(5 => Node(5, 10.0, 10.0, 0.0, 0), 4 => Node(4, 5.0, 3.0, 8.0, 0), 
                              2 => Node(2, 5.0, 6.0, 8.0, 0), 3 => Node(3, 2.0, 2.0, 4.0, 0), 1 => Node(1, 0.0, 0.0, 0.0, 0))


    edges = Dict{Int8, Dict{Int8, Float64}}()
    for i in 1:length(nodes)
        edges[i] = Dict{Int8, Float64}()  # Inicializa el diccionario interno antes de asignar valores
        for j in i:length(nodes)
            edges[i][j] = distance(nodes[i], nodes[j])
        end
    end


    best_reward = 0
    best_route = Route[]

    reward = 0
    route = Route[]
    for _ in 1:100
        reward, route = heuristic_with_BR(n_vehicles, nodes, edges, capacity, alpha, beta)
        if reward > best_reward
            best_reward = reward
            best_route = copy(route)
        end
    end

    println("Best routes: ", best_route)
end

main()
