using Random, Distributions, Combinatorics, DataStructures, Dates, Plots, Base.Threads, JuMP,GLPK


function dummy_solution(nodes::Dict{Int, Node}, edges::Dict{Int8, Dict{Int8, Float64}}, capacity, last_node)
    routes = Dict{Int, Route}()
    for (id, node) in pairs(nodes)
        if id == 1 || id == last_node  # Ignora el primer y el último nodo
            continue
        end
        
        distances = edge_dist(edges, nodes[1].id, node.id) + edge_dist(edges, node.id, nodes[last_node].id)
    
        if distances <= capacity
            node_list = [nodes[1], node, nodes[last_node]]
            routes[id-1] = Route(node_list, distances, node.reward)
            node.route_id = id-1
        else
            delete!(nodes, id)
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
            if i != j
                saving = edge_dist(edges, depot.id, nodes[j].id) + edge_dist(edges, nodes[i].id, nodes[length(nodes)].id) - edge_dist(edges, nodes[i].id, nodes[j].id)
                savings_dict[(i, j)] = saving*alpha+(1-alpha)*(nodes[i].reward+nodes[j].reward)
            end
        end
    end
    sorted_savings_dict = sort(collect(savings_dict), by = x -> x[2], rev = true)
    sorted_savings_dict = OrderedDict(kv[1] => kv[2] for kv in sorted_savings_dict)
    return sorted_savings_dict
end

function calculate_savings_dict_vecinos(nodes::Dict{Int, Node}, edges::Dict{Int8, Dict{Int8, Float64}}, alpha:: Float16,parameters)
        savings_dict = Dict{Tuple{Int, Int}, Float64}()

        depot = nodes[1]
        n = length(nodes)
        last_node = nodes[n]
        dictionary_dist_neight= Dict{Int16, Float64}();
        for i in 2:n-1
            neight_dist_list =[]
            for j in 2:n-1
                push!(neight_dist_list,edge_dist(edges, nodes[i].id, nodes[j].id))
            end
            dictionary_dist_neight[i] = Float64(sort(neight_dist_list)[8])

        end
            
        for i in 2:n-1
            # count = 0
            for j in 2:n-1
                if i != j && dictionary_dist_neight[Int16(i)] >= edge_dist(edges, nodes[i].id, nodes[j].id) &&  edge_dist(edges, nodes[i].id, nodes[j].id) <= parameters["capacity"] - edge_dist(edges, depot.id, nodes[i].id) - edge_dist(edges,nodes[j].id, last_node.id)
                    # count+=1
                    saving = edge_dist(edges, depot.id, nodes[j].id) + edge_dist(edges, nodes[i].id, nodes[length(nodes)].id) - edge_dist(edges, nodes[i].id, nodes[j].id)
                    savings_dict[(i, j)] = saving*alpha+(1-alpha)*(nodes[i].reward+nodes[j].reward)
                end
            end
            # println(i,'/',count)
        end
        sorted_savings_dict = sort(collect(savings_dict), by = x -> x[2], rev = true)
        sorted_savings_dict = OrderedDict(kv[1] => kv[2] for kv in sorted_savings_dict)
        return sorted_savings_dict
end

