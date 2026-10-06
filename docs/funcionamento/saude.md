# Saúde: vacinas e vermífugos

O que a aba **Saúde** faz hoje. As regras de produto estão em [`docs/produto/saude.md`](../produto/saude.md).

## Modelo

**`VaccineDose`** (`lib/features/health/domain/vaccine_dose.dart`): uma dose aplicada, como está na carteirinha. Vacinas e vermífugos usam o mesmo registro.

| Campo | Descrição |
| --- | --- |
| `id`, `pet_id` | UUID da dose e do pet. |
| `kind` | `vaccine` (vacina) ou `dewormer` (vermífugo). |
| `name` | "V10", "Raiva", nome do vermífugo. 1 a 80 caracteres. |
| `applied_on` | Dia da aplicação. Não pode ser no futuro. |
| `next_due_on` | "Revacinar em" na carteirinha. Precisa ser depois da aplicação. Define o status. |
| `product`, `lot`, `veterinarian`, `notes` | Opcionais: produto e fabricante, lote, veterinário (nome e CRMV), observações. |
| `updated_by` | Quem salvou a última versão (inclusive a exclusão). |
| `updated_at`, `deleted_at` | Como nos pets. Excluir marca `deleted_at`. |

## Status

`lib/features/health/domain/vaccine_status.dart`:

- As doses são agrupadas por tipo e nome, ignorando maiúsculas e acentos ("raiva" e "Raíva" são a mesma vacina).
- Em cada grupo, a dose mais recente define o status:

| Faltam | Status | Texto |
| --- | --- | --- |
| Mais de 30 dias | Em dia (`success`) | "Em dia até 04/05/2027" |
| 30 dias ou menos | Vence em breve (`warning`) | "Vence em 12 dias", "Vence amanhã", "Vence hoje" |
| Já passou | Vencida (`danger`) | "Venceu ontem", "Venceu há 3 dias" |

- As doses mais antigas do grupo aparecem como "Substituída por uma dose mais nova" e nunca como vencidas.
- A lista mostra as vencidas primeiro, depois as que vencem em breve, depois as em dia; dentro de cada uma, a data mais próxima primeiro.
- O status sempre aparece com ícone, texto e cor juntos (`StatusBadge`).

## Telas e rotas

| Rota | Tela |
| --- | --- |
| `/saude` | `HealthPage`: vacinas e vermífugos do pet escolhido. Com mais de um pet, um seletor no topo troca de pet. Sem vacinas, convida a registrar a primeira. |
| `/saude/doses/nova?pet=&tipo=&nome=` | `DoseFormPage`: registrar. `tipo` e `nome` são preenchidos quando se registra uma nova dose a partir do histórico. |
| `/saude/doses/:id` | `DoseHistoryPage`: todas as doses daquela vacina, a mais nova primeiro, e o botão "Registrar nova dose". |
| `/saude/doses/:id/editar` | `DoseFormPage`: editar ou excluir um registro. |

No formulário:

- O nome sugere vacinas comuns para cães (V8, V10, Raiva, Giardíase, Tosse dos canis, Gripe canina, Leishmaniose) ou gatos (V3, V4, V5, Raiva, FeLV), e vermífugos. Dá para digitar outro.
- "Aplicada em" começa em hoje. A próxima dose começa em +1 ano para vacinas e +3 meses para vermífugos; os atalhos "+1 ano", "+6 meses" e "+3 meses" recalculam a partir da aplicação.
- Produto, lote, veterinário e observações ficam recolhidos em "Produto, lote e veterinário".

A aba **Início** mostra, em cada pet, a vacina mais urgente com o mesmo selo de status.

## Permissões

Qualquer tutor do pet (vínculo `accepted`) pode registrar, editar e excluir doses (`HealthRepository`, e no servidor as políticas de `pet_vaccines`).

## Ainda não existe

- Lembrete por push 7 dias antes do vencimento.
- Leitura da carteirinha pela câmera ou foto (IA na nuvem).
