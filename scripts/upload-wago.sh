#!/usr/bin/env bash
# upload-wago.sh <zip> <version> <game-versions-csv> — publish a build to Wago Addons.
#
# Env: WAGO_API_TOKEN (secret), WAGO_PROJECT_ID (the project id/slug).
# API: POST https://addons.wago.io/api/projects/{id}/version  (multipart: metadata + file)
set -uo pipefail   # not -e: we want to print Wago's response body on failure

ZIP="${1:?zip path}"; VERSION="${2:?version}"; GAMEVERS="${3:?game versions (csv)}"
: "${WAGO_API_TOKEN:?WAGO_API_TOKEN is required}"
: "${WAGO_PROJECT_ID:?WAGO_PROJECT_ID is required}"

CHANGELOG="$(cat RELEASE_NOTES.md 2>/dev/null || echo "EasyMountFarmer ${VERSION}")"

# "12.0.1,12.0.7" -> JSON array ["12.0.1","12.0.7"]
GV_JSON="$(printf '%s' "$GAMEVERS" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";""))')"

# Send metadata as a typed JSON part (a file, so ';'/quotes in the changelog can't
# break curl's -F parsing). A missing application/json content-type is a common 422.
jq -n --arg l "$VERSION" --arg c "$CHANGELOG" --argjson gv "$GV_JSON" \
  '{label:$l, stability:"stable", changelog:$c, supported_game_versions:$gv}' > wago-metadata.json

echo "Wago metadata:"; cat wago-metadata.json; echo

resp="$(curl -sS -w '\n%{http_code}' -X POST \
  "https://addons.wago.io/api/projects/${WAGO_PROJECT_ID}/version" \
  -H "Authorization: Bearer ${WAGO_API_TOKEN}" \
  -H "accept: application/json" \
  -F "metadata=<wago-metadata.json" \
  -F "file=@${ZIP};type=application/zip")"

code="$(printf '%s' "$resp" | tail -n1)"
body="$(printf '%s' "$resp" | sed '$d')"
echo "HTTP ${code}"
echo "${body}"

if [ "${code}" -ge 200 ] && [ "${code}" -lt 300 ]; then
  echo "Wago upload OK."
else
  echo "Wago upload failed (HTTP ${code})." >&2
  exit 1
fi
