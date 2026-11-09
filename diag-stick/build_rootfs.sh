#!/bin/bash
# Builds the RAM filesystem for the G53 diagnostic stick. Run inside WSL as root.
set -euo pipefail

WORK=/var/tmp/g53diag
ROOT=$WORK/rootfs
MIRROR=http://archive.ubuntu.com/ubuntu
KEY=${KEY:?set KEY to your SSH public key, e.g. /mnt/c/Users/YOU/.ssh/id_ed25519.pub}
export DEBIAN_FRONTEND=noninteractive LC_ALL=C

unmount_all() {
    for m in dev/pts dev sys proc; do
        umount "$ROOT/$m" 2>/dev/null || true
    done
}
trap unmount_all EXIT

echo "=== host tools $(date +%T)"
apt-get update -q
apt-get install -y -q --no-install-recommends debootstrap dosfstools mtools zstd cpio \
    grub-common grub2-common grub-pc-bin grub-efi-amd64-bin qemu-system-x86 ovmf

echo "=== base system $(date +%T)"
mkdir -p "$WORK"
unmount_all
rm -rf "$ROOT"
debootstrap --variant=minbase --arch=amd64 --components=main,universe noble "$ROOT" "$MIRROR"

cat > "$ROOT/etc/apt/sources.list" <<EOF
deb $MIRROR noble main universe
deb $MIRROR noble-updates main universe
deb $MIRROR noble-security main universe
EOF
printf '#!/bin/sh\nexit 101\n' > "$ROOT/usr/sbin/policy-rc.d"
chmod 755 "$ROOT/usr/sbin/policy-rc.d"
mount -t proc proc "$ROOT/proc"
mount -t sysfs sysfs "$ROOT/sys"
mount --bind /dev "$ROOT/dev"
mount --bind /dev/pts "$ROOT/dev/pts"
cp /etc/resolv.conf "$ROOT/etc/resolv.conf"

echo "=== kernel and tools $(date +%T)"
chroot "$ROOT" apt-get update -q
KPKG=$(chroot "$ROOT" apt-cache depends linux-image-generic | awk '/Depends: linux-image-[0-9]/ {print $2; exit}')
KVER=${KPKG#linux-image-}
echo "kernel package: $KPKG"
chroot "$ROOT" apt-get install -y -q --no-install-recommends \
    "$KPKG" "linux-modules-extra-$KVER" \
    kmod util-linux fdisk procps psmisc pciutils usbutils dmidecode lshw \
    ethtool iproute2 iputils-ping iw wpasupplicant rfkill tcpdump openssh-server \
    i2c-tools lm-sensors smartmontools hdparm memtester edid-decode \
    busybox-static dosfstools less wireless-regdb

echo "=== wireless and network firmware, selected files only $(date +%T)"
chroot "$ROOT" sh -c 'cd /tmp && apt-get download linux-firmware-intel-wireless linux-firmware-realtek'
rm -rf "$WORK/fw"
mkdir -p "$WORK/fw"
for deb in "$ROOT"/tmp/linux-firmware-*.deb; do
    dpkg-deb -x "$deb" "$WORK/fw"
done
FWSRC=$WORK/fw/lib/firmware
[ -d "$FWSRC" ] || FWSRC=$WORK/fw/usr/lib/firmware
mkdir -p "$ROOT/usr/lib/firmware"
( cd "$FWSRC" && find . \( \
      -name 'iwlwifi-100-*' -o -name 'iwlwifi-105-*' -o -name 'iwlwifi-135-*' \
      -o -name 'iwlwifi-1000-*' -o -name 'iwlwifi-2000-*' -o -name 'iwlwifi-2030-*' \
      -o -name 'iwlwifi-5000-*' -o -name 'iwlwifi-5150-*' -o -name 'iwlwifi-6000-*' \
      -o -name 'iwlwifi-6000g2a-*' -o -name 'iwlwifi-6000g2b-*' -o -name 'iwlwifi-6050-*' \
      -o -path './rtl_nic/rtl81*' \
    \) -print0 | cpio --null -pdm --quiet "$ROOT/usr/lib/firmware" )
echo "firmware files copied: $(find "$ROOT/usr/lib/firmware" -type f | wc -l)"
rm -rf "$WORK/fw" "$ROOT"/tmp/linux-firmware-*.deb

echo "=== configure $(date +%T)"
echo g53-diag > "$ROOT/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 g53-diag\n' > "$ROOT/etc/hosts"
printf 'blacklist nouveau\nblacklist nvidiafb\nblacklist rivafb\n' > "$ROOT/etc/modprobe.d/g53-gpu-last.conf"

install -d -m 700 "$ROOT/root/.ssh"
install -m 600 "$KEY" "$ROOT/root/.ssh/authorized_keys"
chroot "$ROOT" usermod -p '*' root
chroot "$ROOT" sh -c 'rm -f /etc/ssh/ssh_host_*; ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key'
cat > "$ROOT/etc/ssh/sshd_config.d/g53.conf" <<EOF
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
HostKey /etc/ssh/ssh_host_ed25519_key
EOF

echo "=== trim $(date +%T)"
cp "$ROOT/boot/vmlinuz-$KVER" "$WORK/vmlinuz"
rm -rf "$ROOT"/usr/share/doc/* "$ROOT"/usr/share/man/* "$ROOT"/usr/share/info/* \
       "$ROOT"/usr/share/locale/* "$ROOT"/usr/share/lintian/* "$ROOT"/usr/share/zoneinfo/* \
       "$ROOT"/var/cache/apt/* "$ROOT"/var/lib/apt/lists/* "$ROOT"/var/log/* "$ROOT"/tmp/*
K=$ROOT/usr/lib/modules/$KVER/kernel
# Everything in drivers/media except cec and rc: the GPU driver's display helper needs them.
for d in "$K"/drivers/media/*; do
    case "${d##*/}" in
        cec|rc) ;;
        *) rm -rf "$d" ;;
    esac
