# Contas e tutores

## Cadastro do usuário

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Nome | Sim | Como a pessoa aparece para os outros tutores. |
| Email | Sim | Usado no login e nos convites. |
| Celular | Sim | Recuperação de senha por WhatsApp e, no futuro, SMS comerciais. Veja abaixo. |

O login é **só por email e senha** no MVP, sem "Entrar com Google" ou "Entrar com Apple". Ele é feito no Supabase, seguido do desbloqueio do aparelho com Face ID, Touch ID ou código (veja [funcionamento](../funcionamento/autenticacao-e-navegacao.md)).

### Para que serve o celular

1. **Recuperação de senha.** No MVP, a recuperação é **por email**. A recuperação por WhatsApp vem depois: integrar o WhatsApp tem custo por mensagem e exige aprovação da Meta. O número só passa a ser confirmado com um código quando o WhatsApp for ativado; até lá, o cadastro não pede confirmação.
2. **SMS comerciais, no futuro.** Mensagens de marketing só vão para quem aceitou recebê-las, em uma opção separada, desmarcada por padrão e que pode ser desligada a qualquer momento. Aceitar os termos do app não vale como esse consentimento.

Celular e nome são dados pessoais. Seguem as regras de [dados e privacidade](dados-e-privacidade.md).

## Papéis

Todo pet tem **um tutor principal** e pode ter **vários tutores**.

| Ação | Tutor principal | Tutor |
| --- | --- | --- |
| Ver tudo do pet | Sim | Sim |
| Editar o cadastro do pet | Sim | Sim |
| Registrar e editar vacinas, vermífugos, medicamentos, incidentes e compras | Sim | Sim |
| Convidar outro tutor | Sim | **Não** |
| Remover um tutor | Sim | Não |
| Transferir o pet para outro tutor | Sim | Não |
| Excluir o pet | Sim | **Não** |
| Sair do pet por conta própria | Só depois de transferir o pet | Sim |

Regra geral: **todos podem editar tudo** nos registros do pet. O que fica só com o tutor principal é gerenciar as pessoas e o pet em si: convidar, remover, transferir e excluir.

## Convite

1. O tutor principal informa o email da pessoa no app. O vínculo é criado com status **pendente**.
2. A pessoa recebe um **email de convite** com um link de confirmação.
3. O link leva a uma página com dois botões, um para baixar na App Store (iOS) e outro no Google Play (Android).
4. **Se a pessoa ainda não tem conta:** o email a convida a se cadastrar como tutora. Enquanto ela não se cadastra, o vínculo continua pendente, e o tutor principal vê "Pendente" ao lado do email dela.
5. **Ao se cadastrar** com o mesmo email do convite, ela passa a ser tutora do pet, com as permissões acima.
6. **Se a pessoa já tem conta:** não há email. O convite chega só na [central de notificações](notificacoes.md) do app, com o botão "Aceitar". O vínculo só fica ativo depois desse toque.

O convite pendente expira em **30 dias**. Depois disso, o tutor principal pode reenviá-lo.

O email é o que liga o convite à pessoa: o cadastro precisa usar o mesmo email que recebeu o convite.

O que isso exige do sistema:

- Envio de email transacional pelo servidor (por exemplo, uma função do Supabase com um provedor de email). Hoje o app não envia email nenhum.
- Uma página para o link do convite, com os botões das lojas. Até o app ser publicado, os botões levam aos testes fechados (TestFlight e teste interno do Google Play).
- Reenviar o convite e cancelar um convite pendente, pelo tutor principal.

## Remoção de tutor

O tutor principal pode remover qualquer tutor. A pessoa removida deixa de ver o pet e os registros dele, inclusive nos aparelhos dela na próxima sincronização.

## Exclusão da conta

Quando alguém exclui a própria conta:

- Pets em que a pessoa é **tutora**: ela sai deles, como na saída por conta própria.
- Pets em que a pessoa é **tutora principal**: o app propõe transferir cada pet para um dos tutores. Ex.: o Bruno exclui a conta, e o app sugere transferir o Bowie para a esposa dele.
- Se o pet não tem outro tutor, ele é excluído junto com a conta, depois de uma confirmação que mostra o nome do pet.

## Saída do tutor

Um tutor pode sair do pet quando quiser, sem pedir ao tutor principal. Ao sair, ele deixa de ver o pet e os registros dele, como na remoção. O que ele registrou enquanto era tutor continua no histórico do pet.

O tutor principal não pode simplesmente sair: antes, precisa transferir o pet para outro tutor (veja abaixo).

## Transferência

O tutor principal pode transferir o pet para um tutor que já aceitou o convite, pelo botão "Transformar em tutor principal" ao lado desse tutor, na tela do pet. A transferência pede confirmação e precisa de internet. Esse é o caminho para o tutor principal sair: ele transfere o papel e depois sai ou é removido.

Depois da transferência:

- O novo tutor principal passa a ter todas as permissões da tabela.
- O antigo tutor principal vira tutor comum, a menos que saia.

## Diferenças em relação ao código atual

- O código chama o tutor principal de `owner`. Na interface e na documentação, use "tutor principal".
- Ainda não existem nome e celular no cadastro, email de convite, remoção e saída de tutor.
- Hoje o convidado precisa tocar em "Accept" no app para aceitar. Pela regra acima, o cadastro com o email do convite já basta.
- No banco atual não há política de exclusão (`delete`). O papel (`role`) de um vínculo só muda pela função `transfer_pet` (veja [backend](../funcionamento/backend-supabase.md#transferência-do-pet)).
