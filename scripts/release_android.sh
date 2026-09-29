#!/usr/bin/env bash
# =====================================================================
# HRR — Pubblica un aggiornamento dell'APK agli amici.
#
#   scripts/release_android.sh "Novità di questa versione"
#   scripts/release_android.sh --no-notify "Novità"   # nessuna push
#
# --no-notify registra comunque la versione (l'app la propone
# all'apertura) ma non manda la notifica a tutti — es. la prima release
# con l'aggiornamento in-app, distribuita a mano col link GitHub perché
# le versioni precedenti non hanno ancora il pulsante "Aggiorna".
#
# 1. aumenta la versione in pubspec.yaml (patch + build number: Android
#    installa un aggiornamento solo se il build number cresce);
# 2. compila un'APK per ABI, firmata con android/keystore/ (vedi
#    android/app/build.gradle.kts);
# 3. commit + tag + push, poi crea la Release GitHub con le APK;
# 4. registra la versione in Supabase (publish_app_release,
#    0036_app_releases.sql), che manda la notifica push a tutti.
#
# Requisiti: flutter, gh (loggato), supabase CLI (linkato al progetto),
# android/key.properties + android/keystore/ presenti.
# =====================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

NOTIFY=1
if [[ "${1:-}" == "--no-notify" ]]; then
  NOTIFY=0
  shift
fi
NOTES="${1:-}"
REPO="Leoragno/H.R.R."
ABIS=(arm64-v8a armeabi-v7a x86_64)

if [[ ! -f android/key.properties ]]; then
  echo "ERRORE: manca android/key.properties (chiave di firma)." >&2
  echo "Senza, l'APK non aggiornerebbe le installazioni esistenti." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERRORE: ci sono modifiche non committate, committale prima." >&2
  exit 1
fi

# --- 1. Versione -------------------------------------------------------
CURRENT=$(grep -E '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//')
NAME="${CURRENT%%+*}"
BUILD="${CURRENT##*+}"
IFS=. read -r MAJOR MINOR PATCH <<< "$NAME"
NEW_NAME="$MAJOR.$MINOR.$((PATCH + 1))"
NEW_BUILD=$((BUILD + 1))
TAG="v$NEW_NAME"
echo ">> $CURRENT -> $NEW_NAME+$NEW_BUILD"
sed -i -E "s/^version:.*/version: $NEW_NAME+$NEW_BUILD/" pubspec.yaml

# --- 2. Build ----------------------------------------------------------
flutter build apk --release --split-per-abi

OUT=build/app/outputs/flutter-apk
DIST=build/release-dist
rm -rf "$DIST" && mkdir -p "$DIST"
APKS_JSON="{"
for ABI in "${ABIS[@]}"; do
  FILE="hrr-$NEW_NAME-$ABI.apk"
  cp "$OUT/app-$ABI-release.apk" "$DIST/$FILE"
  SHA=$(sha256sum "$DIST/$FILE" | cut -d' ' -f1)
  URL="https://github.com/$REPO/releases/download/$TAG/$FILE"
  [[ "$APKS_JSON" != "{" ]] && APKS_JSON+=","
  APKS_JSON+="\"$ABI\":{\"url\":\"$URL\",\"sha256\":\"$SHA\"}"
done
APKS_JSON+="}"

# --- 3. Git + Release GitHub -------------------------------------------
git add pubspec.yaml
git commit -m "release: $NEW_NAME+$NEW_BUILD"
git tag "$TAG"
git push origin HEAD "$TAG"
gh release create "$TAG" "$DIST"/*.apk \
  --repo "$REPO" \
  --title "HRR $NEW_NAME" \
  --notes "${NOTES:-Aggiornamento HRR $NEW_NAME}"

# --- 4. Supabase: versione + notifica push -----------------------------
SQL_NOTES=${NOTES//\'/\'\'}
if [[ $NOTIFY == 1 ]]; then
  supabase db query --linked \
    "select public.publish_app_release($NEW_BUILD, '$NEW_NAME', '$APKS_JSON'::jsonb, nullif('$SQL_NOTES', '')) as notificati;"
else
  supabase db query --linked \
    "insert into public.app_releases (version_code, version_name, apks, notes) values ($NEW_BUILD, '$NEW_NAME', '$APKS_JSON'::jsonb, nullif('$SQL_NOTES', '')) returning version_code;"
fi

echo ">> Pubblicata HRR $NEW_NAME (build $NEW_BUILD)."