done
for d in sound ubuntu arch/x86/kvm virt samples \
         drivers/infiniband drivers/staging drivers/iio drivers/isdn \
         drivers/bluetooth drivers/hwtracing drivers/fpga drivers/mtd drivers/nfc drivers/net/can \
         drivers/net/dsa drivers/net/hamradio drivers/net/ieee802154 drivers/net/wwan drivers/net/usb \
         drivers/gpu/drm/amd drivers/gpu/drm/radeon drivers/gpu/drm/xe drivers/gpu/drm/vmwgfx \
         drivers/gpu/drm/mgag200 drivers/gpu/drm/ast drivers/gpu/drm/qxl drivers/gpu/drm/gma500 \
         drivers/net/ethernet/mellanox drivers/net/ethernet/chelsio drivers/net/ethernet/qlogic \
         drivers/net/ethernet/cavium drivers/net/ethernet/netronome drivers/net/ethernet/emulex \
         drivers/net/ethernet/huawei drivers/net/ethernet/sfc drivers/net/ethernet/pensando \
         drivers/net/ethernet/freescale drivers/net/ethernet/microsoft \
         drivers/net/wireless/mediatek drivers/net/wireless/marvell drivers/net/wireless/ralink \
         drivers/net/wireless/rsi drivers/net/wireless/ti drivers/net/wireless/zydas \
         drivers/net/wireless/st drivers/net/wireless/quantenna drivers/net/wireless/microchip \
         drivers/net/wireless/atmel drivers/net/wireless/cisco drivers/net/wireless/intersil \
         drivers/net/wireless/purelifi drivers/net/wireless/silabs \
         drivers/scsi/qla2xxx drivers/scsi/lpfc drivers/scsi/bfa drivers/scsi/be2iscsi drivers/scsi/mpt3sas \
         drivers/scsi/qla4xxx drivers/scsi/qedf drivers/scsi/qedi drivers/scsi/csiostor drivers/scsi/fnic \
         net/bluetooth net/netfilter net/ipv4/netfilter net/ipv6/netfilter net/sunrpc net/ceph net/sctp \
         net/rxrpc net/tipc net/rds net/openvswitch net/sched \
         fs/btrfs fs/xfs fs/ocfs2 fs/gfs2 fs/ceph fs/nfs fs/nfsd fs/smb fs/f2fs fs/jfs fs/reiserfs \
         fs/ubifs fs/nilfs2 fs/bcachefs fs/erofs fs/dlm fs/afs fs/coda fs/orangefs; do
    rm -rf "${K:?}/$d"
done

echo "=== check the trimming left no driver we care about broken $(date +%T)"
chroot "$ROOT" depmod -a -e -F "/boot/System.map-$KVER" "$KVER" 2> "$WORK/depmod.log" || true
echo "modules with unresolved symbols: $(grep -c 'needs unknown symbol' "$WORK/depmod.log" || true)"
grep 'needs unknown symbol' "$WORK/depmod.log" | sed 's|.*/kernel/||; s| needs.*||' | sort -u | head -40
for m in nouveau atl1c alx r8169 e1000e ath9k iwlwifi iwldvm usb-storage uas xhci-pci usbhid hid-generic \
         asus-nb-wmi coretemp i2c-i801 at24 input-leds nls_iso8859_1 ahci; do
    if chroot "$ROOT" modprobe -S "$KVER" --show-depends "$m" > /dev/null 2>&1; then
        echo "ok      $m"
    else
        echo "MISSING $m"
        exit 1
    fi
done
if grep 'needs unknown symbol' "$WORK/depmod.log" | grep -qE '/(nouveau|atl1c|alx|r8169|ath9k|iwlwifi|iwldvm|usb-storage|uas|usbhid|asus-nb-wmi|asus-wmi|drm_display_helper|drm_kms_helper|ttm)\.ko'; then
    echo "a driver we need has unresolved symbols"
    exit 1
fi
rm -rf "$ROOT"/boot/*
rm -f "$ROOT/usr/sbin/policy-rc.d"

unmount_all
trap - EXIT
[ -e "$ROOT/dev/console" ] || mknod -m 600 "$ROOT/dev/console" c 5 1
[ -e "$ROOT/dev/null" ] || mknod -m 666 "$ROOT/dev/null" c 1 3

echo "=== sizes $(date +%T)"
du -sh "$ROOT" "$K" "$ROOT/usr/lib/firmware" "$WORK/vmlinuz"
du -sh "$ROOT"/usr/* 2>/dev/null | sort -h | tail -5
echo "kernel version: $KVER"
echo "=== rootfs done $(date +%T)"
