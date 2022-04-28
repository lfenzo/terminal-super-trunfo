module SuperTrunfo

import Base: isempty

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
Implementação da carta
"""
mutable struct Card
    number::Int64
    name::String
    features::Vector{Float64}
    feature_names::Vector{String}
end


"""
    Player(name::String, cards_at_hand::Queue{Card})

Implementação do jogador com as suas cartas
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

Verifica se o jogador `p` ainda tem cartas em sua mão (ou seja, se ele não está vazio)
"""
isempty(p::Player) = Base.isempty(p.cards_at_hand)


"""
    top_card2str(p::Player) :: Vector{String}

Obtem as correspondências 
Função auxiliar utilizada no menu de escolha de atributos

Parameters
----------
`p::Player`; Jogador atual
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
Monte de cartas que fica na mesa
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
isempty(d::Deck) = Base.isempty(d.cards_available)


"""
Mostra uma carta com os seus atributos
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

function card2panel(p::Player; highlight_feature::Union{Nothing, Int64} = nothing, color::AbstractString = "white")
    return card2panel(first(p.cards_at_hand); highlight_feature, color = color)
end


"""
Mostra a carta do jogador e a carta do bot lado a lado para a comparação
"""
function show_round_cards(current_player::T, next_player::T, choice::Int64, is_first_human::Bool) where {T <: Player}

    current_color, next_color = is_first_human ? ("blue", "yellow") : ("yellow", "blue")

    current_player_panel = card2panel(first(current_player.cards_at_hand);
                                      color = current_color,
                                      highlight_feature = choice)

    next_player_panel = card2panel(first(next_player.cards_at_hand);
                                   color = next_color,
                                   highlight_feature = choice)

    println(current_player_panel * " "^2 * next_player_panel)
end


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

    return player, bot # TODO remover isso depis
    #return first, second
end


function shuffle_cards(all_cards::Vector{Card}) :: Tuple{Vector{Card}, Vector{Card}, Vector{Card}}  
    shuffled_cards = shuffle(all_cards)

    player_cards = Vector{Card}()
    bot_cards = Vector{Card}()
    deck_cards = Vector{Card}()

    for card in shuffled_cards[begin:8]
        push!(player_cards, card) 
    end

    for card in shuffled_cards[9:16]
        push!(bot_cards, card) 
    end

    for card in shuffled_cards[17:end]
        push!(deck_cards, card) 
    end

    return player_cards, bot_cards, deck_cards
end


"""
Executa uma iteração de round  

"""
function execute_round(p1::Player, p2::Player, deck::Deck, choice::Int) :: Union{Nothing, Player}
    p1_card = first(p1.cards_at_hand)
    p2_card = first(p2.cards_at_hand)
    winner = nothing

    if choice in [1, 2]
        compare_func = >
    else
        compare_func = <
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
            while !isempty(deck.stand_by_cards)
                stand_by_card = dequeue!(deck.stand_by_cards)
                enqueue!(winner.cards_at_hand, stand_by_card)
            end
        end
    end

    return winner
end


"""
Escolhe a jogada para o bot: utiliza uma heuristica para realizar a jogada do bot
"""
function bot_plays(b::Player, df::DataFrame) :: Int64

    features = first(b.cards_at_hand).features
    nrows = nrow(df)

    # note as indices...
    vdut_rank = sum(map(x -> x <= features[1] ? 1 : 0,  df[:, 2])) / nrows
    proc_rank = sum(map(x -> x <= features[2] ? 1 : 0,  df[:, 3])) / nrows
    ener_rank = sum(map(x -> x >= features[3] ? 1 : 0,  df[:, 4])) / nrows
    prod_rank = sum(map(x -> x >= features[4] ? 1 : 0,  df[:, 5])) / nrows
    toxc_rank = sum(map(x -> x >= features[5] ? 1 : 0,  df[:, 6])) / nrows

    # mesma ordem dos atributosn
    values = [vdut_rank, proc_rank, ener_rank, prod_rank, toxc_rank]

    return argmax(values)
end


"""
mostra a mensagem inicial no momento de abrir o jogo
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
        TextBox("\n\n[bold green][⯅] Ganha o maior valor[/bold green]", width = 30) / TextBox("[bold red][▼] Ganha o menor valor[/bold red]", width = 30),
        title = "Força dos Atributos",
        title_style = "bold white",
        height = 13,
        width = 36,
    )

    feature_descriptions = Dict(
        "[green]Vida Útil:[/green]" => "Quantidade de tempo (em anos) que o produto deve funcionar sem que seja necessário trocá-lo.",
        "[green]Capacidade de Processamento:[/green]" => "Quantidade de informação que o produto pode processar/utilizar, quando pssivel",
        "[red]Energia Consumida:[/red]" => "Quantidade de energia que o produto gasta durante o seu funcionamento",
        "[red]Produção Anual:[/red]" => "Quantidade de unidades do produto produzidas no último ano no mundo",
        "[red]Toxicidade:[/red]" => "Nível de toxicidade dos materiais que compôem o produto",
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

