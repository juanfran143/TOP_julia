include("structs.jl")
include("parse.jl")
include("get_edges.jl")
include("simulation.jl")
include("rl_dictionary.jl")



function test()
    seed = 123
    Random.seed!(seed)

    println(rand())
end

test()