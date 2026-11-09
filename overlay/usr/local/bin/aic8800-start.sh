#!/bin/bash
# AIC8800D80 (a69c:8d80) Wi-Fi & Bluetooth Bring-Up Script
set -e

echo "[*] Initializing AIC8800D80 (a69c:8d80) Wi-Fi 6 & Bluetooth..."

# 1. Power on RF kill switches and board WLAN rails
rfkill unblock all 2>/dev/null || true
if [ -e /sys/devices/virtual/misc/sunxi-rfkill/wlan/state ]; then
    echo 1 > /sys/devices/virtual/misc/sunxi-rfkill/wlan/state 2>/dev/null || true
fi

# 2. Check and trigger USB modeswitch if in ZeroCD / mass-storage mode (1111:1111 or a69c:572x)
if [ -x /usr/sbin/usb_modeswitch ] && lsusb 2>/dev/null | grep -qiE "1111:1111|a69c:572"; then
    echo "[*] Switching AIC adapter out of ZeroCD storage mode..."
    if [ -f /etc/usb_modeswitch.d/1111:1111 ]; then
        usb_modeswitch -c /etc/usb_modeswitch.d/1111:1111 >/dev/null 2>&1 || true
    fi
    sleep 1
fi

# 3. Load core networking and AIC drivers
echo "[*] Loading kernel wireless modules..."
modprobe cfg80211 2>/dev/null || true
modprobe aic_zlp_quirk 2>/dev/null || true
modprobe aic_load_fw 2>/dev/null || true
sleep 1
modprobe aic8800_fdrv 2>/dev/null || true
sleep 1

# 4. Bring up wireless network interface
WLAN_IF=$(ip link show | grep -oE "wlan[0-9]|wlp[0-9]s[0-9]" | head -n 1 || true)
if [ -n "$WLAN_IF" ]; then
    ip link set "$WLAN_IF" up 2>/dev/null || true
    echo "[✓] Wi-Fi interface $WLAN_IF is online."
else
    echo "[!] Waiting for wireless interface to appear..."
fi

# 5. Bring up Bluetooth if UART or USB interface is present
if [ -x /usr/local/bin/aic-bt-attach ] && [ -e /dev/ttyS1 ]; then
    killall -9 aic-bt-attach hciattach 2>/dev/null || true
    nohup /usr/local/bin/aic-bt-attach /dev/ttyS1 >/dev/null 2>&1 &
    sleep 1
fi
if hciconfig hci0 >/dev/null 2>&1; then
    hciconfig hci0 up 2>/dev/null || true
    echo "[✓] Bluetooth interface hci0 is online."
fi

echo "[✓] AIC8800 bring-up script completed."
