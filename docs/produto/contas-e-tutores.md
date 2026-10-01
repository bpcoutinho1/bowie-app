# Contas e tutores

## Cadastro do usuário

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Nome | Sim | Como a pessoa aparece para os outros tutores. |
| Email | Sim | Usado no login e nos convites. |
| Celular | A definir | Uso ainda em aberto (veja [questões em aberto](questoes-em-aberto.md)). |

O login continua por email e senha no Supabase, seguido do desbloqueio do aparelho com Face ID, Touch ID ou código (veja [funcionamento](../funcionamento/autenticacao-e-navegacao.md)).

Celular e nome são dados pessoais. Seguem as regras de [dados e privacidade](dados-e-privacidade.md).

## Papéis

Todo pet tem **um tutor principal** e pode ter **vários tutores**.

| Ação | Tutor principal | Tutor |
| --- | --- | --- |
| Ver tudo do pet | Sim | Sim |
| Editar o cadastro do pet | Sim | Sim |
| Registrar e editar vacinas, vermífugos, medicamentos, incidentes e compras | Sim | Sim |
| Convidar outro tutor | Sim | A definir |
| Remover um tutor | Sim | Não |
| Transferir o pet para outro tutor | Sim | Não |
| Excluir o pet | Sim | **Não** |

Regra geral: **todos podem editar tudo**. A única ação proibida para o tutor convidado, além de remover pessoas e transferir o pet, é excluir o cadastro do pet.

## Convite

1. O tutor principal informa o email da pessoa.
2. A pessoa vê o convite ao entrar no app com esse email e aceita.
3. A partir daí ela é tutora do pet, com as permissões acima.

Hoje o app não avisa a pessoa por email nem por notificação. Isso está nas [questões em aberto](questoes-em-aberto.md).

## Remoção de tutor

O tutor principal pode remover qualquer tutor. A pessoa removida deixa de ver o pet e os registros dele, inclusive nos aparelhos dela na próxima sincronização.

## Transferência

O tutor principal pode transferir o pet para um tutor que já aceitou o convite. Esse é o caminho para o tutor principal sair: ele transfere o papel e depois sai ou é removido.

Depois da transferência:

- O novo tutor principal passa a ter todas as permissões da tabela.
- O antigo tutor principal vira tutor comum, a menos que saia.

## Diferenças em relação ao código atual

- O código chama o tutor principal de `owner`. Na interface e na documentação, use "tutor principal".
- Ainda não existem nome e celular no cadastro, remoção de tutor, transferência nem exclusão de pet.
- No banco atual não há política de exclusão (`delete`) e o gatilho `pet_tutors_protect_identity` impede trocar o papel (`role`) de um vínculo. A transferência vai exigir uma mudança no esquema.
