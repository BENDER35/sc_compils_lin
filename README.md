# sc_compils_lin

**Instalador de compiladores cruzados: Linux → Windows.**

Un único script para dejar una máquina Linux (Debian/Ubuntu o Fedora/RHEL) lista para compilar
programas que se ejecutan en Windows, sin necesidad de tener Windows instalado.

- Repositorio GitHub: https://github.com/BENDER35/sc_compils_lin
- Repositorio GitLab: https://gitlab.com/BENDER_5000/sc_compils_lin
- Espejo bidireccional automático (GitHub ⇄ GitLab)
- Release con ZIP descargable

---

## Inicio rápido

```bash
git clone https://github.com/BENDER35/sc_compils_lin.git
cd sc_compils_lin

bash install.sh --dry-run     # ver qué haría, sin tocar nada
bash install.sh --list        # listar toolchains del perfil amplio
bash install.sh               # instalación completa (pide confirmación)
bash install.sh --minimal -y  # solo lo esencial, sin preguntar
bash install.sh --with-wine -y
```

Después activa el entorno y comprueba la instalación:

```bash
source "$HOME/.local/opt/bin/sc-compilers-env.sh"
bash verify.sh
```

> **Nota:** los binarios instalados desde tarball (Zig, .NET, Rust, Nim) se enlazan en
> `$HOME/.local/opt/bin`. Añade `source "$HOME/.local/opt/bin/sc-compilers-env.sh"` a tu
> `~/.bashrc` o `~/.zshrc` para no tener que hacerlo en cada terminal.

---

## Opciones de `install.sh`

| Opción | Descripción |
|---|---|
| `--dry-run` | Simula la instalación, no modifica el sistema |
| `-y`, `--yes` | Sin confirmación interactiva |
| `--minimal` | Solo MinGW-w64, Clang, Rust, Go y Zig |
| `--with-wine` | Instala Wine para ejecutar/verificar los `.exe` generados |
| `--with-fpc-cross` | Instrucciones para el compilador cruzado de Free Pascal a Win64 |
| `--prefix DIR` | Cambia el directorio de toolchains (por defecto `~/.local/opt`) |
| `--list` | Muestra el inventario de herramientas |
| `-h`, `--help` | Ayuda |

Variables de entorno admitidas: `ZIG_VERSION` y `ZIG_TARBALL` para fijar una versión concreta
de Zig (útil si falla la detección automática de la última versión).

---

## Toolchains incluidos y ejemplos de uso

### C, C++ (MinGW-w64)

```bash
x86_64-w64-mingw32-gcc  hola.c -o hola64.exe
x86_64-w64-mingw32-g++  hola.cpp -o hola64.exe
i686-w64-mingw32-gcc    hola.c -o hola32.exe
```

### Fortran

```bash
x86_64-w64-mingw32-gfortran hola.f90 -o hola.exe
```

### Objective-C / Objective-C++

```bash
x86_64-w64-mingw32-gobjc++ hola.mm -o hola.exe -lobjc
```

### Clang / LLD (objetivos Windows)

```bash
clang --target=x86_64-w64-mingw32 hola.c -fuse-ld=lld -o hola.exe
clang-cl hola.cpp /link /subsystem:console   # sintaxis MSVC (requiere libs MSVC)
```

### Rust

```bash
rustup target add x86_64-pc-windows-gnu
cargo build --release --target x86_64-pc-windows-gnu
```

También se añaden `i686-pc-windows-gnu`, `aarch64-pc-windows-gnu` y
`x86_64-pc-windows-msvc`. El objetivo MSVC sirve para `cargo check`; para enlazar
necesitas las librerías de Visual Studio (no distribuidas por este script).

### Go

Go compila a Windows de forma nativa, sin toolchain adicional:

```bash
GOOS=windows GOARCH=amd64 go build -o hola.exe .
GOOS=windows GOARCH=386   go build -o hola32.exe .
GOOS=windows GOARCH=arm64 go build -o hola-arm64.exe .
```

### Zig

```bash
zig build-exe hola.zig -target x86_64-windows-gnu -OReleaseFast
zig build-exe hola.zig -target aarch64-windows-msvc -OReleaseFast
```

### .NET

```bash
dotnet publish -c Release -r win-x64 --self-contained false -o publish/
dotnet publish -c Release -r win-arm64 --self-contained true  -o publish/
```

### Nim

```bash
nim c -d:release --os:windows --cpu:amd64 -d:mingw hola.nim
```

### D (LDC / GDC)

```bash
ldc2 -mtriple=x86_64-windows-gnu hola.d -of=hola.exe
```

### Free Pascal

```bash
fpc hola.pas                       # binario Linux
# Con ppcrossx64 instalado (--with-fpc-cross):
ppcrossx64 -Tx86_64-win64 hola.pas  # hola.exe
```

### Wine (opcional, para probar los ejecutables)

```bash
wine64 hola.exe
```

---

## Espejo bidireccional GitHub ⇄ GitLab

```
 push en GitHub  ──► GitHub Actions ──(git push --mirror -o ci.skip)──► GitLab
 push en GitLab  ──► GitLab CI     ──(git push --mirror)──────────────► GitHub
                                            │
                                            └──► GitHub Actions vuelve a GitLab
                                                 con ci.skip → fin del bucle
```

- `ci.skip` es la opción de push de GitLab que evita crear un pipeline. Es el cortocircuito
  que impide el bucle infinito.
- Se usa **una clave SSH de despliegue con permisos de escritura** en ambos repositorios.
  La clave privada se guarda codificada en base64 como secreto de CI
  (`MIRROR_SSH_KEY_B64`) en GitHub Actions y como variable en GitLab CI.
- Se sincronizan todas las ramas (`refs/heads/*`) y todos los tags (`refs/tags/*`),
  incluidas las eliminaciones (`--mirror`). Los refs internos de PR/MR se descartan.

### Verificación del espejo

```bash
bash verify_mirror.sh
```

El script crea una rama temporal en GitHub, comprueba que llega a GitLab; crea otra en
GitLab y comprueba que llega a GitHub; y finalmente borra ambas ramas verificando que
la eliminación también se propaga. Consulta `MIRROR.md` para detalles y
comandos manuales de verificación.

> **Importante:** con `--mirror`, si se envían commits distintos en ambos lados al mismo
> tiempo, el último push gana y sobrescribe el otro. Evita commits concurrentes; piensa en
> un lado como "principal" y en el otro como "espejo de lectura/escritura".

---

## Release

La release `v1.0.0` incluye `sc_compils_lin-v1.0.0.zip` con el instalador, el verificador,
los scripts de espejo, la documentación y ejemplos mínimos.

```bash
# Descarga directa
curl -fLO https://github.com/BENDER35/sc_compils_lin/releases/download/v1.0.0/sc_compils_lin-v1.0.0.zip
unzip sc_compils_lin-v1.0.0.zip
```

---

## Licencia

MIT. Consulta el archivo `LICENSE`.