function merge_routes(Node1::Node, Node2::Node, edges::Dict{Int8, Dict{Int8, Float64}}, routes::Dict{Int, Route}, max_distance::Float64, 
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, parameters)
    route1 = routes[Node1.route_id]
    route2 = routes[Node2.route_id]

    if Node1.route_id != Node2.route_id && route1.route[end-1].id == Node1.id && route2.route[2].id == Node2.id
        # Fusionar las rutas excluyendo el nodo final de la primera ruta y el nodo de inicio de la segunda ruta
        merged_route_nodes = vcat(route1.route[1:end-1], route2.route[2:end])
        new_route = [i.id for i in merged_route_nodes]

        # Aprendizaje en el merge: Si es una mierda, entonces no las juntamos
        join = true
        if haskey(rl_dic, new_route)
            # TODO Pensar un poco esto
            if (rl_dic[new_route][2] == parameters["num_simulations_per_merge"] && rl_dic[new_route][3] >= parameters["max_reliability_to_merge_routes"])
                join = false
            end
        end

        # 1-2-3-5 (route1)
        # 1-4-5 (route2)
        # S_34 => 1-2-3-4-5  
        # Calcular distancia:
        # 1.- edges(1, 2) +  edges(2, 3) + .... edges(4, 5)
        # 2.- route1.distance + route2.distance - edges(3, 5) - edges(1, 4) + edges(3, 4) 1-2-3//5 1//4-5    3-4 
        if join
            merged_route_distance = route1.dist + route2.dist - edge_dist(edges, route1.route[end-1].id, route1.route[end].id) - edge_dist(edges, route2.route[1].id, route2.route[2].id) + edge_dist(edges, Node1.id, Node2.id)
  
            # Verificar si la distancia total de la nueva ruta fusionada está dentro del límite de distancia máximo
            if merged_route_distance <= max_distance
                merged_route_reward = route1.reward + route2.reward
                routes[Node1.route_id] = Route(merged_route_nodes, merged_route_distance, merged_route_reward)
                        
                original_route_id = Node2.route_id
                for r in routes[original_route_id].route
                    r.route_id = Node1.route_id
                end
                delete!(routes, original_route_id)

                #Algoritmo Juanfran y Antonio contienen el siguiente cacho de código en común
                
                if merged_route_distance >= parameters["capacity"]*parameters["max_percentaje_of_distance_to_do_simulations"]
                    reward_input, n_simulations_completed, fails_input = update_dict(edges, rl_dic, new_route, merged_route_reward, parameters)

                    rl_dic[new_route] = [reward_input, n_simulations_completed, fails_input, merged_route_distance, merged_route_reward]
                end
            end
        end
        
        
    end
end

function reorder_saving_list(savings::OrderedDict{Tuple{Int, Int}, Float64}, beta::Float16)
    aux = OrderedDict{Tuple{Int, Int}, Float64}()
    keys_list = collect(keys(savings))
    while !isempty(savings)
        position = Int(floor((log(rand()) / log(1 - beta))) % length(savings)) + 1
        # print(position)
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

function heuristic_with_BR(edges::Dict{Int8, Dict{Int8, Float64}}, beta, savings, rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, parameters)
    routes = dummy_solution(parameters["nodes"], edges, parameters["capacity"], parameters["last_node"])
    savings = reorder_saving_list(savings, beta)
    for key in keys(savings)
        if haskey(parameters["nodes"], key[1]) && haskey(parameters["nodes"], key[2])
            NodeX = parameters["nodes"][key[1]]
            NodeY = parameters["nodes"][key[2]]
            merge_routes(NodeX, NodeY, edges, routes, parameters["capacity"], rl_dic, parameters)
        end
    end
    sorted_routes = sort(collect(routes), by = x -> x[2].reward, rev = true)
    sorted_routes = Dict(kv[1] => kv[2] for kv in sorted_routes)

    return get_reward_and_route(sorted_routes, parameters["n_vehicles"])
end

function original(iter)
    return 1
end

function progresive(iter)
    return (iter+1)/1000
end

function progresive_exponencial(iter)
    return 2^(iter+1)/1000
end

