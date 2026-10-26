# Diário

O que a aba **Diário** faz hoje. As regras de produto estão em [`docs/produto/diario.md`](../produto/diario.md).

## Modelo

**`PetEvent`** (`lib/features/diary/domain/pet_event.dart`):

| Campo | Descrição |
| --- | --- |
| `id`, `pet_id` | UUID do registro e do pet. |
| `kind` | `symptom` (Sintoma), `vet_visit` (Consulta), `exam` (Exame), `weight` (Peso) ou `other` (Outro). Um tipo desconhecido (de uma versão mais nova) vira `other`. |
| `title` | 1 a 80 caracteres. Sugestões por tipo em `eventSuggestions`. |
| `occurs_on` | O dia. De 2000 até o fim do ano daqui a 5 anos. |
| `occurs_time` | Horário opcional, `HH:MM`. |
| `notes` | Até 1000 caracteres. |
| `photo_paths` | Até 4 fotos (`maxEventPhotos`), em JSON: caminhos `<id do pet>/<id da foto>.jpg` no bucket privado `pet-photos`, os mesmos da foto do pet. |
| `files` | Até 5 PDFs (`maxEventFiles`), em JSON: `[{"path": "<id do pet>/<id>.pdf", "name": "Hemograma.pdf"}]`, no mesmo bucket. |
| `contact_id` | Um contato da casa do pet (veja [contatos](contatos.md)). O repositório recusa contato de outra casa. |
| `weight_kg` | Só nas pesagens (`weight`): de 0,1 a 150 kg, com uma casa decimal. Local: versão 13 do banco do celular. Servidor: migração `20261026120000_weight_and_pet_dates.sql`. |
| `updated_by`, `updated_at`, `deleted_at` | Como nas vacinas. Excluir marca `deleted_at`. |

`isScheduled(hoje)`: o dia é depois de hoje. `upcomingEvents` lista os agendados, o mais próximo primeiro. `sortEvents` ordena do dia mais recente para o mais antigo; dentro do dia, os com horário em ordem de horário.

## Tela

`/diario` (`DiaryPage`):

- Seletor de pet (o mesmo da Saúde, `PetSelector`), quando há mais de um.
- `MonthCalendar` (`lib/features/diary/presentation/month_calendar.dart`): mês com setas, domingo primeiro, hoje com contorno, dia escolhido preenchido com `primary`. Dias com registros têm um ponto na cor `categoryIncidents`: cheio para o passado, vazado para agendamentos. Cada dia tem rótulo de acessibilidade ("Hoje, 2 registros").
- O dia escolhido (padrão: hoje) com os registros dele, depois "Próximos agendamentos" (até 5) e "Registros recentes" (até 5).
- Cada registro (`EventCard`) mostra tipo, "Agendado", horário, contato e o começo das observações. Com contato com telefone, um botão liga.
- O botão principal diz "Registrar" ou "Agendar", conforme o dia escolhido.

`/diario/novo?pet=&dia=&tipo=` e `/diario/:id` (`EventFormPage`): tipo (um campo que abre a lista Sintoma, Consulta, Exame, Peso e Outro, cada um com ícone e exemplo; `tipo=peso` já abre em Peso), título com sugestões, dia, horário opcional (com botão para tirar), profissional ou local (lista de contatos da casa do pet), observações. Em "Sintoma", um texto lembra que o diário não faz diagnóstico. Editando, há "Excluir este registro".

## Peso

- No formulário, o tipo **Peso** ("Controle o peso do seu pet") troca o título por "Peso (kg)" e esconde horário, contato, fotos e arquivos. O dia vai só até hoje.
- `DiaryRepository.saveEvent` desvia para `_saveWeight`: confere o peso (0,1 a 150 kg) e o dia (não futuro), arredonda para uma casa e grava o título "Peso: 23,5 kg", para outras telas e versões antigas do app lerem. Um registro que vira pesagem perde fotos e arquivos.
- `recordWeight` grava a pesagem de um dia, trocando a que já existe nesse dia. É usado pelo "Peso atual" da página do pet (pesagem de hoje, quando o valor muda) e pela leitura da carteirinha (no dia da medição).
- `weightHistory` (em `pet_event.dart`) lista as pesagens da mais antiga para a mais nova, uma por dia. `applyLatestWeight` (`lib/features/diary/data/weight_sync.dart`) põe a mais recente no "Peso atual" do perfil; o formulário chama ao salvar ou excluir uma pesagem.
- Página do pet: embaixo de "Peso atual", `WeightChart` (`lib/features/pets/presentation/weight_chart.dart`), desenhado com `CustomPaint`: datas no eixo horizontal (primeira e última, em proporção ao tempo), kg no vertical (três ou mais marcas, `weightTicks`), linha e pontos em `link`, grade em `border`. Acima, um resumo ("+2,5 kg desde 01/06/2026"); para leitores de tela, um rótulo com o número de pesagens, a primeira e a última. Abaixo, "Registrar peso" abre `/diario/novo?pet=&tipo=peso`. Se o "Peso atual" não foi mexido, ele acompanha uma pesagem nova.
- Na ficha compartilhada com o veterinário, a pesagem aparece no diário como "Peso".

Fotos (`lib/features/diary/presentation/event_photos.dart`):

- No formulário, "Fotos" mostra miniaturas com um botão para remover e um bloco "Adicionar" (tirar foto ou escolher da galeria, até 1600 px).
- `DiaryRepository.saveEvent` grava as fotos novas no celular (`PetPhotoStore`) e, na mesma transação do registro, enfileira o envio delas e a remoção das que saíram. As que saíram também saem do celular. Excluir o registro apaga todas as fotos dele.
- Nos registros do diário, as fotos aparecem em miniatura (`EventPhotoStrip`). Tocar abre a galeria em tela cheia, com zoom e deslizar entre as fotos. Fotos tiradas por outro tutor são baixadas uma vez e guardadas.

Arquivos (`lib/features/diary/presentation/event_files.dart`), em qualquer tipo de registro:

- No formulário, "Arquivos" lista os PDFs com um botão para remover e "Adicionar PDF", que abre o seletor de arquivos do celular (`DocumentPicker`, com `file_picker`; no iOS, o app Arquivos). Arquivos acima de 10 MB são recusados antes de serem lidos.
- `DiaryRepository.saveEvent` confere que é PDF pelos primeiros bytes (`%PDF`), o limite de 10 MB (`maxEventFileBytes`) e de 5 arquivos, e limpa o nome (`cleanFileName`: sem pastas nem caracteres estranhos, até 80 caracteres, sempre `.pdf`). Envio e remoção seguem a mesma fila das fotos; o tipo do arquivo no Storage vem dos primeiros bytes (`fileMediaType`).
- Nos registros, cada PDF vira um botão com o nome. Tocar abre no visualizador do celular (`DocumentOpener`, com `open_filex`), a partir de uma cópia temporária com o nome original. Arquivos de outro tutor são baixados uma vez e guardados.
- Os PDFs entram na ficha compartilhada com o veterinário.

A aba **Início** mostra, em cada pet, um horário marcado para hoje ou o próximo agendamento (`_NextAppointment`).

## Permissões

Qualquer tutor `accepted` do pet (`DiaryRepository` e as políticas de `pet_events`).

## Ainda não existe

- Lembrete por push de agendamentos.
- Aviso na central de notificações.
