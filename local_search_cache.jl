using LinearAlgebra, Random


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

function improveNodesOrder_2opt(aRoute::Route, edges)
    nodes = aRoute.route
    improve = false
    if length(nodes) >= 4
        dist = aRoute.dist
        for i in 1:length(nodes)-3
            #edge_dist(edge::Dict{Int8, Dict{Int8, Float64}}, i::Int8, j::Int8)
            e1 = edge_dist(edges, nodes[i].id, nodes[i+1].id)
            e2 = edge_dist(edges, nodes[i + 2].id, nodes[i+3].id)

            # El e3 no hace falta, si son Arcos sí que haría falta
            # e3 = edge_dist(edges, nodes[i + 1].id, nodes[i+2].id) 
            currentCosts = e1 + e2 # + e3
            
            #ae := Alternative edge
            ae1 = edge_dist(edges, nodes[i].id, nodes[i+2].id)
            ae2 = edge_dist(edges, nodes[i+1].id, nodes[i+3].id) 

            # El e3 no hace falta, si son Arcos sí que haría falta
            # ae3 = edge_dist(edges, nodes[i+2].id, nodes[i+1].id)

            alterCosts = ae1 + ae2 # + ae3
            if (alterCosts < currentCosts)
                #dist = dist + (ae1 + ae2 + ae3) - (e1 + e2 + e3)
                dist = dist + (ae1 + ae2) - (e1 + e2)
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

function improveNodesOrder_3opt(aRoute::Route, edges)
    nodes = aRoute.route
    improve = false
    if length(nodes) >= 5
        dist = aRoute.dist
        for i in 1:length(nodes)-4
            #edge_dist(edge::Dict{Int8, Dict{Int8, Float64}}, i::Int8, j::Int8)
            e1 = edge_dist(edges, nodes[i].id, nodes[i+1].id)
            e2 = edge_dist(edges, nodes[i+3].id, nodes[i+4].id)
            currentCosts = e1 + e2
            
            #ae := Alternative edge
            ae1 = edge_dist(edges, nodes[i].id, nodes[i+3].id)
            ae2 = edge_dist(edges, nodes[i+1].id, nodes[i+4].id)

            alterCosts = ae1 + ae2
            if (alterCosts < currentCosts)
                #println("i = ", i)
                #println("Old route: ", nodes)
                dist = dist + (ae1 + ae2) - (e1 + e2)
                node_aux1 = nodes[i+3]
                node_aux2 = nodes[i+1]
                deleteat!(nodes, i+1)
                insert!(nodes, i+1, node_aux1)

                deleteat!(nodes, i+3)
                insert!(nodes, i+3, node_aux2)
                #println("New route: ", nodes)
                #println("")
                improve = true
            end
        end
        return Route(nodes, dist, aRoute.reward), improve
    end
    return aRoute, improve
end

function improveWithCache_2_3opt(cache::Dict, newSol, edges, rl_dic, parameters)
    n = length(newSol)
    for i in 1:n
        route = newSol[i]
        route, improve_2opt = improveNodesOrder_2opt(route, edges)
        route, improve_3opt = improveNodesOrder_3opt(route, edges)
        improve = improve_2opt || improve_3opt
        if improve && route.dist > parameters["capacity"]*parameters["max_percentaje_of_distance_to_do_simulations"]
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


function improveWithCache_2opt(cache::Dict, newSol, edges, rl_dic, parameters)
    n = length(newSol)
    for i in 1:n
        route = newSol[i]
        route, improve = improveNodesOrder_2opt(route, edges)
        if improve && route.dist > parameters["capacity"]*parameters["max_percentaje_of_distance_to_do_simulations"]
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
