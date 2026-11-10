#!/bin/bash
set -eo pipefail

BOARD="${1:-radxa-cubie-a7s}"
OUTPUT_DIR="${2:-/srv/kernel/Allwinner-A733-kernel/bootloader/u-boot-mainline/out/$BOARD}"

echo "=================================================="
echo " Building Mainline U-Boot for $BOARD"
echo " Target Output: $OUTPUT_DIR"
echo "=================================================="

WORK_DIR="$(mktemp -d -t uboot-build-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "--> [1/4] Cloning dlan17/trusted-firmware-a (branch A733)..."
git clone --depth 1 -b A733 https://github.com/dlan17/trusted-firmware-a "$WORK_DIR/tfa"

echo "--> [2/4] Building ARM Trusted Firmware (BL31)..."
make -C "$WORK_DIR/tfa" PLAT=sun60i_a733 CROSS_COMPILE=aarch64-linux-gnu- bl31

export BL31="$WORK_DIR/tfa/build/sun60i_a733/release/bl31.bin"
[ ! -f "$BL31" ] && BL31="$WORK_DIR/tfa/build/sun60i_a733/debug/bl31.bin"

echo "Using BL31: $BL31"

echo "--> [3/4] Cloning dlan17/u-boot (branch allwinner/A733/next)..."
git clone --depth 1 -b allwinner/A733/next https://github.com/dlan17/u-boot "$WORK_DIR/u-boot"

echo "--> [4/4] Applying board & pinctrl patches..."
PATCH_DIR="$(dirname "$0")/patches"
cd "$WORK_DIR/u-boot"

for p in "$PATCH_DIR"/*.patch; do
  [ -f "$p" ] || continue
  echo "Applying: $(basename "$p")"
  git apply --verbose "$p" || patch -p1 < "$p"
done

DEFCONFIG=""
case "$BOARD" in
  radxa-cubie-a7s|a7s)
    DEFCONFIG="radxa-cubie-a7s_defconfig"
    ;;
  radxa-cubie-a7a|a7a)
    DEFCONFIG="radxa-cubie-a7a_defconfig"
    ;;
  orangepi-4-pro|opi4pro|orangepi4pro)
    DEFCONFIG="orangepi-4-pro_defconfig"
    ;;
  *)
    echo "Unknown board: $BOARD. Defaulting to radxa-cubie-a7s_defconfig"
    DEFCONFIG="radxa-cubie-a7s_defconfig"
    ;;
esac

echo "Configuring with $DEFCONFIG..."
make $DEFCONFIG
./scripts/config --disable TOOLS_LIBCRYPTO --disable TOOLS_FIT_SIGNATURE --disable TOOLS_MKEFICAPSULE || true

echo "Compiling U-Boot..."
make -j"$(nproc)" CROSS_COMPILE=aarch64-linux-gnu-

mkdir -p "$OUTPUT_DIR"
cp -v u-boot-sunxi-with-spl.bin "$OUTPUT_DIR/" 2>/dev/null || true
cp -v u-boot-sunxi-with-spl.fit.fit "$OUTPUT_DIR/" 2>/dev/null || true
cp -v u-boot.bin "$OUTPUT_DIR/" 2>/dev/null || true
cp -v u-boot.dtb "$OUTPUT_DIR/" 2>/dev/null || true

echo "=================================================="
echo " U-Boot build for $BOARD completed successfully!"
echo " Artifacts saved in: $OUTPUT_DIR"
echo "=================================================="
