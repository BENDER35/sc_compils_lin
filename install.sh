#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# install.sh - Instalador de compiladores cruzados Linux -> Windows
# Repositorio: sc_compils_lin
# Licencia: MIT
#
# Instala toolchains que permiten compilar código en Linux para objetivos
# Windows (x86, x86_64 y ARM64 donde está disponible).
# ---------------------------------------------------------------------------
set -euo pipefail

VERSION="1.0.0"
PREFIX="${HOME}/.local/opt"
DRY_RUN=0
ASSUME_YES=0
MINIMAL=0
WITH_WINE=0
WITH_FPC_CROSS=0
PM=""
UPDATED=0
SUDO=""

# ---------------------------- utilidades ----------------------------------
log()  { printf '\033[1;34m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

run() {
  if (( DRY_RUN )); then
    printf '[dry-run]'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

run_sudo() {
  if (( DRY_RUN )); then
    printf '[dry-run] sudo'; printf ' %q' "$@"; printf '\n'
  elif [[ -n "$SUDO" ]]; then
    "$SUDO" "$@"
  else
    "$@"
  fi
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

detect_pm() {
  if need_cmd apt-get; then PM="apt"
  elif need_cmd dnf; then PM="dnf"
  else
    die "No se encontró apt-get ni dnf. Este instalador soporta Debian/Ubuntu y Fedora/RHEL. Instala los toolchains manualmente."
  fi
  log "Gestor de paquetes detectado: $PM"
}

pm_install() {
  (( $# )) || return 0
  log "Instalando: $*"
  case "$PM" in
    apt)
      if (( ! UPDATED )); then
        run_sudo env DEBIAN_FRONTEND=noninteractive apt-get update
        UPDATED=1
      fi
      run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
      ;;
    dnf)
      run_sudo dnf install -y "$@"
      ;;
  esac
}

pm_group_install() {
  local group_name="$1"; shift
  (( $# )) || return 0
  log "[$group_name]"
  pm_install "$@"
}

link_bin() {
  # link_bin <ruta absoluta al ejecutable> <nombre>
  local target="$1" name="$2"
  if (( DRY_RUN )); then
    log "[dry-run] enlazar ${PREFIX}/bin/${name} -> $target"
    return 0
  fi
  mkdir -p "${PREFIX}/bin"
  if [[ -e "${PREFIX}/bin/${name}" || -L "${PREFIX}/bin/${name}" ]]; then
    rm -f "${PREFIX}/bin/${name}"
  fi
  ln -s "$target" "${PREFIX}/bin/${name}"
}

write_env_file() {
  local f="${PREFIX}/bin/sc-compilers-env.sh"
  if (( DRY_RUN )); then
    log "[dry-run] crear $f"
    return 0
  fi
  mkdir -p "${PREFIX}/bin"
  cat > "$f" <<EOF
# Generado por sc_compils_lin/install.sh v${VERSION}
# Fuente: source ${f}
export SC_COMPILERS_PREFIX="${PREFIX}"
export PATH="${PREFIX}/bin:\$PATH"
export PATH="\${HOME}/.cargo/bin:\$PATH"
# Ejemplos de compilación cruzada:
#   x86_64-w64-mingw32-gcc hola.c -o hola.exe
#   GOOS=windows GOARCH=amd64 go build -o hola.exe .
#   rustup target add x86_64-pc-windows-gnu && cargo build --target x86_64-pc-windows-gnu
#   zig build-exe hola.zig -target x86_64-windows-gnu
#   dotnet publish -r win-x64 --self-contained false
#   nim c --os:windows --cpu:amd64 -d:mingw hola.nim
EOF
  log "Archivo de entorno creado: $f"
}

list_tools() {
  cat <<'EOF'
Toolchains que instala este script (perfil 'amplio'):

  Sistema / build
    - build-essential (gcc, g++, make, ld), CMake, Ninja, Meson, pkg-config
    - Git, curl, wget, unzip, xz, Python 3

  C / C++ / Objective-C / Fortran / ADA
    - MinGW-w64: x86_64-w64-mingw32-gcc/g++ , i686-w64-mingw32-gcc/g++
    - gfortran-mingw-w64 (x86_64 e i686)
    - gobjc++/mingw-w64 (Objective-C++)
    - Clang + LLD + LLVM (objetivos x86_64-pc-windows-gnu / msvc)

  Rust
    - rustup + stable + targets windows-gnu (x86_64, i686, aarch64)
    - target windows-msvc (útil para 'cargo check'; requiere libs MSVC para enlazar)

  Go
    - toolchain de Go (GOOS=windows GOARCH=amd64|386|arm64)

  Zig
    - Zig stable (compilación nativa a windows-gnu / windows-msvc)

  .NET
    - SDK LTS (dotnet publish -r win-x64|win-arm64)

  Nim
    - choosenim + Nim stable (--os:windows)

  D
    - LDC y GDC

  Pascal
    - Free Pascal Compiler (fpc); --with-fpc-cross añade ppcrossx64

  Opcionales
    - --with-wine : Wine para ejecutar/verificar los .exe en Linux
    - --minimal   : solo C/C++ (MinGW-w64), Clang, Rust, Go y Zig
EOF
}

usage() {
  cat <<EOF
Uso: $0 [opciones]

Instala compiladores cruzados Linux -> Windows.

Opciones:
  --dry-run           Muestra qué haría sin modificar el sistema
  -y, --yes           No pedir confirmación
  --minimal           Instalar solo MinGW-w64, Clang, Rust, Go y Zig
  --with-wine         Instalar Wine para probar los ejecutables generados
  --with-fpc-cross    Descargar el compilador cruzado de Free Pascal a Win64
  --prefix DIR        Directorio para toolchains instaladas desde tarball
                      (por defecto: \$HOME/.local/opt)
  --list              Listar las herramientas instaladas por el perfil amplio
  -h, --help          Mostrar esta ayuda

Ejemplos:
  $0 --dry-run
  $0 --minimal -y
  $0 --with-wine -y
EOF
}

# ------------------------------- argumentos -------------------------------
while (( $# )); do
  case "$1" in
    --dry-run)        DRY_RUN=1 ;;
    -y|--yes)         ASSUME_YES=1 ;;
    --minimal)        MINIMAL=1 ;;
    --with-wine)      WITH_WINE=1 ;;
    --with-fpc-cross) WITH_FPC_CROSS=1 ;;
    --prefix)
      [[ $# -ge 2 ]] || die "--prefix requiere un directorio"
      PREFIX="$2"; shift ;;
    --list)  list_tools; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opción desconocida: $1 (usa --help)" ;;
  esac
  shift
done

# --------------------------- comprobación inicial -------------------------
log "sc_compils_lin/install.sh v${VERSION}"
(( DRY_RUN )) && log "MODO SIMULACIÓN: no se modifica el sistema"

for c in curl tar; do
  need_cmd "$c" || die "Falta '$c'. Instálalo con tu gestor de paquetes antes de continuar."
done

detect_pm

if (( ! DRY_RUN && ! ASSUME_YES )); then
  printf 'Se instalarán toolchains en el sistema y en %s.\n' "$PREFIX"
  read -r -p "¿Continuar? [s/N] " answer
  [[ "$answer" =~ ^[sSyY] ]] || die "Instalación cancelada por el usuario."
fi

if [[ $EUID -ne 0 ]] && ! need_cmd sudo; then
  die "Se necesita sudo para instalar paquetes del sistema."
fi
[[ -n "$SUDO" ]] || SUDO="sudo"

if (( ! DRY_RUN )); then
  mkdir -p "${PREFIX}/bin"
fi

# ------------------------------- paquetes ---------------------------------
case "$PM" in
  apt)
    PKG_BASE=(build-essential cmake ninja-build meson pkg-config git curl wget \
              unzip xz-utils python3 python3-pip ca-certificates)
    PKG_MINGW=(gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 \
               gcc-mingw-w64-i686 g++-mingw-w64-i686)
    PKG_CLANG=(clang lld llvm)
    PKG_FORTRAN=(gfortran-mingw-w64-x86-64 gfortran-mingw-w64-i686)
    PKG_OBJC=(gobjc++-mingw-w64-x86-64)
    PKG_GO=(golang-go)
    PKG_D=(ldc gdc)
    PKG_PASCAL=(fpc)
    PKG_WINE=(wine64)
    ;;
  dnf)
    PKG_BASE=(gcc gcc-c++ make cmake ninja-build meson pkgconf-pkg-config git \
              curl wget unzip xz python3 python3-pip ca-certificates)
    PKG_MINGW=(mingw64-gcc mingw64-gcc-c++ mingw32-gcc mingw32-gcc-c++)
    PKG_CLANG=(clang lld llvm)
    PKG_FORTRAN=(mingw64-gcc-gfortran mingw32-gcc-gfortran)
    PKG_OBJC=()
    PKG_GO=(golang)
    PKG_D=(ldc)
    PKG_PASCAL=(fpc)
    PKG_WINE=(wine)
    ;;
