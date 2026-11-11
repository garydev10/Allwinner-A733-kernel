#!/bin/bash
# ==============================================================================
# daily-build-and-release.sh
# Unified Daily Build & Release Automation for Allwinner A733 Boards:
#   1. Orange Pi 4 Pro
#   2. Radxa Cubie A7A
#   3. Radxa Cubie A7S
# Runs on Local Development Server and publishes to GitHub Releases via gh CLI.
# ==============================================================================
set -euo pipefail

export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
export NO_HOST_RELEASE_CHECK=yes
export EXPERT=yes

DATE_TAG="$(date +'%Y-%m-%d')"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"

HARNESS_DIR="/srv/kernel/orangepi-build"
KERNEL_REPO="/srv/kernel/Allwinner-A733-kernel"
WORK_DIR="/srv/storage/daily-workflow/run_${TIMESTAMP}"
LOG_FILE="/srv/storage/daily-workflow/daily_build_${TIMESTAMP}.log"

mkdir -p "${WORK_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "========================================================================"
echo " Starting Allwinner A733 Daily Build & Release: ${DATE_TAG}"
echo " Timestamp: ${TIMESTAMP}"
echo " Harness:   ${HARNESS_DIR}"
echo " Kernel:    ${KERNEL_REPO}"
echo " Work dir:  ${WORK_DIR}"
echo "========================================================================"

