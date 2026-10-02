# Contas e tutores

## Cadastro do usuário

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Nome | Sim | Como a pessoa aparece para os outros tutores. |
| Email | Sim | Usado no login e nos convites. |
| Celular | Sim | Recuperação de senha por WhatsApp e, no futuro, SMS comerciais. Veja abaixo. |

O login continua por email e senha no Supabase, seguido do desbloqueio do aparelho com Face ID, Touch ID ou código (veja [funcionamento](../funcionamento/autenticacao-e-navegacao.md)).

### Para que serve o celular

1. **Recuperação de senha por WhatsApp.** Quem esqueceu a senha pode recebê-la pelo WhatsApp, além do caminho por email. Para isso, o número precisa ser confirmado (por exemplo, com um código) antes de ser usado.
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

O email é o que liga o convite à pessoa: o cadastro precisa usar o mesmo email que recebeu o convite.

O que isso exige do sistema:

- Envio de email transacional pelo servidor (por exemplo, uma função do Supabase com um provedor de email). Hoje o app não envia email nenhum.
- Uma página para o link do convite, com os botões das lojas. Até o app ser publicado, os botões levam aos testes fechados (TestFlight e teste interno do Google Play).
- Reenviar o convite e cancelar um convite pendente, pelo tutor principal.

## Remoção de tutor

O tutor principal pode remover qualquer tutor. A pessoa removida deixa de ver o pet e os registros dele, inclusive nos aparelhos dela na próxima sincronização.

## Saída do tutor

Um tutor pode sair do pet quando quiser, sem pedir ao tutor principal. Ao sair, ele deixa de ver o pet e os registros dele, como na remoção. O que ele registrou enquanto era tutor continua no histórico do pet.

O tutor principal não pode simplesmente sair: antes, precisa transferir o pet para outro tutor (veja abaixo).

## Transferência

O tutor principal pode transferir o pet para um tutor que já aceitou o convite. Esse é o caminho para o tutor principal sair: ele transfere o papel e depois sai ou é removido.

Depois da transferência:

- O novo tutor principal passa a ter todas as permissões da tabela.
- O antigo tutor principal vira tutor comum, a menos que saia.

## Diferenças em relação ao código atual

- O código chama o tutor principal de `owner`. Na interface e na documentação, use "tutor principal".
- Ainda não existem nome e celular no cadastro, email de convite, remoção e saída de tutor, transferência nem exclusão de pet.
- Hoje o convidado precisa tocar em "Accept" no app para aceitar. Pela regra acima, o cadastro com o email do convite já basta.
- No banco atual não há política de exclusão (`delete`) e o gatilho `pet_tutors_protect_identity` impede trocar o papel (`role`) de um vínculo. A transferência vai exigir uma mudança no esquema.
