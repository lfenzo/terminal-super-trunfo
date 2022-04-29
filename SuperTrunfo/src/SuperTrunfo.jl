module SuperTrunfo

using Term
using Random
using Statistics
using DataFrames
using DataStructures

# tipos
export Card
export Deck
export Player

# funções
export bot_plays
export choose_first
export card2panel
export execute_round
export print_greeting
export top_card2str
export show_round_cards
export shuffle_cards


"""
    Card(number::Int64 name::String features::Vector{Float64} feature_names::Vector{String})

Instancia uma nova carta para ser utilizada durante o jogo.

# Parametros

`number::Int64` Número da carta
`name::String` Nome do objeto na carta
`features::Vector{Float64}` Valor de cada um dos atributos da carta.
`feature_names::Vector{String}` Nomes dos atributos da carta.
"""
mutable struct Card
    number::Int64
    name::String
    features::Vector{Float64}
    feature_names::Vector{String}
end


"""
    Player(name::String, cards::Vector{Card})

Instancia um jogador a partir do seu nome e das cartas em sua mão.

# Parametros

`name::String` Nome do jogador
`cards_at_hand::Queue{Card}` Conjunto de cartas na mão do jogador.
"""
mutable struct Player
    name::String
    cards_at_hand::Queue{Card}

    function Player(name::String, cards::Vector{Card})
        player_cards = Queue{Card}()
        for card in cards
            enqueue!(player_cards, card)
        end
        return new(name, player_cards)
    end
end

"""
    isempty(p::Player)

Verifica se o jogador `p` ainda tem cartas em sua mão.
"""
Base.isempty(p::Player) = Base.isempty(p.cards_at_hand)


"""
    top_card2str(p::Player) :: Vector{String}

Função auxiliar utilizada no menu de escolha de atributos.

# Parametros

- `p::Player`; Jogador atual
"""
function top_card2str(p::Player) :: Vector{String}

    card_features = Vector{String}()
    first_card = first(p.cards_at_hand)

    for (value, feature) in zip(first_card.features, first_card.feature_names) 
        push!(card_features, "$feature")
    end

    return card_features
end


"""
    Deck(cards::Vector{Card})

Instancia um novo conjunto de cartas. Essas cartas não fazem parte da mão de 
nenhum jogador, na verdade elas ficam à disposiçao na mesa e, em caso de empatae,
as cartas nas mãos dos jogadores vão para o `Deck`.

# Parametros

- `cards::Vector{Card}` Vetor contendo as cartas que devem colocadas no deck.
"""
mutable struct Deck
    cards_available::Queue{Card}
    stand_by_cards::Queue{Card}

    function Deck(cards::Vector{Card})
        cards_in_deck, stand_by_cards = Queue{Card}(), Queue{Card}()
        for card in cards
            enqueue!(cards_in_deck, card)
        end
        return new(cards_in_deck, stand_by_cards)
    end
end
Base.isempty(d::Deck) = Base.isempty(d.cards_available)


"""
    card2panel(c::Card; color::AbstractString = "white", highlight_feature::Union{Nothing, Int64} = nothing) :: Panel


Mostra uma carta `c` com os seus respectivos atributos em um painel do Term.jl

# Parametros

- `c::Card` Carta a ser mostrada. 
- `color::AbstractString = "white"` Cor padrão para realizar a coloração da carta.
- `highlight_feature::Union{Nothing, Int64} = nothing` Dá destaque para o atributo
    (utilizado na comparação dos atributos das cartas dos jogadores).
"""
function card2panel(c::Card;
        color::AbstractString = "white",
        highlight_feature::Union{Nothing, Int64} = nothing) :: Panel

    feature_names = ""
    feature_values = ""

    for (i, (feature_name, feature_value)) in enumerate(zip(c.feature_names, c.features))

        if i == highlight_feature
            feature_names *= "\n[bold red]$feature_name[/bold red]"
            feature_values *= "\n[bold red]>> $(feature_value) <<[/bold red]"
        else
            feature_names *= "\n$feature_name"
            feature_values *= "\n   $(feature_value)  "
        end
    end

    # tira o primeiro '\n' desnecessário dentro dos feature_*
    feature_names_panel = Panel(feature_names[2:end], fit = true)
    feature_values_panel = Panel(feature_values[2:end], fit = true)

    main_card_panel = Panel(feature_names_panel * feature_values_panel;
        title = "$(c.name) -- $(c.number)",
        justify = :center,
        style = "bold $color",
        box = :HEAVY,
        height = 10,
        width = 50,
        padding = (1, 1, 4, 0)
    )

    return main_card_panel
