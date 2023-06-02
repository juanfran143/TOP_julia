include("structs.jl")
include("parse.jl")
include("get_edges.jl")
include("simulation.jl")
include("rl_dictionary.jl")



function test()
    n_vehicles, capacity, nodes = parse_txt("C:/Users/jfg14/OneDrive/Documentos/GitHub/TOP_julia/Instances/Set_64_234/p6.2.n.txt")
    a = Route(Node[Node(1, 0.0, -7.0, 0.0, 8), Node(5, 0.0, -5.0, 6.0, 4), Node(13, 0.0, -3.0, 12.0, 4), Node(19, 1.0, -2.0, 18.0, 8), Node(26, 2.0, -1.0, 24.0, 8), Node(41, 2.0, 1.0, 24.0, 8), Node(33, 1.0, 0.0, 24.0, 8), Node(32, -1.0, 0.0, 24.0, 8), Node(24, -2.0, -1.0, 24.0, 8), Node(31, -3.0, 0.0, 30.0, 1), Node(23, -4.0, -1.0, 30.0, 1), Node(22, -6.0, -1.0, 36.0, 3), Node(37, -6.0, 1.0, 36.0, 3), Node(30, -5.0, 0.0, 36.0, 3), Node(38, -4.0, 1.0, 30.0, 1), Node(50, -4.0, 3.0, 24.0, 3), Node(55, -3.0, 4.0, 18.0, 3), Node(59, -2.0, 5.0, 12.0, 3), Node(62, -1.0, 6.0, 6.0, 3), Node(64, 0.0, 7.0, 0.0, 8)], 30.97056274847715, 414.0)
    edges = precalculate_distances(nodes::Dict{Int64, Node})
    dist = 0
    route = a.route
    first_node = route[1]
    for next_node in route[2:end]
        dist += edge_dist(edges, first_node.id, next_node.id)
        first_node = next_node
    end
    print(dist)
end

test()