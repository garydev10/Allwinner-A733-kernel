#!/bin/bash
# ==============================================================================
# Allwinner A733 / Radxa Cubie A7A & A7S / Orange Pi 4 Pro SD Card Fix Script
# ==============================================================================
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jonas5/Allwinner-A733-kernel/main/tools/fix-sdcard.sh | sudo bash
# Or if mounting the SD card on another host:
#   curl -fsSL https://raw.githubusercontent.com/jonas5/Allwinner-A733-kernel/main/tools/fix-sdcard.sh | sudo bash -s -- /media/user/rootfs
# ==============================================================================
set -euo pipefail

TARGET_DIR="${1:-}"

# Auto-detect rootfs mount point if not specified
if [ -z "$TARGET_DIR" ]; then
    if [ -f "/boot/boot.scr" ] || [ -f "/boot/orangepiEnv.txt" ] || [ -f "/boot/radxaEnv.txt" ]; then
        TARGET_DIR="/"
    else
        # Search mounted block devices for /boot/boot.scr
        CANDIDATE=$(find /media /mnt /run/media -maxdepth 3 -type f -name "boot.scr" 2>/dev/null | head -n 1 || true)
        if [ -n "$CANDIDATE" ]; then
            TARGET_DIR=$(dirname "$(dirname "$CANDIDATE")")
        fi
    fi
fi

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR/boot" ]; then
    echo "[-] Error: Could not locate SD card /boot directory."
    echo "    Please specify the mount path of the SD card rootfs:"
    echo "    sudo bash fix-sdcard.sh /path/to/sdcard_mount"
    exit 1
fi

echo "[*] Target SD root filesystem: $TARGET_DIR"
BOOT_DIR="$TARGET_DIR/boot"

# Check required tools
if ! command -v mkimage >/dev/null 2>&1; then
    echo "[*] Installing u-boot-tools for mkimage..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq u-boot-tools
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y u-boot-tools
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm u-boot-tools
    else
        echo "[!] Warning: mkimage not installed and package manager not recognized. Trying direct install..."
    fi
fi

# Detect board model
BOARD_MODEL="cubie-a7a"
if [ -f "$BOOT_DIR/radxaEnv.txt" ]; then
    if grep -q "cubie-a7s" "$BOOT_DIR/radxaEnv.txt"; then
        BOARD_MODEL="cubie-a7s"
    fi
elif [ -f "$BOOT_DIR/orangepiEnv.txt" ]; then
    if grep -q "orangepi-4-pro" "$BOOT_DIR/orangepiEnv.txt"; then
        BOARD_MODEL="orangepi-4-pro"
    elif grep -q "cubie-a7s" "$BOOT_DIR/orangepiEnv.txt"; then
        BOARD_MODEL="cubie-a7s"
    fi
fi

DTB_NAME="sun60i-a733-${BOARD_MODEL}.dtb"
echo "[*] Detected board configuration: $BOARD_MODEL ($DTB_NAME)"

# 1. Download official tested boot.cmd
echo "[*] Updating /boot/boot.cmd from GitHub..."
TMP_CMD=$(mktemp)
curl -fsSL "https://raw.githubusercontent.com/jonas5/Allwinner-A733-kernel/main/boot/boot.cmd" -o "$TMP_CMD"

# Patch boot.cmd to load radxaEnv.txt or orangepiEnv.txt seamlessly
sed -i 's/if test -e ${devtype} ${devnum} ${prefix}orangepiEnv.txt; then/if test -e ${devtype} ${devnum} ${prefix}radxaEnv.txt; then\n\tload ${devtype} ${devnum} ${load_addr} ${prefix}radxaEnv.txt\n\tenv import -t ${load_addr} ${filesize}\nelif test -e ${devtype} ${devnum} ${prefix}orangepiEnv.txt; then/' "$TMP_CMD"

cp "$TMP_CMD" "$BOOT_DIR/boot.cmd"
rm -f "$TMP_CMD"

# 2. Compile boot.scr with u-boot-tools
if command -v mkimage >/dev/null 2>&1; then
    echo "[*] Compiling /boot/boot.scr..."
    mkimage -C none -A arm -T script -d "$BOOT_DIR/boot.cmd" "$BOOT_DIR/boot.scr"
else
    echo "[*] Downloading pre-compiled boot.scr from GitHub..."
    curl -fsSL "https://raw.githubusercontent.com/jonas5/Allwinner-A733-kernel/main/boot/boot.scr" -o "$BOOT_DIR/boot.scr"
fi

# 3. Write clean, dual-console environment files with verbose systemd service output
cat << ENV_EOF > "$BOOT_DIR/radxaEnv.txt"
verbosity=7
bootlogo=false
console=both
overlay_prefix=sun60i-a733
fdtfile=allwinner/${DTB_NAME}
rootfstype=ext4
extraargs=console=tty1 console=ttyS0,115200 earlycon=uart8250,mmio32,0x02500000 cma=256M systemd.show_status=1 systemd.default_standard_output=journal+console systemd.default_standard_error=journal+console
ENV_EOF

cp -v "$BOOT_DIR/radxaEnv.txt" "$BOOT_DIR/orangepiEnv.txt"
cp -v "$BOOT_DIR/radxaEnv.txt" "$BOOT_DIR/a733-allwinnerEnv.txt"

# 4. Check & fix /etc/fstab
if [ -f "$TARGET_DIR/etc/fstab" ]; then
    echo "[*] Ensuring /etc/fstab root mount is configured..."
    if ! grep -q "/ ext4" "$TARGET_DIR/etc/fstab"; then
        echo "/dev/mmcblk0p1 / ext4 defaults,noatime,commit=600,errors=remount-ro 0 1" >> "$TARGET_DIR/etc/fstab"
    fi
fi

# 5. Sync disks
sync
echo "[+] SD card fix completed successfully! You can now safely insert and boot the board."
