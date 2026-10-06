# Contatos

O que a agenda de **Contatos** faz hoje. As regras de produto estão em [`docs/produto/contatos.md`](../produto/contatos.md).

## Modelo

**`Contact`** (`lib/features/contacts/domain/contact.dart`), por casa como a lista de compras (`house_id` é o id do tutor principal):

| Campo | Descrição |
| --- | --- |
| `name` | 1 a 80 caracteres. |
| `category` | `vet`, `nutritionist`, `physio`, `trainer`, `daycare`, `hotel`, `groomer`, `walker`, `lab`, `pet_shop` ou `other`. A ordem do enum é a ordem dos grupos na tela. |
| `phone` | Só dígitos, com DDD (10 ou 11). `normalizePhone` aceita "(11) 98765-4321", "+55 11..." e "011..."; `formatPhone` mostra "(11) 98765-4321". |
| `email` | Em minúsculas, validado. |
| `address`, `notes` | Até 200 e 500 caracteres. |

## Telas

- Entrada: card "Contatos" no topo da aba **Pets**.
- `/pets/contatos` (`ContactsPage`): seletor de casa (o mesmo de Compras, `HouseSelector`), lista agrupada por tipo, busca a partir de seis contatos, botão de ligar em cada um. Tocar abre uma folha com ligar, WhatsApp (celulares: 11 dígitos começando com 9), email, mapa e "Editar contato".
- `/pets/contatos/novo?casa=` e `/pets/contatos/:id` (`ContactFormPage`): tipo em chips com ícone, nome, telefone, email, endereço e observações. Editando, há "Excluir contato".

Os links abrem com `url_launcher`: `tel:`, `https://wa.me/55<número>`, `mailto:` e o Google Maps. Se o celular não conseguir abrir, o app avisa.

Excluir é lógico (`deleted_at`): o contato some da agenda, mas os registros do diário que apontam para ele continuam mostrando o nome.

## Permissões

Qualquer pessoa da casa (`ContactsRepository`, via `Houses`, e no servidor `is_house_member`).
