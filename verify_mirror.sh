#!/usr/bin/env bash
# verify_mirror.sh - Verificación end-to-end del espejo GitHub <-> GitLab
#
# 1. Crea una rama de prueba en GitHub  -> comprueba que aparece en GitLab.
# 2. Crea una rama de prueba en GitLab  -> comprueba que aparece en GitHub.
# 3. Borra ambas ramas                  -> comprueba que el borrado se propaga.
#
# Requiere: git, gh autenticado y acceso SSH (clave de despliegue) a GitLab,
# o la variable MIRROR_SSH_KEY_B64 para usar la misma clave de la CI.
set -euo pipefail

GH_REPO="${GH_REPO:-BENDER35/sc_compils_lin}"
GL_PROJECT="${GL_PROJECT:-BENDER_5000/sc_compils_lin}"
GH_URL="https://github.com/${GH_REPO}.git"
GL_SSH="git@gitlab.com:${GL_PROJECT}.git"
GL_URL="https://gitlab.com/${GL_PROJECT}.git"
TIMEOUT="${MIRROR_TIMEOUT:-300}"

suffix="$(date +%s)"
GH_BRANCH="mirror-test-gh-${suffix}"
GL_BRANCH="mirror-test-gl-${suffix}"

log() { printf '\033[1;34m[+]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

wait_for_ref() {
  # wait_for_ref <url> <refs/heads/...> [present|absent]
  local url="$1" ref="$2" mode="${3:-present}"
  local deadline=$(( $(date +%s) + TIMEOUT ))
  local out=""
  log "Esperando a que '$ref' esté ${mode} en $url (máx. ${TIMEOUT}s)..."
  while (( $(date +%s) < deadline )); do
    out="$(git ls-remote "$url" "$ref" 2>/dev/null || true)"
    if [[ "$mode" == "present" && -n "$out" ]]; then return 0; fi
    if [[ "$mode" == "absent"  && -z "$out" ]]; then return 0; fi
    sleep 10
  done
  die "Timeout esperando '$ref' (${mode}) en $url"
}

# Preparar SSH para GitLab ----------------------------------------------------
SSH_DIR="${HOME}/.ssh"
if [[ -n "${MIRROR_SSH_KEY_B64:-}" ]] && [[ ! -s "${SSH_DIR}/mirror_ed25519" ]]; then
  install -d -m 700 "$SSH_DIR"
  printf '%s' "$MIRROR_SSH_KEY_B64" | base64 -d > "${SSH_DIR}/mirror_ed25519"
  chmod 600 "${SSH_DIR}/mirror_ed25519"
fi
if [[ -s "${SSH_DIR}/mirror_ed25519" ]]; then
  export GIT_SSH_COMMAND="ssh -i ${SSH_DIR}/mirror_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "Clonando $GH_URL"
git clone --quiet --no-checkout "$GH_URL" "$tmp/repo"
cd "$tmp/repo"
git config user.name  "sc_compils_lin mirror test"
git config user.email "mirror-test@sc_compils_lin.local"

# 1) GitHub -> GitLab ---------------------------------------------------------
git checkout --quiet -b "$GH_BRANCH" origin/main
echo "github ->gitlab $(date -Is)" > MIRROR_TEST_GH.txt
git add MIRROR_TEST_GH.txt
git commit --quiet -m "test(mirror): rama temporal desde GitHub"
git push --quiet "$GH_URL" "HEAD:refs/heads/${GH_BRANCH}"
wait_for_ref "$GL_URL" "refs/heads/${GH_BRANCH}" present
ok "GitHub -> GitLab: rama ${GH_BRANCH} sincronizada"

# 2) GitLab -> GitHub ---------------------------------------------------------
git checkout --quiet -b "$GL_BRANCH" origin/main
echo "gitlab ->github $(date -Is)" > MIRROR_TEST_GL.txt
git add MIRROR_TEST_GL.txt
git commit --quiet -m "test(mirror): rama temporal desde GitLab"
git push --quiet "$GL_SSH" "HEAD:refs/heads/${GL_BRANCH}"
wait_for_ref "$GH_URL" "refs/heads/${GL_BRANCH}" present
ok "GitLab -> GitHub: rama ${GL_BRANCH} sincronizada"

# 3) Borrado en ambas direcciones --------------------------------------------
git push --quiet "$GH_URL" --delete "refs/heads/${GH_BRANCH}"
git push --quiet "$GL_SSH" --delete "refs/heads/${GL_BRANCH}"
wait_for_ref "$GL_URL" "refs/heads/${GH_BRANCH}" absent
wait_for_ref "$GH_URL" "refs/heads/${GL_BRANCH}" absent
ok "Eliminación propagada en ambos sentidos"

echo
ok "Espejo bidireccional verificado correctamente."
