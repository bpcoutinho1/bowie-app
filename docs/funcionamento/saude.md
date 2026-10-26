# Saúde: cuidados, vacinas, vermífugos, antipulgas e medicações

O que a aba **Saúde** faz hoje. As regras de produto estão em [`docs/produto/saude.md`](../produto/saude.md).

## Modelo

**`VaccineDose`** (`lib/features/health/domain/vaccine_dose.dart`): uma dose aplicada, como está na carteirinha. Vacinas, vermífugos e antipulgas usam o mesmo registro.

| Campo | Descrição |
| --- | --- |
| `id`, `pet_id` | UUID da dose e do pet. |
| `kind` | `vaccine` (vacina), `dewormer` (vermífugo) ou `flea_tick` (pulgas e carrapatos). No app, `DoseKind.code`; `dueLabel` dá "Revacinar em", "Próxima dose em" ou "Trocar em". |
| `name` | "V10", "Raiva", nome do vermífugo, "Coleira Seresto". 1 a 80 caracteres. |
| `applied_on` | Dia da aplicação. Não pode ser no futuro. |
| `next_due_on` | "Revacinar em" na carteirinha. Precisa ser depois da aplicação. Define o status. |
| `product`, `lot`, `veterinarian`, `notes` | Opcionais: produto e fabricante, lote, veterinário (nome e CRMV), observações. |
| `remind_days` | 7, 14 ou 30: quantos dias antes do vencimento o celular avisa (`reminderDayOptions`). Linhas antigas, sem o campo, valem 7. Local: versão 12 do banco do celular. Servidor: migração `20261022120000_flea_tick_reminders.sql`. |
| `proof_paths` | Fotos do comprovante, até 2 (`maxProofPhotos`), em JSON (`["<petId>/<uuid>.jpg"]`). `hasProof` diz se há alguma. |
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

## Comprovante

As fotos ficam no celular (`PetPhotoStore`) e sobem para o bucket `pet-photos` pela mesma fila das fotos do pet (`pet_photos` na outbox), depois da dose. `HealthRepository.saveDose` aceita fotos novas (`DoseInput.newProofs`) e caminhos já no celular (`keptProofs`): os da própria dose, ou arquivos do mesmo pet que já estão no aparelho (as páginas da carteirinha). Caminhos de outro pet são ignorados. Uma foto tirada da dose é apagada do celular e do servidor, a menos que outra dose ainda use o mesmo arquivo (`PetLocalStore.isProofInUse`): uma página da carteirinha pode ser o comprovante de várias doses.

No formulário, "Comprovante" fica antes do botão Salvar, com a explicação de que hotéis e creches costumam pedir. A aba Saúde e o histórico mostram o selo `ProofBadge` ("Com comprovante", ícone de selo verde, ou "Sem comprovante", em cinza), sempre com texto. O histórico mostra as fotos em miniatura; tocar abre com zoom.

## Importante sobre o pet

**`HealthNote`** (`lib/features/health/domain/health_note.dart`): `kind` (`special_care`, `allergy` ou `diet`), `title` (1 a 80) e `details` (até 500). `HealthNoteRepository` lista na ordem cuidados especiais, alergias e alimentação, e só tutores do pet salvam ou excluem (`requirePetMember`). Excluir marca `deleted_at`.

No topo da aba Saúde, "Importante sobre Bowie" lista os registros com ícone (alerta para cuidados e alergias, talheres para alimentação). Tocar abre a edição.

## Telas e rotas

| Rota | Tela |
| --- | --- |
| `/saude` | `HealthPage`: vacinas, vermífugos e antipulgas do pet escolhido. Com mais de um pet, um seletor no topo troca de pet. Sem vacinas, convida a registrar a primeira: no Premium, "Ler a carteirinha" primeiro; no grátis, "Registrar uma vacina" primeiro e a leitura como "(Premium)". |
| `/saude/carteirinha?pet=` | `CardReadingPage`: ler a carteirinha por foto (veja abaixo). Abre pelo ícone de leitura no topo da aba Saúde ou pelo botão "Ler a carteirinha" quando o pet ainda não tem vacinas. |
| `/saude/doses/nova?pet=&tipo=&nome=` | `DoseFormPage`: registrar. `tipo` e `nome` são preenchidos quando se registra uma nova dose a partir do histórico, e `nome` quando se registra uma vacina que falta a partir do sino. |
| `/saude/doses/:id` | `DoseHistoryPage`: todas as doses daquela vacina, a mais nova primeiro, e o botão "Registrar nova dose". |
| `/saude/doses/:id/editar` | `DoseFormPage`: editar ou excluir um registro. |
| `/saude/notas/nova?pet=&tipo=` | `HealthNoteFormPage`: cuidado especial, alergia ou alimentação (`tipo` = `special_care`, `allergy` ou `diet`), num campo que abre a lista dos três. Título com sugestões e detalhes. |
| `/saude/notas/:id` | `HealthNoteFormPage`: editar ou excluir. |

