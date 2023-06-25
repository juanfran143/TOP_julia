using Random, Distributions, Combinatorics, DataStructures, Distributed, Base.Threads

addprocs(2)

function modify_value_lognormal(mean::Float64, variance::Float64)
    mu = log(mean^2 / sqrt(mean^2 + variance))
    sigma = sqrt(log(1 + (variance / mean^2)))
    lognormal_dist = LogNormal(mu, sigma)
    return rand(lognormal_dist)
end


function update_dict(edges::Dict{Int8, Dict{Int8, Float64}},
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, new_route::Array{Int8,1}, route_reward::Float64, parameters)

    # rl_dic va a tener los siguientes atributos guardados por ruta
    #   - Reward medio
    #   - Número de simulaciones ejecutadas
    #   - % de fallo de la ruta (reliability)
    n_simulations_completed = 0
    n_fails = 0
    avg_reward = 0

    # Meter como parámetro: Número de simulaciones que hagamos cada vez que ejecutaremos (num_simulations) y número máximo de simulaciones para
    # no simular mas (max_simulations)
    num_simulations = parameters["num_simulations_per_merge"]
    max_simulations = parameters["max_simulations_per_route"]

    if haskey(rl_dic, new_route)
        if rl_dic[new_route][2] >= max_simulations
            return rl_dic[new_route]
        else
            n_simulations_completed = rl_dic[new_route][2]
            n_fails = rl_dic[new_route][3]
            avg_reward = rl_dic[new_route][1]
        end
    end

    reward, fails = simulation_dict(edges, new_route, route_reward, parameters)
    reward_input = (avg_reward*n_simulations_completed+reward*num_simulations)/(num_simulations+n_simulations_completed)
    fails_input = (n_fails*n_simulations_completed+fails*num_simulations)/(num_simulations+n_simulations_completed)
    return [reward_input, num_simulations+n_simulations_completed, fails_input]
    
end

function single_simulation_dict(edges::Dict{Int8, Dict{Int8, Float64}}, route::Array{Int8,1}, route_reward::Float64, parameters, fails::Atomic{Int64}, avg_reward)
    thread_number_sims = floor(Int, parameters["num_simulations_per_merge"]/4)
    local_array = Float64[]
    
    for _ in 1:thread_number_sims
        dist = 0
        first_node = route[1]

        for next_node in route[2:end]
            t_ij = edge_dist(edges, first_node, next_node)
            dist += modify_value_lognormal(t_ij, t_ij * parameters["var_lognormal"])
            first_node = next_node
        end

        reward = route_reward
        if dist > parameters["capacity"]
            reward = 0
            atomic_add!(fails, 1)
        end
        push!(local_array, reward)
    end
    
    push!(avg_reward, mean(local_array))
end


function simulation_dict(edges::Dict{Int8, Dict{Int8, Float64}}, route::Array{Int8,1}, route_reward::Float64, parameters)
    fails = Atomic{Int64}(0)
    avg_reward = []
    @threads for _ in 1:4
        single_simulation_dict(edges, route, route_reward, parameters, fails, avg_reward)
    end
    avg_reward = vcat(avg_reward...)
    return (mean(avg_reward), fails.value / parameters["num_simulations_per_merge"])              
end



function reorder_rl_dict(rl_dict, beta)
    aux = OrderedDict{Array{Int64,1}, Array{Float64,1}}()
    keys_list = collect(keys(rl_dict))
    while !isempty(rl_dict)
        position = Int(floor((log(rand()) / log(1 - beta))) % length(rl_dict)) + 1
        key = keys_list[position]
        aux[key] = pop!(rl_dict, key)
        deleteat!(keys_list, position)
    end
    return aux    
end

function get_stochastic_solution_br(rl_dic::OrderedDict{Array{Int64,1}, Array{Float64,1}}, parameters) 
    rl_dic_max = OrderedDict{Array{Int64,1}, Array{Float64,1}}()
    for (key, value) in rl_dic
        if length(rl_dic_max) >= length(rl_dic)
            break
        end
        rl_dic_max[key] = value
    end

    #Stochastic route
    
    stochastic_reward = [valor[1] for valor in values(rl_dic_max)]
    best_routes_sto, best_reward_sto = simple_MIP(keys(rl_dic_max),stochastic_reward, parameters["n_vehicles"])
    best_pairs_sto = []

    for route in best_routes_sto
        push!(best_pairs_sto, (route, rl_dic_max[route]))
    end

    #Deterministic route

    deterministic_reward = [valor[5] for valor in values(rl_dic_max)]
    best_routes_det, best_reward_det = simple_MIP(keys(rl_dic_max),deterministic_reward, parameters["n_vehicles"])
    best_pairs_det = []

    for route in best_routes_det
        push!(best_pairs_det, (route, rl_dic_max[route]))
    end

    # println("Deterministic Solution: ", best_pairs_det, "\n" )
    # println("Deterministic Reward: ", best_reward_det, "\n" )

    return best_pairs_sto, best_reward_sto, best_pairs_det, best_reward_det
end


function large_simulation(edges::Dict{Int8, Dict{Int8, Float64}}, num_simulations::Int, capacity::Float64, selected_pairs::Vector{Any}, variance:: Float64)
    total_reward = []
    
    n_fails_total = []
     
    # println("Sctochastic solutions : ")
    for pair in selected_pairs
        # println(pair)
        route = pair[1]

        avg_reward = []
        n_fails = 0
        for _ in 1:num_simulations
            dist = 0
            first_node = Int8(route[1])
            for next_node in route[2:end]
                t_ij = edge_dist(edges, first_node, Int8(next_node))
                dist += modify_value_lognormal(t_ij, t_ij*variance)
                first_node = Int8(next_node)
            end

            reward = pair[2][5]
            if dist > capacity
                reward = 0
                n_fails += 1
            end
            push!(avg_reward, reward)
        end

        push!(total_reward, mean(avg_reward))
        push!(n_fails_total, n_fails)
    end
    # reliability
    # println("reliability: ", 1-mean(n_fails_total)/num_simulations)
    return sum(total_reward), 1-mean(n_fails_total)/num_simulations
end

function get_stochastic_solution_greedy(rl_dic::OrderedDict{Array{Int64,1}, Array{Float64,1}}, n_vehicles::Int64)
    
    #TODO En lugar de coger siempre el 1º elemento del diccionario, coger uno basándonos en una geométrica (Bias)

    # Crear un conjunto (Pensar si mejor una lista?) vacío para rastrear los nodos seleccionados
    selected_nodes = Set{Int}([])

    # Crear una lista vacía para almacenar los pares seleccionados
    selected_pairs = []

    """
    for kv in rl_dic
        println("Key: ", kv[1], ", Value: ", kv[2])
    end
    """
    # Iterar sobre los pares del dict
    for (key, value) in rl_dic
        # Verificar si todos los nodos en la clave (excepto nodo origen y el destino) no han sido seleccionados antes
        if !any(node ∈ selected_nodes for node in key[2:end-1])
            # Si todos los nodos son únicos, añadirlos a los nodos seleccionados
            for node in key
                push!(selected_nodes, node)
            end

            # Añadir el par a la lista de pares seleccionados
            push!(selected_pairs, (key, value))

            if length(selected_pairs) >= n_vehicles
                break
            end
        end
    end

    return selected_pairs
end
