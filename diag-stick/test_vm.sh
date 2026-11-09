#!/bin/bash
# Boots a throwaway copy of the stick image in a virtual machine, then prints what
# it saved. Usage: test_vm.sh bios|uefi [hold minutes]
# This checks the build only. It cannot reproduce the G53's hardware faults.
set -uo pipefail

MODE=${1:-bios}
HOLD=${2:-1}
WORK=/var/tmp/g53diag
T=$WORK/test-$MODE
rm -rf "$T"
mkdir -p "$T/mnt"
cp --sparse=always "$WORK/g53diag.img" "$T/test.img"

LOOP=$(losetup -fP --show "$T/test.img")
sleep 1
mount "${LOOP}p1" "$T/mnt"
cat > "$T/mnt/grub-extra.cfg" <<'EOF'
set extra_args="console=tty0 console=ttyS0,115200"
export extra_args
EOF
sed -i "s/^HOLD_MINUTES=.*/HOLD_MINUTES=$HOLD/; s/^RAM_TEST_MB=.*/RAM_TEST_MB=16/" "$T/mnt/config.txt"
cat > "$T/mnt/TESTS/run.sh" <<'EOF'
echo "user test ran in $RUNNAME"
uname -r
EOF
umount "$T/mnt"
losetup -d "$LOOP"

FW=()
[ "$MODE" = uefi ] && FW=(-bios /usr/share/ovmf/OVMF.fd)
echo "=== starting VM, $MODE, $(date +%T)"
timeout 840 qemu-system-x86_64 -enable-kvm -cpu host -m 1024 -smp 2 "${FW[@]}" \
    -display none -serial "file:$T/serial.log" -no-reboot \
    -device usb-ehci,id=ehci \
    -drive if=none,id=stick,format=raw,file="$T/test.img" \
    -device usb-storage,bus=ehci.0,drive=stick,bootindex=1 \
    -nic user,model=e1000e,hostfwd=tcp:0.0.0.0:2222-:22
echo "=== VM exit code $? at $(date +%T) (0 means it powered itself off, 124 means it ran out of time)"

LOOP=$(losetup -fP --show "$T/test.img")
sleep 1
mount -o ro "${LOOP}p1" "$T/mnt"
echo "=== files saved"
find "$T/mnt/LOGS" -type f | sed "s|$T/mnt/||" | sort
RUN=$(tr -d '\r\n' < "$T/mnt/LOGS/LAST_RUN.txt" 2>/dev/null)
echo "=== grubenv"
grep -a grub_starts "$T/mnt/boot/grub/grubenv"
echo "=== progress.txt"
cat "$T/mnt/LOGS/$RUN/progress.txt"
echo "=== SUMMARY.txt"
cat "$T/mnt/LOGS/$RUN/SUMMARY.txt"
echo "=== user-tests.txt"
cat "$T/mnt/LOGS/$RUN/user-tests.txt"
echo "=== network.txt, first 30 lines"
head -30 "$T/mnt/LOGS/$RUN/network.txt"
echo "=== modprobe.txt errors"
cat "$T/mnt/LOGS/$RUN/modprobe.txt" | head -20
echo "=== FINISHED marker"
ls -l "$T/mnt/LOGS/$RUN/FINISHED.txt"
umount "$T/mnt"
losetup -d "$LOOP"
echo "=== last serial lines"
tail -5 "$T/serial.log"