O botão "Registrar" da aba abre `showHealthAddSheet`: "O que você quer registrar?", com Ler a carteirinha com IA (abre `/saude/carteirinha`), Medicação, Vacina ou vermífugo, Contra pulgas e carrapatos (`/saude/doses/nova?tipo=flea_tick`), Alergia, Alimentação e Cuidado especial.

No formulário:

- O tipo é um `ChoiceField` (Vacina, Vermífugo, Pulgas e carrapatos), travado na edição.
- O nome sugere vacinas comuns para cães (V8, V10, Raiva, Giardíase, Tosse dos canis, Gripe canina, Leishmaniose) ou gatos (V3, V4, V5, Raiva, FeLV), vermífugos e antipulgas (Coleira Seresto, Bravecto, NexGard, Simparic e outros, por espécie). Dá para digitar outro.
- "Aplicada em" começa em hoje. A próxima dose começa em +1 ano para vacinas e +3 meses para vermífugos e antipulgas; os atalhos "+1 ano", "+6 meses" e "+3 meses" recalculam a partir da aplicação. No antipulgas, o campo se chama "Trocar em".
- "Lembrete no celular": 7, 14 ou 30 dias antes.
- Produto, lote, veterinário e observações ficam recolhidos em "Produto, lote e veterinário" (no antipulgas, "Lote, veterinário e observações": o nome já é o produto).

A aba **Início** mostra, em cada pet, a vacina mais urgente com o mesmo selo de status.

## Leitura da carteirinha

