using Random, Distributions, Combinatorics, DataStructures, Dates, Plots, Base.Threads

include("structs.jl")
include("parse.jl")
include("get_edges.jl")
include("simulation.jl")
include("rl_dictionary.jl")
include("reactive_Search.jl")
include("local_search_cache.jl")
include("plot_solutions.jl")

function constructive_with_BR(route, edges::Dict{Int8, Dict{Int8, Float64}}, beta, savings, 
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, parameters, restricted_nodes)
    savings = reorder_saving_list(savings, beta)
    #TODO coger aquellos savings vinculados únicamente con el nodo de la ruta
    # Route: 1-2-3-4-5      - 12, coger los savings vinculados con el 5
    for key in keys(savings)
        if haskey(parameters["nodes"], key[2]) && !(key[2] in restricted_nodes) && route[end].id == key[1]
            NodeX = parameters["nodes"][key[1]]
            NodeY = parameters["nodes"][key[2]]
            merge_routes(NodeX, NodeY, edges, route, parameters["capacity"], rl_dic, parameters)
        end
    end
    sorted_routes = sort(collect(routes), by = x -> x[2].reward, rev = true)
    sorted_routes = Dict(kv[1] => kv[2] for kv in sorted_routes)

    return route
end

function destroysolution(route::Route, edges, n_destroy_nodes::Int64)
    sum = 0
    for i = 0:n_destroy_nodes
        route.route[1:end-n_destroy_nodes]
        sum += edge_dist(edges, route.route[end-i].id, route.route[end-(i+1)].id)
    sum += edge_dist(edges, route.route[end-i].id, route.route[end].id)

    return Route(vcat(route.route[1:end-n_destroy_nodes], route.route[end]), route.dist - sum, route.reward)
end

function destruction(sol::Route[], edges, p::Float64, beta, savings, rl_dic, parameters)
    restricted_nodes = []
    for i = 1:length(sol)
        restricted_nodes  = vcat(restricted_nodes, [j.id for j in sol[i].route])

    for i = 1:length(sol)
        detroysol = deepcopy(sol[i])
        best_sol = deepcopy(sol[i])

        nRoutesDestroy = int(length(detroysol.route)*p);
        destroysol = destroysolution(detroysol, edges, nRoutesDestroy)

        for _ in 1:20
            sol = constructive_with_BR(route, edges, beta, savings,rl_dic, parameters, restricted_nodes)
            if best_sol.reward < sol.reward
                
            end
        end
end



