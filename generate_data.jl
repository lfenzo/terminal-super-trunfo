using DataFrames
using CSV

const TOTAL_ENTITIES = 32

df = DataFrame()

# adicionando os nomes das entidades
insertcols!(df, "num" => collect(1:TOTAL_ENTITIES))
insertcols!(df, "name" => ["qualquer coisa" for _ in 1:TOTAL_ENTITIES])

# valores aleatorios nos atributos
for atributo in 1:5
    insertcols!(df, "atributo $atributo" => rand((1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 5), TOTAL_ENTITIES))
end

CSV.write("auto_generated_deck.csv", df)
