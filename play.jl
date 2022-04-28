using SuperTrunfo


using DataFrames
using Term
using REPL.TerminalMenus
using CSV


function main()
    all_cards_df = DataFrame(CSV.File("baralho.csv"))

    transform!(all_cards_df, "Produção Mundial Anual" => ByRow((x) -> replace(x, "." => "")), renamecols = false)
    transform!(all_cards_df, "Produção Mundial Anual" => ByRow((x) -> parse(Float64, x) / 1000), renamecols = false)
    transform!(all_cards_df, :name => ByRow((x) -> titlecase(x)) => :name)
    all_cards_df[!, :num] = collect(1:nrow(all_cards_df))

    all_cards = Vector{Card}()

    for row in eachrow(all_cards_df)
        push!(all_cards, Card(row["num"], row["name"], collect(row[2:end-1]), names(all_cards_df)[2:end-1]))
    end

    # embaralha as cartas e designica cada uma delas aos jogadores
    player_cards, bot_cards, deck_cards = shuffle_cards(all_cards)

    print_greeting()

    player = Player("Joao", player_cards)
    bot = Player("Bot", bot_cards)

    deck = Deck(deck_cards)

    # apenas para a primeira rodada
    current_player, next_player = choose_first(player, bot)


    while !isempty(current_player) && !isempty(next_player)

        run(`clear`)

        if current_player === player
            println(Panel("Jogador, sua vez!"))
            println(card2panel(current_player, color = "blue")
                * " "^4 *  "Além dessa você tem mais $(length(current_player.cards_at_hand) - 1) carta(s)")

            menu = RadioMenu(top_card2str(current_player))
            println("\nEscolha o atributo de comparação:")
            chosen_feature = request(menu)
            print("\n")
        else
            println(Panel("Agora é a vez do Bot, vamos aguardar enquanto ele escolhe..."))
            sleep(1)
            println(card2panel(current_player, color = "yellow")
                * " "^4 *  "Além dessa o bot tem mais $(length(current_player.cards_at_hand) - 1) carta(s)")
            chosen_feature = bot_plays(current_player, all_cards_df)
            println("Bot escolheu o atributo $chosen_feature")
            sleep(2)
        end

        if current_player === player
            println(Panel("Comparando a [bold blue]carta do jogador[/bold blue] com a [bold yellow]carta do bot[/bold yellow]"))
        else
            println(Panel("Comparando a [bold yellow]carta do bot[/bold yellow] com a [bold blue]carta do jogador[/bold blue]"))
        end

        show_round_cards(current_player, next_player, chosen_feature, current_player === player)

        sleep(2)
        winner = execute_round(current_player, next_player, deck, chosen_feature)

        if winner != nothing
            color = winner === player ? "green" : "red"
            println(Panel("[$color]O $(winner.name) venceu![/$color]"))

            if current_player !== winner 
                current_player, next_player = next_player, current_player 
            end
        else
            println(Panel("[yellow]Empate! Cartas as duas cartas vão para o Deck[/yellow]"))
        end

        print("Aperte Enter para o próximo round...\n")
        _ = readline() # pressionar para ir para o próximo round
    end

    winner = isempty(current_player) ? next_player : current_player
    println("\n\no $(winner.name) venceu!!!\n\n")
end

main()
