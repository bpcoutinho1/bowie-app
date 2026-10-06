# Compras: a lista da casa

O que a aba **Compras** faz hoje. As regras de produto estão em [`docs/produto/compras.md`](../produto/compras.md).

## Casa

Não existe tabela de casas. A casa é o **id de usuário do tutor principal**: reúne os pets de que ele é tutor principal e quem é tutor `accepted` de algum deles.

- `Houses` (`lib/features/houses/houses.dart`) é usada por Compras e Contatos. `PetLocalStore.listHouses(email)` lista, a partir dos pets que a pessoa aceitou, os tutores principais desses pets. Cada um é uma casa.
- `House.label`: "Minha casa" para a própria. Para as outras, "Casa de ana@example.com": o cadastro ainda não tem nome, então o app usa o email do tutor principal.
- Quem ainda não tem pet (nem como tutor) não tem casa. A aba convida a cadastrar o primeiro pet.

Casa que a tela abre (`currentHouseProvider`): a escolhida no seletor; senão a própria; senão a última usada neste celular (`PrefsLastHouse`, chave `last_house_id`); senão a primeira. O seletor no topo só aparece para quem participa de mais de uma casa.

## Modelo

**`ShoppingItem`** (`lib/features/shopping/domain/shopping_item.dart`):

| Campo | Descrição |
| --- | --- |
| `id` | UUID gerado no aparelho. |
| `house_id` | Id de usuário do tutor principal da casa. |
| `name` | 1 a 80 caracteres. Não se repete na mesma casa (ignorando maiúsculas e acentos). |
| `details` | Descrição opcional (marca, tamanho), até 120 caracteres. |
| `catalog_key` | Item do catálogo que dá o ícone. Vazio para itens fora do catálogo. |
| `status` | `to_buy` (a comprar) ou `bought` (comprado, fica em "Itens frequentes"). |
| `updated_by`, `updated_at`, `deleted_at` | Quem fez a última alteração, quando, e a exclusão lógica. |

## Catálogo

`lib/features/shopping/domain/shopping_catalog.dart`: 16 itens com ícone Lucide (Ração, Sachê, Petisco, Osso, Areia, Tapete higiênico, Saquinhos, Antipulgas, Vermífugo, Remédio, Shampoo, Brinquedo, Escova, Caminha, Comedouro, Coleira). Um item digitado recebe o ícone do catálogo quando o nome começa por um rótulo ou apelido conhecido ("Ração Golden 15 kg" → Ração; "bolinha" → Brinquedo). Os demais usam uma cesta. As chaves (`food`, `toy`...) ficam gravadas nos itens e não podem mudar.

## Tela

`/compras` (`ShoppingPage`):

- **A comprar**: blocos de três por linha no celular, com ícone na cor `categoryShopping`, nome e descrição. Tocar marca como comprado: o item vai para "Itens frequentes", com "Desfazer" na mensagem.
- **Itens frequentes**: os comprados, em blocos mais apagados. Tocar põe de volta na lista.
- Segurar um bloco abre "Editar" e "Remover" (sai da lista e dos frequentes).
- **Adicionar item** abre uma folha com o campo "O que precisa comprar?", a descrição opcional e o catálogo, filtrado pelo que se digita. Tocar num bloco do catálogo ou em "Adicionar \"…\"" adiciona. A folha continua aberta para adicionar vários em seguida. Itens do catálogo que já estão na lista aparecem com um visto.
- Adicionar um nome que está nos frequentes devolve esse item para a lista, em vez de criar outro. Um nome que já está na lista mostra "Ração já está na lista."

## Permissões

Qualquer pessoa da casa vê e altera a lista (`ShoppingRepository` e, no servidor, a função `is_house_member` nas políticas de `shopping_items`).

## Ainda não existe

- Aviso na central de notificações quando alguém adiciona um item.
- Atualização em tempo real: a lista de outra pessoa só muda na próxima sincronização dela (veja [sincronização](sincronizacao.md#quando-a-sincronização-roda)).

O aviso de "Desfazer" some sozinho depois de 5 segundos (`persist: false`). Desde o Flutter 3.29, um aviso com ação fica na tela até ser fechado, e ele cobria o botão "Adicionar item".
- Links de afiliado.
