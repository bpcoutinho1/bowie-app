#!/usr/bin/env bash
# Prepara o projeto iOS e abre no Xcode, pronto para o botão Play.
#
# Uso (na pasta do projeto, no Mac):
#   ./scripts/abrir-no-xcode.sh
#
# Rode de novo sempre que puxar código novo ou mudar o dart_defines.json.
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
  echo "Copie o exemplo e preencha com a URL e a chave anon do Supabase:" >&2
  echo "  cp dart_defines.example.json dart_defines.json" >&2
  exit 1
fi

if grep -q "YOUR_PROJECT\|YOUR_ANON_KEY" dart_defines.json; then
  echo "O dart_defines.json ainda tem os valores de exemplo. Preencha com os do Supabase." >&2
  exit 1
fi

echo "Baixando pacotes..."
flutter pub get

# Grava a configuração (inclusive o Supabase) que o Xcode usa ao apertar Play.
# --no-codesign: só prepara o projeto, sem exigir certificado da Apple. O
# simulador não precisa de assinatura; para o iPhone, o Xcode assina ao
# apertar Play, depois de escolher um Team em Signing & Capabilities.
echo "Preparando o projeto iOS..."
flutter build ios --config-only --no-codesign --debug \
  --dart-define-from-file=dart_defines.json

echo "Abrindo no Xcode..."
open ios/Runner.xcworkspace
