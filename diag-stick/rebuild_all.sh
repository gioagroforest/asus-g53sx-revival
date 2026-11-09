#!/bin/bash
# Full rebuild of the stick image. Run inside WSL as root.
set -euo pipefail
SRC=$(cd "$(dirname "$0")" && pwd)
bash "$SRC/build_rootfs.sh"
bash "$SRC/make_image.sh"
