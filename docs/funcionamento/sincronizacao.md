# Armazenamento local e sincronização

O app funciona primeiro no aparelho. Toda leitura vem do SQLite e toda escrita vai para o SQLite. A sincronização com o Supabase acontece por trás, quando há sessão e internet.

```mermaid
flowchart LR
    UI[Telas] -->|lê / escreve| Repo[PetRepository]
    Repo --> Store[(SQLite: pets, pet_tutors, sync_outbox)]
    Store -->|changes| UI
    Store -->|changes local| Ctrl[SyncController]
    Net[NetworkStatus] -->|mudou conexão| Ctrl
    Ctrl --> Svc[PetSyncService]
    Svc -->|1. push outbox| API[SupabasePetApi]
    Svc -->|2. pull tudo| API
    API --> SB[(Supabase)]
    Svc -->|applyRemote| Store
```

## Banco local

Arquivo `bowie.db`, criado por `PetLocalStore` (`lib/features/pets/data/pet_local_store.dart`). Tabelas:

- `pets` e `pet_tutors`: espelho das tabelas do servidor.
- `sync_outbox`: alterações que ainda não subiram. Colunas `entity` (`pets` ou `pet_tutors`), `entity_id`, `payload` (o registro em JSON) e `created_at`.

A outbox tem índice único em `(entity, entity_id)`. Se o mesmo registro é alterado duas vezes antes de subir, fica só a última versão.

Toda gravação local atualiza a tabela e a outbox na mesma transação e emite um evento no stream `changes` (`ChangeReason.local`). Dados vindos do servidor emitem `ChangeReason.remote`.

## Quando a sincronização roda

`SyncController` (`lib/features/pets/data/pet_sync_controller.dart`) dispara `sync()` quando:

1. O `AuthGate` passa a `ready` (depois do login ou do desbloqueio).
2. Há uma alteração local.
3. A conectividade muda (por exemplo, o aparelho volta a ficar online).
4. O usuário toca no botão de sincronizar em `/pets`.

Não há sincronização periódica nem ao voltar do segundo plano. Alterações feitas por outra pessoa só aparecem quando um desses eventos acontece.

`PetSyncService` evita execuções em paralelo: se um `sync()` chega com outro em andamento, ele reaproveita o que está rodando e marca para rodar mais uma vez no final.

## Um ciclo de sincronização

`PetSyncService._once` (`lib/features/pets/data/pet_sync_service.dart`):

1. Sem Supabase configurado ou sem sessão: termina como `SyncSkipped`.
2. Offline: termina como `SyncWaiting`, com a mensagem "Saved on this device. Will sync when you are online." se houver pendências, ou "You are offline. Showing what is saved on this device." se não houver.
3. **Push**: envia a outbox, primeiro os `pets`, depois os `pet_tutors`, e dentro de cada grupo por ordem de criação. Pets vão antes para que o servidor já conheça o pet quando receber o vínculo.
   - Depois de cada envio, o item sai da outbox, mas só se o `payload` ainda for o mesmo que foi enviado. Se o usuário alterou o registro durante o envio, a nova versão continua na fila.
   - No primeiro erro, o push para e o ciclo termina.
4. **Pull**: baixa todos os `pets` e `pet_tutors` que o usuário pode ver (de 200 em 200, ordenados por `updated_at` e `id`) e aplica no SQLite.
5. Termina como `SyncOk`.

### Como cada registro é enviado

`SupabasePetApi._save` (`lib/features/pets/data/pet_remote_api.dart`) faz um **update pelo id e, se nada foi atualizado, um insert**. Um upsert simples não funcionaria: o Postgres checaria a política de insert contra a linha final, e isso rejeitaria a aceitação de um convite. Se o insert falhar com chave duplicada (`23505`), tenta o update de novo.

### Como o pull é aplicado

`PetLocalStore.applyRemote`:

- Registros com alteração pendente na outbox são ignorados. A versão local vence até subir.
- Vínculos de tutor só entram se o pet correspondente existir localmente.
- Os demais sobrescrevem a cópia local. Depois que a alteração sobe, o que vale é o que o servidor devolve.

## Resultado e mensagens

| Resultado | Quando | O que a tela mostra |
| --- | --- | --- |
| `SyncOk` | Push e pull concluídos | Nada; atualiza `lastSyncedAt`. |
| `SyncSkipped` | Sem Supabase ou sem sessão | Nada. |
| `SyncWaiting` | Offline ou erro de rede (`AppFailure.retryable`) | Faixa azul com a mensagem. |
| `SyncFailed` | Erro do servidor, como violação de RLS | Faixa vermelha com a mensagem. |

Erros de rede (`SocketException`, timeout, falha de DNS) viram "Could not reach the server. Changes stay on this device." e são tratados como temporários.

## Limitações conhecidas

- **Sem sincronização periódica.** Mudanças de outras pessoas só chegam com um dos gatilhos acima.
- **O pull não remove registros.** Se o servidor deixar de devolver uma linha (por exemplo, porque o acesso foi revogado no banco), a cópia local continua lá.
- **O banco local não é limpo no sign out.** As telas filtram pelo email do usuário, então outra conta não vê os pets da anterior. Mas a outbox continua, e pendências de uma conta seriam enviadas com a sessão da próxima, onde o RLS as rejeita e o push para nesse item.
- **Um item rejeitado trava a fila.** Como o push para no primeiro erro, um item que o servidor sempre recusa impede os seguintes de subir.
- **Conflitos simples.** Não há comparação de `updated_at` entre aparelhos: a última escrita que chega ao servidor prevalece.