function algo_time(txt::Dict, time::Int16)
    #alpha = Float16(0.3)
    #beta = Float16(0.1)

    #return n_nodes, n_vehicles, capacity, nodes
    n_vehicles, capacity, nodes = parse_txt(string(txt["instance"]))

    parameters = Dict(
        # Problem
        "start_node" => 1,
        "last_node" => length(nodes),
        "n_vehicles" => n_vehicles,
        "capacity" => capacity,
        "nodes" => nodes,
        
        # simulations
        "var_lognormal" => txt["variance"],
        "large_simulation_simulations" => txt["simulations_large_simulation"],

        # RL_DICT
        "num_simulations_per_merge" => txt["num_simulations_per_merge"],
        "max_simulations_per_route" => txt["max_simulations_per_route"],
        "max_reliability_to_merge_routes" => txt["max_reliability_to_merge_routes"],
        "max_percentaje_of_distance_to_do_simulations" => txt["max_percentaje_of_distance_to_do_simulations"],

        # Reactive 
        "function" => txt["function_name"],
        "active_agresive" => txt["active_agresive"],
        "alpha_candidates" => [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
        "beta_cancidates" => [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7],
        
        #LS_2_opt
        "LS_2_opt" => txt["LS_2_opt"],

        #LS Destoyer
        "LS_destroyer" => txt["LS_destroyer"],
        "p" => txt["p"],
        "NumIterBrInLS" => txt["NumIterBrInLS"]
    )

    edges = precalculate_distances(nodes::Dict{Int64, Node})
    list_savings_dict_alpha = Dict{Float16,OrderedDict{Tuple{Int, Int}, Float64}}()
    for i in parameters["alpha_candidates"]
        list_savings_dict_alpha[Float16(i)] = calculate_savings_dict_vecinos(nodes, edges, Float16(i),parameters)
    end

    best_reward = 0
    best_route = Route[]
    rl_dic = Dict{Array{Int64,1}, Array{Float64,1}}()
    Param_dict,params,no_null_index,cum_probabilities = Init_dict_probabilities(parameters["alpha_candidates"], parameters["beta_cancidates"])
    cache = Dict()

    duration_senconds = time
    iter = 1
    start_time = now()
    while now()-start_time<Second(duration_senconds) 

        (alpha,beta) = choose_with_probability(params,no_null_index, cum_probabilities)

        original_savings=list_savings_dict_alpha[alpha]

        savings = copy(original_savings)

        reward, routes = heuristic_with_BR(edges, beta, savings, rl_dic, parameters)
        
        # 1º LS 2 y 3-opt
        if parameters["LS_2_opt"]
            routes = improveWithCache_2_3opt(cache, routes, edges, rl_dic, parameters)
        end
        
        # 2º LS_destroyer
        if parameters["LS_destroyer"]
            savings = copy(original_savings)
            routes = destruction(routes, edges, beta, savings, rl_dic, parameters)
        end

        if reward > best_reward
            best_reward = reward
            best_route = copy(routes)
        end
            
        if reward > Param_dict[(alpha,beta)][2] && iter <= 5000
            Param_dict[(alpha,beta)][2]=reward
        end
        
        # TODO: ¿Quieres parametrizar también estos valores? 

        if iter % 1000 == 999 && iter <= 5000
            k = eval(Symbol(parameters["function"]))(iter)
            params,no_null_index,cum_probabilities =  modify_param_dictionary_RS(Param_dict, k, parameters["active_agresive"])
        end
        iter += 1

    end
    
    # plot_routes(nodes,best_route)

    # println("Número de iteraciones: ", iter)
    # println("")
    rl_dic_sorted = OrderedDict(sort(collect(rl_dic), by = x -> x[2][1], rev = true))
    # println("Tamaño del Dic ", length(rl_dic_sorted) ,"\n")
    stochastic_solution, stochastic_reward, deterministic_solution, deterministic_reward = get_stochastic_solution_br(rl_dic_sorted, parameters)
    # plot_routes_Sto(nodes,deterministic_solution)
    plot_routes_Sto(nodes,stochastic_solution)
    stochastic_reward_large, reliability = large_simulation(edges, parameters["large_simulation_simulations"], parameters["capacity"], stochastic_solution, parameters["var_lognormal"])
    # println("El reward estocástico es: ",stochastic_reward)
    # println("El reward real es: ", stochastic_reward_large)

    return deterministic_reward, stochastic_reward_large, reliability, length(rl_dic_sorted), iter
end
