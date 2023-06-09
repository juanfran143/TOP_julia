#Reactive Search
using Random, Distributions, Combinatorics, DataStructures

#Initial parameter candidates with equal choose_with_probability
#Return the Param dict ( parameter => (probability, best reward =0)), the list of parameters,  and the cumulative distribuction

function  Init_dict_probabilities(alpha_candidates,beta_candidates)
    Param_dict=Dict{Tuple{Float16,Float16},Array{Float64,1}}()
    len_params = length(alpha_candidates)*length(beta_candidates)
    for a in alpha_candidates
        for b in beta_candidates
            Param_dict[(Float16(a),Float16(b))] = [1/len_params,0]
        end
    end
    params  = collect(keys(Param_dict))
    probabilities = [valor[1] for valor in values(Param_dict)]
    no_null_index = findall(probabilities .!=0)
    cum_probabilities = cumsum(probabilities[no_null_index])
    return Param_dict, params, no_null_index, cum_probabilities
end

## Use a random for choose a parameter given a cumulative distribuction
function choose_with_probability(params,no_null_index,cum_probabilities)
    r = rand()
    choose_param = no_null_index[findfirst(cum_probabilities .>= r)]
    return params[choose_param]
end

#Modify the dictionary

function modify_param_dictionary_RS(Param_dict, k, active_agresive)
    #sum of all best values
    sum_q =  (sum([valor[2]^k for valor in values(Param_dict)]))
    # Refresh probabilites with RS formula and reestart best values at 0
    if active_agresive 
        for key in keys(Param_dict)
            Param_dict[key][1] = (Param_dict[key][2]^k)/sum_q
            Param_dict[key][2] = 0 
        end
    else 
        for key in keys(Param_dict)
            Param_dict[key][1] = (Param_dict[key][2]^k)/sum_q
            # Param_dict[key][2] = 0 
        end
    end
    
    params  = collect(keys(Param_dict))
    probabilities = [valor[1] for valor in values(Param_dict)]
    no_null_index = findall(probabilities .!=0)
    cum_probabilities = cumsum(probabilities[no_null_index])
    return params,no_null_index,cum_probabilities
end
