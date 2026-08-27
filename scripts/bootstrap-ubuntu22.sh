#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap-ubuntu22.sh [--dry-run]

Install the Ubuntu 22.04 packages needed for Android kernel builds.
EOF
}

dry_run=0

while (($#)); do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! -r /etc/os-release ]]; then
  printf 'Unable to identify this operating system.\n' >&2
  exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != ubuntu || "${VERSION_ID:-}" != 22.04 ]]; then
  printf 'This bootstrap supports Ubuntu 22.04; detected %s %s.\n' \
    "${ID:-unknown}" "${VERSION_ID:-unknown}" >&2
  exit 1
fi

packages=(
  bc
  bison
  build-essential
  ccache
  device-tree-compiler
  dwarves
  flex
  git
  libelf-dev
  libncurses5-dev
  libssl-dev
  libtinfo5
  lz4
  make
  python3
  rsync
  shellcheck
  unzip
  zip
  zlib1g-dev
)

if ((EUID == 0)); then
  elevate=()
elif command -v sudo >/dev/null 2>&1; then
  elevate=(sudo)
else
  printf 'Run this script as root or install sudo first.\n' >&2
  exit 1
fi

if ((dry_run)); then
  printf 'Would run:\n'
  printf '  %q' "${elevate[@]}" apt-get update
  printf '\n'
  printf '  %q' "${elevate[@]}" apt-get install -y --no-install-recommends "${packages[@]}"
  printf '\n'
  exit 0
fi

"${elevate[@]}" apt-get update
"${elevate[@]}" apt-get install -y --no-install-recommends "${packages[@]}"

printf 'Ubuntu 22.04 Android kernel build dependencies are installed.\n'
