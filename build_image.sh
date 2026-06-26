#!/usr/bin/env bash
#
# build_image.sh — build a chiron-bootable Linux image end to end and install it
# into the chiron repo's bins/.
#
#   ./build_image.sh [s1|q4] [DEST_BINS_DIR]
#
#   s1  single-core image  -> linux-s1.bin   (CONFIG_SMP off, device_tree/sample.dts)
#   q4  quad-core SMP image -> linux-q4.bin  (CONFIG_SMP=y NR_CPUS=4, sample_quad.dts)
#
# DEST_BINS_DIR defaults to ../bins (the chiron repo, when this is its submodule).
#
# Prereqs (once):
#   ./submodule_update                 # clone linux/ buildroot/ riscv-pk/
#   cd buildroot && make -j$(nproc)    # build the toolchain + rootfs once
#   export RISCV=$PWD/buildroot/output/host
#   ./apply_configs_and_patches        # stage chiron configs + patches
#
# This is exactly the manual pipeline (kernel .config -> vmlinux -> bbl ->
# flat bbl.bin @ 0x80000000), automated. See README.md for the why behind each
# knob; the gotchas that bite if you skip them:
#   * SMP MUST be off for s1 — an SMP kernel hangs at getty on chiron's CLINT.
#   * The uartlite console options MUST be set or the kernel boots silently.
#   * mem-start / PAGE_OFFSET MUST be 0x80000000 / 0x80200000 (chiron RAM base).
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

VARIANT="${1:-s1}"
DEST="${2:-../bins}"

: "${RISCV:?set RISCV to the buildroot host dir, e.g. export RISCV=$ROOT/buildroot/output/host}"
export PATH="$PATH:$RISCV/bin"
export ARCH=riscv
export CROSS_COMPILE=riscv64-buildroot-linux-uclibc-
command -v "${CROSS_COMPILE}gcc" >/dev/null || { echo "toolchain ${CROSS_COMPILE}gcc not on PATH (is RISCV correct?)"; exit 1; }

case "$VARIANT" in
  s1) DTS="device_tree/sample.dts";      IMG="linux-s1.bin"; SMP="off" ;;
  q4) DTS="device_tree/sample_quad.dts"; IMG="linux-q4.bin"; SMP="on"  ;;
  *)  echo "usage: $0 [s1|q4] [dest_bins_dir]"; exit 2 ;;
esac
echo "== build_image: variant=$VARIANT  dts=$DTS  SMP=$SMP =="

# ── 1. Kernel config: console/nommu/page-offset come from the staged .config;
#       only SMP differs per variant. ───────────────────────────────────────────
cd "$ROOT/linux"
if [ "$SMP" = "on" ]; then
  ./scripts/config --enable SMP --set-val NR_CPUS 4
else
  ./scripts/config --disable SMP
fi
make olddefconfig >/dev/null
grep -q 'CONFIG_SERIAL_UARTLITE_CONSOLE=y' .config \
  || { echo "ERROR: uartlite console not enabled — run ./apply_configs_and_patches first"; exit 1; }
grep -q 'CONFIG_PAGE_OFFSET=0x80200000' .config \
  || echo "WARN: CONFIG_PAGE_OFFSET is not 0x80200000 — is the 0001 page-offset patch applied?"

# ── 2. vmlinux (entry must be 0x80200000) ─────────────────────────────────────
make -j"$(nproc)" vmlinux
"${CROSS_COMPILE}readelf" -h vmlinux | grep -i 'Entry point' || true

# ── 3. bbl + flat bbl.bin @ 0x80000000 ────────────────────────────────────────
cd "$ROOT/riscv-pk"
mkdir -p build && cd build
../configure --prefix="$RISCV" --host=riscv64-buildroot-linux-uclibc \
  --with-arch=rv64ima --with-abi=lp64 --with-mem-start=0x80000000 \
  --with-payload=../../linux/vmlinux --with-dts="../../$DTS" \
  --enable-print-device-tree --disable-vm --enable-boot-machine
make clean >/dev/null 2>&1 || true
make -j"$(nproc)"

# ── 4. install the flat image into chiron's bins/ ─────────────────────────────
mkdir -p "$ROOT/$DEST"
cp bbl.bin "$ROOT/$DEST/$IMG"
echo
echo "== done: $ROOT/$DEST/$IMG ($(wc -c < bbl.bin) bytes) =="
echo "   golden-model shell:  make linux-emu  LINUX_IMAGE=bins/$IMG"
echo "   on the RTL core:     make linux-sim  LINUX_IMAGE=bins/$IMG"
