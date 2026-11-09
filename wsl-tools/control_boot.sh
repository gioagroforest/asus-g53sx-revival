#!/bin/bash
# Healthy-boot control for the hot-boot evidence: boots the UNMODIFIED Ubuntu ISO in a VM, on a
# throwaway stick image of the real size and read speed, and records when the writable partition
# gets each new journal commit. Touches no real disk and not the evidence copy.
# Usage: control_boot.sh <seconds> <results-file>
set -uo pipefail
SECS=${1:-420}
OUT=${2:-/var/tmp/g53control/timeline.txt}
ISO="${PROJECT:?set PROJECT to the project folder as seen from WSL}/iso/ubuntu-24.04.5-live-server-amd64.iso"
T=/var/tmp/g53control
STICK=$T/stick.img
OFFSET=4081057792      # where the ASUS got partition 4 on the real stick
mkdir -p "$T"; rm -f "$STICK" "$OUT"
cp --sparse=always "$ISO" "$STICK"
truncate -s 8053063680 "$STICK"

say() { echo "$(date -u +%H:%M:%S) $*" | tee -a "$OUT"; }
say "VM starting with the stock ISO"
timeout "$SECS" qemu-system-x86_64 -enable-kvm -cpu host -m 8192 -smp 4 \
    -smbios "type=1,manufacturer=ASUSTeK Computer Inc.,product=G53SX" \
    -rtc base=utc -display none -vga std -no-reboot \
    -device usb-ehci,id=ehci \
    -drive if=none,id=stick,format=raw,cache=none,aio=threads,file="$STICK",throttling.bps-total=11534336 \
    -device usb-storage,bus=ehci.0,drive=stick,bootindex=1 \
    -nic user,model=e1000e > "$T/qemu.log" 2>&1 &
VM=$!

snapshot() {   # replays the journal on a private copy of the partition and lists the files
    local C=$T/snap.img
    dd if="$STICK" of="$C" bs=1M iflag=skip_bytes skip=$OFFSET conv=sparse status=none
    e2fsck -fy "$C" > /dev/null 2>&1
    debugfs -R "ls -p /" "$C" 2>/dev/null | grep -q install-logs || { say "  (no install-logs yet)"; rm -f "$C"; return; }
    local D
    D=$(debugfs -R "ls -p /" "$C" 2>/dev/null | tr -d '\r' | awk -F/ '$6 ~ /install-logs/ {print $6}' | head -1)
    for dir in "$D/log" "$D/log/installer" "$D/crash"; do
        debugfs -R "ls -p $dir" "$C" 2>/dev/null | awk -F/ -v d="$dir" 'NF>6 && $6!="." && $6!=".." {printf "  %s/%s size=%s\n", d, $6, $7}' | tee -a "$OUT"
    done
    rm -f "$C"
}

last=""
while kill -0 "$VM" 2>/dev/null; do
    if [ "$(blkid -p -O "$OFFSET" -s LABEL -o value "$STICK" 2>/dev/null)" = writable ] || \
       dumpe2fs -h "$STICK?offset=$OFFSET" 2>/dev/null | grep -q writable; then
        J=$(debugfs -c -R "logdump" "$STICK?offset=$OFFSET" 2>/dev/null | grep -c 'commit block')
        S=$(dumpe2fs -h "$STICK?offset=$OFFSET" 2>/dev/null | grep -E 'Last mount time' | cut -d: -f2-)
        if [ "$J" != "$last" ]; then
            say "commits in journal: $J  (mounted:$S)"
            last=$J
            snapshot
        fi
    fi
    sleep 3
done
say "VM stopped"
snapshot
debugfs -c -R "logdump" "$STICK?offset=$OFFSET" 2>/dev/null | grep -E 'commit block' | tail -5 | tee -a "$OUT"
say "DONE"
