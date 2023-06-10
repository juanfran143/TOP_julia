using Random, Distributions, Combinatorics, DataStructures, Dates, Plots, Base.Threads

include("structs.jl")
include("parse.jl")
include("get_edges.jl")
include("simulation.jl")
include("rl_dictionary.jl")
include("reactive_Search.jl")
include("local_search_cache.jl")
include("plot_solutions.jl")

function destroysolution(route::Route, edges, n_destroy_nodes::Int64)
    sum = 0
    for i = 0:n_destroy_nodes
        #route.route[1:end-n_destroy_nodes]
        route.route[1:end-n_destroy_nodes]
        sum += edge_dist(edges, route.route[1:end-i].id, route.route[1:end-(i+1)].id)

    return Route(route.route[1:end-n_destroy_nodes], route.dist - sum, route.reward)
end

function destruction(sol::Route[], edges, p::Float64)
    restricted_nodes = []
    for i = 1:length(sol)
        restricted_nodes  = vcat(restricted_nodes, [j.id for j in sol[i].route])

    for i = 1:length(sol)
        detroysol = deepcopy(sol[i])
        aux_sol = deepcopy(sol[i])

        nRoutesDestroy = int((length(detroysol.route)*p));
        destroysol = destroysolution(detroysol, edges, nRoutesDestroy)

end



