#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/build-kernel.sh --kernel DIR --defconfig TARGET [options]

Required:
  --kernel DIR          Android kernel source directory
  --defconfig TARGET    Kernel configuration target, such as vendor/device_defconfig

Options:
  --toolchain PROFILE   aosp12, sdclang8, gcc49, or linaro75 (default: aosp12)
  --out DIR             Output directory (default: DIR/out/PROFILE)
  --jobs COUNT          Parallel make jobs (default: all host CPUs)
  --target TARGET       Build target; may be repeated (default: kernel default)
  --make-arg ARG        Extra make assignment or target; may be repeated
  --clean               Run clean and mrproper before configuring
  --no-ccache           Do not use ccache when it is installed
  -h, --help            Show this help
EOF
}

kernel_dir=
defconfig=
profile=aosp12
out_dir=
jobs="$(nproc --all)"
clean=0
use_ccache=1
targets=()
extra_make_args=()

while (($#)); do
  case "$1" in
    --kernel)
      kernel_dir="${2:?--kernel requires a directory}"
      shift
      ;;
    --defconfig)
      defconfig="${2:?--defconfig requires a target}"
      shift
      ;;
    --toolchain)
      profile="${2:?--toolchain requires a profile}"
      shift
      ;;
    --out)
      out_dir="${2:?--out requires a directory}"
      shift
      ;;
    --jobs)
      jobs="${2:?--jobs requires a count}"
      shift
      ;;
    --target)
      targets+=("${2:?--target requires a target}")
      shift
      ;;
    --make-arg)
      extra_make_args+=("${2:?--make-arg requires an argument}")
      shift
      ;;
    --clean)
      clean=1
      ;;
    --no-ccache)
      use_ccache=0
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

if [[ -z "$kernel_dir" || -z "$defconfig" ]]; then
  usage >&2
  exit 2
fi

if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Job count must be a positive integer: %s\n' "$jobs" >&2
  exit 2
fi

kernel_dir="$(realpath "$kernel_dir")"

if [[ ! -f "${kernel_dir}/Makefile" ]]; then
  printf 'Kernel Makefile not found in %s\n' "$kernel_dir" >&2
  exit 1
fi

if [[ -z "$out_dir" ]]; then
  out_dir="${kernel_dir}/out/${profile}"
fi

mkdir -p "$out_dir"
out_dir="$(realpath "$out_dir")"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/toolchain-env.sh
source "${script_dir}/toolchain-env.sh" "$profile"

make_args=(
  -C "$kernel_dir"
  "O=${out_dir}"
  "ARCH=${ARCH}"
  "SUBARCH=${SUBARCH}"
  "CROSS_COMPILE=${CROSS_COMPILE}"
  "CROSS_COMPILE_ARM32=${CROSS_COMPILE_ARM32}"
  "CLANG_TRIPLE=${CLANG_TRIPLE}"
  "${TOOLCHAIN_MAKE_ARGS[@]}"
  "${extra_make_args[@]}"
)

if ((use_ccache)) && command -v ccache >/dev/null 2>&1; then
  make_args+=("CC=ccache ${CC}" "HOSTCC=ccache ${HOSTCC}")
  export CCACHE_BASEDIR="$kernel_dir"
  export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.cache/android-kernel-ccache}"
  export CCACHE_COMPILERCHECK=content
  mkdir -p "$CCACHE_DIR"
fi

printf 'Kernel:     %s\n' "$kernel_dir"
printf 'Output:     %s\n' "$out_dir"
printf 'Toolchain:  %s\n' "$TOOLCHAIN_DESCRIPTION"
printf 'Defconfig:  %s\n' "$defconfig"
printf 'Jobs:       %s\n' "$jobs"

if ((clean)); then
  make "${make_args[@]}" clean mrproper
fi

make "${make_args[@]}" "$defconfig"
make -j"$jobs" "${make_args[@]}" "${targets[@]}"
