#!/bin/bash
# Read-only: the journal's last commit, the log file's state, and what the image does
# right after it copies casper.log.
IMG=${PROJECT:?set PROJECT to the project folder as seen from WSL}/stick-evidence/partition4.img
ISO="${PROJECT:?set PROJECT to the project folder as seen from WSL}/iso/ubuntu-24.04.5-live-server-amd64.iso"
COPY=/var/tmp/g53diag/p4-copy.img
echo "=== journal transactions on the untouched copy"
debugfs -c -R "logdump" "$IMG" 2>/dev/null | tail -14
echo "=== casper.log on the replayed copy"
debugfs -R "stat install-logs-2011-08-15.0/log/casper.log" "$COPY" 2>/dev/null | sed -n '1,12p'
echo "=== installer dir on the replayed copy"
debugfs -R "ls -l install-logs-2011-08-15.0/log/installer" "$COPY" 2>/dev/null
echo "=== where the image writes casper.log and the installer folder"
W=$(mktemp -d /tmp/isoinspect.XXXXXX)
mkdir -p "$W/iso" "$W/sq"
mount -o loop,ro "$ISO" "$W/iso"
mount -t squashfs -o loop,ro "$W/iso/casper/ubuntu-server-minimal.ubuntu-server.installer.squashfs" "$W/sq"
S="$W/sq/usr/share/initramfs-tools/scripts"
grep -n 'casper.log\|setup_auto_log_persistence\|run_scripts /scripts/casper-bottom\|/var/log' "$S/casper" | cut -c1-120
LINE=$(grep -n 'setup_auto_log_persistence$' "$S/casper" | tail -1 | cut -d: -f1)
echo "--- end of mountroot"
tail -24 "$S/casper"
echo "--- scripts that touch /var/log/installer"
grep -rln 'var/log/installer' "$S" | sed "s|$S/||"
umount "$W/sq"; umount "$W/iso"; rm -rf "$W"
