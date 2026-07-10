#!/usr/bin/env bash
# upload-wago.sh <zip> <version> <patch> — publish a build to Wago Addons.
#
# Env: WAGO_API_TOKEN (secret), WAGO_PROJECT_ID (the project's id/slug).
# API: POST https://addons.wago.io/api/projects/{id}/version  (multipart: metadata + file)
set -euo pipefail

ZIP="${1:?zip path}"; VERSION="${2:?version}"; PATCH="${3:?game patch}"
: "${WAGO_API_TOKEN:?WAGO_API_TOKEN is required}"
: "${WAGO_PROJECT_ID:?WAGO_PROJECT_ID is required}"

CHANGELOG="$(cat RELEASE_NOTES.md 2>/dev/null || echo "EasyMountFarmer ${VERSION}")"
METADATA="$(jq -n --arg l "$VERSION" --arg c "$CHANGELOG" --arg v "$PATCH" \
  '{label:$l, stability:"stable", changelog:$c, supported_game_versions:[$v]}')"

echo "Uploading ${ZIP} to Wago project ${WAGO_PROJECT_ID} (label ${VERSION}, patch ${PATCH})…"
curl -fsS -X POST "https://addons.wago.io/api/projects/${WAGO_PROJECT_ID}/version" \
  -H "Authorization: Bearer ${WAGO_API_TOKEN}" \
  -H "accept: application/json" \
  -F "metadata=${METADATA}" \
  -F "file=@${ZIP}" \
  | jq . || { echo "Wago upload failed" >&2; exit 1; }
