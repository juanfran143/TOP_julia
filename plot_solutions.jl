
function plot_routes(nodes,routes)
    list_x = []
    list_y = []
    for key in collect(keys(nodes))
        push!(list_x,(nodes[key].x))
        push!(list_y,(nodes[key].y))
    end
    p = plot()

    scatter!(p,list_x,list_y,color=:black, label="Nodes")
    colors = [:red,:blue,:green,:yellow]
    route_id=1
    for route in routes
        node_list = route.route
        c=0
        prev_x = 0
        prev_y = 0
        for node in node_list
            if c!=0
                plot!(p,[prev_x, node.x], [prev_y, node.y], color = colors[route_id], linewidth = 2,label="")
            end
            # plot!([prev_x, node.x], [prev_y, node.y], color = :red, linewidth = 2)
            prev_x = node.x
            prev_y = node.y
            c=c+1
        end  
        route_id =route_id+1  
    end
    # legend!(p, :topleft, ["Nodes", "Route 1", "Route 2"])
    display(p)
end