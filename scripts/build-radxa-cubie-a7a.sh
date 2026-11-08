#!/bin/bash
# ==============================================================================
# build-radxa-cubie-a7a.sh — Standalone Local Builder for Radxa Cubie A7A
# Supports: Debian 13 (Trixie), Ubuntu, minimal (no X11) or desktop
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HARNESS_DIR="/srv/kernel/orangepi-build"

RELEASE="${1:-trixie}"
FLAVOUR="${2:-minimal}"

export NO_HOST_RELEASE_CHECK=yes
export EXPERT=yes

echo "========================================================================"
echo "  Building Radxa Cubie A7A Image (Local Development Server)"
echo "  Distribution: ${RELEASE} | Flavour: ${FLAVOUR}"
echo "  Repo:         ${REPO_ROOT}"
echo "  Harness:      ${HARNESS_DIR}"
echo "========================================================================"

BUILD_MINIMAL="no"
BUILD_DESKTOP="no"
DESKTOP_ENV_ARGS=()

if [ "${FLAVOUR}" = "minimal" ]; then
    BUILD_MINIMAL="yes"
    BUILD_DESKTOP="no"
elif [ "${FLAVOUR}" = "desktop-xfce" ]; then
    BUILD_MINIMAL="no"
    BUILD_DESKTOP="yes"
    DESKTOP_ENV_ARGS=("DESKTOP_ENVIRONMENT=xfce" "DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base" "DESKTOP_APPGROUPS_SELECTED=")
else
    echo "Flavour ${FLAVOUR} not explicitly mapped, defaulting to minimal=no, desktop=no"
fi

# Sync patches
mkdir -p "${HARNESS_DIR}/external/patch/kernel/sun60iw2-next"
cp -v "${REPO_ROOT}/patch/0001-allwinner-a733-orangepi-4-pro-6.18-mainline.patch" "${HARNESS_DIR}/external/patch/kernel/sun60iw2-next/"
cp -v "${REPO_ROOT}/patch/0300-packaging-armbian-builddeb.patch" "${HARNESS_DIR}/external/patch/kernel/sun60iw2-next/"
[ -f "${REPO_ROOT}/patch/0003-allwinner-a733-cedrus-vpu-support.patch" ] && cp -v "${REPO_ROOT}/patch/0003-allwinner-a733-cedrus-vpu-support.patch" "${HARNESS_DIR}/external/patch/kernel/sun60iw2-next/"

mkdir -p "${HARNESS_DIR}/external/config/kernel"
cp -v "${REPO_ROOT}/config/orangepi_4pro_defconfig" "${HARNESS_DIR}/external/config/kernel/linux-sun60iw2-next-a733.config"

mkdir -p "${HARNESS_DIR}/external/packages/bsp/common"
cp -rv "${REPO_ROOT}/overlay/"* "${HARNESS_DIR}/external/packages/bsp/common/"

cd "${HARNESS_DIR}"

# Build base image
echo "[*] Launching build.sh..."
./build.sh \
    BOARD=orangepi4pro \
    BRANCH=next \
    BUILD_OPT=image \
    RELEASE="${RELEASE}" \
    BUILD_MINIMAL="${BUILD_MINIMAL}" \
    BUILD_DESKTOP="${BUILD_DESKTOP}" \
    NO_HOST_RELEASE_CHECK=yes \
    EXPERT=yes \
    KERNEL_CONFIGURE=no \
    ${DESKTOP_ENV_ARGS[@]+"${DESKTOP_ENV_ARGS[@]}"}

echo "[*] Base build complete. Transforming into Radxa Cubie A7A image..."

RAW_IMG=$(find output/images/ -type f -name "*.img" | grep -v "Radxa" | head -n 1)
if [ -z "$RAW_IMG" ]; then
    RAW_IMG=$(find output/ -type f -name "*.img" | grep -v "Radxa" | head -n 1)
fi
if [ -z "$RAW_IMG" ]; then
    echo "[-] Error: Built .img not found!"
    exit 1
fi

