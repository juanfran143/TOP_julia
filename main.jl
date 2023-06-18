using DelimitedFiles

include("structs.jl")
include("parse.jl")
include("get_edges.jl")
include("rl_dictionary_MIP.jl")
include("reactive_Search.jl")
include("local_search_cache.jl")
include("plot_solutions.jl")
include("iterativeMIP.jl")
include("algorithm.jl")
include("local_search_destruction.jl")

function main()
    name_output = "Output.txt"
    raw_data = readdlm("config.txt", '\n')

    file = open(name_output, "w")

    write(file, "Instancia;seed;num_simulations_per_merge;max_simulations_per_route;max_reliability_to_merge_routes;max_percentaje_of_distance_to_do_simulations;det_reward;stochastic_reward","\n")
    close(file) 
    # Itera sobre cada línea en raw_data
    for line in eachrow(raw_data)
        file = open(name_output, "a")
        str = line[1]
        str_splitted = split(str)
        if startswith(line[1], "#")
            continue
        end

        # Separa los datos en sus respectivos parámetros
        instance, seed, num_simulations_per_merge, max_simulations_per_route, max_reliability_to_merge_routes, 
        max_percentaje_of_distance_to_do_simulations, active_agresive, function_name, time, LS_destroyer, LS_2_opt, simulations_large_simulation, variance, p, NumIterBrInLS = str_splitted
        
        Random.seed!(parse(Int, seed))

        # Crea un nuevo diccionario para los parámetros de esta línea
        println(instance)
        println("")
        txt = Dict(
            "instance" => instance,
            "seed" => seed,
            "num_simulations_per_merge" => parse(Int, num_simulations_per_merge),
            "max_simulations_per_route" => parse(Int, max_simulations_per_route),
            "max_reliability_to_merge_routes" => parse(Float64, max_reliability_to_merge_routes),
            "max_percentaje_of_distance_to_do_simulations" => eval(Meta.parse(max_percentaje_of_distance_to_do_simulations)),

            "active_agresive" => parse(Bool, active_agresive),
            "function_name" => function_name,

            "LS_destroyer" => parse(Bool, LS_destroyer),
            "LS_2_opt" => parse(Bool, LS_2_opt),


            "simulations_large_simulation" => parse(Int, simulations_large_simulation),
            "variance" => parse(Float64, variance),

            "p" => parse(Float64, p),
            "NumIterBrInLS" => parse(Int, NumIterBrInLS)

        )
        
        det_reward, stochastic_reward = algo_time(txt, Int16(parse(Int, time)))
        println(file, txt["instance"],";", txt["seed"],";",string(txt["num_simulations_per_merge"]),";",string(txt["max_simulations_per_route"]),";",
        string(txt["max_reliability_to_merge_routes"]),";",string(txt["max_percentaje_of_distance_to_do_simulations"]),";",
        string(txt["active_agresive"]),";",string(txt["function_name"]),";",string(time),";",string(txt["LS_destroyer"]),";",
        string(txt["LS_2_opt"]),";",string(txt["simulations_large_simulation"]),";",string(txt["variance"]),";",
        string(txt["p"]),";",string(txt["NumIterBrInLS"]),";",
        string(det_reward),";",string(stochastic_reward))
        close(file) 
        # Instance function time LS_Destroyer LS_2_opt simulations_large_simulation variance p NumIterBrInLS
# Instances/Set_102_234/p7.4.n.txt 123456 100 200 0.3 4/5 true original 100 true true 1000 0.05 0.2 5
    end  
end

main()
