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

Não há quantidades nem preços no MVP. O item é só um nome, com uma descrição opcional (ex.: marca, tamanho). Por enquanto, o item também não é ligado a um pet: não existe lista de compras por pet.

Como no Bring, a lista tem um **catálogo de itens com ícones** (ração, petisco, areia, antipulgas, brinquedo etc.), mostrados em blocos fáceis de tocar. Também dá para adicionar um item digitado, fora do catálogo. O item deve seguir os tokens de design, com a cor `category.shopping` para ícones e marcadores.

## Compartilhamento

A lista é **por casa**, não por pet: uma única lista reúne as compras de todos os pets da casa. Ração do Bowie e areia de um gato, por exemplo, ficam na mesma lista.

Todas as pessoas da casa veem e editam a mesma lista. Quando alguém marca um item como comprado, ele some da lista dos outros logo em seguida.

### Como a casa é formada

- Cada tutor principal tem **uma casa**, que reúne todos os pets de que ele é tutor principal.
- Fazem parte da casa o tutor principal e os tutores de qualquer pet dela.
- A casa não é criada à parte: ela existe a partir do primeiro pet cadastrado.
- Quem entra como tutor de um pet passa a ver e editar a lista da casa desse pet. Quem é removido de todos os pets da casa deixa de vê-la.
- Se um pet é transferido, ele passa para a casa do novo tutor principal. Os itens da lista **ficam na casa antiga**: a lista é da casa, e os itens não são ligados a um pet. Exemplo: se a mãe transfere a Mia para o Bruno, a Mia entra na casa do Bruno, e a areia da Mia continua na lista da casa da mãe.

### Quem participa de mais de uma casa

Exemplo: o Bruno é tutor principal do Bowie (casa do Bruno) e tutor convidado da gata da mãe (casa da mãe).

- Cada casa tem a sua lista, separada. Os itens de uma casa nunca aparecem na outra.
- A tela de compras abre na **casa própria** da pessoa, aquela em que ela é tutora principal.
- Um seletor no topo da tela troca de casa. Cada casa aparece com o nome do tutor principal: "Casa do Bruno", "Casa da Ana". Enquanto o cadastro não tiver nome, o app mostra "Minha casa" para a própria e o email do tutor principal nas outras ("Casa de ana@exemplo.com").
- Quem não tem casa própria (por exemplo, um passeador que só é tutor convidado) abre na última casa que usou.

A lista por casa vale "por enquanto" e pode mudar.

## Afiliados (futuro)

Itens da lista poderão levar a lojas parceiras com link de afiliado. Isso não entra no MVP. Quando entrar:

- O link deve ser identificado como parceria.
- Comprar pelo link nunca pode ser obrigatório para usar a lista.
