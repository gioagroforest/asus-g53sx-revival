#!/bin/bash
# Boots the finished image in both firmware modes, then copies it to the Windows side
# for writing. Run inside WSL as root, after make_image.sh. Frees the file cache between
# steps, because a build of this size has triggered low-memory stops on the PC.
set -uo pipefail
SRC=$(cd "$(dirname "$0")" && pwd)
LOGS=/var/tmp/g53diag-logs
free_cache() { sync; echo 3 > /proc/sys/vm/drop_caches; }

bash "$SRC/test_vm.sh" bios 1 > "$LOGS/test-bios.log" 2>&1
free_cache
bash "$SRC/test_vm.sh" uefi 1 > "$LOGS/test-uefi.log" 2>&1
free_cache
grep -a 'VM exit code' "$LOGS/test-bios.log" "$LOGS/test-uefi.log"
cp /var/tmp/g53diag/g53diag.img "$SRC/g53diag.img"
sha256sum /var/tmp/g53diag/g53diag.img "$SRC/g53diag.img"
free_cache
