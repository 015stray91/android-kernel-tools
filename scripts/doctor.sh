#!/usr/bin/env bash

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
failures=0

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  failures=$((failures + 1))
}

check_command() {
  local command_name="$1"

  if command -v "$command_name" >/dev/null 2>&1; then
    pass "command available: ${command_name}"
  else
    fail "command missing: ${command_name}"
  fi
}

check_version() {
  local profile="$1"
  local expected="$2"
  local output

  if output="$(
    source "${script_dir}/toolchain-env.sh" "$profile" >/dev/null &&
      "$CC" --version 2>&1 | head -n 1
  )"; then
    if [[ "$output" == *"$expected"* ]]; then
      pass "${profile}: ${output}"
    else
      fail "${profile}: expected version containing '${expected}', got '${output}'"
    fi
  else
    fail "${profile}: compiler could not start"
  fi
}

compile_object() {
  local description="$1"
  local compiler="$2"
  local output="$3"
  shift 3

  if "$compiler" "$@" -c "${work_dir}/probe.c" -o "$output" >/dev/null 2>&1; then
    pass "$description"
  else
    fail "$description"
  fi
}

if [[ -r /etc/os-release ]]; then
  source /etc/os-release
  if [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 22.04 ]]; then
    pass 'host is Ubuntu 22.04'
  else
    fail "host must be Ubuntu 22.04; detected ${ID:-unknown} ${VERSION_ID:-unknown}"
  fi
else
  fail 'unable to identify host operating system'
fi

if [[ "$(uname -m)" == x86_64 ]]; then
  pass 'host architecture is x86_64'
else
  fail "host architecture must be x86_64; detected $(uname -m)"
fi

available_kib="$(df -Pk "$repo_root" | awk 'NR == 2 {print $4}')"
if [[ "$available_kib" =~ ^[0-9]+$ ]] && ((available_kib >= 50 * 1024 * 1024)); then
  pass 'at least 50 GiB of free disk space is available'
else
  fail 'less than 50 GiB of free disk space is available'
fi

for command_name in \
  bc \
  bison \
  ccache \
  flex \
  git \
  make \
  python3 \
  readelf \
  rsync; do
  check_command "$command_name"
done

sdclang="${repo_root}/sdclang/linux-x86_64/bin/clang"
if ldd "$sdclang" 2>&1 | grep -q 'not found'; then
  fail 'Snapdragon Clang runtime libraries are incomplete; run bootstrap-ubuntu22.sh'
else
  pass 'Snapdragon Clang runtime libraries are available'
fi

check_version aosp12 '12.0.5'
check_version sdclang8 '8.0.6'
check_version gcc49 '4.9'
check_version linaro75 '7.5.0'

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
printf 'int compiler_probe(void) { return 42; }\n' >"${work_dir}/probe.c"

source "${script_dir}/toolchain-env.sh" aosp12 >/dev/null
compile_object \
  'AOSP Clang 12 compiles ARM64 objects' \
  clang \
  "${work_dir}/aosp-arm64.o" \
  --target=aarch64-linux-gnu
compile_object \
  'AOSP Clang 12 compiles ARM32 objects' \
  clang \
  "${work_dir}/aosp-arm32.o" \
  --target=arm-linux-gnueabi

source "${script_dir}/toolchain-env.sh" sdclang8 >/dev/null
compile_object \
  'Snapdragon Clang 8 compiles ARM64 objects' \
  clang \
  "${work_dir}/sdclang-arm64.o" \
  --target=aarch64-linux-gnu

source "${script_dir}/toolchain-env.sh" gcc49 >/dev/null
compile_object \
  'Android GCC 4.9 compiles ARM64 objects' \
  aarch64-linux-android-gcc \
  "${work_dir}/gcc49-arm64.o"
compile_object \
  'Android GCC 4.9 compiles ARM32 objects' \
  arm-linux-androideabi-gcc \
  "${work_dir}/gcc49-arm32.o"

source "${script_dir}/toolchain-env.sh" linaro75 >/dev/null
compile_object \
  'Linaro GCC 7.5 compiles ARM64 objects' \
  aarch64-linux-gnu-gcc \
  "${work_dir}/linaro75-arm64.o"

if ((failures)); then
  printf '\nCompiler node has %d failed check(s).\n' "$failures" >&2
  exit 1
fi

printf '\nCompiler node is ready.\n'
