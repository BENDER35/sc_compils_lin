#!/usr/bin/env bash
# sync_to_gitlab.sh - Espejo GitHub -> GitLab
# Ejecutado por .github/workflows/mirror.yml
set -euo pipefail

SOURCE_URL="${SOURCE_URL:?Se requiere SOURCE_URL}"
TARGET_URL="${TARGET_URL:?Se requiere TARGET_URL}"
WORKDIR="${WORKDIR:-$(mktemp -d)}"
# Se permite PUSH_OPTS="" para servidores que no soportan push-options.
PUSH_OPTS="${PUSH_OPTS--o ci.skip}"

echo "[mirror] Clonando espejo desde GitHub..."
rm -rf "$WORKDIR"
git clone --quiet --mirror "$SOURCE_URL" "$WORKDIR"

cd "$WORKDIR"

# GitHub crea refs de PR que no deben replicarse como ramas en GitLab.
git for-each-ref --format='delete %(refname)' refs/pull | git update-ref --stdin || true

echo "[mirror] Refs que se van a sincronizar:"
git for-each-ref --format='  %(refname)' refs/heads refs/tags

# ci.skip evita que este push dispare de nuevo el pipeline de GitLab (anti-bucle).
echo "[mirror] Pushing a GitLab (${TARGET_URL})..."
# shellcheck disable=SC2086
git push --mirror $PUSH_OPTS "$TARGET_URL"

echo "[mirror] GitHub -> GitLab completado."
