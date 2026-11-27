#!/usr/bin/env bash
# sync_to_github.sh - Espejo GitLab -> GitHub
# Ejecutado por .gitlab-ci.yml
set -euo pipefail

SOURCE_URL="${SOURCE_URL:-${CI_REPOSITORY_URL:-}}"
TARGET_URL="${TARGET_URL:?Se requiere TARGET_URL}"
WORKDIR="${WORKDIR:-$(mktemp -d)}"

[[ -n "$SOURCE_URL" ]] || { echo "[mirror] Falta SOURCE_URL/CI_REPOSITORY_URL" >&2; exit 1; }

echo "[mirror] Clonando espejo desde GitLab..."
rm -rf "$WORKDIR"
git clone --quiet --mirror "$SOURCE_URL" "$WORKDIR"

cd "$WORKDIR"

# GitLab crea refs internos de MR y pipelines que no deben ir a GitHub.
git for-each-ref --format='delete %(refname)' refs/merge-requests refs/pipelines | \
  git update-ref --stdin || true

echo "[mirror] Refs que se van a sincronizar:"
git for-each-ref --format='  %(refname)' refs/heads refs/tags

echo "[mirror] Pushing a GitHub (${TARGET_URL})..."
git push --mirror "$TARGET_URL"

# El push anterior dispara GitHub Actions, que vuelve a GitLab con 'ci.skip'.
# Ese ci.skip es lo que rompe el bucle; no hace falta marcar los commits.
echo "[mirror] GitLab -> GitHub completado."
