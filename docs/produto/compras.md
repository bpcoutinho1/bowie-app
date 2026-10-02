# Lista de compras

Uma lista compartilhada entre os tutores, inspirada no app [Bring!](https://www.getbring.com/): itens grandes e fáceis de tocar, e um jeito rápido de pôr de volta na lista o que se compra sempre.

## Como funciona

A lista tem duas partes:

1. **A comprar:** os itens que precisam ser comprados.
2. **Itens frequentes:** itens já usados antes, prontos para voltar à lista com um toque.

Fluxo:

1. Alguém adiciona um item (ex.: "Ração 15 kg"). Ele entra em "A comprar".
2. Quando o item é comprado, a pessoa toca nele. Ele sai de "A comprar" e vai para "Itens frequentes".
3. Quando o item faz falta de novo, um toque em "Itens frequentes" o devolve para "A comprar".

Não há quantidades nem preços no MVP. O item é só um nome, com uma descrição opcional (ex.: marca, tamanho).

Como no Bring, a interface pode mostrar os itens em blocos, com ícone ou imagem, em vez de uma lista de texto. O item deve seguir os tokens de design, com a cor `category.shopping` para ícones e marcadores.

## Compartilhamento

A lista é **por casa**, não por pet: uma única lista reúne as compras de todos os pets da casa. Ração do Bowie e areia de um gato, por exemplo, ficam na mesma lista.

Todas as pessoas da casa veem e editam a mesma lista. Quando alguém marca um item como comprado, ele some da lista dos outros logo em seguida.

Ainda está em aberto como uma casa é formada e quem faz parte dela (veja [questões em aberto](questoes-em-aberto.md)). Essa decisão vale "por enquanto" e pode mudar.

## Afiliados (futuro)

Itens da lista poderão levar a lojas parceiras com link de afiliado. Isso não entra no MVP. Quando entrar:

- O link deve ser identificado como parceria.
- Comprar pelo link nunca pode ser obrigatório para usar a lista.