RADXA_IMG_NAME="Radxa-Cubie-A7A_1.0.0-alpha_${RELEASE}_${FLAVOUR}_linux6.18.img"
RADXA_IMG="/srv/storage/radxa-build/${RADXA_IMG_NAME}"

cp -v "$RAW_IMG" "$RADXA_IMG"

MNT="/mnt/radxa_loop"
mkdir -p "$MNT"
OFFSET=$((65536 * 512))
mount -o loop,offset=$OFFSET "$RADXA_IMG" "$MNT"

# 1. Install Cubie A7A DTB
CUBIE_DTB=$(find "${HARNESS_DIR}/" -name "sun60i-a733-cubie-a7a.dtb" 2>/dev/null | head -n 1)
if [ -z "$CUBIE_DTB" ] || [ ! -f "$CUBIE_DTB" ]; then
    echo "[*] Compiling Cubie A7A DTB from kernel source tree..."
    KDIR=$(find "${HARNESS_DIR}/kernel/" -maxdepth 1 -name "linux-6.18*" -type d 2>/dev/null | head -n 1)
    DTC_BIN="${KDIR}/scripts/dtc/dtc"
    [ ! -x "$DTC_BIN" ] && DTC_BIN="dtc"
    gcc -E -nostdinc -I "${KDIR}/scripts/dtc/include-prefixes" -undef -D__DTS__ -x assembler-with-cpp -o /tmp/cubie.dts.pre "${REPO_ROOT}/dts/sun60i-a733-cubie-a7a.dts"
    $DTC_BIN -o /tmp/sun60i-a733-cubie-a7a.dtb -b 0 -i"${KDIR}/arch/arm64/boot/dts/allwinner/" -i"${KDIR}/scripts/dtc/include-prefixes" -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-interrupt_map -Wno-simple_bus_reg /tmp/cubie.dts.pre
    CUBIE_DTB="/tmp/sun60i-a733-cubie-a7a.dtb"
fi

echo "[*] Using DTB: $CUBIE_DTB"
cp -v "$CUBIE_DTB" "$MNT/boot/sun60i-a733-cubie-a7a.dtb"
cp -v "$CUBIE_DTB" "$MNT/boot/dtb/allwinner/sun60i-a733-cubie-a7a.dtb"
cp -v "$CUBIE_DTB" "$MNT/boot/dtb/allwinner/sun60i-a733-orangepi-4-pro.dtb"
find "$MNT/boot/dtb-"* -maxdepth 2 -name "allwinner" -exec cp -v "$CUBIE_DTB" {}/sun60i-a733-cubie-a7a.dtb \; 2>/dev/null || true
find "$MNT/boot/dtb-"* -maxdepth 2 -name "allwinner" -exec cp -v "$CUBIE_DTB" {}/sun60i-a733-orangepi-4-pro.dtb \; 2>/dev/null || true

# 2. Splash screens
if [ -d "${REPO_ROOT}/splash" ]; then
    [ -f "${REPO_ROOT}/splash/boot.bmp" ] && cp -v "${REPO_ROOT}/splash/boot.bmp" "$MNT/boot/boot.bmp"
    [ -f "${REPO_ROOT}/splash/logo.bmp" ] && cp -v "${REPO_ROOT}/splash/logo.bmp" "$MNT/boot/logo.bmp"
    if [ -d "$MNT/usr/share/plymouth/themes/orangepi" ]; then
        [ -f "${REPO_ROOT}/splash/watermark.png" ] && cp -v "${REPO_ROOT}/splash/watermark.png" "$MNT/usr/share/plymouth/themes/orangepi/watermark.png"
    fi
fi

# 3. radxaEnv.txt
cat << 'ENV_EOF' > "$MNT/boot/radxaEnv.txt"
verbosity=1
bootlogo=true
console=both
overlay_prefix=sun60i-a733
fdtfile=allwinner/sun60i-a733-cubie-a7a.dtb
rootfstype=ext4
extraargs=cma=256M
ENV_EOF
cp -v "$MNT/boot/radxaEnv.txt" "$MNT/boot/orangepiEnv.txt"

