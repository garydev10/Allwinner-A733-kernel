# Supported Boards & Platform Status

This document tracks Allwinner A733-based hardware supported and tested by the **Allwinner-A733-kernel** project, covering build workflows, mainline device trees, and bootloader configurations.

## Project Goal

The objective of this project is to provide and maintain unified modern Linux (6.18.y) and U-Boot support across the **Allwinner A733 (`sun60iw2`)** ecosystem.

## Board Support Matrix

| Board | Vendor | Form Factor | Video Output | Storage | U-Boot Profile | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Orange Pi 4 Pro** | Orange Pi / Xunlong | Full SBC | HDMI 2.0 / MIPI DSI | SD / eMMC / NVMe | `orangepi-4-pro_defconfig` | ✅ **Fully Validated** |
| **Radxa Cubie A7A** | Radxa | Full SBC | HDMI 2.0 / MIPI DSI | SD / eMMC / NVMe | `radxa-cubie-a7a_defconfig` | ✅ **Fully Validated** |
| **Radxa Cubie A7S** | Radxa | Micro / Dongle | USB-C DP Alt Mode | SD / USB Stick | `radxa-cubie-a7s_defconfig` | ✅ **Fully Validated** |
| **Banana Pi BPI-M8** | Banana Pi | Full SBC | HDMI 2.0 | SD / eMMC | Compatible baseline | 🔄 Hardware Incoming |
| **Orange Pi Zero 3W** | Orange Pi / Xunlong | Micro SBC | Mini-HDMI | SD / eMMC | Compatible baseline | ⏳ Platform Ready |

---

## Hardware Differences & Specifics

### 1. Orange Pi 4 Pro
- **Display**: Physical HDMI 2.0 connector (`sunxi-drm` with CMA 256M).
- **Network**: Motorcomm YT8531 Gigabit Ethernet PHY on `end0` (EEE / auto-sleep disabled).
- **Wireless**: AIC8800D80 SDIO 4-bit Wi-Fi 6 + Bluetooth 5.4 over UART1.
- **Power & Switching**: Fixed 5V supply with PL2 USB VBUS switching.
- **Storage**: MicroSD (`mmc0`), onboard SPI NOR flash (`mtd0`), eMMC socket, M.2 NVMe PCIe 3.0.

### 2. Radxa Cubie A7A
- **Display**: Physical HDMI 2.0 connector (`sunxi-drm` / `&hdmi0`) + MIPI DSI.
- **Cooling**: 2-pin PWM fan on `s_pwm0` pin 7 (`cooling_device2`).
- **Power**: AXP8191 PMIC with stepped voltage transitions; PCIe power rail via PE11 (`reg_pcie_pwr`).
- **Storage & Boot**: MicroSD, onboard 64GB eMMC (`mmc2`), SPI NOR flash (`mtdblock0`), M.2 NVMe via FPC.

### 3. Radxa Cubie A7S
- **Display**: **No physical HDMI**. Video is exclusively output via **USB-C DisplayPort Alt Mode** (`phy_switcher@10`, `combo0_dp`, `&edp0`) negotiated by the HUSB311/RT1711H Type-C PD controller.
- **Cooling**: PWM fan on `pwm1` pin 9.
- **USB Host & Wi-Fi**: USB-A socket and AIC8800 sit behind an onboard CH334F hub on `usb1`. Power is switched via **PM5** (`USB_HOST_EN`) driving an SGM2576 load switch for `VCC5V0_USB20`.
- **Boot**: MicroSD or direct USB OS boot via mainline U-Boot over FEL.

---

## Bootloader Architecture (Mainline U-Boot)

All three boards are supported via mainline U-Boot trees (`dlan17/u-boot` branch `allwinner/A733/next` with BL31 from `dlan17/trusted-firmware-a`):

1. **Orange Pi 4 Pro**: `configs/orangepi-4-pro_defconfig` -> `sun60i-a733-orangepi-4-pro.dts`
2. **Radxa Cubie A7A**: `configs/radxa-cubie-a7a_defconfig` -> `sun60i-a733-radxa-a7a.dts`
3. **Radxa Cubie A7S**: `configs/radxa-cubie-a7s_defconfig` -> `sun60i-a733-radxa-a7s.dts`

To build the modern bootloader for any target board:
```bash
./bootloader/u-boot-mainline/build-uboot-allwinner.sh radxa-cubie-a7s
./bootloader/u-boot-mainline/build-uboot-allwinner.sh radxa-cubie-a7a
./bootloader/u-boot-mainline/build-uboot-allwinner.sh orangepi-4-pro
```
