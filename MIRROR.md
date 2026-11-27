# Espejo bidireccional GitHub ⇄ GitLab

## Arquitectura

| Dirección | Disparador | Mecanismo | Anti-bucle |
|---|---|---|---|
| GitHub → GitLab | `push` en GitHub | GitHub Actions + `git push --mirror` sobre SSH | `-o ci.skip` evita el pipeline de GitLab |
| GitLab → GitHub | `push` en GitLab | GitLab CI + `git push --mirror` sobre SSH | El push en GitHub dispara Actions, que vuelve a GitLab con `ci.skip` y se detiene |

Flujo completo tras un push en GitLab:

```
push GitLab → pipeline GitLab → push --mirror a GitHub
            → GitHub Actions → push --mirror -o ci.skip a GitLab → FIN
```

## Clave de despliegue

Se genera una clave Ed25519 exclusiva para el espejo (`~/.ssh/sc_compils_lin_mirror_ed25519`)
y se registra como **deploy key con escritura** en ambos repositorios:

- GitHub: `POST /repos/{owner}/{repo}/keys` con `"read_only": false`
- GitLab: `POST /projects/{id}/deploy_keys` con `"can_push": true`

La clave privada se almacena en base64 en:

- GitHub Actions: secreto de repositorio `MIRROR_SSH_KEY_B64`
- GitLab CI: variable de proyecto `MIRROR_SSH_KEY_B64`

## Verificación automática

```bash
bash verify_mirror.sh
```

Hace tres pruebas reales contra los remotos:

1. Crea `mirror-test-gh-<timestamp>` en GitHub y espera a que exista en GitLab.
2. Crea `mirror-test-gl-<timestamp>` en GitLab y espera a que exista en GitHub.
3. Borra ambas ramas y verifica que las eliminaciones se propagan.

Tiempo de espera por defecto: 300 s (configurable con `MIRROR_TIMEOUT`).

## Verificación manual

```bash
# Estado de los workflows en GitHub
gh run list --repo BENDER35/sc_compils_lin --limit 5

# Estado del pipeline en GitLab
glab ci status

# Ramas/tags en cada lado
git ls-remote https://github.com/BENDER35/sc_compils_lin.git | head
git ls-remote https://gitlab.com/BENDER_5000/sc_compils_lin.git | head

# Probar un push en GitHub y verlo en GitLab
echo prueba >> README.md && git commit -am "test mirror" && git push origin main
# ...esperar y comprobar:
git ls-remote https://gitlab.com/BENDER_5000/sc_compils_lin.git refs/heads/main
```

## Limitaciones

- `--mirror` sobreescribe: si se modifica el mismo archivo en ambos lados antes de que
  sincronicen, gana el último push. No es una fusión bidireccional inteligente.
- Los refs internos (`refs/pull/*` en GitHub, `refs/merge-requests/*` y `refs/pipelines/*`
  en GitLab) se eliminan antes de pushear; solo se replican ramas y tags.
- Los secretos de CI no se sincronizan (solo el código Git).
