# Crear un diccionario de datos de prueba
data = Dict(
    [1, 3, 64] => [180.0, 130.0, 0.0, 35.754108604574476, 180.0],
    [1, 62, 64] => [176.0, 300.0, 0.08333333333333333, 37.91569081416397, 192.0],
    # Incluye más pares clave-valor aquí...
)

# Crear un conjunto vacío para rastrear los nodos seleccionados
selected_nodes = Set{Int}([1, 3, 64])

# Crear una lista vacía para almacenar los pares seleccionados
selected_pairs = []

# Iterar sobre los pares en orden
for (key, value) in data
    # Verificar si todos los nodos en la clave (excepto 1 y 64) no han sido seleccionados antes

    if !any(node ∈ selected_nodes for node in key if node != 1 && node != 64)
        # Si todos los nodos son únicos, añadirlos a los nodos seleccionados
        for node in key
            if node != 1 && node != 64
                push!(selected_nodes, node)
            end
        end

        # Añadir el par a la lista de pares seleccionados
        push!(selected_pairs, (key, value))

        # Detener la selección después de seleccionar 5 pares
        if length(selected_pairs) >= 5
            break
        end
    end
end

# Imprimir los pares seleccionados
for (key, value) in selected_pairs
    println("Key: ", key, ", Value: ", value)
end