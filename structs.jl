using Random, Distributions, Combinatorics, DataStructures

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

function Base.deepcopy(r::Route)
    new_route = deepcopy(r.route)
    return Route(new_route, r.dist, r.reward)
end