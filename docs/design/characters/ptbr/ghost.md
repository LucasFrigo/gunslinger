# O Fantasma

| | |
|---|---|
| Status | `partial` |
| Tipo | NPC inimigo |
| No código | `ai/archetypes/ghost.tres` — opção do duelo livre + gauntlet. Greybox compartilhado `ai/duelist.tscn`. O visual e a história descritos abaixo não estão no código |
| Design | [`../../README.md`](../../README.md) |

Uma figura só nos dois degraus. O mesmo Fantasma guarda o Canyon e depois segue o Jogador até o Saloon (2× de vida). Ele não tem nome; ninguém vivo lembra como era chamado.
## Visual

No jogo hoje: cápsula provisória + chapéu, tingidos de quase branco `Color(0.85, 0.88, 0.92)`. Ainda sem malha própria. Um revólver.

Projetado (`planned`):

- **Leitura à distância:** Um cone pálido sem pés, com a barra mais larga que os ombros, um chapéu amarrado em cima e tiras se arrastando pelas costas. Duas cores chapadas e dois pontos acesos onde deveria estar o rosto.
- **Cores:** Guarda-pó e chapéu água-marinha; ataduras e cabo da arma branco-osso. A água-marinha é pálida e puxa para o azul, bem longe do verde-absinto de Lata. O tom quase branco sai quando a malha chegar.
- **Cabeça:** Totalmente enrolada em ataduras branco-osso. Os olhos são o rosto inteiro.
- **Olhos:** Água-marinha e acesos. A única coisa nele que brilha.
- **Chapéu:** Um chapéu comum, água-marinha, preso à cabeça pelas mesmas ataduras: por cima da copa e por baixo do queixo, do jeito que se amarra o queixo de um defunto. As pontas soltas se arrastam atrás.
- **Guarda-pó:** Até o chão e comprido demais para ele. A barra arrasta e não aparece bota nenhuma. As mangas cobrem as mãos até os nós dos dedos; a fenda das costas se abre em duas caudas.
- **Arma:** Um revólver com cabo branco-osso e uma tira de atadura enrolada na coronha.
- **Saloon:** Nada muda. Mesma malha, mesma textura; em ambiente fechado os olhos aparecem mais.

## Personalidade / voz

- Texto do gauntlet (no jogo, em inglês): **The Ghost of the canyon** — o Fantasma do cânion (Canyon); **The Ghost, up close** — o Fantasma, de perto (Saloon, 2× de vida).
- Calado. É o único duelista sem falas, de propósito.

## História

Morto. O primeiro do elenco que está.

A ferrovia o contratou para segurar o cânion contra uma linha rival. As companhias resolveram tudo no tribunal e ninguém veio avisá-lo. A ferrovia o matou; como, não se diz. [O Xerife](sheriff.md) assinou o papel que dizia que o cânion estava limpo.

Nunca ninguém sacou mais rápido que ele, e não foi isso que o matou. Ele quer ser vencido em um saque limpo, e é bom demais.

O cânion é faixa de domínio da companhia, onde nada se resolve à bala. Por isso ele segue o Jogador até o Saloon, fora do chão da companhia, para perder onde vale.

## Combate (no jogo)

Strafe rápido, cone fechado, recarga curta — o mais difícil dos três arquétipos do jogo. O design não muda nenhum parâmetro; a última coluna é a ficção para o que já está no jogo.

| Parâmetro | Valor | Por quê |
|---|---|---|
| `reaction_time` | 0.22 (±0.05) | Ele espera por isso desde o seu posto |
| `draw_time` | 0.28 | |
| `accuracy_angle_deg` | 1.5 | Olhos que não piscam |
| `followup_interval` | 0.7 | |
| `reload_time` | 1.4 | Nada nele atrapalha |
| `bullet_speed` | 70 | |
| `health` | 2 | Não sobrou muito dele. O 2× do Saloon é ele fora do chão da companhia, onde vale |
| `move_style` | `STRAFE` (`strafe_speed` 1.6) | Sem pés debaixo da barra; ele desliza |

O aviso do strafe são as tiras soltas e as caudas do guarda-pó esvoaçando para o outro lado antes de ele voltar. Isso vem com a malha, assim como o material emissivo dos olhos; nenhum comportamento, efeito de acerto ou som novo faz parte deste design.

## Referências

- Moodboard #28: uma cabeça enrolada em ataduras, os olhos como o rosto inteiro. Moodboard #22: uma figura amortalhada da cabeça aos pés, o fantasma como tecido.
- A "Guerra do Cânion" da Royal Gorge, 1878–79: duas ferrovias disputaram um mesmo cânion, ergueram 17 fortes de pedra nele e contrataram pistoleiros sob o comando de Bat Masterson; tudo se resolveu no tribunal, com muito pouco sangue. <https://en.wikipedia.org/wiki/Railroad_Wars> · <https://en.wikipedia.org/wiki/Royal_Gorge_Route_Railroad>
- Guarda-pós de linho: casacos de montaria longos e soltos, com uma fenda nas costas, crus ou caramelo nos exemplares que sobreviveram. <https://grpmcollections.org/Detail/objects/5419>. O dele usa água-marinha para mantê-lo em duas cores.
- A atadura no queixo é o pano que o fantasma de Marley usa em *Um Conto de Natal*; não foi conferida com uma fonte de época.
- Fatos do jogo: os rótulos em uso acima e os atributos em `ai/archetypes/ghost.tres`.
