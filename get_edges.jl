function precalculate_distances(nodes::Dict{Int64, Node})
    edges = Dict{Int8, Dict{Int8, Float64}}()
    for i in keys(nodes)
        edges[i] = Dict{Int64, Float64}() 
        for j in keys(nodes)
            edges[i][j] = distance(nodes[i], nodes[j])
        end
    end
    return edges
end

function edge_dist(edge::Dict{Int8, Dict{Int8, Float64}}, i::Int8, j::Int8)
    if i>j
        return edge[j][i]
    end
    return edge[i][j]
end

function distance(NodeX::Node, NodeY::Node)
    return sqrt((NodeX.x-NodeY.x)^2+(NodeX.y-NodeY.y)^2)
end