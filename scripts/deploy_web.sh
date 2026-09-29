#!/usr/bin/env bash
# =====================================================================
# HRR — Pubblica il sito/PWA su Vercel (hrr-delta.vercel.app).
#
#   scripts/deploy_web.sh
#
# Compila con un id di build univoco (--dart-define=WEB_BUILD_ID) e lo
# scrive anche in build/web/build.json: chi ha il sito aperto con la build
# precedente vede il banner "Nuova versione disponibile" (vedi
# lib/features/app_update/web_update_banner.dart). Il deploy è sempre il
# build già compilato: i push su GitHub non deployano (vercel.json in
# root, git.deploymentEnabled=false).
# =====================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_ID="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
echo ">> build web $BUILD_ID"

flutter build web --release --no-wasm-dry-run --dart-define=WEB_BUILD_ID="$BUILD_ID"
printf '{"build":"%s"}\n' "$BUILD_ID" > build/web/build.json

if [[ ! -f build/web/.vercel/project.json ]]; then
  echo "ERRORE: build/web non è collegata al progetto Vercel 'hrr'." >&2
  echo "Esegui una volta: (cd build/web && vercel link --project hrr)" >&2
  exit 1
fi

(cd build/web && vercel deploy --prod --yes)
echo ">> Pubblicato $BUILD_ID su https://hrr-delta.vercel.app"
