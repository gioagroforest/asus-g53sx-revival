#!/bin/bash
# The evidence copy stays untouched: journal replay happens on a second, throwaway copy.
IMG=${PROJECT:?set PROJECT to the project folder as seen from WSL}/stick-evidence/partition4.img
ISO="${PROJECT:?set PROJECT to the project folder as seen from WSL}/iso/ubuntu-24.04.5-live-server-amd64.iso"
WORK=/var/tmp/g53diag
COPY=$WORK/p4-copy.img
M=$WORK/p4
free_cache() { sync; echo 3 > /proc/sys/vm/drop_caches; }

echo "=== all filesystem details"
dumpe2fs -h "$IMG" 2>/dev/null | grep -E 'features|Lifetime writes|Journal size|Journal length|Journal start|Journal sequence|Journal checksum|Inode count|Free inodes|Mount count|Filesystem UUID|Reserved block|mount options'

echo "=== what Ubuntu mounts there"
W=$(mktemp -d /tmp/isoinspect.XXXXXX)
mkdir -p "$W/iso" "$W/sq"
mount -o loop,ro "$ISO" "$W/iso"
mount -t squashfs -o loop,ro "$W/iso/casper/ubuntu-server-minimal.ubuntu-server.installer.squashfs" "$W/sq"
sed -n '880,915p' "$W/sq/usr/share/initramfs-tools/scripts/casper"
umount "$W/sq"; umount "$W/iso"; rm -rf "$W"

echo "=== replay the journal on the throwaway copy"
umount "$M" 2>/dev/null
rm -f "$COPY"
cp --sparse=always "$IMG" "$COPY"
free_cache
e2fsck -fy "$COPY" 2>&1 | tail -15

echo "=== files after replay"
mkdir -p "$M"
mount -o loop,ro "$COPY" "$M" && {
    ls -la --time-style='+%Y-%m-%d %H:%M:%S' "$M"
    find "$M" -mindepth 1 -printf '%TY-%Tm-%Td %TH:%TM:%.2TS %y %10s %P\n' 2>/dev/null | sort | head -100
    echo "file count: $(find "$M" -type f | wc -l)"
    umount "$M"
}

echo "=== raw text search of the untouched copy"
strings -n 8 "$IMG" > "$WORK/p4-strings.txt"
wc -l "$WORK/p4-strings.txt"
grep -vE '^[[:space:]]*$' "$WORK/p4-strings.txt" | head -40 | cut -c1-140
echo "--- lines mentioning hardware, kernel or logs"
grep -aiE 'nouveau|nvidia|asustek|g53|atl1c|kernel|panic|oops|segfault|apport|Package:|ProblemType|casper|subiquity|systemd|/var/' "$WORK/p4-strings.txt" | sort -u | head -60 | cut -c1-160
free_cache