cleanup() {
    echo "[*] Cleaning up temporary mounts and artifacts..."
    for m in $(mount | grep "${WORK_DIR}" | awk '{print $3}' | sort -r); do
        umount -l "$m" || true
    done
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

# 1. Update source repositories
echo "[*] Syncing kernel repositories..."
cd "${KERNEL_REPO}"
git fetch origin main
git reset --hard origin/main

# Sync patches, defconfigs, and overlays into orangepi-build harness
echo "[*] Syncing patches and overlays into harness..."
mkdir -p "${HARNESS_DIR}/external/patch/kernel/sun60iw2-next"
cp -v "${KERNEL_REPO}/patch/0001-allwinner-a733-orangepi-4-pro-6.18-mainline.patch" "${HARNESS_DIR}/external/patch/kernel/sun60iw2-next/"
cp -v "${KERNEL_REPO}/patch/0300-packaging-armbian-builddeb.patch" "${HARNESS_DIR}/external/patch/kernel/sun60iw2-next/"
[ -f "${KERNEL_REPO}/patch/0003-allwinner-a733-cedrus-vpu-support.patch" ] && cp -v "${KERNEL_REPO}/patch/0003-allwinner-a733-cedrus-vpu-support.patch" "${HARNESS_DIR}/external/patch/kernel/sun60iw2-next/"

mkdir -p "${HARNESS_DIR}/external/config/kernel"
cp -v "${KERNEL_REPO}/config/orangepi_4pro_defconfig" "${HARNESS_DIR}/external/config/kernel/linux-sun60iw2-next-a733.config"

mkdir -p "${HARNESS_DIR}/external/packages/bsp/common"
cp -rv "${KERNEL_REPO}/overlay/"* "${HARNESS_DIR}/external/packages/bsp/common/"

# Clean previous build output images to prevent picking up stale builds
cd "${HARNESS_DIR}"
rm -rf output/images/*

# 2. Build Base Orange Pi 4 Pro Image (Debian 13 Trixie Minimal)
echo "[*] Building Base Orange Pi 4 Pro Image with Linux 6.18.y..."
./build.sh \
    BOARD=orangepi4pro \
    BRANCH=next \
    BUILD_OPT=image \
    RELEASE=trixie \
    BUILD_MINIMAL=yes \
    BUILD_DESKTOP=no \
    KERNEL_CONFIGURE=no

# Find newly generated base image
BASE_RAW_IMG=$(find output/images/ -type f -name "*.img" | head -n 1)
if [ -z "${BASE_RAW_IMG}" ] || [ ! -f "${BASE_RAW_IMG}" ]; then
    echo "[-] Error: Base Orange Pi 4 Pro image not found in output/images/!"
    exit 1
fi
echo "[+] Base image built successfully: ${BASE_RAW_IMG}"

# Detect kernel version from build
KVER=$(basename "$(dirname "${BASE_RAW_IMG}")" | grep -o 'linux.*' | sed 's/linux//')
[ -z "${KVER}" ] && KVER="6.18.63"

OPI_IMG="${WORK_DIR}/Orangepi4pro_1.1.0_debian_trixie_minimal_linux${KVER}.img"
A7A_IMG="${WORK_DIR}/Radxa-Cubie-A7A_1.0.1-beta_trixie_minimal_linux${KVER}.img"
A7S_IMG="${WORK_DIR}/Radxa-Cubie-A7S_1.0.0-beta_trixie_minimal_linux${KVER}.img"

echo "[*] Creating target board images..."
cp --sparse=always "${BASE_RAW_IMG}" "${OPI_IMG}"
cp --sparse=always "${BASE_RAW_IMG}" "${A7A_IMG}"
cp --sparse=always "${BASE_RAW_IMG}" "${A7S_IMG}"

# Compile DTBs if needed
KDIR=$(find "${HARNESS_DIR}/kernel/" -maxdepth 1 -name "linux-6.18*" -type d 2>/dev/null | head -n 1)
DTC_BIN="${KDIR}/scripts/dtc/dtc"
[ ! -x "$DTC_BIN" ] && DTC_BIN="dtc"

compile_dtb() {
    local dts_in="$1"
    local dtb_out="$2"
    gcc -E -nostdinc -I "${KDIR}/scripts/dtc/include-prefixes" -undef -D__DTS__ -x assembler-with-cpp -o /tmp/target.dts.pre "${dts_in}"
    ${DTC_BIN} -o "${dtb_out}" -b 0 -i"${KDIR}/arch/arm64/boot/dts/allwinner/" -i"${KDIR}/scripts/dtc/include-prefixes" \
        -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size -Wno-alias_paths \
        -Wno-graph_child_address -Wno-interrupt_map -Wno-simple_bus_reg /tmp/target.dts.pre
}

DTB_A7A="${WORK_DIR}/sun60i-a733-cubie-a7a.dtb"
DTB_A7S="${WORK_DIR}/sun60i-a733-cubie-a7s.dtb"

if [ -f "${KERNEL_REPO}/dts/sun60i-a733-cubie-a7a.dts" ]; then
    compile_dtb "${KERNEL_REPO}/dts/sun60i-a733-cubie-a7a.dts" "${DTB_A7A}"
elif [ -f "${KERNEL_REPO}/sun60i-a733-cubie-a7a.dtb" ]; then
    cp -v "${KERNEL_REPO}/sun60i-a733-cubie-a7a.dtb" "${DTB_A7A}"
fi

if [ -f "${KERNEL_REPO}/dts/sun60i-a733-cubie-a7s.dts" ]; then
    compile_dtb "${KERNEL_REPO}/dts/sun60i-a733-cubie-a7s.dts" "${DTB_A7S}"
elif [ -f "${KERNEL_REPO}/sun60i-a733-cubie-a7s.dtb" ]; then
    cp -v "${KERNEL_REPO}/sun60i-a733-cubie-a7s.dtb" "${DTB_A7S}"
fi

# Function to patch a target loop-mounted rootfs
patch_image() {
    local img="$1"
    local board_type="$2" # opi4pro | a7a | a7s
    local mnt="${WORK_DIR}/mnt_${board_type}"
    mkdir -p "${mnt}"

    local offset=$((65536 * 512))
    mount -o loop,offset=${offset} "${img}" "${mnt}"

    echo "[*] Customizing [${board_type}] inside ${mnt}..."

    # Ensure /boot/boot.cmd loads correct env file and preserves serial console
    cat << 'BOOT_CMD_EOF' > "${mnt}/boot/boot.cmd"
# DO NOT EDIT THIS FILE
# Please edit /boot/orangepiEnv.txt or radxaEnv.txt to set supported parameters
setenv load_addr "0x43100000"
setenv overlay_error "false"
setenv verbosity "7"
setenv console "both"
setenv bootlogo "false"
setenv rootfstype "ext4"
setenv docker_optimizations "on"
setenv earlycon "on"

echo "Boot script loaded from ${devtype} ${devnum}"

if test -e ${devtype} ${devnum} ${prefix}radxaEnv.txt; then
	load ${devtype} ${devnum} ${load_addr} ${prefix}radxaEnv.txt
	env import -t ${load_addr} ${filesize}
elif test -e ${devtype} ${devnum} ${prefix}orangepiEnv.txt; then
	load ${devtype} ${devnum} ${load_addr} ${prefix}orangepiEnv.txt
	env import -t ${load_addr} ${filesize}
elif test -e ${devtype} ${devnum} ${prefix}a733-allwinnerEnv.txt; then
	load ${devtype} ${devnum} ${load_addr} ${prefix}a733-allwinnerEnv.txt
	env import -t ${load_addr} ${filesize}
fi

if test "${logo}" = "disabled"; then setenv logo "logo.nologo"; fi

# Ensure serial console is last when both is selected so it remains primary on UART
if test "${console}" = "display"; then setenv consoleargs "console=tty1"; fi
if test "${console}" = "serial"; then setenv consoleargs "console=ttyS0,115200"; fi
if test "${console}" = "both"; then setenv consoleargs "console=tty1 console=ttyS0,115200"; fi

if test "${earlycon}" = "on"; then setenv consoleargs "earlycon=uart8250,mmio32,0x02500000 earlyprintk=sunxi-uart,0x02500000 ${consoleargs}"; fi
if test "${bootlogo}" = "true"; then
	setenv consoleargs "splash plymouth.ignore-serial-consoles ${consoleargs}";
else
	setenv consoleargs "splash=verbose ${consoleargs}"
fi

part uuid ${devtype} ${devnum}:1 partuuid
if test -z "${rootdev}"; then rootdev=PARTUUID="${partuuid}"; fi

setenv bootargs "root=${rootdev} rootwait rootdelay=1 rootfstype=${rootfstype} ${consoleargs} consoleblank=0 loglevel=${verbosity} clk_ignore_unused swiotlb=65536 usb-storage.quirks=${usbstoragequirks} ${extraargs} ${extraboardargs}"

if test "${docker_optimizations}" = "on"; then setenv bootargs "${bootargs} cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1"; fi

load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}uImage

load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
fdt addr ${fdt_addr_r}
fdt resize 65536
for overlay_file in ${overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/allwinner/overlay/${overlay_prefix}-${overlay_file}.dtbo; then
		echo "Applying kernel provided DT overlay ${overlay_prefix}-${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done
for overlay_file in ${user_overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}overlay-user/${overlay_file}.dtbo; then
		echo "Applying user provided DT overlay ${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done

bootm ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
BOOT_CMD_EOF

    mkimage -C none -A arm -T script -d "${mnt}/boot/boot.cmd" "${mnt}/boot/boot.scr"

    # Configure board specific details
    if [ "${board_type}" = "opi4pro" ]; then
        cat << 'ENV_EOF' > "${mnt}/boot/orangepiEnv.txt"
verbosity=7
bootlogo=false
console=both
overlay_prefix=sun60i-a733
fdtfile=allwinner/sun60i-a733-orangepi-4-pro.dtb
rootfstype=ext4
extraargs=cma=256M
ENV_EOF
    elif [ "${board_type}" = "a7a" ]; then
        # Install A7A DTB
        cp -v "${DTB_A7A}" "${mnt}/boot/sun60i-a733-cubie-a7a.dtb"
        cp -v "${DTB_A7A}" "${mnt}/boot/dtb/allwinner/sun60i-a733-cubie-a7a.dtb"
        cp -v "${DTB_A7A}" "${mnt}/boot/dtb/allwinner/sun60i-a733-orangepi-4-pro.dtb"
        find "${mnt}/boot/dtb-"* -maxdepth 2 -name "allwinner" -exec cp -v "${DTB_A7A}" {}/sun60i-a733-cubie-a7a.dtb \; 2>/dev/null || true
        find "${mnt}/boot/dtb-"* -maxdepth 2 -name "allwinner" -exec cp -v "${DTB_A7A}" {}/sun60i-a733-orangepi-4-pro.dtb \; 2>/dev/null || true

        cat << 'ENV_EOF' > "${mnt}/boot/radxaEnv.txt"
verbosity=7
bootlogo=false
console=both
overlay_prefix=sun60i-a733
fdtfile=allwinner/sun60i-a733-cubie-a7a.dtb
rootfstype=ext4
extraargs=cma=256M
ENV_EOF
        cp -v "${mnt}/boot/radxaEnv.txt" "${mnt}/boot/orangepiEnv.txt"

        echo "radxa-cubie-a7a" > "${mnt}/etc/hostname"
        sed -i 's/orangepi-4-pro/radxa-cubie-a7a/g' "${mnt}/etc/hosts" 2>/dev/null || true
        sed -i 's/orangepi4pro/radxa-cubie-a7a/g' "${mnt}/etc/hosts" 2>/dev/null || true

        # Radxa User
        local pass_hash
        pass_hash=$(openssl passwd -6 -salt radxa123 radxa)
        if ! grep -q "^radxa:" "${mnt}/etc/passwd"; then
            sed -i '/orangepi/ s/$/,radxa/' "${mnt}/etc/group" || true
            echo "radxa:x:1001:" >> "${mnt}/etc/group"
            echo "radxa:x:1001:1001:Radxa User,,,:/home/radxa:/bin/bash" >> "${mnt}/etc/passwd"
            echo "radxa:${pass_hash}:19800:0:99999:7:::" >> "${mnt}/etc/shadow"
            mkdir -p "${mnt}/home/radxa"
            if [ -d "${mnt}/home/orangepi" ]; then
                cp -a "${mnt}/home/orangepi/." "${mnt}/home/radxa/" || true
            fi
            chown -R 1001:1001 "${mnt}/home/radxa"
            echo "radxa ALL=(ALL) NOPASSWD: ALL" > "${mnt}/etc/sudoers.d/010_radxa-nopasswd"
            chmod 0440 "${mnt}/etc/sudoers.d/010_radxa-nopasswd"
        fi

        # Branding & Splash
        [ -f "${KERNEL_REPO}/splash/boot.bmp" ] && cp -v "${KERNEL_REPO}/splash/boot.bmp" "${mnt}/boot/boot.bmp"
        [ -f "${KERNEL_REPO}/splash/logo.bmp" ] && cp -v "${KERNEL_REPO}/splash/logo.bmp" "${mnt}/boot/logo.bmp"
        cat << 'OS_EOF' > "${mnt}/etc/os-release"
PRETTY_NAME="Radxa OS 1.0 (Trixie)"
NAME="Debian GNU/Linux"
VERSION_ID="13"
VERSION="13 (trixie)"
VERSION_CODENAME=trixie
ID=debian
HOME_URL="https://radxa.com"
SUPPORT_URL="https://forum.radxa.com"
BUG_REPORT_URL="https://github.com/radxa"
OS_EOF

    elif [ "${board_type}" = "a7s" ]; then
        # Install A7S DTB
        cp -v "${DTB_A7S}" "${mnt}/boot/sun60i-a733-cubie-a7s.dtb"
        cp -v "${DTB_A7S}" "${mnt}/boot/dtb/allwinner/sun60i-a733-cubie-a7s.dtb"
        cp -v "${DTB_A7S}" "${mnt}/boot/dtb/allwinner/sun60i-a733-orangepi-4-pro.dtb"
        find "${mnt}/boot/dtb-"* -maxdepth 2 -name "allwinner" -exec cp -v "${DTB_A7S}" {}/sun60i-a733-cubie-a7s.dtb \; 2>/dev/null || true
        find "${mnt}/boot/dtb-"* -maxdepth 2 -name "allwinner" -exec cp -v "${DTB_A7S}" {}/sun60i-a733-orangepi-4-pro.dtb \; 2>/dev/null || true

        cat << 'ENV_EOF' > "${mnt}/boot/radxaEnv.txt"
verbosity=7
bootlogo=false
console=both
overlay_prefix=sun60i-a733
fdtfile=allwinner/sun60i-a733-cubie-a7s.dtb
rootfstype=ext4
extraargs=cma=256M
ENV_EOF
        cp -v "${mnt}/boot/radxaEnv.txt" "${mnt}/boot/orangepiEnv.txt"

        echo "radxa-cubie-a7s" > "${mnt}/etc/hostname"
        sed -i 's/orangepi-4-pro/radxa-cubie-a7s/g' "${mnt}/etc/hosts" 2>/dev/null || true
        sed -i 's/orangepi4pro/radxa-cubie-a7s/g' "${mnt}/etc/hosts" 2>/dev/null || true

        # Radxa User
        local pass_hash
        pass_hash=$(openssl passwd -6 -salt radxa123 radxa)
        if ! grep -q "^radxa:" "${mnt}/etc/passwd"; then
            sed -i '/orangepi/ s/$/,radxa/' "${mnt}/etc/group" || true
            echo "radxa:x:1001:" >> "${mnt}/etc/group"
            echo "radxa:x:1001:1001:Radxa User,,,:/home/radxa:/bin/bash" >> "${mnt}/etc/passwd"
            echo "radxa:${pass_hash}:19800:0:99999:7:::" >> "${mnt}/etc/shadow"
            mkdir -p "${mnt}/home/radxa"
            if [ -d "${mnt}/home/orangepi" ]; then
                cp -a "${mnt}/home/orangepi/." "${mnt}/home/radxa/" || true
            fi
            chown -R 1001:1001 "${mnt}/home/radxa"
            echo "radxa ALL=(ALL) NOPASSWD: ALL" > "${mnt}/etc/sudoers.d/010_radxa-nopasswd"
            chmod 0440 "${mnt}/etc/sudoers.d/010_radxa-nopasswd"
        fi

        # Branding & Splash
        [ -f "${KERNEL_REPO}/splash/boot.bmp" ] && cp -v "${KERNEL_REPO}/splash/boot.bmp" "${mnt}/boot/boot.bmp"
        [ -f "${KERNEL_REPO}/splash/logo.bmp" ] && cp -v "${KERNEL_REPO}/splash/logo.bmp" "${mnt}/boot/logo.bmp"
        cat << 'OS_EOF' > "${mnt}/etc/os-release"
PRETTY_NAME="Radxa OS 1.0 (Trixie)"
NAME="Debian GNU/Linux"
VERSION_ID="13"
VERSION="13 (trixie)"
VERSION_CODENAME=trixie
ID=debian
HOME_URL="https://radxa.com"
SUPPORT_URL="https://forum.radxa.com"
BUG_REPORT_URL="https://github.com/radxa"
OS_EOF
    fi

    # Ensure /etc/fstab mounts root by PARTUUID
    if [ -f "${mnt}/etc/fstab" ]; then
        sed -i 's|^/dev/mmcblk0p1|/dev/disk/by-partuuid/.*|' "${mnt}/etc/fstab" || true
    fi

    sync
    umount "${mnt}"
    rmdir "${mnt}"
    echo "[+] Board customization for [${board_type}] complete."
}

patch_image "${OPI_IMG}" "opi4pro"
patch_image "${A7A_IMG}" "a7a"
patch_image "${A7S_IMG}" "a7s"

# 3. Compression (.xz) and SHA256 generation
compress_and_hash() {
    local raw="$1"
    local xz_file="${raw}.xz"
    echo "[*] Compressing ${raw} to ${xz_file}..."
    xz -T0 -3 -c "${raw}" > "${xz_file}"
    (cd "$(dirname "${xz_file}")" && sha256sum "$(basename "${xz_file}")" > "$(basename "${xz_file}").sha256")
    echo "[+] Generated: ${xz_file} and checksum."
}

compress_and_hash "${OPI_IMG}"
compress_and_hash "${A7A_IMG}"
compress_and_hash "${A7S_IMG}"

# Copy built DEB packages
DEB_DIR="${WORK_DIR}/debs"
mkdir -p "${DEB_DIR}"
find "${HARNESS_DIR}/output/debs/" -maxdepth 2 -type f -name "*.deb" -exec cp -v {} "${DEB_DIR}/" \; 2>/dev/null || true

# 4. Upload Release Images to GitHub Releases
echo "========================================================================"
echo " Uploading Daily Release Images to GitHub..."
echo "========================================================================"

# Board 1: Orange Pi 4 Pro -> release tag: daily-trixie
echo "[*] Publishing Orange Pi 4 Pro image to 'daily-trixie'..."
OPI_XZ="${OPI_IMG}.xz"
OPI_SHA="${OPI_IMG}.xz.sha256"
gh release upload daily-trixie "${OPI_XZ}" "${OPI_SHA}" --clobber -R jonas5/Allwinner-A733-kernel || \
    echo "[-] Failed to upload OPI4PRO to daily-trixie"

# Board 2: Radxa Cubie A7A -> release tag: radxa-cubie-a7a-beta-v1.0.1
echo "[*] Publishing Radxa Cubie A7A image to 'radxa-cubie-a7a-beta-v1.0.1'..."
A7A_XZ="${A7A_IMG}.xz"
A7A_SHA="${A7A_IMG}.xz.sha256"
gh release upload radxa-cubie-a7a-beta-v1.0.1 "${A7A_XZ}" "${A7A_SHA}" --clobber -R jonas5/Allwinner-A733-kernel || \
    echo "[-] Failed to upload A7A to radxa-cubie-a7a-beta-v1.0.1"

# Board 3: Radxa Cubie A7S -> release tag: radxa-cubie-a7s-beta-v1.0.0
echo "[*] Publishing Radxa Cubie A7S image to 'radxa-cubie-a7s-beta-v1.0.0'..."
A7S_XZ="${A7S_IMG}.xz"
A7S_SHA="${A7S_IMG}.xz.sha256"
gh release upload radxa-cubie-a7s-beta-v1.0.0 "${A7S_XZ}" "${A7S_SHA}" --clobber -R jonas5/Allwinner-A733-kernel || \
    echo "[-] Failed to upload A7S to radxa-cubie-a7s-beta-v1.0.0"

echo "========================================================================"
echo " [✓] Daily build and upload completed successfully!"
echo " Timestamp: $(date)"
echo "========================================================================"