esac

pm_group_install "Herramientas base" "${PKG_BASE[@]}"
pm_group_install "MinGW-w64 (C/C++ x86_64 e i686)" "${PKG_MINGW[@]}"
pm_group_install "Clang / LLD / LLVM" "${PKG_CLANG[@]}"

if (( ! MINIMAL )); then
  pm_group_install "Fortran cruzado" "${PKG_FORTRAN[@]}"
  (( ${#PKG_OBJC[@]} )) && pm_group_install "Objective-C++ cruzado" "${PKG_OBJC[@]}"
  pm_group_install "Go" "${PKG_GO[@]}"
  pm_group_install "D (LDC y GDC)" "${PKG_D[@]}"
  pm_group_install "Free Pascal" "${PKG_PASCAL[@]}"
  (( WITH_WINE )) && pm_group_install "Wine" "${PKG_WINE[@]}"
fi

# --------------------------------- Rust -----------------------------------
log "Rust (rustup)"
if need_cmd rustup; then
  log "rustup ya está instalado; actualizando targets"
  run rustup update stable
else
  if (( DRY_RUN )); then
    log "[dry-run] curl https://sh.rustup.rs | sh -s -- -y --profile minimal"
  else
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | \
      sh -s -- -y --profile minimal --default-toolchain stable
  fi
fi
for t in x86_64-pc-windows-gnu i686-pc-windows-gnu aarch64-pc-windows-gnu x86_64-pc-windows-msvc; do
  run "${HOME}/.cargo/bin/rustup" target add "$t" || \
    warn "No se pudo añadir el target Rust $t"
done
if [[ -x "${HOME}/.cargo/bin/rustc" ]]; then
  link_bin "${HOME}/.cargo/bin/rustc"  rustc
  link_bin "${HOME}/.cargo/bin/cargo"  cargo
  link_bin "${HOME}/.cargo/bin/rustup" rustup
fi

# --------------------------------- Zig ------------------------------------
log "Zig"
if [[ ! -x "${PREFIX}/zig/zig" ]]; then
  zig_version="${ZIG_VERSION:-}"
  zig_url="${ZIG_TARBALL:-}"
  if [[ -z "$zig_version" || -z "$zig_url" ]]; then
    if need_cmd python3; then
      parsed="$(curl -fsSL --retry 3 https://ziglang.org/download/index.json | \
        python3 -c 'import json,sys
d=json.load(sys.stdin)
for v,i in d.items():
    if v!="master" and "x86_64-linux" in i:
        print(v, i["x86_64-linux"]["tarball"]); break' || true)"
      [[ -n "$parsed" ]] && read -r zig_version zig_url <<<"$parsed"
    fi
  fi
  if [[ -z "$zig_version" || -z "$zig_url" ]]; then
    warn "No se pudo resolver la última versión de Zig; usa ZIG_VERSION y ZIG_TARBALL."
  else
    log "Zig $zig_version"
    if (( DRY_RUN )); then
      log "[dry-run] descargar $zig_url en ${PREFIX}/zig"
    else
      tmp="$(mktemp -d)"
      curl -fL --retry 3 -o "${tmp}/zig.tar.xz" "$zig_url"
      tar -xJf "${tmp}/zig.tar.xz" -C "$tmp"
      rm -rf "${PREFIX}/zig"
      mv "${tmp}/zig-x86_64-linux-${zig_version}" "${PREFIX}/zig"
      rm -rf "$tmp"
      link_bin "${PREFIX}/zig/zig" zig
    fi
  fi
else
  log "Zig ya instalado en ${PREFIX}/zig"
fi

if (( ! MINIMAL )); then
  # --------------------------------- .NET ----------------------------------
  log ".NET SDK (LTS)"
  if [[ ! -x "${PREFIX}/dotnet/dotnet" ]]; then
    if (( DRY_RUN )); then
      log "[dry-run] dotnet-install.sh --channel LTS --install-dir ${PREFIX}/dotnet"
    else
      tmp="$(mktemp -d)"
      curl -fsSL --retry 3 https://dot.net/v1/dotnet-install.sh -o "${tmp}/dotnet-install.sh"
      bash "${tmp}/dotnet-install.sh" --channel LTS --install-dir "${PREFIX}/dotnet" --no-path
      rm -rf "$tmp"
      link_bin "${PREFIX}/dotnet/dotnet" dotnet
    fi
  else
    log ".NET SDK ya instalado"
  fi

  # --------------------------------- Nim -----------------------------------
  log "Nim (choosenim)"
  if ! need_cmd nim && [[ ! -x "${HOME}/.nimble/bin/nim" ]]; then
    if (( DRY_RUN )); then
      log "[dry-run] curl https://nim-lang.org/choosenim/init.sh | sh"
    else
      curl -fsSL --retry 3 https://nim-lang.org/choosenim/init.sh | sh -s -- -y
    fi
  fi
  if [[ -x "${HOME}/.nimble/bin/nim" ]]; then
    link_bin "${HOME}/.nimble/bin/nim" nim
  fi
fi

# ------------------------- FPC cross (opcional) ----------------------------
if (( WITH_FPC_CROSS )) && (( ! MINIMAL )); then
  log "Compilador cruzado Free Pascal -> Win64 (opcional)"
  warn "ppcrossx64 no está en los repositorios habituales; descárgalo desde"
  warn "https://sourceforge.net/projects/freepascal/files/Win64/ y coloca los binarios en /usr/lib/fpc/<version>/"
fi

# ------------------------------- entorno ----------------------------------
write_env_file

log "Instalación terminada."
log "Activa el entorno con:  source ${PREFIX}/bin/sc-compilers-env.sh"
log "Verifica con:           bash verify.sh"
log "Si los comandos no aparecen, abre una terminal nueva o vuelve a hacer 'source' del entorno."