end

function card2panel(p::Player;
        highlight_feature::Union{Nothing, Int64} = nothing,
        color::AbstractString = "white")

    return card2panel(first(p.cards_at_hand); highlight_feature, color = color)
end


"""
    show_round_cards(current_player::T, next_player::T, choice::Int64, is_first_human::Bool) where {T <: Player}

Mostra a carta do jogador e a carta do bot lado a lado para a comparação do round atual.

# Parametros

- `current_player::Player`
- `next_player::Player`
- `choice::Int64`
- `is_first_human::Bool`
"""
function show_round_cards(current_player::T,
        next_player::T,
        choice::Int64,
        is_first_human::Bool) where {T <: Player}

    current_color, next_color = is_first_human ? ("blue", "yellow") : ("yellow", "blue")

    current_player_panel = card2panel(first(current_player.cards_at_hand);
                                      color = current_color,
                                      highlight_feature = choice)

    next_player_panel = card2panel(first(next_player.cards_at_hand);
                                   color = next_color,
                                   highlight_feature = choice)

    println(current_player_panel * " "^2 * next_player_panel)
end


"""
    choose_first(player::T, bot::T) :: Tuple{T, T} where {T <: Player}

Escolho o primeiro jogador no início do jogo retornando a order dos jogadores
para a primeira rodada: jogador atual e jogador da próxima rodada.
"""
function choose_first(player::T, bot::T) :: Tuple{T, T} where {T <: Player}

    panel = Panel("Vamos tirar par ou impar para ver quem começa..."; width = 98)

    println(panel)

    print("\n\t\t\t\t\tPar ou Impar? (p/i): ")
    choice = readline()

    luck_number = rand(1:100)
    println("\nO número aleatório deu $luck_number")

    number_parity = iseven(luck_number) ? "p" : "i"
    
    if number_parity == choice
        println("Acertou, você começa!\n")
        first = player
        second = bot
    else
        println("Vish, o Bot começa!\n")
        first = bot
        second = player
    end

    return first, second
end


"""
    shuffle_cards(all_cards::Vector{Card}) :: Tuple{Vector{Card}, Vector{Card}, Vector{Card}}

Embaralha as cartas `all_cards` returnando 3 conjuntos nas proporções 25%, 25%
e 50%, respectivamente:
- cartas do jogador
- cartas do bot
- cartas do deck

# Parametros

- `all_cards::Vector{Card}` Vetor com todas as cartas disponíveis no jogo.
"""
function shuffle_cards(all_cards::Vector{Card}) :: Tuple{Vector{Card}, Vector{Card}, Vector{Card}}  

    shuffled_cards = shuffle(all_cards)

    card_sets = [Vector{Card}() for i in 1:3] # vatores de cartas 
    split_ranges = [1:8, 9:16, 17:32]

    for (card_set, range) in zip(card_sets, split_ranges)
        for card in shuffled_cards[range]
            push!(card_set, card)
        end
    end

    return tuple(card_sets...)
end


"""
    execute_round(p1::Player, p2::Player, deck::Deck, choice::Int) :: Union{Nothing, Player}

Avalia o reultado de um round no jogo, a partir dos jogadores `p1` e `p2` e da
escolha feita pelo jogador que pode escolhar o atributo na rodada. Em caso de empate
então `nothing` é retornado e as duas cartas das mãos dos jogadores vão parar no
`deck`.

# Parametros

- `p1::Player` Jogador atual (aquele que escolheu o atributo)
- `p2::Player` Jogador oponente
- `deck::Deck` Conjunto de cartas da mesa, inclusive aquelas que foram adicionadas no empate
- `choice::Int` Atributo escolhido pelo jogador `p1` a partir do qual a comparação será feita
"""
function execute_round(p1::Player, p2::Player, deck::Deck, choice::Int) :: Union{Nothing, Player}
    p1_card = first(p1.cards_at_hand)
    p2_card = first(p2.cards_at_hand)
    winner = nothing

    # determina a função de comparação com base no atributo escolhido.
    if choice in [1, 2]
        compare_func = > # maior é melhor
    else
        compare_func = < # menor é melhor
    end

    if compare_func(p1_card.features[choice], p2_card.features[choice])
        winner = p1
        loser = p2
    elseif compare_func(p2_card.features[choice], p1_card.features[choice])
        winner = p2
        loser = p1
    else
        p1_card = dequeue!(p1.cards_at_hand)
        p2_card = dequeue!(p2.cards_at_hand)

        # as cartas de ambos os jogadores vão parar no monte de empate
        enqueue!(deck.stand_by_cards, p1_card)
        enqueue!(deck.stand_by_cards, p2_card)
    end

    if winner != nothing

        card = dequeue!(loser.cards_at_hand)
        enqueue!(winner.cards_at_hand, card)

        # se houve empate antes o ganhador fica com as cartas do monte de empate
        if !isempty(deck.stand_by_cards)
            print("Nesta rodada o $(winner.name) ganhou a(s) seguinte(s) carta(s) do(s) empate(s): ")
            while !isempty(deck.stand_by_cards)
                stand_by_card = dequeue!(deck.stand_by_cards)
                print(" [$(stand_by_card.number)]")
                enqueue!(winner.cards_at_hand, stand_by_card)
            end
            println()
        end
    end

    return winner
