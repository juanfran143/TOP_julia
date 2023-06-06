using LinearAlgebra, Random

include("structs.jl")
include("parse.jl")
include("get_edges.jl")
include("rl_dictionary.jl")
include("reactive_Search.jl")

function obtainKey(r::Route)
    v = sort([node.id for node in r.route])
    str1 = join(v)
    return str1
end

function calcCosts(origin_node::Node, end_node::Node)
    X1 = origin_node.x
    Y1 = origin_node.y
    X2 = end_node.x
    Y2 = end_node.y
    d = sqrt((X2 - X1) * (X2 - X1) + (Y2 - Y1) * (Y2 - Y1))
    return d
end

function improveNodesOrder(aRoute::Route, edges)
    nodes = aRoute.route

    if length(edges) >= 4
        for i in 1:length(edges)-3
            #edge_dist(edge::Dict{Int8, Dict{Int8, Float64}}, i::Int8, j::Int8)
            e1 = edge_dist(edges, nodes[i].id, nodes[i+1].id)
            e2 = edge_dist(edges, nodes[i + 1].id, nodes[i+2].id)
            e3 = edge_dist(edges, nodes[i + 2].id, nodes[i+3].id)
            currentCosts = e1 + e2 + e3
            
            #ae := Alternative edge
            ae1 = edge_dist(edges, nodes[i].id, nodes[i+2].id)
            ae2 = edge_dist(edges, nodes[i+2].id, nodes[i+1].id)
            ae3 = edge_dist(edges, nodes[i+1].id, nodes[i+3].id)

            alterCosts = ae1 + ae2 + ae3
            if (alterCosts < currentCosts)
                aRoute.dist -= e1 + e2 + e3
                aRoute.dist += ae1 + ae2 + ae3

                deleteat!(aRoute.route, i+1)
                insert!(aRoute.route, i+1, nodes[i+2])

                deleteat!(aRoute.route, i+2)
                insert!(aRoute.route, i+2, nodes[i+1])
            end
        end
    end

    return aRoute
end

function improveWithCache(cache::Dict, newSol, edges)
    n = length(newSol)
    for i in 1:n
        route = newSol[i]
        route = improveNodesOrder(route, edges)

        skey = obtainKey(route)

        if !haskey(cache.cache, skey)
            cache.cache[skey] = route
        else
            rCached = cache.cache[skey]

            dif = rCached.dist - route.dist
            if dif > 0
                cache.cache[skey] = route
            elseif dif != 0
                cost = sum([r.dist for r in newSol.route])
                newSol.dist = cost
                deleteat!(newSol.route, i)
                push!(newSol.route, rCached)
            end
        end
    end
end

function main()

    n_vehicles, capacity, nodes = parse_txt("C:/Users/jfg14/OneDrive/Documentos/GitHub/TOP_julia/Instances/Set_64_234/p6.2.g.txt")

    parameters = Dict(
        # Problem
        "start_node" => 1,
        "last_node" => length(nodes),
        "n_vehicles" => n_vehicles,
        "capacity" => capacity,
        "nodes" => nodes,
        
        # simulations
        "var_lognormal" => 0.05,
        "large_simulation_simulations" => 10000,

        # RL_DICT
        "num_simulations_per_merge" => 100,
        "max_simulations_per_route" => 200,
        "max_reliability_to_merge_routes" => 0.3,
        "max_percentaje_of_distance_to_do_simulations" => 3/5,

        # Stochastic solution
        "num_iterations_stochastic_solution" => 50,
        "beta_stochastic_solution" => 0.4
        )

    edges = precalculate_distances(nodes::Dict{Int64, Node})

    newSol = Route[Route(Node[Node(1, 0.0, -7.0, 0.0, 1), Node(5, 0.0, -5.0, 6.0, 4), Node(13, 0.0, -3.0, 12.0, 4), Node(14, 2.0, -3.0, 18.0, 4), Node(20, 3.0, -2.0, 24.0, 4), Node(34, 3.0, 0.0, 30.0, 4), Node(27, 4.0, -1.0, 30.0, 4), Node(42, 4.0, 1.0, 30.0, 4), Node(48, 3.0, 2.0, 24.0, 4), Node(53, 2.0, 3.0, 18.0, 4), Node(63, 1.0, 6.0, 6.0, 4), Node(64, 0.0, 7.0, 0.0, 1)], 20.23334547203386, 198.0), Route(Node[Node(1, 0.0, -7.0, 0.0, 1), Node(8, -1.0, -4.0, 12.0, 7), Node(18, -1.0, -2.0, 18.0, 7), Node(25, 0.0, -1.0, 18.0, 7), Node(40, 0.0, 1.0, 18.0, 7), Node(47, 1.0, 2.0, 18.0, 7), Node(57, 1.0, 4.0, 12.0, 7), Node(64, 0.0, 7.0, 0.0, 1)], 15.15298244508295, 96.0)]
    cache = Dict()
    improveWithCache(cache::Dict, newSol, edges)
end

main()
