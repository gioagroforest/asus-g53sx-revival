#!/bin/bash
# Tests the built ISO in a VM shaped like the laptop: USB stick plus an internal disk.
# Usage: test_vm.sh boot bios|uefi    starts the VM in the foreground, from a fresh copy
#        test_vm.sh reboot bios|uefi  boots again keeping the stick and disk as they are
#        test_vm.sh kill              pulls the virtual plug, like a freeze
#        test_vm.sh shot              saves a picture of the VM screen as shot.png
#        test_vm.sh inspect           reads the stick and internal disk from outside
# This checks the build only. It cannot reproduce the G53's hardware faults.
set -uo pipefail

W=/var/tmp/g53server
T=$W/vm
CMD=${1:-}
MODE=${2:-bios}

run_vm() {
    local fw=()
    [ "$MODE" = uefi ] && fw=(-bios /usr/share/ovmf/OVMF.fd)
    echo "=== VM starting, $MODE, $(date +%T)"
    timeout 3600 qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 2 "${fw[@]}" \
        -smbios "type=1,manufacturer=ASUSTeK Computer Inc.,product=G53SX" \
        -display none -vga std -monitor "unix:$T/mon,server,nowait" -no-reboot \
        -device usb-ehci,id=ehci \
        -drive if=none,id=stick,format=raw,file="$T/stick.img" \
        -device usb-storage,bus=ehci.0,drive=stick,bootindex=1 \
        -device ahci,id=ahci \
        -drive if=none,id=disk,format=raw,file="$T/disk.img" \
        -device ide-hd,bus=ahci.0,drive=disk \
        -nic user,model=e1000e,hostfwd=tcp:0.0.0.0:2222-:22
    echo "=== VM exit code $? at $(date +%T)"
}

case "$CMD" in
boot)
    pkill -f 'qemu-system-x86_64.*g53server' 2>/dev/null; sleep 1
    rm -rf "$T"; mkdir -p "$T"
    # A stick of the real size, with the free space casper turns into "writable".
    cp --sparse=always "$W/g53-server.iso" "$T/stick.img"
    truncate -s 8053063680 "$T/stick.img"
    truncate -s 20G "$T/disk.img"
    # Something recognisable on the internal disk, to prove nothing touches it.
    printf 'G53-PROBE-INTERNAL-DISK' | dd of="$T/disk.img" bs=1M seek=100 conv=notrunc 2>/dev/null
    sha256sum "$T/disk.img" | tee "$T/disk.sha.before"
    run_vm
    ;;
reboot)
    run_vm
    ;;
installed)
    # Boots the internal disk alone, stick removed, as the server would run.
    echo "=== installed system starting, $(date +%T)"
    timeout 3600 qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 2 \
        -smbios "type=1,manufacturer=ASUSTeK Computer Inc.,product=G53SX" \
        -display none -vga std -monitor "unix:$T/mon,server,nowait" -no-reboot \
        -device ahci,id=ahci \
        -drive if=none,id=disk,format=raw,file="$T/disk.img" \
        -device ide-hd,bus=ahci.0,drive=disk,bootindex=1 \
        -nic user,model=e1000e,hostfwd=tcp:0.0.0.0:2222-:22
    echo "=== VM exit code $? at $(date +%T)"
    ;;
kill)
    pkill -9 -f 'qemu-system-x86_64.*g53server'; sleep 1; echo killed
    ;;
shot)
    printf 'screendump %s/shot.ppm\n' "$T" | socat - "UNIX-CONNECT:$T/mon" >/dev/null
    sleep 1
    python3 - "$T/shot.ppm" "${SHOT:-$T/shot.png}" <<'PY'
import sys, zlib, struct
d = open(sys.argv[1], 'rb').read()
parts = d.split(maxsplit=4)
w, h = int(parts[1]), int(parts[2])
px = parts[4]
raw = b''.join(b'\0' + px[y*w*3:(y+1)*w*3] for y in range(h))
def chunk(t, c):
    return struct.pack('>I', len(c)) + t + c + struct.pack('>I', zlib.crc32(t + c))
open(sys.argv[2], 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
PY
    echo saved
    ;;
inspect)
    echo "=== internal disk, before then now"
    cat "$T/disk.sha.before"; sha256sum "$T/disk.img"
    echo "=== stick partitions"
    sgdisk -p "$T/stick.img" 2>&1 | tail -8
    L=$(losetup -fP --show -r "$T/stick.img"); sleep 1
    P=$(blkid -t LABEL=writable -o device "${L}"p* 2>/dev/null | head -1)
    echo "writable partition: ${P:-NONE}"
    if [ -n "${P:-}" ]; then
        mkdir -p "$T/w"
        # noload: read as it would be after a freeze, without replaying the journal.
        mount -o ro,noload "$P" "$T/w"
        ls -la "$T/w"
        for r in "$T"/w/install-logs-*; do
            echo "--- $r"; ls -la "$r/log" "$r/log/g53" "$r/log/journal" 2>&1 | head -40
            echo "--- heartbeat"; cat "$r/log/g53/heartbeat.txt" 2>&1 | tail -12
        done
        umount "$T/w"
    fi
    losetup -d "$L"
    ;;
*)
    echo "unknown command"; exit 2 ;;
esac
