using Random, Distributions, Combinatorics, DataStructures

function update_dict(edges::Dict{Int8, Dict{Int8, Float64}}, max_distance::Float64, 
    rl_dic::Dict{Array{Int64,1}, Array{Float64,1}}, new_route::Array{Int8,1}, route_reward::Float64)
    # rl_dic va a tener los siguientes atributos guardados por ruta
    #   - Reward medio
    #   - Número de simulaciones ejecutadas
    #   - % de fallo de la ruta (reliability)
    n_simulations_completed = 0
    n_fails = 0
    avg_reward = 0

    # Meter como parámetro: Número de simulaciones que hagamos cada vez que ejecutaremos (num_simulations) y número máximo de simulaciones para
    # no simular mas (max_simulations)
    num_simulations = 10
    max_simulations = 300

    if haskey(rl_dic, new_route)
        if rl_dic[new_route][2] >= max_simulations
            return rl_dic[new_route]
        else
            n_simulations_completed = rl_dic[new_route][2]
            n_fails = rl_dic[new_route][3]
            avg_reward = rl_dic[new_route][1]
        end
    end

    reward, fails = simulation_dict(edges, num_simulations, max_distance, new_route, route_reward)
    reward_input = (avg_reward*n_simulations_completed+reward*num_simulations)/(num_simulations+n_simulations_completed)
    fails_input = (n_fails*n_simulations_completed+fails*num_simulations)/(num_simulations+n_simulations_completed)
    return [reward_input, num_simulations+n_simulations_completed, fails_input]
    
end

function simulation_dict(edges::Dict{Int8, Dict{Int8, Float64}}, num_simulations::Int, capacity::Float64, route::Array{Int8,1},
    route_reward::Float64)
    avg_reward = []
    n_fails = 0
    for _ in 1:num_simulations
        dist = 0
        first_node = route[1]
        for next_node in route[2:end]
            t_ij = edge_dist(edges, first_node, next_node)
            dist += modify_value_lognormal(t_ij, t_ij*0.05)
            first_node = next_node
        end

        reward = route_reward
        if dist > capacity
            reward = 0
            n_fails += 1
        end
        push!(avg_reward, reward)
    end

    return (mean(avg_reward), n_fails/num_simulations)
end

function get_stochastic_solution(rl_dic::OrderedDict{Array{Int64,1}, Array{Float64,1}}, n_vehicles::Int64)
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


function large_simulation(edges::Dict{Int8, Dict{Int8, Float64}}, num_simulations::Int, capacity::Float64, selected_pairs::Vector{Any})
    total_reward = []
    
    for pair in selected_pairs
        route = pair[1]

        avg_reward = []
        n_fails = 0
        for _ in 1:num_simulations
            dist = 0
            first_node = Int8(route[1])
            for next_node in route[2:end]
                t_ij = edge_dist(edges, first_node, Int8(next_node))
                dist += modify_value_lognormal(t_ij, t_ij*0.05)
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
    end

    return sum(total_reward)
end