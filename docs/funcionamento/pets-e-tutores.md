# Pets e tutores

## Modelo

Dois tipos de registro, nos mesmos formatos no SQLite e no Postgres:

**`Pet`** (`lib/features/pets/domain/pet.dart`)

| Campo | Descrição |
| --- | --- |
| `id` | UUID v4 gerado no aparelho. |
| `name` | Nome, de 1 a 80 caracteres depois de tirar espaços. |
| `updated_at` | Momento da última alteração, em UTC. |
| `deleted_at` | Marcação de exclusão lógica. Ainda não há tela para excluir. |

**`PetTutor`** (`lib/features/pets/domain/pet_tutor.dart`): uma pessoa ligada a um pet.

| Campo | Descrição |
| --- | --- |
| `id` | UUID v4 gerado no aparelho. |
| `pet_id` | Pet a que se refere. |
| `user_id` | Usuário do Supabase. Fica vazio até o convite ser aceito. |
| `email` | Email da pessoa, normalizado em minúsculas. |
| `role` | `owner` (dono) ou `tutor`. |
| `status` | `pending` (convidado) ou `accepted`. |
| `updated_at`, `deleted_at` | Como em `Pet`. |

Um pet tem exatamente um dono. O vínculo entre pessoa e pet é feito pelo **email**: o convite é criado para um email e qualquer conta com esse email pode aceitá-lo.

## Operações

Todas passam por `PetRepository` (`lib/features/pets/data/pet_repository.dart`), que valida, grava no SQLite e coloca a alteração na fila de envio. Nenhuma operação espera a rede.

### Criar pet

Tela: botão "Adicionar pet" em `/pets` (ou "Cadastrar pet" na aba Início, quando não há pets), que abre `/pets/new`.

- Gera o `Pet` e um `PetTutor` com `role = owner`, `status = accepted` e o `user_id` do usuário atual.
- Grava os dois na mesma transação e enfileira os dois.
- Navega para `/pets/<id>`.

### Renomear pet

Tela: `/pets/:id`, campo "Nome" e botão "Salvar".

- Qualquer pessoa com vínculo `accepted` no pet pode renomear (dono ou tutor).

### Convidar tutor

Tela: `/pets/:id`, campo "Convidar por email". Só aparece para o tutor principal.

Validações:

- O email precisa ter formato válido.
- Não pode ser o próprio email ("Você já cuida deste pet.").
- Só o tutor principal pode convidar ("Só o tutor principal pode convidar pessoas.").
- A pessoa não pode já estar no pet ("Essa pessoa já faz parte deste pet.").

Cria um `PetTutor` com `role = tutor`, `status = pending` e `user_id` vazio. O app não envia email: o convite aparece para a outra pessoa quando ela sincroniza.

### Aceitar convite

Tela: card "Convites" em `/pets`, botão "Aceitar". A aba Início também mostra o convite e leva para `/pets`.

- O convite precisa existir no aparelho e ter sido feito para o email do usuário.
- Muda `status` para `accepted` e preenche `user_id`.
- O pet passa a aparecer na lista.

Não há como recusar um convite, remover um tutor ou excluir um pet pela interface.

## O que cada tela mostra

**`/pets` (`PetsPage`)**

- Faixa de status da sincronização, quando há mensagem (azul para aviso, vermelho para falha).
- "Convites": vínculos `pending` com o email do usuário, mais recentes primeiro.
- Lista de pets em que o usuário tem vínculo `accepted`, em ordem alfabética.
- Botão de sincronizar, botão "Sair" e o sino na barra superior.

**`/pets/:id` (`PetPage`)**

- Nome editável.
- "Tutores": tutor principal primeiro, depois os demais por email, com o rótulo "Tutor principal", "Convite pendente" ou "Tutor".
- Campo de convite, só para o dono.

As duas telas recarregam sozinhas sempre que o banco local muda, seja por ação do usuário ou por dados vindos do servidor.

## Permissões, resumidas

| Ação | Quem pode | Onde é verificado |
| --- | --- | --- |
| Ver um pet | Vínculo `accepted`, ou convite `pending` para o seu email | App (consultas) e RLS |
| Criar pet | Qualquer usuário autenticado | App e RLS |
| Renomear pet | Vínculo `accepted` | `PetRepository` e RLS |
| Convidar | Dono | `PetRepository` e RLS |
| Aceitar convite | Dono da conta com o email convidado | `PetRepository` e RLS |

As regras no aparelho dão retorno imediato. As regras do servidor (veja [Backend no Supabase](backend-supabase.md)) são as que valem.
