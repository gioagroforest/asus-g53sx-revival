#!/bin/bash
# Run on the live system, as root, ONLY after the user has agreed to erase the drive.
# Usage: install_server.sh <disk serial> <path to autoinstall.yaml>
# Erases that one disk, installs Ubuntu Server on it, then powers off.
set -euo pipefail

SERIAL=${1:?disk serial}
TEMPLATE=${2:?autoinstall template}

DEV=$(lsblk -dnro NAME,SERIAL | awk -v s="$SERIAL" '$2==s {print $1}')
[ "$(printf '%s\n' "$DEV" | grep -c .)" = 1 ] || { echo "Refusing: need exactly one disk with serial $SERIAL, found: '$DEV'"; exit 1; }
if lsblk -nro MOUNTPOINTS "/dev/$DEV" | grep -q .; then
    echo "Refusing: /dev/$DEV has mounted filesystems, so it is probably the stick"; exit 1
fi

KEY=$(head -1 /home/g53/.ssh/authorized_keys)
sed -e "s|__SSH_KEY__|$KEY|" -e "s|__DISK_SERIAL__|$SERIAL|" "$TEMPLATE" > /autoinstall.yaml
chmod 600 /autoinstall.yaml
grep -q '__' /autoinstall.yaml && { echo "Refusing: unfilled placeholder in autoinstall.yaml"; exit 1; }

# Lift the disk guard for this one disk only.
touch /run/g53-allow-writes
blockdev --setrw "/dev/$DEV"
echo "Erasing and installing to /dev/$DEV (serial $SERIAL)"

# The installer waits for a yes on its screen unless "autoinstall" is on the kernel
# command line, and this machine has no screen. It reads the line from /proc/cmdline.
echo "$(cat /proc/cmdline) autoinstall" > /run/g53-cmdline
mountpoint -q /proc/cmdline || mount --bind /run/g53-cmdline /proc/cmdline
systemctl restart snap.subiquity.subiquity-server.service
echo "Installer restarted. Follow it with: tail -f /var/log/installer/subiquity-server-debug.log"
