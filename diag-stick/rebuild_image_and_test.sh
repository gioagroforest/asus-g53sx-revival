#!/bin/bash
# Repacks the image from the existing system, then tests it. Run inside WSL as root.
set -uo pipefail
SRC=$(cd "$(dirname "$0")" && pwd)
bash -n "$SRC/init" || exit 1
bash "$SRC/make_image.sh" > /var/tmp/g53diag-logs/image.log 2>&1 || { tail -20 /var/tmp/g53diag-logs/image.log; exit 1; }
sha256sum /var/tmp/g53diag/g53diag.img
sync; echo 3 > /proc/sys/vm/drop_caches
bash "$SRC/final_check.sh"
