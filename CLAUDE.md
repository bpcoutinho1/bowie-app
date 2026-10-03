# Bowie: guia para o Claude Code

Leia este arquivo antes de criar ou alterar qualquer tela, componente, asset ou regra de negócio.

## O produto

Bowie é um app de iOS e Android, em Flutter, para tutores de cães e gatos registrarem a vida do pet e dividirem o cuidado com outras pessoas. O nome homenageia o border collie do fundador, Bruno Coutinho, que tem heterocromia (um olho castanho, outro azul) e orelhas assimétricas. É isso que o logo mostra.

Tom da marca: **ternura com credibilidade**. O app guarda dados de saúde de um membro da família: carinhoso, mas nunca infantil, e sempre claro e confiável.

## Onde estão as coisas

```
docs/produto/          o que o app DEVE fazer: visão, regras de negócio, prioridade do MVP, questões em aberto
docs/funcionamento/    o que o código faz HOJE
docs/design/           regras de uso da marca
design/tokens/         tokens.json (fonte da verdade) e derivados para web (tokens.css, theme.ts, tailwind.preset.js)
design/brand/logo/     símbolo, wordmark e lockups em SVG (+ PNG em logo/png/)
design/brand/app-icon/ ícone 1024, foreground adaptativo Android, splash
scripts/               outline-wordmark.py (regenera o logo em curvas)
lib/                   app Flutter (veja docs/funcionamento/visao-geral.md)
supabase/migrations/   esquema do banco e políticas de RLS
```

## Regras de trabalho

- **Escopo:** `docs/produto/` decide o que construir e em que ordem. Se uma regra estiver em `docs/produto/questoes-em-aberto.md`, pergunte antes de inventar uma resposta.
- **Documentação junto com o código:** uma mudança que altera o comportamento descrito em `docs/funcionamento/` atualiza o documento no mesmo commit. Ao concluir uma área do MVP, atualize a tabela de prioridade em `docs/produto/README.md`.
- **Vocabulário:** na interface e na documentação, use "tutor principal" (no código e no banco ainda aparece como `owner`) e "tutor".
- **Testes:** rode `flutter test` antes de enviar.

## Design no Flutter

**Regra:** `design/tokens/tokens.json` é a fonte da verdade. O tema Flutter (`lib/app/theme.dart`) usa `lib/app/design_tokens.dart`, gerado por `python3 scripts/generate-dart-tokens.py`. Se um valor mudar, mude no JSON, rode o script e atualize os derivados de web em `design/tokens/` no mesmo commit. Nunca escreva uma cor solta em widget: use `context.colors` (a `ThemeExtension` `BowieColors`) e os estilos de `BowieType`.

### Cores

Paleta da marca (aprovada):

| Token | Hex | Uso |
|---|---|---|
| `night` (Azul Noite) | `#1D2B45` | Cor primária: textos, botão primário, contornos |
| `bowieBlue` (Azul Bowie) | `#6FA8DC` | Fundo do ícone, destaques, anel de foco. **Nunca como texto sobre branco** (2.5:1) |
| `chestnut` (Castanho) | `#9A6440` | Acento quente, coração do logo |
| `merle` | `#8C97A6` | Ilustração e divisores. **Não usar para texto** (3:1) |
| `smile` (Sorriso) | `#EE8E98` | Afeto, uso raro (ex.: aniversário do pet) |
| `mist` (Névoa) | `#F4F6F8` | Fundo do app |

Nos widgets, use os **tokens semânticos** (`background`, `surface`, `text`, `textMuted`, `primary`, `accent`, `link`, `success`, `warning`, `danger`, `info` e as versões `*Soft`). Eles têm variantes clara e escura, e o app segue o tema do sistema. Todas as combinações texto/fundo previstas passam no contraste WCAG AA (≥ 4.5:1).

- Texto azul sobre branco usa `link` (`#2F6FA8`), não o Azul Bowie.
- Botão primário: fundo `primary` + texto `textOnPrimary`. No tema escuro o primário vira Azul Bowie com texto escuro, e isso já está nos tokens.
- Cores por área (`category.vaccines`, `category.shopping`, `category.incidents`) servem para ícones e marcadores de seção, não para fundos grandes.
- Status de vacina: em dia → `success`; vence em ≤ 30 dias → `warning`; vencida → `danger`. Nunca indique status só pela cor: acompanhe sempre com texto ("Vence em 12 dias") e ícone.

