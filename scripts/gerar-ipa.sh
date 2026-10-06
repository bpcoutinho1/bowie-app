#!/usr/bin/env bash
# Gera o pacote do iOS (.ipa) para enviar ao TestFlight.
#
# Uso (na pasta do projeto, no Mac):
#   ./scripts/gerar-ipa.sh
#
# O número do build vem da data e hora (ex.: 20261011.1530), então cada envio
# tem um número novo sem mexer no pubspec.yaml. A versão (ex.: 0.1.0) continua
# vindo do pubspec.yaml.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Este script precisa rodar num Mac com Xcode." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "O Flutter não foi encontrado. Instale com: brew install --cask flutter" >&2
  exit 1
fi

if [[ ! -f dart_defines.json ]]; then
  echo "Falta o arquivo dart_defines.json na raiz do projeto." >&2
  exit 1
fi

if grep -q "YOUR_PROJECT\|YOUR_ANON_KEY\|•" dart_defines.json; then
  echo "O dart_defines.json está com valores de exemplo ou com a chave mascarada (•)." >&2
  exit 1
fi

build_number="$(date +%Y%m%d).$(date +%H%M)"
version="$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([^+]+).*/\1/')"

echo "Versão $version, build $build_number"
echo "Baixando pacotes..."
flutter pub get

echo "Gerando o pacote (leva alguns minutos)..."
flutter build ipa --release \
  --build-number="$build_number" \
  --dart-define-from-file=dart_defines.json

ipa="$(ls -t build/ios/ipa/*.ipa | head -n 1)"
echo
echo "Pronto: $ipa"
echo "Para enviar: abra o app Transporter, arraste esse arquivo e clique em Deliver."
open -R "$ipa"
