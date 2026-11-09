#!/bin/bash
# Packs the RAM filesystem and creates the stick image. Run inside WSL as root,
# after build_rootfs.sh. Never touches a real disk, only the image file.
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
WORK=/var/tmp/g53diag
ROOT=$WORK/rootfs
IMG=$WORK/g53diag.img
MNT=$WORK/mnt
SIZE_MB=1024
LOOP=

cleanup() {
    mountpoint -q "$MNT" && umount "$MNT"
    [ -n "$LOOP" ] && losetup -d "$LOOP"
    return 0
}
trap cleanup EXIT

echo "=== pack RAM filesystem $(date +%T)"
install -m 755 "$SRC/init" "$ROOT/init"
mkdir -p "$ROOT/usr/local/sbin"
install -m 755 "$SRC/udhcpc.script" "$ROOT/usr/local/sbin/udhcpc.script"
( cd "$ROOT" && find . -xdev -print0 | cpio --null -H newc -o --quiet --owner=0:0 ) \
    | zstd -19 -T0 -q -f -o "$WORK/initrd.zst"
ls -l "$WORK/initrd.zst" "$WORK/vmlinuz"

echo "=== create image $(date +%T)"
rm -f "$IMG"
truncate -s "${SIZE_MB}M" "$IMG"
printf 'label: dos\nstart=2048, type=c, bootable\n' | sfdisk -q "$IMG"
LOOP=$(losetup -fP --show "$IMG")
partprobe "$LOOP" 2>/dev/null || true
sleep 1
[ -b "${LOOP}p1" ] || { echo "no partition device for $LOOP"; exit 1; }
mkfs.vfat -F 32 -n G53DIAG "${LOOP}p1" > /dev/null
mkdir -p "$MNT"
mount "${LOOP}p1" "$MNT"

mkdir -p "$MNT/diag" "$MNT/boot/grub" "$MNT/LOGS" "$MNT/TESTS"
cp "$WORK/vmlinuz" "$MNT/diag/vmlinuz"
cp "$WORK/initrd.zst" "$MNT/diag/initrd.zst"
cp "$SRC/grub.cfg" "$MNT/boot/grub/grub.cfg"
cp "$SRC/config.txt" "$MNT/config.txt"
cp "$SRC/README-stick.txt" "$MNT/README.txt"
printf '# Optional: extra Linux start options, for example:\n# set extra_args="acpi=off"\n' > "$MNT/grub-extra.cfg"
grub-editenv "$MNT/boot/grub/grubenv" create

echo "=== install boot loaders $(date +%T)"
grub-install --target=i386-pc --boot-directory="$MNT/boot" --modules="part_msdos fat biosdisk" --force "$LOOP"
grub-install --target=x86_64-efi --efi-directory="$MNT" --boot-directory="$MNT/boot" \
    --removable --no-nvram --no-uefi-secure-boot
df -h "$MNT" | tail -1
find "$MNT" -maxdepth 3 -type f -not -path '*/i386-pc/*' -not -path '*/x86_64-efi/*' -not -path '*/fonts/*' -not -path '*/locale/*' | sed "s|$MNT||"
sync

cleanup
LOOP=
trap - EXIT
ls -l "$IMG"
sha256sum "$IMG"
echo "=== image done $(date +%T)"