end


"""
    bot_plays(b::Player, df::DataFrame, difficulty::AbstractSring = "easy") :: Int64

No modo dificil, a heurística ranqueia as valores dos atributos na mão do jogador. O atributo
escolhido será aquele que possui o maior valor do percentil de cada atributo. Esse valor é 
determinado com auxilio de todos os valores de todas as cartas (por meio do dataframe `df`).

Caso o modo seja facil (`difficulty == "easy"`) o bot escolho um atributo aleatoriamente
caso contrário ele utiiza uma heurística para realizar a jogada.
"""
function bot_plays(b::Player, df::DataFrame, difficulty::AbstractString = "easy") :: Int64

    if difficulty == "easy"
        choice = rand(1:5)
    else
        nrows = nrow(df)
        features = first(b.cards_at_hand).features

        # note as indices...
        vdut_rank = sum(map(x -> x <= features[1] ? 1 : 0,  df[:, 2])) / nrows
        proc_rank = sum(map(x -> x <= features[2] ? 1 : 0,  df[:, 3])) / nrows
        ener_rank = sum(map(x -> x >= features[3] ? 1 : 0,  df[:, 4])) / nrows
        prod_rank = sum(map(x -> x >= features[4] ? 1 : 0,  df[:, 5])) / nrows
        toxc_rank = sum(map(x -> x >= features[5] ? 1 : 0,  df[:, 6])) / nrows

        # mesma ordem dos atributosn
        choice = argmax([vdut_rank, proc_rank, ener_rank, prod_rank, toxc_rank])
    end

    return choice
end


"""
    print_greeting()

Exibe a mensagem inicial com a descrição dos atributos e as regras do jogo.
"""
function print_greeting()

    title_panel = Panel(
        "[green][bold]!! Super Trunfo Sustentabilidade !![/bold][/green]",
        justify = :center,
        style = "bold green",
        width = 92,
        box = :DOUBLE,
    )

    supertrunfo_description = Panel(
        TextBox("""
                Escolha o atributo da sua carta que voce acha que irá ganhar da carta
                do outro jogador conforme os critérios abaixo:
            """,
           justify = :left,
           width = 30,
        );
        title = "Como Jogar",
        title_style = "bold white",
        fit = true,
    )

    greater_better = Panel(
        /(TextBox("\n\n[bold green][⯅] Ganha o maior valor[/bold green]", width = 30),
          TextBox("[bold red][▼] Ganha o menor valor[/bold red]", width = 30)),
        title = "Força dos Atributos",
        title_style = "bold white",
        height = 13,
        width = 36,
    )

    feature_descriptions = Dict(
        "[green]Vida Útil:[/green]" => """Quantidade de tempo (em anos) que o produto 
            deve funcionar sem que seja necessário trocá-lo.""",

        "[green]Capacidade de Processamento:[/green]" => """Quantidade de informação que 
            o produto pode processar/utilizar, quando pssivel""",

        "[red]Energia Consumida:[/red]" => """Quantidade de energia que o produto 
            gasta durante o seu funcionamento""",

        "[red]Produção Anual:[/red]" => """Quantidade de unidades do produto produzidas 
            no último ano no mundo""",

        "[red]Toxicidade:[/red]" => """Nível de toxicidade dos materiais que compôem o produto""",
    )

    text_boxes = [
        TextBox(
            "$name $description",
            justify = :left,
            width = 50,
        )
    for (name, description) in feature_descriptions]

    feature_description = Panel(text_boxes...;
                                title = "Atributos",
                                title_style = "bold white",
                                fit = true)

    greeting_panel = Panel(title_panel,
                           feature_description * (supertrunfo_description / greater_better),
                           box = :DOUBLE,
                           fit = true)

    println(greeting_panel)
end

end

