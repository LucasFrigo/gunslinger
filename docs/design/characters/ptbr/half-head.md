# Meia-cabeça (Half-head)

| | |
|---|---|
| Status | `planned` |
| Tipo | Antagonista principal / chefe final do gauntlet |
| No código | Nada ainda — não é um `AIArchetype`; o elenco hoje é Drunk / Sheriff / Ghost (`ai/archetypes/*.tres`). Não existem duas armas ao mesmo tempo, duelista gigante nem arena de campo de petróleo |
| Design | [`../../README.md`](../../README.md) |

Ele é o dono da ferrovia. É o último degrau do gauntlet, depois de **The Ghost, up close**, e só é encontrado ali. Não tem outro nome; ninguém diz nenhum.

Listado como o primeiro design em **More enemy NPCs**, na seção Ideas do [`Roadmap.md`](../../../../Roadmap.md).

## Visual

- **Leitura à distância:** Uma parede xadrez, mais alta e mais larga que qualquer outro do elenco, com um anel acima dela e uma cúpula pálida subindo por dentro do anel. Uma arma preta, uma arma branca. Nenhuma cor.
- **Cores:** Preto, branco e osso. Sem terceira cor. Ele é a única figura sem cor em um elenco berrante.
- **Corpo:** Um gigante. O Bêbado é um sino, o Xerife um poste, o Fantasma um cone; ele é uma parede.
- **Cabeça:** Partida na **horizontal**. A metade de cima é osso exposto: calota do crânio e órbitas. A metade de baixo é carne viva: nariz, boca e mandíbula. Ele fala e sorri com uma boca de verdade. A ferida continua legível à distância de duelo.
- **Chapéu:** Uma aba larga sem copa. A calota do crânio sobe por dentro dela. O único chapéu do elenco sem nada para cobrir.
- **Roupa:** Poncho comprido, xadrez grande em preto e branco. A estampa é a silhueta do corpo; não suavizar.
- **Armas:** Dois revólveres, um preto e um branco. Usa os dois; não é um duelista de uma arma só.

## Personalidade / voz

- Provocador. Cutuca o jogador; gosta do impasse.
- Visceral e violento. Cruel no jeito de falar e no jeito de matar.
- Voz: rouca e aguda, saindo de um gigante.
- Um homem de negócios por baixo da provocação. Tudo é livro-caixa: passagens, preços, o que um homem custou a ele. A crueldade é contabilidade.
- Poucas falas, bem escolhidas. Ele vem logo depois do Fantasma calado e não preenche o silêncio; diz uma coisa cortante e deixa a espera trabalhar.
- Nenhum texto de gauntlet nem fala foi escrito ainda.

## História

Humano, com um fato estranho: ele é dono de metade de tudo. Metade de qualquer homem que aceita dinheiro da companhia é dele, e ele pode cobrar. A própria metade que falta é a única coisa que ele não possui.

Ele vendeu o topo da cabeça em troca da ferrovia. Quem comprou, não se diz.

[O Jogador](player.md) estava na sala. Que papel o Jogador teve, não se diz. É por isso que o Jogador esconde o rosto.

Os homens da companhia abaixo dele na escada são dele: a ferrovia comprou [o Xerife](sheriff.md), contratou e matou [o Fantasma](ghost.md) e mandou espetar o punho em [Lata](drunk.md).

Quando o Jogador vence, ele morre de vez. É a única morte definitiva do gauntlet.

## Combate

Nada está no jogo. Decidido até agora:

| Ponto | Decisão | Custo |
|---|---|---|
| Degrau | O último, depois do degrau do Fantasma no Saloon | Nova entrada na escada |
| Armas | Dois revólveres disparados em alternância: esquerda, direita, esquerda, direita. Atributos idênticos; as cores são só visual | Precisa de código: duas armas na IA e na cena do duelista, cada arma com o próprio tambor |
| `move_style` | `STRAFE` | Parâmetro existente |
| Tamanho | Gigante | Precisa de uma malha ou de uma escala, e das hitboxes junto |

O aviso é a cor da arma que sobe. Nenhum valor de atributo está definido, e nenhuma fase de chefe ou segunda regra faz parte deste design.

## Onde

O mapa **Oil-field Train** no [`Roadmap.md`](../../../../Roadmap.md) (seção 3, planejado): o trem do Train Rooftop parado num campo de petróleo ao anoitecer, bombas cavalo de pau dos dois lados do trilho, poços em chamas no horizonte. O petróleo está debaixo dos quadrados dele e o trem é dele. As chamas são a única cor na luta dele.

Esta página não acrescenta nada a esse mapa. Ele não espera o trem que cruza a pista (**Train Map Concept**, ainda uma ideia). Até ele chegar, o mapa é uma rodada final temporária da gauntlet.

## Referências

- Moodboard #30 (deimos art): gigantes de pied-de-poule sobre uma cidade; um terno xadrez como vilão e o chefe desenhado como paisagem.
- Moodboard #09 (esboço de Araki): um chapéu com pedaços recortados.
- Moodboard #27: um cavaleiro atirando com uma pistola em cada mão.
- Concessões de terra em xadrez: o Pacific Railway Act de 1862 deu à ferrovia as seções de uma milha quadrada de número ímpar ao lado do trilho, cinco por milha de cada lado, e a emenda de 1864 dobrou isso para dez, dentro de vinte milhas. As seções pares continuaram públicas, então terra da companhia e terra pública se alternavam como em um tabuleiro. <https://www.govinfo.gov/content/pkg/CRPT-108srpt305/html/CRPT-108srpt305.htm> · <https://www.law.cornell.edu/supremecourt/text/440/668>
- Fatos do jogo: a ferrovia como o poder por trás das páginas do Xerife, do Fantasma e do Bêbado; as entradas Oil-field Train (seção 3) e Train Map Concept (Ideias) no `Roadmap.md`.
