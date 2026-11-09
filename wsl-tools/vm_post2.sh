#!/bin/bash
# Read-only: compact results of a VM test run. Usage: vm_post2.sh bios|uefi
MODE=${1:-bios}
T=/var/tmp/g53diag/test-$MODE
LOOP=$(losetup -fP --show "$T/test.img")
sleep 1
mount -o ro "${LOOP}p1" "$T/mnt"
R="$T/mnt/LOGS/run-001"
echo "=== exit line"
grep -a 'VM exit code' "/var/tmp/g53diag-logs/test-$MODE.log"
echo "=== grubenv"
grep -a grub_starts "$T/mnt/boot/grub/grubenv"
echo "=== key progress"
grep -nE 'drivers done|TIMEOUT|LINK|SSH|ABOUT|FINISHED|stick mounted|held|skipped|connected' "$R/progress.txt" | cut -c1-110
echo "=== modprobe errors"
cat "$R/modprobe.txt" | cut -c1-110
echo "=== nouveau in kernel log"
grep -nE 'Unknown symbol|nouveau' "$R/dmesg-live.txt" | head -8 | cut -c1-110
echo "=== gpu-after, first lines"
head -12 "$R/gpu-after.txt" | cut -c1-110
echo "=== kernel errors from SUMMARY"
sed -n '/kernel errors/,/steps that timed out/p' "$R/SUMMARY.txt" | cut -c1-110 | head -14
echo "=== FINISHED marker and file count"
ls "$R" | wc -l
ls -l "$R/FINISHED.txt" | cut -c1-60
umount "$T/mnt"
losetup -d "$LOOP"
echo "=== serial log problems"
grep -nE 'error:|grub>|play|unknown command|Press any key' "$T/serial.log" | head -10 | cut -c1-110
echo "=== needed drivers with unresolved symbols, full list check"
grep 'needs unknown symbol' /var/tmp/g53diag/depmod.log | sed 's|.*/kernel/||; s| needs.*||' | sort -u \
  | grep -E '^(net/(mac80211|wireless|rfkill|core|ipv4|ipv6|packet)|drivers/net/(ethernet/(atheros|realtek|intel)|wireless/(ath|intel)|phy|mii)|drivers/gpu/drm/(nouveau|display|ttm|drm)|drivers/usb/(storage|host|core)|drivers/hid/(usbhid|hid-generic)|drivers/ata|drivers/platform/x86/(asus|wmi)|drivers/acpi|drivers/i2c/busses/i2c-i801|drivers/misc/eeprom)' \
  || echo "none of them"
