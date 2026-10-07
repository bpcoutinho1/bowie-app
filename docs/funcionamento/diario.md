# Diário

O que a aba **Diário** faz hoje. As regras de produto estão em [`docs/produto/diario.md`](../produto/diario.md).

## Modelo

**`PetEvent`** (`lib/features/diary/domain/pet_event.dart`):

| Campo | Descrição |
| --- | --- |
| `id`, `pet_id` | UUID do registro e do pet. |
| `kind` | `symptom` (Sintoma), `vet_visit` (Consulta), `exam` (Exame) ou `other` (Outro). |
| `title` | 1 a 80 caracteres. Sugestões por tipo em `eventSuggestions`. |
| `occurs_on` | O dia. De 2000 até o fim do ano daqui a 5 anos. |
| `occurs_time` | Horário opcional, `HH:MM`. |
| `notes` | Até 1000 caracteres. |
| `photo_paths` | Até 4 fotos (`maxEventPhotos`), em JSON: caminhos `<id do pet>/<id da foto>.jpg` no bucket privado `pet-photos`, os mesmos da foto do pet. |
| `contact_id` | Um contato da casa do pet (veja [contatos](contatos.md)). O repositório recusa contato de outra casa. |
| `updated_by`, `updated_at`, `deleted_at` | Como nas vacinas. Excluir marca `deleted_at`. |

`isScheduled(hoje)`: o dia é depois de hoje. `upcomingEvents` lista os agendados, o mais próximo primeiro. `sortEvents` ordena do dia mais recente para o mais antigo; dentro do dia, os com horário em ordem de horário.

## Tela

`/diario` (`DiaryPage`):

- Seletor de pet (o mesmo da Saúde, `PetSelector`), quando há mais de um.
- `MonthCalendar` (`lib/features/diary/presentation/month_calendar.dart`): mês com setas, domingo primeiro, hoje com contorno, dia escolhido preenchido com `primary`. Dias com registros têm um ponto na cor `categoryIncidents`: cheio para o passado, vazado para agendamentos. Cada dia tem rótulo de acessibilidade ("Hoje, 2 registros").
- O dia escolhido (padrão: hoje) com os registros dele, depois "Próximos agendamentos" (até 5) e "Registros recentes" (até 5).
- Cada registro (`EventCard`) mostra tipo, "Agendado", horário, contato e o começo das observações. Com contato com telefone, um botão liga.
- O botão principal diz "Registrar" ou "Agendar", conforme o dia escolhido.

`/diario/novo?pet=&dia=` e `/diario/:id` (`EventFormPage`): tipo, título com sugestões, dia, horário opcional (com botão para tirar), profissional ou local (lista de contatos da casa do pet), observações. Em "Sintoma", um texto lembra que o diário não faz diagnóstico. Editando, há "Excluir este registro".

Fotos (`lib/features/diary/presentation/event_photos.dart`):

- No formulário, "Fotos" mostra miniaturas com um botão para remover e um bloco "Adicionar" (tirar foto ou escolher da galeria, até 1600 px).
- `DiaryRepository.saveEvent` grava as fotos novas no celular (`PetPhotoStore`) e, na mesma transação do registro, enfileira o envio delas e a remoção das que saíram. As que saíram também saem do celular. Excluir o registro apaga todas as fotos dele.
- Nos registros do diário, as fotos aparecem em miniatura (`EventPhotoStrip`). Tocar abre a galeria em tela cheia, com zoom e deslizar entre as fotos. Fotos tiradas por outro tutor são baixadas uma vez e guardadas.

A aba **Início** mostra, em cada pet, um horário marcado para hoje ou o próximo agendamento (`_NextAppointment`).

## Permissões

Qualquer tutor `accepted` do pet (`DiaryRepository` e as políticas de `pet_events`).

## Ainda não existe

- Lembrete por push de agendamentos.
- Aviso na central de notificações.
