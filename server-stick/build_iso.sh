#!/bin/bash
# Builds the headless G53 server ISO from the stock 24.04.5 ISO, which is not changed.
# Boots to a live system with SSH and no disk writes. It contains no automatic install.
set -euo pipefail

SRC=${PROJECT:?set PROJECT to the project folder as seen from WSL}
ORIG=$SRC/iso/ubuntu-24.04.5-live-server-amd64.iso
ORIG_SHA=97f3d7ffb032c3eb3b23d2c8be9cc76e60c2c1f2c0146ba5ba9fe01cafae0fd8
KEY=${KEY:?set KEY to your SSH public key, e.g. /mnt/c/Users/YOU/.ssh/id_ed25519.pub}
W=/var/tmp/g53server
B=$W/build
OUT=$W/g53-server.iso

echo "$ORIG_SHA  $ORIG" | sha256sum -c -
rm -rf "$B"; mkdir -p "$B/cpio/g53" "$B/cpio/scripts/casper-bottom" "$W/isoro"
mountpoint -q "$W/isoro" || mount -o loop,ro "$ORIG" "$W/isoro"
trap 'umount "$W/isoro" 2>/dev/null || true' EXIT

# 1. The extra initrd. A later archive overwrites same-named files from earlier ones.
[ -d "$W/initrd/main/scripts" ] || { mkdir -p "$W/initrd"; unmkinitramfs "$W/isoro/casper/initrd" "$W/initrd"; }
cp "$SRC/server-stick/hook/62g53" "$B/cpio/scripts/casper-bottom/62g53"
cp "$W/initrd/main/scripts/casper-bottom/ORDER" "$B/cpio/scripts/casper-bottom/ORDER"
printf '/scripts/casper-bottom/62g53 "$@"\n[ -e /conf/param.conf ] && . /conf/param.conf\n' >> "$B/cpio/scripts/casper-bottom/ORDER"
cp -r "$SRC/server-stick/hook/rootfs" "$B/cpio/g53/rootfs"
tr -d '\r' < "$KEY" > "$B/cpio/g53/authorized_keys"
grep -q '^ssh-ed25519 ' "$B/cpio/g53/authorized_keys"

find "$B/cpio" -type d -exec chmod 755 {} +
find "$B/cpio" -type f -exec chmod 644 {} +
chmod 755 "$B/cpio/scripts/casper-bottom/62g53" "$B/cpio/g53/rootfs/usr/local/sbin/g53-report"
chmod 440 "$B/cpio/g53/rootfs/etc/sudoers.d/g53"
(cd "$B/cpio" && find . | sort | cpio -o -H newc --owner=0:0 --quiet) > "$B/g53-hook.img"

# 2. Boot entries. Arguments after --- are the ones the installer copies to the installed system.
patch_cfg() {
    sed -E \
      -e 's|^set timeout=30|set timeout=5|' \
      -e 's#^(\s*linux\s+/casper/(hwe-)?vmlinuz\s+)(.*)---\s*$#\1noprompt fsck.mode=skip \3--- nomodeset module_blacklist=nouveau#' \
      -e 's#^(\s*initrd\s+/casper/(hwe-)?initrd)\s*$#\1 /casper/g53-hook.img#' \
      "$1"
}
patch_cfg "$W/isoro/boot/grub/grub.cfg"     > "$B/grub.cfg"
patch_cfg "$W/isoro/boot/grub/loopback.cfg" > "$B/loopback.cfg"
echo "=== grub.cfg changes"; diff "$W/isoro/boot/grub/grub.cfg" "$B/grub.cfg" || true
[ "$(grep -c 'nomodeset module_blacklist=nouveau' "$B/grub.cfg")" = 2 ]
[ "$(grep -c 'g53-hook.img' "$B/grub.cfg")" = 2 ]
[ "$(grep -c 'nomodeset module_blacklist=nouveau' "$B/loopback.cfg")" = 2 ]

# 3. Keep the integrity list true.
cp "$W/isoro/md5sum.txt" "$B/md5sum.txt"
for pair in "grub.cfg ./boot/grub/grub.cfg" "loopback.cfg ./boot/grub/loopback.cfg"; do
    set -- $pair
    sum=$(md5sum "$B/$1" | cut -d' ' -f1)
    sed -i -E "s#^[0-9a-f]{32}  $2\$#$sum  $2#" "$B/md5sum.txt"
done
echo "$(md5sum "$B/g53-hook.img" | cut -d' ' -f1)  ./casper/g53-hook.img" >> "$B/md5sum.txt"

# 4. Replay keeps the original boot records and hybrid MBR/GPT layout.
rm -f "$OUT"
xorriso -abort_on FAILURE -indev "$ORIG" -outdev "$OUT" \
    -map "$B/grub.cfg" /boot/grub/grub.cfg \
    -map "$B/loopback.cfg" /boot/grub/loopback.cfg \
    -map "$B/md5sum.txt" /md5sum.txt \
    -map "$B/g53-hook.img" /casper/g53-hook.img \
    -boot_image any replay 2>&1 | tail -5

# 5. Compare boot structures with the stock image.
report() { xorriso -indev "$1" -report_el_torito plain -report_system_area plain 2>&1 | grep -E 'El Torito (boot img|img)|System area|MBR partition|GPT partname|GPT type' | sed -E 's/[[:space:]]+/ /g'; }
echo "=== structure, stock"; report "$ORIG"
echo "=== structure, new";   report "$OUT"
sha256sum "$OUT"
ls -l "$OUT"
cp "$OUT" "$SRC/iso/g53-server-24.04.5.iso"
(cd "$W" && sha256sum g53-server.iso | sed 's/g53-server.iso/g53-server-24.04.5.iso/') > "$SRC/iso/g53-server-24.04.5.iso.sha256"
