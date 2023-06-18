using JuMP
using GLPK

function simple_MIP(rutas, recompensas, n_vehicles)
    # Crear modelo con el solver GLPK
    modelo = Model(GLPK.Optimizer)

    # cambiamos el modelo de rutas
    rutasv2 = []
    for rute in rutas
        push!(rutasv2, rute)
    end
        
    last_node = rutasv2[1][length(rutasv2[1])]

    # Crear variable binaria para cada ruta
    @variable(modelo, x[1:length(rutas)], Bin)

    # Objetivo: Maximizar recompensa total
    @objective(modelo, Max, sum(x[i]*recompensas[i] for i in 1:length(rutas)))

    @constraint(modelo, sum(x[i] for i in 1:length(rutas))<=n_vehicles)
    
    # Restricción: Cada nodo solo puede ser visitado una vez
    
    for nodo in 2:last_node-1
        @constraint(modelo, sum(x[i] for i in 1:length(rutas) if nodo in rutasv2[i]) <= 1)
    end

    # Resolver el modelo
    optimize!(modelo)

    # Devolver las rutas seleccionadas

    best_solution = [rutasv2[i] for i in 1:length(rutas) if value(x[i]) > 0.5]
    best_reward = sum([recompensas[i] for i in 1:length(rutas) if value(x[i]) > 0.5])
        
    return best_solution, best_reward
end


function iterative_MIP(rutas, recompensas, n_vehicles)
    # Crear modelo con el solver GLPK
    modelo = Model(GLPK.Optimizer)

    # cambiamos el modelo de rutas
    rutasv2 = []
    for rute in rutas
        push!(rutasv2, rute)
    end
        
    last_node = rutasv2[1][length(rutasv2[1])]

    # Crear variable binaria para cada ruta
    @variable(modelo, x[1:length(rutas)], Bin)

    # Objetivo: Maximizar recompensa total
    @objective(modelo, Max, sum(x[i]*recompensas[i] for i in 1:length(rutas)))

    @constraint(modelo, sum(x[i] for i in 1:length(rutas))<=n_vehicles)
    
    # Restricción: Cada nodo solo puede ser visitado una vez
    
    for nodo in 2:last_node-1
        @constraint(modelo, sum(x[i] for i in 1:length(rutas) if nodo in rutasv2[i]) <= 1)
    end

    # Resolver el modelo
    optimize!(modelo)

    stochastics_solutions = []
    push!(stochastics_solutions,[rutasv2[i] for i in 1:length(rutas) if value(x[i]) > 0.5])
    # se itera 4 veces para tener 4 soluciones diferentes, metiendo una restriccion para obtenerlas

    for i in 1:4
        @constraint(modelo, sum([x[i] for i in 1:length(rutas) if value(x[i]) > 0.5]) <= n_vehicles-1)
        optimize!(modelo)
        push!(stochastics_solutions,[rutasv2[i] for i in 1:length(rutas) if value(x[i]) > 0.5])
    end

    # Devolver las rutas seleccionadas

    # best_solution = [rutasv2[i] for i in 1:length(rutas) if value(x[i]) > 0.5]
    # best_reward = sum([recompensas[i] for i in 1:length(rutas) if value(x[i]) > 0.5])
        
    return stochastics_solutions
end