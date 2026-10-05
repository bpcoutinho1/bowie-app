# Documentação do Bowie

Esta pasta guarda a documentação do projeto. O `README.md` da raiz continua sendo o guia rápido (como rodar, como configurar o Supabase). Aqui fica o que explica **como o app funciona** e **por que** ele foi feito assim.

## Estrutura

| Pasta | Conteúdo | Quem decide |
| --- | --- | --- |
| [`produto/`](produto/) | O que o app **deve** fazer: visão, regras de negócio, prioridade do MVP e questões em aberto. | Fundador do produto. |
| [`funcionamento/`](funcionamento/) | O que o app faz **hoje**: telas, autenticação, dados, sincronização e backend. | O código. |
| [`guias/`](guias/) | Passo a passo para tarefas práticas, como [rodar o app no Xcode](guias/rodar-no-iphone.md). | — |
| [`design/`](design/) | Regras de uso da marca. Os arquivos (tokens, logo, ícones) ficam em [`/design`](../design/). | Fundador do produto. |

A diferença entre `produto/` e `funcionamento/` mostra o que ainda falta construir.

Seções que podem entrar depois, quando houver material para elas:

- `decisoes/`: registros de decisão (ADRs), um arquivo por decisão, no formato `AAAA-MM-DD-titulo.md`.

## Produto

Comece pelo [índice do produto](produto/README.md), que traz a prioridade do MVP.

## Funcionamento do app

1. [Visão geral](funcionamento/visao-geral.md): o que o app faz, a pilha e a organização do código.
2. [Fluxo de telas e autenticação](funcionamento/autenticacao-e-navegacao.md): login, desbloqueio do aparelho e rotas.
3. [Pets e tutores](funcionamento/pets-e-tutores.md): o modelo de dados e as regras de quem pode fazer o quê.
4. [Armazenamento local e sincronização](funcionamento/sincronizacao.md): SQLite, outbox, push e pull.
5. [Backend no Supabase](funcionamento/backend-supabase.md): tabelas, políticas de RLS e gatilhos.

## Convenções

- Escreva em português. Nomes de código (classes, arquivos, tabelas, rotas) ficam como estão no código.
- Ao citar código, use o caminho a partir da raiz do repositório, por exemplo `lib/app/router.dart`.
- Em `funcionamento/`, descreva só o comportamento atual. O que ainda vai ser feito fica em `produto/`.
- Quando uma mudança no código alterar algo descrito aqui, atualize o documento no mesmo commit.
- Diagramas usam [Mermaid](https://mermaid.js.org/), que o GitHub renderiza direto no Markdown.
