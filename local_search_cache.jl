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
    improve = false
    if length(nodes) >= 4
        dist = aRoute.dist
        for i in 1:length(nodes)-3
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
                dist = dist + (ae1 + ae2 + ae3) - (e1 + e2 + e3)
                node_aux1 = nodes[i+2]
                node_aux2 = nodes[i+1]
                deleteat!(nodes, i+1)
                insert!(nodes, i+1, node_aux1)

                deleteat!(nodes, i+2)
                insert!(nodes, i+2, node_aux2)
                improve = true
            end
        end
        return Route(nodes, dist, aRoute.reward), improve
    end
    return aRoute, improve
end

function improveWithCache(cache::Dict, newSol, edges, rl_dic, parameters)
    n = length(newSol)
    for i in 1:n
        route = newSol[i]
        route, improve = improveNodesOrder(route, edges)
        if improve
            new_route = [i.id for i in route.route]
            reward_input, n_simulations_completed, fails_input = update_dict(edges, rl_dic, new_route, route.reward, parameters)
            rl_dic[new_route] = [reward_input, n_simulations_completed, fails_input, route.dist, route.reward]
        end
        skey = obtainKey(route)

        if !haskey(cache, skey)
            cache[skey] = route
            newSol[i] = route
        else
            rCached = cache[skey]

            dif = rCached.dist - route.dist
            if dif > 0
                cache[skey] = route
            elseif dif != 0
                #TODO ver si funciona
                newSol[i] = cache[skey]
            end
        end
    end

    return newSol
end