### Tipografia

- Fonte única: **Figtree** (licença OFL), nos pesos 400, 600 e 800, já empacotada em `assets/fonts/` e declarada no `pubspec.yaml`.
- ExtraBold (800) para títulos e para a assinatura "bowie". Semibold (600) para rótulos e ênfase. Regular (400) para leitura.
- Use a escala de `typography` de `tokens.json` (display, title1–3, body, bodyStrong, callout, caption, overline), mapeada no `TextTheme`. Não invente tamanhos novos. `letterSpacing` está em em: multiplique pelo tamanho da fonte.
- Respeite o tamanho de fonte do sistema (Dynamic Type no iOS, escala de fonte no Android). Não trave `textScaler`.

### Layout e componentes

- Espaçamento em grade de 4 (`spacing`). Margem lateral padrão: 16 (`spacing[4]`) no celular e 24 no tablet.
- Raios: `md` 12 para inputs e botões, `lg` 18 para cards, `xl` 28 para bottom sheets.
- Cards: fundo `surface` com `shadow.card` sobre o fundo `background`. Sem bordas coloridas laterais.
- Alvos de toque com no mínimo 44×44.
- Ícones: **Lucide** (`lucide_icons_flutter`, `LucideIcons.*`), na cor `text` ou `textMuted`. Sem emoji na interface. O Phosphor foi descartado: o pacote para Flutter não compila nas versões atuais.
- Movimento: `motion.fast` (150 ms) para feedback e `motion.base` (250 ms) para transições, com a curva `motion.easing` (`Cubic(0.2, 0, 0, 1)`). Respeite "reduzir movimento" (`MediaQuery.disableAnimations`).
- Acessibilidade: `Semantics`/`tooltip` em todo botão só com ícone; o foco visível usa `focusRing`.

### Logo e ícone

- Dentro do app (cabeçalho, login, splash) use `bowie-symbol-no-ring.svg`, `bowie-wordmark.svg` ou um lockup (com `flutter_svg`). Na versão com anel, o anel e o coração fazem parte do símbolo e não podem ser removidos ou separados.
- Fundo escuro → versões `*-negative`. Uma cor → `bowie-symbol-mono.svg`.
- **Não** recolorir, distorcer, rotacionar, aplicar sombra ou trocar a cor dos olhos (a heterocromia é a assinatura da marca). Regras completas em `docs/design/brand-guidelines.md`.
- Tamanho mínimo: símbolo com anel ≥ 32 px; abaixo disso use o ícone do app.
- Ícone e splash (sugestão: `flutter_launcher_icons` e `flutter_native_splash`):
  - iOS: `design/brand/app-icon/icon-1024.png` (sem transparência; o sistema aplica a máscara).
  - Android adaptativo: `adaptive-foreground-1024.png` sobre fundo `#6FA8DC`.
  - Splash: `splash-icon-1024.png` sobre `#F4F6F8` (tema claro).

## Voz e microcopy

- Português do Brasil, segunda pessoa ("você"), frases curtas.
- Sem gênero para quem lê: "Você recebeu um convite", não "Você foi convidado".
- Fale do pet pelo nome sempre que puder: "A vacina V10 do Bowie vence em 12 dias".
- Seja caloroso sem infantilizar: nada de "au au!", diminutivos em excesso ou trocadilhos em mensagens de saúde.
- Em incidentes de saúde, seja neutro e prático. O app registra informação e não faz diagnóstico; para sintomas graves, oriente procurar um veterinário.
- Estados vazios convidam à ação: "Nenhuma vacina registrada ainda. Adicionar a primeira?"

## Dados e privacidade

O app guarda dados de saúde de pets e dados pessoais dos tutores. A LGPD vale desde o início: consentimento claro, exportação e exclusão de dados pelo usuário, acesso restrito aos tutores do pet e nada de dados sensíveis em logs. Detalhes em `docs/produto/dados-e-privacidade.md`.

## Marca

Mudanças na marca (logo, paleta) passam pelo fundador antes. As telas ainda não foram desenhadas: siga os tokens e as regras acima.
