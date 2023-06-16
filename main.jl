using DelimitedFiles

include("structs.jl")
include("parse.jl")
include("get_edges.jl")
include("simulation.jl")
include("rl_dictionary.jl")
include("reactive_Search.jl")
include("algorithm.jl")

function main()
    raw_data = readdlm("config.txt", '\n')

    file = open("Output_ComparativaLS.txt", "w")

    write(file, "Instancia;num_simulations_per_merge;max_simulations_per_route;max_reliability_to_merge_routes;max_percentaje_of_distance_to_do_simulations;num_iterations_stochastic_solution;beta_stochastic_solution;det_reward;stochastic_reward","\n")
    # Itera sobre cada línea en raw_data
    for line in eachrow(raw_data)
        str = line[1]
        str_splitted = split(str)
        if startswith(line[1], "#")
            continue
        end

        # Separa los datos en sus respectivos parámetros
        instance, num_simulations_per_merge, max_simulations_per_route, max_reliability_to_merge_routes, 
        max_percentaje_of_distance_to_do_simulations, num_iterations_stochastic_solution, 
        beta_stochastic_solution, function_name, time, LS_destroyer = str_splitted

        # Crea un nuevo diccionario para los parámetros de esta línea
        println(instance)
        println("")
        txt = Dict(
            "instance" => instance,
            "num_simulations_per_merge" => parse(Int, num_simulations_per_merge),
            "max_simulations_per_route" => parse(Int, max_simulations_per_route),
            "max_reliability_to_merge_routes" => parse(Float64, max_reliability_to_merge_routes),
            "max_percentaje_of_distance_to_do_simulations" => eval(Meta.parse(max_percentaje_of_distance_to_do_simulations)),
            "num_iterations_stochastic_solution" => parse(Int, num_iterations_stochastic_solution),
            "beta_stochastic_solution" => parse(Float64, beta_stochastic_solution),
            "LS_destroyer" => parse(Bool, LS_destroyer)
        )
        
        det_reward, stochastic_reward = algo_time(txt, Int16(parse(Int, time)))
        write(file, txt["instance"],";",string(txt["num_simulations_per_merge"]),";",string(txt["max_simulations_per_route"]),";",
        string(txt["max_reliability_to_merge_routes"]),";",string(txt["max_percentaje_of_distance_to_do_simulations"]),";",
        string(txt["num_iterations_stochastic_solution"]),";",string(txt["beta_stochastic_solution"]),";",string(det_reward),";",string(stochastic_reward),"\n")
    end  
end

main()
