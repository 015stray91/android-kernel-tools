# Ubuntu 22 Android Kernel Compiler Node

This repository can supply a dedicated Ubuntu 22.04 x86_64 server with:

- AOSP Clang/LLVM 12.0.5
- Qualcomm Snapdragon Clang 8.0.6
- Android GCC 4.9 for ARM64 and ARM32
- Linaro GCC 7.5 for ARM64

The checked-out repository consumes about 4.6 GB. Keep at least 50 GB free for
kernel sources, build output, ccache, packaging, and logs. A 512 GB NVMe is
appropriate for multiple kernel trees and their outputs.

## Target device

The initial target is the Moto G Stylus 5G (2023):

- Device codename: `genevn`
- Qualcomm platform: `parrot`
- SoC: SM6450 / Snapdragon 6 Gen 1
- Architecture: ARM64
- Stock kernel family: Android 12 Linux 5.10

This toolchain repository does not contain the device kernel source, its
Motorola release tag, or a complete build configuration. Do not guess a
defconfig. First check out the matching kernel and module sources for the exact
firmware build. Motorola's newer 5.10 releases may use Android kernel
`build.config` or Bazel/Kleaf flows instead of a standalone `make <defconfig>`
flow; use the build system supplied by that kernel tree.

## Prepare Ubuntu 22.04

Install Ubuntu Server 22.04 x86_64 on the dedicated NVMe, update firmware, and
create a normal non-root build user. Then clone this repository and run:

```bash
git clone https://github.com/015stray91/android-kernel-tools.git
cd android-kernel-tools
scripts/bootstrap-ubuntu22.sh
scripts/doctor.sh
```

The bootstrap intentionally installs `libtinfo5`. Snapdragon Clang 8 cannot
start on a clean Ubuntu 22.04 installation without `libtinfo.so.5`.

## Select a compiler

Source one profile in the shell that will run the kernel build:

```bash
source scripts/toolchain-env.sh aosp12
clang --version
llvm-config --version
```

Available profiles are `aosp12`, `sdclang8`, `gcc49`, and `linaro75`.

## Build a make-based kernel

For a kernel tree that documents a conventional defconfig build:

```bash
scripts/build-kernel.sh \
  --kernel /srv/android/repos/kernel \
  --defconfig <documented-defconfig> \
  --toolchain aosp12 \
  --clean
```

Add one or more explicit targets when the kernel requires them:

```bash
scripts/build-kernel.sh \
  --kernel /srv/android/repos/kernel \
  --defconfig <documented-defconfig> \
  --toolchain aosp12 \
  --target Image.gz \
  --target dtbs
```

The build driver uses ccache when available. Its default output directory is
`<kernel>/out/<toolchain-profile>`.

## Run Devin on the headless compiler node

A browser is not required on the server for compilation-only Devin sessions.
Use Devin Outposts so the worker executes directly on the dedicated node.
Outposts must be enabled for the Devin account.

1. On a laptop or phone with a browser, open Devin **Settings → Environment →
   Outposts**.
2. Create a Linux Outpost and copy its token. The token is displayed only once.
3. On the Ubuntu server, install the Devin CLI:

   ```bash
   curl -fsSL https://cli.devin.ai/install.sh | bash
   ```

4. Start the worker from a dedicated directory. Read the token without placing
   it in shell history:

   ```bash
   mkdir -p "$HOME/devin-worker/repos"
   cd "$HOME/devin-worker"
   read -rsp "Outpost token: " DEVIN_OUTPOSTS_TOKEN
   printf '\n'
   export DEVIN_OUTPOSTS_TOKEN
   devin worker start --outpost=android-compiler
   unset DEVIN_OUTPOSTS_TOKEN
   ```

5. Start a Devin session in the web application and select the Outpost as its
   virtual environment.

Run the worker as a dedicated unprivileged user. Do not grant passwordless
`sudo` on a long-lived machine containing personal data. Chrome and a graphical
desktop are optional; omit them on a compilation-only node. Install them later
only if browser or computer-use features are required.

Official references:

- [Devin Outposts quickstart](https://docs.devin.ai/cloud/outposts/quickstart)
- [Outposts machine dependencies](https://docs.devin.ai/cloud/outposts/overview#machine-dependencies)
