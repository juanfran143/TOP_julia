#Reactive Search
using Random, Distributions, Combinatorics, DataStructures
#Initial probabilities

function  Init_dict_probabilities(nParams::Int64)
    Param_dict=Dict{Float64,Float64}()
    for i in 1:nParams
        param = round(i/(nParams+1),digits =3)
        Param_dict[param] = 1/(nParams)

    end
    params  = collect(keys(Param_dict))
    probabilities = collect(values(Param_dict))
    no_null_index = findall(probabilities .!=0)
    cum_probabilities = cumsum(probabilities[no_null_index])
    return Param_dict, params, probabilities, no_null_index, cum_probabilities
end

function choose_with_probability(params,no_null_index,cum_probabilities)
    r = rand()
    choose_param = no_null_index[findfirst(cum_probabilities .>= r)]
    return params[choose_param]
end

Param_dict,params,probabilities,no_null_index,cum_probabilities = Init_dict_probabilities(100)

@time begin
    for t = 1:100000
        chosed =choose_with_probability(params,no_null_index,cum_probabilities)
    end
end