A regra de produto e o exemplo do Bowie estão em [`docs/produto/carteirinha-de-vacinacao.md`](../produto/carteirinha-de-vacinacao.md). Abre pelo ícone de leitura no topo da aba Saúde, pela primeira opção do "Registrar" ("Ler a carteirinha com IA") e pelo convite da aba quando o pet não tem vacinas. A leitura reconhece vacinas, vermífugos e antipulgas (`kind` `flea_tick`). Precisa da Edge Function `read-vaccine-card` publicada, com o segredo `ANTHROPIC_API_KEY` ([guia](../guias/publicar-leitura-da-carteirinha.md)). A leitura é do Premium: no plano grátis, a tela mostra "Leitura da carteirinha por IA", com "Conhecer o Premium" e "Registrar à mão" (veja [planos](planos.md#no-app)), e a função recusa a leitura com 403. No Premium, a tela tem três etapas:

1. **Fotos.** "Tirar foto" (câmera) ou "Da galeria" (várias de uma vez), até 4 fotos por leitura, com miniaturas que dá para remover. As fotos chegam redimensionadas para no máximo 2000 px, em JPEG com qualidade 85 (`ImagePickerPhotos`, `lib/features/health/data/photo_picker.dart`). O formato é conferido pelos primeiros bytes: JPEG, PNG e WebP passam; outros (como HEIC) mostram um aviso.
2. **Leitura.** Na primeira vez, um diálogo pede consentimento antes de qualquer foto sair do celular ("Enviar as fotos para leitura?"). O aceite fica guardado no aparelho (`PrefsReadingConsent`, chave `card_reading_consent_v1`). `SupabaseCardReader` (`lib/features/health/data/card_reader.dart`) chama a Edge Function `read-vaccine-card` com as fotos em base64 e espera até 160 s. A tela mostra "Lendo a carteirinha de Bowie" e um botão "Cancelar", que descarta a resposta quando ela chegar. Erros voltam como mensagens em português (sem internet, servidor ocupado, foto ilegível).
3. **Revisão.** `buildReview` (`lib/features/health/domain/card_reading.dart`) monta a lista:
   - Doses repetidas na leitura (a mesma página em duas fotos) aparecem uma vez.
   - Doses que o pet já tem (mesmo tipo, nome e data de aplicação) aparecem com "Já registrada" e desmarcadas.
   - Doses sem nome, sem data, com aplicação no futuro ou com a próxima dose antes da aplicação aparecem desmarcadas, com o problema em vermelho. Marcar uma delas abre a correção.
   - Campos que a leitura marcou como incertos aparecem em "Confira: lote, próxima dose", em amarelo.
   - Tocar num registro abre a correção (bottom sheet). Ao confirmar, as dúvidas somem, porque a pessoa conferiu.
   - As fotos aparecem em miniatura no topo; tocar abre a foto com zoom para comparar.
   - Se a leitura achou peso, um item oferece atualizar o peso do perfil. Vem marcado quando o perfil não tem peso ou quando a medição é dos últimos 90 dias e diferente da atual.
   - "Salvar N registros" grava tudo de uma vez (`HealthRepository.saveDoses`: se um registro for inválido, nada é salvo) e o peso, como uma pesagem no diário no dia da medição (`DiaryRepository.recordWeight`); o "Peso atual" do perfil passa a ser a pesagem mais recente (`applyLatestWeight`, veja [diário](diario.md#peso)). Sair com algo lido e não salvo pede confirmação.

Nada é salvo sem passar pela revisão. Ao salvar, cada página que tem uma dose escolhida é guardada no celular e vira o comprovante dessas doses: a Edge Function diz em que foto está cada dose (`photo`, a partir de 1). Sem essa informação, só uma leitura de uma foto só tem comprovante. Páginas sem dose escolhida não são guardadas, e se nada for salvo as páginas são apagadas.

## Medicações

**`Medication`** (`lib/features/health/domain/medication.dart`):

| Campo | Descrição |
| --- | --- |
| `name`, `strength` | Nome (1 a 80) e concentração opcional ("75 mg"). |
| `amount`, `unit` | Quantidade por dose (0,01 a 100) e unidade (`DoseUnit`: comprimido, tablete, cápsula, gota, ml, sachê, pipeta, aplicação, coleira, unidade). `doseText` mostra "2 comprimidos · 75 mg". |
| `frequency`, `interval_count` | `daily`, `weekly`, `monthly`, `every_days` ou `every_months`; o intervalo vale para os dois últimos. |
| `times` | Só para diários: períodos (`morning`, `afternoon`, `night`) com horário, em JSON (`[{"period":"morning","time":"07:00"}]`). |
| `start_on`, `end_on` | Início e fim. Sem fim é uso contínuo. |

`isDueOn(dia)` diz se há dose no dia: diário todo dia; semanal a cada 7 dias desde o início; mensal e "a cada X meses" no mesmo dia do mês do início (o dia 31 cai no último dia dos meses mais curtos); "a cada X dias" a cada X dias. `nextDueOn` acha a próxima data dos não diários.

**`MedDose`**: uma dose marcada como dada, com quem deu (`given_by`, `given_by_email`) e quando. O id é um UUID v5 de remédio + dia + período (`MedicationRepository.doseId`), então dois tutores que marcam a mesma dose gravam o mesmo registro. Desmarcar grava `deleted_at` e mantém quem tinha dado.

`dosesOn(dia, ...)` monta as doses do dia (`DoseSlot`), uma por período dos diários e uma por remédio não diário, em ordem de horário.

Telas:

- Aba Saúde: o botão "Registrar" abre a escolha do que registrar. Com remédios, aparecem "Remédios de hoje" (cada dose com horário, quantidade, um círculo para marcar como dada e "Dada por você às 07:05") e "Medicações do Bowie" (remédios em uso; os encerrados ficam recolhidos).
- `/saude/medicacoes/nova?pet=` e `/saude/medicacoes/:id` (`MedicationFormPage`): nome, concentração, quantidade e unidade, frequência, períodos com horário (padrão 07:00, 13:00 e 19:00) ou intervalo, início, "Uso contínuo" ou fim, observações. Editando, há "Excluir este remédio".
- Início: em cada pet, "Remédios de hoje: 2 de 5 dados · próximo: Pregabalina às 19:00".

## Permissões

Qualquer tutor do pet (vínculo `accepted`) pode registrar, editar e excluir vacinas, remédios e cuidados e marcar doses (`HealthRepository`, `MedicationRepository`, e no servidor as políticas de `pet_vaccines`, `pet_medications`, `pet_medication_doses` e `pet_health_notes`). No servidor, quem marca uma dose só pode se registrar como quem deu.

## Ainda não existe

- Lembrete por push no horário de cada dose e a repetição em 30 minutos.

- Histórico de peso: a leitura só atualiza o peso atual do perfil.
