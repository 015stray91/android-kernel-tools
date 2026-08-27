#!/usr/bin/env bash

toolchain_env_usage() {
  cat <<'EOF'
Usage: source scripts/toolchain-env.sh PROFILE

Profiles:
  aosp12      AOSP Clang/LLVM 12.0.5 with Android GCC 4.9 binutils
  sdclang8    Qualcomm Snapdragon Clang 8.0.6 with bundled GCC binutils
  gcc49       Android GCC 4.9 for ARM64 with an ARM32 companion
  linaro75    Linaro GCC 7.5 for ARM64 with an ARM32 companion
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  toolchain_env_usage
  printf '\nThis script must be sourced so its environment remains active.\n' >&2
  exit 2
fi

profile="${1:-aosp12}"
tools_root="${ANDROID_KERNEL_TOOLS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
aosp_bin="${tools_root}/clang/host/linux-x86/clang-r416183b/bin"
aosp_lib="${tools_root}/clang/host/linux-x86/clang-r416183b/lib64"
sdclang_bin="${tools_root}/sdclang/linux-x86_64/bin"
android_aarch64_bin="${tools_root}/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin"
android_arm_bin="${tools_root}/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin"
linaro_aarch64_bin="${tools_root}/gcc/linux-x86/aarch64/gcc-linaro-7.5.0/bin"

for directory in \
  "$aosp_bin" \
  "$sdclang_bin" \
  "$android_aarch64_bin" \
  "$android_arm_bin" \
  "$linaro_aarch64_bin"; do
  if [[ ! -d "$directory" ]]; then
    printf 'Toolchain directory is missing: %s\n' "$directory" >&2
    return 1
  fi
done

export ANDROID_KERNEL_TOOLS_ROOT="$tools_root"
export ARCH=arm64
export SUBARCH=arm64
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-
export TOOLCHAIN_PROFILE="$profile"

TOOLCHAIN_MAKE_ARGS=()

case "$profile" in
  aosp12)
    export PATH="${aosp_bin}:${android_aarch64_bin}:${android_arm_bin}:${PATH}"
    export LD_LIBRARY_PATH="${aosp_lib}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    export CROSS_COMPILE=aarch64-linux-android-
    export CC=clang
    export HOSTCC=clang
    TOOLCHAIN_MAKE_ARGS=(
      "CC=clang"
      "HOSTCC=clang"
      "LD=ld.lld"
      "AR=llvm-ar"
      "NM=llvm-nm"
      "STRIP=llvm-strip"
      "OBJCOPY=llvm-objcopy"
      "OBJDUMP=llvm-objdump"
    )
    ;;
  sdclang8)
    export PATH="${sdclang_bin}:${linaro_aarch64_bin}:${android_arm_bin}:${PATH}"
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CC=clang
    export HOSTCC=gcc
    TOOLCHAIN_MAKE_ARGS=(
      "CC=clang"
      "HOSTCC=${HOSTCC}"
    )
    ;;
  gcc49)
    export PATH="${android_aarch64_bin}:${android_arm_bin}:${PATH}"
    export CROSS_COMPILE=aarch64-linux-android-
    export CC=aarch64-linux-android-gcc
    export HOSTCC=gcc
    TOOLCHAIN_MAKE_ARGS=(
      "CC=aarch64-linux-android-gcc"
      "HOSTCC=${HOSTCC}"
    )
    ;;
  linaro75)
    export PATH="${linaro_aarch64_bin}:${android_arm_bin}:${PATH}"
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CC=aarch64-linux-gnu-gcc
    export HOSTCC=gcc
    TOOLCHAIN_MAKE_ARGS=(
      "CC=aarch64-linux-gnu-gcc"
      "HOSTCC=${HOSTCC}"
    )
    ;;
  -h | --help)
    toolchain_env_usage
    return 0
    ;;
  *)
    printf 'Unknown toolchain profile: %s\n\n' "$profile" >&2
    toolchain_env_usage >&2
    return 2
    ;;
esac

export TOOLCHAIN_DESCRIPTION
case "$profile" in
  aosp12)
    TOOLCHAIN_DESCRIPTION='AOSP Clang/LLVM 12.0.5'
    ;;
  sdclang8)
    TOOLCHAIN_DESCRIPTION='Qualcomm Snapdragon Clang 8.0.6'
    ;;
  gcc49)
    TOOLCHAIN_DESCRIPTION='Android GCC 4.9'
    ;;
  linaro75)
    TOOLCHAIN_DESCRIPTION='Linaro GCC 7.5'
    ;;
esac

printf 'Selected %s (%s)\n' "$TOOLCHAIN_DESCRIPTION" "$TOOLCHAIN_PROFILE"
