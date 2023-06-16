using JuMP
using GLPK

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

        # Devolver las rutas seleccionadas

        best_solution = [rutasv2[i] for i in 1:length(rutas) if value(x[i]) > 0.5]
        best_reward = sum([recompensas[i] for i in 1:length(rutas) if value(x[i]) > 0.5])
        

        print("Solucion MIP: ", best_solution)
        print("Reward:", best_reward )
    return best_solution, best_reward
end