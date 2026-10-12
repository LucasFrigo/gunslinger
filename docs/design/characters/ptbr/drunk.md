# O Bêbado (Lata & Plata)

| | |
|---|---|
| Status | `partial` |
| Tipo | NPC inimigo |
| No código | `ai/archetypes/drunk.tres` — opção do duelo livre + gauntlet. Greybox compartilhado `ai/duelist.tscn`. O visual, os nomes, a voz e a história descritos abaixo não estão no código |
| Design | [`../../README.md`](../../README.md) |

Gêmeos. **Lata** é o degrau da Main Street; **Plata** é o degrau do Saloon (1,5× de vida). O jogo ainda diz apenas "The Drunk".

## Visual

No jogo hoje: cápsula provisória + chapéu, tingidos de bege empoeirado `Color(0.55, 0.45, 0.3)`. Ainda sem malha própria. Um revólver.

Projetado (`planned`):

- **Leitura à distância:** Um sino largo com uma cabeça pequena em cima, mais alto em um dos ombros, com um punhado de formas grandes e claras sobre ele. Três cores chapadas.
- **Cores:** Uma malha, duas texturas; os gêmeos trocam as cores.

  | | Casaco e copa do chapéu | Forro, fitas, aba do chapéu | Amuletos |
  |---|---|---|---|
  | Lata | verde-absinto | amarelo-bile | lata clara |
  | Plata | amarelo-bile | verde-absinto | lata clara |

- **Corpo:** Sessenta e poucos anos, inchado. A barriga empurra o casaco e forma o sino; pernas finas aparecem abaixo da barra.
- **Ombros:** Um dos ombros leva uma almofada grossa por baixo do casaco, herança dos tempos de carregador de andor. Do mesmo lado nos dois gêmeos.
- **Chapéu:** Baixo, de copa chata, com aba dura e estreita, assentado perfeitamente reto. O menor chapéu do elenco.
- **Casaco:** Na altura do joelho, duro, aberto sobre a barriga. Seis milagros de lata enormes, cada um pendurado em um laço de fita grande o bastante para ser lido como uma segunda forma:
  - um fígado atravessado na barriga, o maior
  - um coração no peito
  - uma perna descendo pela saia do casaco
  - um braço ao longo da manga do braço da arma
  - um par de olhos nas costas
  - um punho sobre o ombro almofadado
- **Rosto:** Descoberto. Um olho de lata com o dobro do tamanho real está espetado sobre uma das órbitas e nunca pisca; o outro olho é o dele, pequeno e úmido. Uma boca de lata está espetada na bochecha, ao lado da boca de verdade. A pele se enruga em volta dos alfinetes. O mesmo olho nos dois gêmeos.
- **Arma:** Um revólver comum, o objeto mais sem graça que ele carrega, com uma fita amarrada na coronha.

## Personalidade / voz

- Texto do gauntlet (no jogo, em inglês): **A drunk with a grudge** — um bêbado com um rancor (Main Street); **His angrier brother** — o irmão mais bravo dele (Saloon, 1,5× de vida).
- Não está com raiva, nem com quase nada: é um homem levando uma carga inteira que foi parado no meio da rua.
- Voz: um murmúrio baixo, sem relevo e contínuo, que nunca sobe. Ele recita os pedidos espetados nele e nunca um pedido seu.
- Falas de exemplo, escritas para depois (nenhuma fala de NPC está no jogo):
  - Esperando: "Pelo joelho do Anselmo. Pela viúva Paz, os olhos dela. Pelo menino dos Ortega, seja lá o que era aquilo."
  - No saque: "Fica parado. Estou carregando quarenta pessoas."
  - Atingido: "Essa era do padeiro."
  - Vencendo: "Pelo forasteiro. Alguém espeta ele."
  - Plata, esperando: "Pelo do meu irmão — pelo meu — pelo que é meu."
  - Plata, morrendo: "Quem leva eles agora."

## História

Humano, com um fato estranho: os gêmeos pegam para si qualquer mal que for espetado neles.

Viviam de carregar santos, com o andor no ombro nas procissões, onde o santo nunca é posto no chão e o conjunto todo balança enquanto anda. Num dia de festa, uma mulher espetou o amuleto no carregador em vez de na imagem; a perna do marido sarou e a de Lata estragou. Há onze anos cada cidade espeta sua doença nos casacos deles, e os dois passaram esse tempo todo bêbados da bebida que outros homens engoliram.

O rancor de Lata não é dele. [O Xerife](sheriff.md) o espetou nele, na forma do punho de lata, por ordem da ferrovia. O de Plata é dele: o Jogador matou seu irmão a tiros na Main Street, e essa é a primeira coisa em onze anos que ele sente por conta própria.

## Combate (no jogo)

Fica parado. Saque lento, cone de mira largo, recarga longa — o primeiro degrau, o fácil. O design não muda nenhum parâmetro; a última coluna é a ficção para o que já está no jogo.

| Parâmetro | Valor | Por quê |
|---|---|---|
| `reaction_time` | 0.9 (±0.35) | O amuleto do braço pende da manga da arma |
| `draw_time` | 0.9 | Idem |
| `accuracy_angle_deg` | 9.0 | Um olho só funcionando |
| `followup_interval` | 1.6 | |
| `reload_time` | 3.5 | Ele se atrapalha com as fitas até alcançar o cinto |
| `bullet_speed` | 40 | |
| `health` | 2 | O 1,5× de Plata é ele sóbrio de raiva |
| `move_style` | `STAND` | Um carregador não sai da fila; ele balança no lugar |

Nenhum comportamento, efeito de acerto ou som novo faz parte deste design.

## Referências

- Moodboard #23 (Atlas Sellman): metal votivo usado no peito de um terno western.
- Milagros: amuletos de lata prensada no formato da parte doente do corpo, espetados na roupa de um santo ou pendurados em fita; corações e olhos são as formas mais comuns. <https://en.wikipedia.org/wiki/Milagro_(votive)> · <https://lammuseum.wfu.edu/2024/10/mexican-milagros/>. As fitas reais são vermelhas; estas usam a cor trocada para mantê-lo em três cores.
- Andas de procissão: o andor nunca é posto no chão e balança enquanto se move. <https://www.revuemag.com/?p=15619>. Almofada de ombro dos carregadores: <https://catholicsstrivingforholiness.org/a-salute-to-the-hidden-heroes-of-the-holy-week-in-seville-the-costaleros/>
- Fatos do jogo: os rótulos em uso acima e os atributos em `ai/archetypes/drunk.tres`.
