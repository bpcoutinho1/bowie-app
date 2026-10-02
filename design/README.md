# Design

Hand-off de design do Bowie, gerado no Claude a partir do canvas "Bowie — Logo".

| Pasta | Conteúdo |
| --- | --- |
| `tokens/` | `tokens.json` (fonte da verdade) e derivados para web: `tokens.css`, `theme.ts`, `tailwind.preset.js`. O app Flutter deriva o próprio tema de `tokens.json`. |
| `brand/logo/` | Símbolo (cor, sem anel, negativo, mono), wordmark e lockups em SVG, mais PNGs de 1024 px em `png/`. |
| `brand/app-icon/` | Ícone iOS 1024, foreground adaptativo Android, splash, favicons e apple-touch-icon. |

O tema do app Flutter sai de `tokens.json` por `scripts/generate-dart-tokens.py`, que grava `lib/app/design_tokens.dart`.

As regras de uso estão em [`docs/design/brand-guidelines.md`](../docs/design/brand-guidelines.md) e no [`CLAUDE.md`](../CLAUDE.md).

## Wordmark em curvas

O wordmark e os lockups já estão em curvas. Para regenerá-los (por exemplo, se o tracking mudar):

```bash
pip install fonttools
curl -L -o Figtree.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/figtree/Figtree%5Bwght%5D.ttf"
python3 scripts/outline-wordmark.py Figtree.ttf
```
