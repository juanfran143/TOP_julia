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

function insertion_savings(destroysol, parameters)
    nodes = parameters["nodes"]
    for n in nodes
        
    end
end

function inserction(sol::Vector{Route}, edges, beta, original_savings, rl_dic, parameters)
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
        destroysol = destroy_solution(detroysol, edges, nRoutesDestroy)
        
        # TODO change NumIterBrInLS to NumIterBrInLS_inserction
        for _ in 1:parameters["NumIterBrInLS"]
            #savings = copy(original_savings)
            inserction_savings = insertion_savings(destroysol, parameters)
            #route = constructive_with_BR_destructive(destroysol, edges, beta, savings, rl_dic, parameters, restricted_nodes)
            if best_sol.reward < route.reward
                best_sol = deepcopy(route)
            end
        end
        push!(best_list_sol, best_sol)
    end

    return best_list_sol
end