# using Random, Distributions, Combinatorics, DataStructures, Distributed

# addprocs(4) #number of workers


# function modify_value_lognormal(mean::Float64, variance::Float64)
#     mu = log(mean^2 / sqrt(mean^2 + variance))
#     sigma = sqrt(log(1 + (variance / mean^2)))
#     lognormal_dist = LogNormal(mu, sigma)
#     return rand(lognormal_dist)
# end


# function simulation(edges::Dict{Int8, Dict{Int8, Float64}}, num_simulations::Int, capacity::Float64, routes::Array{Route,1})
#     avg_reward = []
#     for _ in 1:num_simulations
#         reward_route = []
#         for route in routes
#             dist = 0
#             first_node = route.route[1]
#             for next_node in route.route[2:end]
#                 dist += modify_value_lognormal(edge_dist(edges, first_node.id, next_node.id), 0.2)
#                 first_node = next_node
#             end

#             reward = route.reward
#             if dist > capacity
#                 reward = 0
#             end
#             push!(reward_route, reward)
#         end
#         push!(avg_reward, sum(reward_route))
#     end

#     return mean(avg_reward)
# end