# 4. Patch boot.cmd / boot.scr
sed -i 's/if test -e ${devtype} ${devnum} ${prefix}orangepiEnv.txt; then/if test -e ${devtype} ${devnum} ${prefix}radxaEnv.txt; then\n\tload ${devtype} ${devnum} ${load_addr} ${prefix}radxaEnv.txt\n\tenv import -t ${load_addr} ${filesize}\nelif test -e ${devtype} ${devnum} ${prefix}orangepiEnv.txt; then/' "$MNT/boot/boot.cmd"
mkimage -C none -A arm -T script -d "$MNT/boot/boot.cmd" "$MNT/boot/boot.scr"

# 5. Hostname & Hosts
echo "radxa-cubie-a7a" > "$MNT/etc/hostname"
cat << 'HOSTS_EOF' > "$MNT/etc/hosts"
127.0.0.1   localhost
127.0.1.1   radxa-cubie-a7a
::1         localhost radxa-cubie-a7a ip6-localhost ip6-loopback
fe00::0     ip6-localnet
ff00::0     ip6-mcastprefix
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS_EOF

# 6. OS Branding
cat << 'OS_EOF' > "$MNT/etc/os-release"
PRETTY_NAME="Radxa OS 1.0 Alpha (Trixie)"
NAME="Debian GNU/Linux"
VERSION_ID="13"
VERSION="13 (trixie) Alpha"
VERSION_CODENAME=trixie
ID=debian
HOME_URL="https://radxa.com"
SUPPORT_URL="https://forum.radxa.com"
BUG_REPORT_URL="https://github.com/radxa"
OS_EOF
echo -e "Radxa Cubie A7A Alpha (Debian Trixie) \l\n" > "$MNT/etc/issue"
echo "Radxa Cubie A7A Alpha (Debian Trixie)" > "$MNT/etc/issue.net"

# 7. Create Radxa User
PASS_HASH=$(openssl passwd -6 -salt radxa123 radxa)
sed -i '/orangepi/ s/$/,radxa/' "$MNT/etc/group"
echo "radxa:x:1001:" >> "$MNT/etc/group"
echo "radxa:x:1001:1001:Radxa User,,,:/home/radxa:/bin/bash" >> "$MNT/etc/passwd"
echo "radxa:${PASS_HASH}:19800:0:99999:7:::" >> "$MNT/etc/shadow"
if [ -d "$MNT/home/orangepi" ]; then
    cp -a "$MNT/home/orangepi/." "$MNT/home/radxa/"
else
    mkdir -p "$MNT/home/radxa"
fi
chown -R 1001:1001 "$MNT/home/radxa"
echo "radxa ALL=(ALL) NOPASSWD: ALL" > "$MNT/etc/sudoers.d/010_radxa-nopasswd"
chmod 0440 "$MNT/etc/sudoers.d/010_radxa-nopasswd"

# 8. MOTD
if [ -f "$MNT/etc/update-motd.d/10-orangepi-header" ]; then
    cat << 'MOTD_EOF' > "$MNT/etc/update-motd.d/10-orangepi-header"
#!/bin/sh
echo "Welcome to Radxa Cubie A7A Alpha (Debian Trixie)"
MOTD_EOF
fi

sync
umount "$MNT"
echo "[✓] Transformation complete!"

echo "[*] Compressing with xz..."
xz -T0 -3 -c "$RADXA_IMG" > "/srv/storage/radxa-build/${RADXA_IMG_NAME}.xz"
(cd /srv/storage/radxa-build && sha256sum "${RADXA_IMG_NAME}.xz" > "${RADXA_IMG_NAME}.xz.sha256")

echo "[*] Copying to production web server..."
scp "/srv/storage/radxa-build/${RADXA_IMG_NAME}.xz" production:/srv/www/drivers.raccoon.ing/
scp "/srv/storage/radxa-build/${RADXA_IMG_NAME}.xz.sha256" production:/srv/www/drivers.raccoon.ing/

echo "========================================================================"
echo " [✓] Published to: https://drivers.raccoon.ing/${RADXA_IMG_NAME}.xz"
echo "========================================================================"
