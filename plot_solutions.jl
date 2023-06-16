
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



function plot_routes_Sto(nodes,routes)
    list_x = []
    list_y = []
    rewards = []
    ids=[]
    for key in collect(keys(nodes))
        push!(list_x,(nodes[key].x))
        push!(list_y,(nodes[key].y))
        push!(rewards,(nodes[key].reward))
        push!(ids,(nodes[key].id))
    end
    p = plot()

    scatter!(p,list_x,list_y,color=:black, label="Nodes")

    # for i in 1:length(list_x)
    #     annotate!(p,list_x[i],list_y[i] + 0.2, text(string(rewards[i]) ))
    # end
    
    colors = [:red,:blue,:green,:yellow]
    route_id=1
    for route in routes
        node_list = route[1]
        c=0
        prev_x = 0
        prev_y = 0
        for node in node_list
            (nodes[node].x)
            if c!=0
                plot!(p,[prev_x, (nodes[node].x)], [prev_y,(nodes[node].y)], color = colors[route_id], linewidth = 2,label="")
            end
            prev_x = (nodes[node].x)
            prev_y = (nodes[node].y)
            c=c+1
        end  
        route_id =route_id+1  
    end
    display(p)
    for i in 1:length(list_x)
        annotate!(p,list_x[i],list_y[i] + 0.2, text(string(rewards[i]) ))
        # annotate!(p,list_x[i],list_y[i] + 0.2, text(string(ids[i]) ))
    end
    display(p)
end