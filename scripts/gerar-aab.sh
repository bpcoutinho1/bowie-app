#!/usr/bin/env bash
# Gera o pacote do Android (.aab) para enviar à Google Play.
#
# Uso (na pasta do projeto, no Mac):
#   ./scripts/gerar-aab.sh
#
# O código da versão (versionCode) vem do relógio, em minutos desde 1970
# (ex.: 29904165), então cada envio tem um número maior sem mexer no
# pubspec.yaml. A versão (ex.: 0.1.0) continua vindo do pubspec.yaml.
# Guia: docs/guias/play-store.md
set -euo pipefail

cd "$(dirname "$0")/.."

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

# Sem a chave de upload, o pacote sairia assinado com a chave de testes, e a
# Google Play recusa.
if [[ ! -f android/key.properties ]]; then
  echo "Falta o arquivo android/key.properties com a chave de upload." >&2
  echo "Veja o passo 3 de docs/guias/play-store.md." >&2
  exit 1
fi

build_number="$(( $(date +%s) / 60 ))"
version="$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([^+]+).*/\1/')"

echo "Versão $version, código $build_number"
echo "Baixando pacotes..."
flutter pub get

echo "Gerando o pacote (leva alguns minutos)..."
flutter build appbundle --release \
  --build-number="$build_number" \
  --dart-define-from-file=dart_defines.json

aab="build/app/outputs/bundle/release/app-release.aab"
echo
echo "Pronto: $aab"
echo "Para enviar: Play Console → o app Bowie → Testes → Teste interno → Criar versão, e arraste esse arquivo."
if [[ "$(uname)" == "Darwin" ]]; then
  open -R "$aab"
fi
