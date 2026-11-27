#!/usr/bin/env bash
# verify.sh - Comprueba qué toolchains Linux -> Windows están disponibles
set -uo pipefail

PREFIX="${SC_COMPILERS_PREFIX:-${HOME}/.local/opt}"
export PATH="${PREFIX}/bin:${HOME}/.cargo/bin:${HOME}/.nimble/bin:${PATH}"

ok=0
missing=0
optional_missing=0

check() {
  # check <nombre> <comando> [crítico=1]
  local label="$1" cmd="$2" critical="${3:-1}"
  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver="$($cmd --version 2>&1 | head -n 1)"
    printf '  \033[1;32mOK\033[0m    %-28s %s\n' "$label" "$ver"
    ok=$((ok + 1))
  else
    if (( critical )); then
      printf '  \033[1;31mFALTA\033[0m %-28s (crítico)\n' "$label"
      missing=$((missing + 1))
    else
      printf '  \033[1;33mOPC\033[0m   %-28s (no instalado)\n' "$label"
      optional_missing=$((optional_missing + 1))
    fi
  fi
}

printf 'Verificando toolchains (PREFIX=%s)\n\n' "$PREFIX"

echo "Sistema y build:"
check "gcc"                gcc
check "g++"                g++
check "make"               make
check "cmake"              cmake
check "ninja"              ninja
check "meson"              meson
check "clang"              clang
check "lld (ld.lld)"       ld.lld

echo
echo "MinGW-w64 (objetivos Windows):"
check "MinGW x86_64 C"     x86_64-w64-mingw32-gcc
check "MinGW x86_64 C++"   x86_64-w64-mingw32-g++
check "MinGW i686 C"       i686-w64-mingw32-gcc
check "MinGW i686 C++"     i686-w64-mingw32-g++
check "MinGW Fortran"      x86_64-w64-mingw32-gfortran 0
check "MinGW ObjC++"       x86_64-w64-mingw32-gobjc++ 0

echo
echo "Lenguajes:"
check "Rust"               rustc
check "Cargo"              cargo
check "Go"                 go
check "Zig"                zig
check ".NET SDK"           dotnet 0
check "Nim"                nim 0
check "LDC (D)"            ldc2 0
check "GDC (D)"            gdc 0
check "Free Pascal"        fpc 0
check "Wine (pruebas)"     wine64 0

echo
printf 'Resumen: %s disponibles, %s críticos ausentes, %s opcionales ausentes\n' \
  "$ok" "$missing" "$optional_missing"

if (( missing > 0 )); then
  echo "Instala lo que falta con: bash install.sh"
  exit 1
fi
echo "Toolchains críticos OK. Puedes compilar para Windows."
