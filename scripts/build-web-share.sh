#!/usr/bin/env bash
# Builds the public pages (the shared pet sheet) into a folder for GitHub
# Pages. Used by .github/workflows/ficha-pages.yml; also works locally:
#
#   SUPABASE_URL=https://xxxx.supabase.co scripts/build-web-share.sh _site
#
# SUPABASE_ANON_KEY is optional: the pet-share function does not need it.
set -euo pipefail

cd "$(dirname "$0")/.."
out="${1:-_site}"

rm -rf "$out"
mkdir -p "$out/fonts" "$out/brand"
cp -R web-share/. "$out/"
# The fonts are served from here, so the page asks nothing of Google.
sed '/fonts.googleapis.com/d' design/tokens/tokens.css > "$out/tokens.css"
cp assets/fonts/Figtree-Regular.ttf assets/fonts/Figtree-SemiBold.ttf \
  assets/fonts/Figtree-ExtraBold.ttf assets/fonts/OFL.txt "$out/fonts/"
for logo in bowie-wordmark bowie-wordmark-negative bowie-symbol \
  bowie-lockup-horizontal bowie-lockup-horizontal-negative \
  bowie-lockup-vertical-tagline bowie-lockup-vertical-tagline-negative; do
  cp "design/brand/logo/$logo.svg" "$out/brand/"
done
SUPABASE_URL="${SUPABASE_URL:-}" SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" python3 -I -c '
import json, os
config = {"supabaseUrl": os.environ["SUPABASE_URL"], "anonKey": os.environ["SUPABASE_ANON_KEY"]}
print("window.BOWIE_CONFIG = " + json.dumps(config) + ";")
' > "$out/config.js"
touch "$out/.nojekyll"
echo "Built $out"
