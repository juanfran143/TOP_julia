function parse_txt(file_path::String)
    open(file_path, "r") do file
        lines = readlines(file)

        n_nodes = parse(Int, split(lines[1])[2])
        n_vehicles = parse(Int, split(lines[2])[2])
        capacity = parse(Float64, split(lines[3])[2])

        nodes = Dict{Int64, Node}()
        for i in 4:length(lines)
            line = split(lines[i])
            x, y, reward = parse(Float64, line[1]), parse(Float64, line[2]), parse(Float64, line[3])
            node_id = i - 3
            nodes[node_id] = Node(node_id, x, y, reward, 0)
        end
        
        return n_vehicles, capacity, nodes
    end
end