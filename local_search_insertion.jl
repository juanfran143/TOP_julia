using Random, Distributions, Combinatorics, DataStructures, Dates, Plots, Base.Threads
include("structs.jl")

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

function destroy_solution(route, edges, n_destroy_nodes::Int64)
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

function destroy_solution_II(route, edges::Dict{Int8, Dict{Int8, Float64}}, n_destroy_nodes::Int64, nodes)
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
    saving = OrderedDict()
    for i in 2:length(destroysol.route)-1
        element_1 = destroysol.route[i].id
        element_2 = destroysol.route[i+1].id
        for (k, v) in nodes
            if k in restricted_nodes
                continue
            end
            dist = edge_dist(edges, element_1, Int8(k)) +  edge_dist(edges, Int8(k), element_2) - edge_dist(edges, element_1, element_2)
            if dist + destroysol.dist <= parameters["capacity"] 
                saving[(k, i)] = dist/v.reward
            end
        end
    end
    return saving
end

function insertion(destroysol, inserction_savings, nodes, capacity)
    best_route = []
    best_reward = destroysol.reward
    best_dist = destroysol.dist
    improve = false
    for _ in 1:5
        route_list = copy(destroysol.route)
        reward = destroysol.reward
        dist = destroysol.dist

        imposible_include = 0
        no_include = []
        key_list = collect(keys(inserction_savings))
        while imposible_include < 5 && length(key_list) > 0
            random_num = rand(1:min(length(key_list), 5))
            position = key_list[random_num][2]+1
            node = key_list[random_num][1]
            if position in no_include
                deleteat!(key_list, random_num)
                continue
            end
            if inserction_savings[key_list[random_num]]*reward + dist > capacity
                deleteat!(key_list, random_num)
                imposible_include += 1
                continue
            end
            imposible_include = 0
            push!(no_include, position)
            insert!(route_list, position, nodes[node])
            reward += nodes[node].reward
            dist += inserction_savings[key_list[random_num]]*reward
        end

        if best_reward < reward
            best_route = copy(route_list)
            best_reward = reward
            best_dist = dist
            improve = true
        end
    end

    return Route(copy(best_route), best_dist, best_reward), improve
end

function inserction(sol, edges, beta, rl_dic, parameters)
    restricted_nodes = []
    for i = 1:length(sol)
        restricted_nodes  = vcat(restricted_nodes, [j.id for j in sol[i].route])
    end
    best_list_sol = []
    for i = 1:length(sol)
        destroysol = deepcopy(sol[i])
        best_sol = deepcopy(sol[i])

        # TODO change p to p_inserction
        nRoutesDestroy = floor(Int, length(destroysol.route)*parameters["p"])

        
        # TODO change NumIterBrInLS to NumIterBrInLS_inserction
        for _ in 1:parameters["NumIterBrInLS"]
            #savings = copy(original_savings)
            restricted_nodes  = [j.id for j in best_sol.route]
            destroysol = destroy_solution_II(best_sol, edges, nRoutesDestroy, parameters["nodes"])
            route = destroysol
            improve = true
            while improve
                improve = false
                inserction_savings = insertion_savings(route, edges, restricted_nodes, parameters)
                inserction_savings = sort(collect(inserction_savings), by = x -> x[2], rev = false)
                inserction_savings = OrderedDict((kv[1][1], kv[1][2]) => kv[2] for kv in inserction_savings)
                route, improve = insertion(route, inserction_savings, parameters["nodes"], parameters["capacity"])
                restricted_nodes = vcat(restricted_nodes, [j.id for j in route.route])
            end
            #route = constructive_with_BR_destructive(destroysol, edges, beta, savings, rl_dic, parameters, restricted_nodes)
            if best_sol.reward < route.reward
                best_sol = deepcopy(route)
            end
        end
        push!(best_list_sol, best_sol)
    end

    return best_list_sol
end