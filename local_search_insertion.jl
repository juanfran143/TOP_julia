using Random, Distributions, Combinatorics, DataStructures, Dates, Plots, Base.Threads


function reorder_inserction_saving_list(inserction_saving::OrderedDict{Tuple{Int, Int}, Float64}, beta::Float16)
    aux = OrderedDict{Tuple{Int, Int}, Float64}()
    keys_list = collect(keys(inserction_saving))
    while !isempty(inserction_saving)
        position = Int(floor((log(rand()) / log(1 - beta))) % length(inserction_saving)) + 1
        # print(position)
        key = keys_list[position]
        aux[key] = pop!(inserction_saving, key)
        deleteat!(keys_list, position)
    end
    return aux    
end

function destroy_solution(route::Route, edges, n_destroy_nodes::Int64)
    sum = 0
    non_reward = 0
    for i = 0:n_destroy_nodes
        #route.route[1:end-n_destroy_nodes]
        non_reward += route.route[end-(i+1)].reward
        sum += edge_dist(edges, route.route[end-i].id, route.route[end-(i+1)].id)
    end
    sum -= edge_dist(edges, route.route[end-(n_destroy_nodes+1)].id, route.route[end].id)
    non_reward -= route.route[end-(n_destroy_nodes+1)].reward 

    return Route(vcat(route.route[1:end-(n_destroy_nodes+1)], route.route[end]), route.dist - sum, route.reward-non_reward)
end

function eval_solution(route, edges::Dict{Int8, Dict{Int8, Float64}})
    dist = 0
    for i = 1:length(route)-1
        dist += edge_dist(edges, route[i].id, route[i+1].id) 
    end

    return dist
end

function destroy_solution_II(route::Route, edges::Dict{Int8, Dict{Int8, Float64}}, n_destroy_nodes::Int64, nodes)
    non_reward = 0
    route_list = copy(route.route)
    for _ = 0:n_destroy_nodes
        if length(route_list) <= 2
            break
        end
        random_element = rand(2:length(route_list)-1)
        non_reward += nodes[route_list[random_element].id].reward
        deleteat!(route_list, random_element)
    end
    dist = eval_solution(route_list, edges) 

    return Route(route_list, dist, route.reward-non_reward)
end

function insertion_savings(destroysol, edges, restricted_nodes, parameters)
    nodes = parameters["nodes"]
    # TODO pensar si hacer TODAS las combinaciones o no
    for i in 2:length(destroysol)-1
        saving = OrderedDict()
        element_1 = destroysol[i].id
        element_2 = destroysol[i+1].id
        for n in nodes
            if n in restricted_nodes
                continue
            end
            dist = edge_dist(edges, element_1, n.id) +  edge_dist(edges, n.id, element_2) - edge_dist(edges, element_1, element_2)
            if dist + destroy_solution.dist < parameters["capacity"] 
                saving[(n, i)] = dist/n.reward
            end
        end
    end
    return saving
end

function insertion(destroysol, inserction_savings, nodes, capacity)
    best_route = []
    best_reward = destroysol.reward
    best_dist = destroysol.dist
    for _ in 1:100
        route_list = copy(destroysol.route)
        reward = destroysol.reward
        dist = destroysol.dist

        imposible_include = 0
        no_include = []
        key_list = keys(inserction_savings)
        while imposible_include < 5 && length(key_list) > 0
            random_num = rand(1:min(length(key_list), 5))
            position = key_list[random_num][2]
            node = key_list[random_num][1]
            if position in no_include
                delete!(key_list, random_num)
                continue
            end
            if inserction_savings[key_list[random_num]]*reward + dist > capacity
                imposible_include += 1
                continue
            end
            push!(no_include, position)
            insert!(route_list.route, position, node)
            reward = nodes[node].reward
            dist += inserction_savings[key_list[random_num]]*reward
        end

        if best_reward < reward
            best_route = route_list
            best_reward = reward
            best_dist = dist
        end
    end

    return Route(best_route, best_dist, best_reward)
end

function inserction(sol::Vector{Route}, edges, beta, rl_dic, parameters)
    restricted_nodes = []
    for i = 1:length(sol)
        restricted_nodes  = vcat(restricted_nodes, [j.id for j in sol[i].route])
    end
    best_list_sol = []
    for i = 1:length(sol)
        detroysol = deepcopy(sol[i])
        best_sol = deepcopy(sol[i])

        # TODO change p to p_inserction
        nRoutesDestroy = floor(Int, length(detroysol.route)*parameters["p"])

        
        # TODO change NumIterBrInLS to NumIterBrInLS_inserction
        for _ in 1:parameters["NumIterBrInLS"]
            #savings = copy(original_savings)
            destroysol = destroy_solution_II(detroysol, edges, nRoutesDestroy, parameters["nodes"])
            inserction_savings = insertion_savings(destroysol, edges, restricted_nodes, parameters)
            inserction_savings = sort(collect(inserction_savings), by = x -> x[3], rev = false)
            inserction_savings = OrderedDict((kv[1], kv[2]) => kv[3] for kv in inserction_savings)
            route = insertion(destroysol, inserction_savings, parameters["nodes"], parameters["capacity"])
            #route = constructive_with_BR_destructive(destroysol, edges, beta, savings, rl_dic, parameters, restricted_nodes)
            if best_sol.reward < route.reward
                best_sol = deepcopy(route)
            end
        end
        push!(best_list_sol, best_sol)
    end

    return best_list_sol
end