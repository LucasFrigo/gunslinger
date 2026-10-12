# O Xerife (Encarnado)

| | |
|---|---|
| Status | `partial` |
| Tipo | NPC inimigo |
| No código | `ai/archetypes/sheriff.tres` — opção do duelo livre + gauntlet. Greybox compartilhado `ai/duelist.tscn`. O visual, o nome, a voz e a história descritos abaixo não estão no código |
| Design | [`../../README.md`](../../README.md) |

Um homem só nos dois degraus. **Encarnado** é o xerife na Main Street e viaja no degrau do Train Rooftop como subxerife (1,5× de vida). O jogo ainda diz apenas "The Sheriff".

## Visual

No jogo hoje: cápsula provisória + chapéu, tingidos de cinza-azulado `Color(0.25, 0.3, 0.45)`. Ainda sem malha própria. Um revólver.

Projetado (`planned`):

- **Leitura à distância:** Um poste vermelho debaixo de um chapéu alto, braços um pouco afastados do corpo, franjas compridas balançando nas duas mangas e um coração de luz do dia na copa do chapéu. Três cores chapadas.
- **Cores:** Jaqueta vermelho-vivo; chapéu e calça sangue de boi; pala, pontas das franjas e estrela douradas. O tom cinza-azulado sai quando a malha chegar.
- **Corpo:** Quarenta e poucos anos, um dândi esguio. Cintura fina, pernas longas e magras, postura de dançarino. O contorno mais alto e mais estreito do elenco, em contraste com o sino do Bêbado.
- **Chapéu:** Copa alta em pão de açúcar, com a aba inclinada para a frente. Um coração foi vazado de um lado ao outro da copa, da frente até atrás, grande o bastante para mostrar o céu.
- **Rosto:** Nunca aparece. Tudo debaixo da aba é um buraco negro até o queixo.
- **Jaqueta:** Curta e justa, vermelho-vivo, com uma pala dourada metálica sobre os ombros e franjas do comprimento do antebraço ao longo das duas mangas, douradas nas pontas.
- **Estrela:** Dourada, no lado esquerdo do peito, com o mesmo coração vazado. O mesmo formato do chapéu, então o mesmo furador cortou os dois.
- **Pernas e botas:** Calça sangue de boi bem ajustada; botas vermelhas, pisando calcanhar com ponta.
- **Arma:** Um revólver com cabo vermelho e um pingente de franja na coronha.
- **Train Rooftop:** Nada muda. Mesma malha, mesma textura; o rebaixamento está no rótulo e nas falas.

## Personalidade / voz

- Texto do gauntlet (no jogo, em inglês): **The crooked sheriff** — o xerife corrupto (Main Street); **Deputy on the 3:10** — subxerife no trem das 3:10 (Train Rooftop, 1,5× de vida).
- Um exibido vaidoso. Atua para a plateia, exista ela ou não, fala de si mesmo e da jaqueta, e está inteiramente à venda.
- Voz: um mestre de picadeiro apresentando o próprio número.
- A vaidade nunca racha. Ele perde ainda em cena, e preocupado com a jaqueta.
- Falas de exemplo, escritas para depois (nenhuma fala de NPC está no jogo):
  - Esperando: "Olha os pés, amigo. Todo mundo olha os pés."
  - No saque: "Cuidado com a jaqueta. Custou um condado."
  - Atingido: "Na franja não. Atira onde quiser, na franja não."
  - Vencendo: "Obrigado. Obrigado. Ele fica em cartaz a semana toda."
  - Train Rooftop, esperando: "Neste trem me chamam de Subxerife. Não começa você também."
  - Morrendo: "Me deita de barriga para cima. A pala aparece mais."

## História

Humano, com um fato estranho: desde que aceitou o passe da ferrovia, o chão debaixo das botas dele é faixa de domínio da companhia. Ele anda sobre um trilho invisível aonde quer que vá e não consegue sair dele.

A ferrovia o comprou com um passe anual, renovado a cada ano em que ele é útil, e o condutor que emitiu o passe furou o chapéu e a estrela dele do jeito que se cancela um bilhete. Na cidade, a estrela ainda faz dele o xerife. No trem, o agente da própria companhia manda mais que ele, então ele viaja no 3:10 como subxerife e odeia isso.

Ele espetou o punho de lata em Lata, por ordem da ferrovia (ver [O Bêbado](drunk.md)).

Ele assinou o papel que dizia que o cânion estava limpo (ver [O Fantasma](ghost.md)).

## Combate (no jogo)

Faz strafe em volta do ponto de spawn do inimigo. Meio da tabela: mais rápido e mais preciso que o Bêbado, mais lento que o Fantasma. O design não muda nenhum parâmetro; a última coluna é a ficção para o que já está no jogo.

| Parâmetro | Valor | Por quê |
|---|---|---|
| `reaction_time` | 0.45 (±0.12) | Ele espera até ter certeza de que você está olhando |
| `draw_time` | 0.45 | |
| `accuracy_angle_deg` | 4.0 | |
| `followup_interval` | 1.0 | |
| `reload_time` | 2.2 | Um floreio que ele não apressa |
| `bullet_speed` | 55 | |
| `health` | 3 | O 1,5× do Train Rooftop é ele enfim sobre trilho de verdade |
| `move_style` | `STRAFE` (`strafe_speed` 0.8) | O andar no trilho: de um lado para o outro sobre uma linha só, calcanhar com ponta |

O aviso do strafe é a franja abrindo para fora antes de ele voltar. Isso vem com a malha; nenhum comportamento, efeito de acerto ou som novo faz parte deste design.

## Referências

- Moodboard #26 (Astrud, "Weird Wild West") e #24: uma figura de vermelho sobre vermelho, com franjas; o glamour como ameaça.
- Moodboard #09 (esboço de Araki): um chapéu com furos recortados.
- Jaqueta de couro de Nudie Cohn para Hank Thompson, anos 1950: pala metálica e franjas cravejadas de strass. <https://countrymusichalloffame.org/exhibit/suiting-the-sound/nudie-cohn-the-original-rhinestone-cowboy/nudie-suits-and-boots/>
- Passes ferroviários: as ferrovias davam passes gratuitos a xerifes, juízes, promotores e escrivães que lhes faziam favores. <https://web.stanford.edu/group/spatialhistory/railroaded/footnotes/themes/corruption_page=16.html> · Debs, 1887: <https://www.marxists.org/archive/debs/works/1887/870300-debs-legislationlawfreetrans.pdf>
- Furadores de condutor: o furador de cada condutor cortava um formato próprio, de modo que um bilhete cancelado podia ser rastreado até ele. <https://www.si.edu/object/nmah_1061199> · <https://www.nps.gov/museum/exhibits/stea/community/occupation/conductor/stea-3269-punch.html>
- A polícia ferroviária não tinha autoridade fora da propriedade da ferrovia, a menos que fosse nomeada subxerife ou policial especial. <https://sk.sagepub.com/ency/edvol/embed/lawenforcement/chpt/railroad-policing>
- Fatos do jogo: os rótulos em uso acima e os atributos em `ai/archetypes/sheriff.tres`.
