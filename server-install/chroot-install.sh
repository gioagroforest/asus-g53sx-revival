#!/bin/bash
# Runs INSIDE the new Ubuntu 22.04 system on the SSD (chroot), started by hand from the diag
# stick (docs/server-setup.md, step 7). Usage: chroot-install.sh <root-UUID> <ssd-by-id-path>
# Installs kernel, SSH, network, safety guards. Does not touch any other disk.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C
ROOT_UUID="$1"
SSD_DEV="$2"

echo "== sources"
cat > /etc/apt/sources.list <<'EOF'
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
# no services start inside the chroot
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; chmod +x /usr/sbin/policy-rc.d

echo "== apt update / upgrade"
apt-get update -q
apt-get -y -q dist-upgrade

echo "== preseed grub-pc (device installed by hand below)"
echo "grub-pc grub-pc/install_devices multiselect" | debconf-set-selections
echo "grub-pc grub-pc/install_devices_empty boolean true" | debconf-set-selections

echo "== packages"
apt-get -y -q install --no-install-recommends \
  ubuntu-minimal linux-generic grub-pc initramfs-tools \
  openssh-server systemd-timesyncd netplan.io ethtool \
  smartmontools lm-sensors hdparm pciutils usbutils \
  nano less vim-tiny curl ca-certificates bash-completion htop \
  iputils-ping unattended-upgrades locales tzdata

echo "== hostname, time zone, locale"
echo g53 > /etc/hostname
printf '127.0.0.1 localhost\n127.0.1.1 g53\n::1 localhost ip6-localhost ip6-loopback\n' > /etc/hosts
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime; echo Etc/UTC > /etc/timezone
locale-gen en_US.UTF-8 >/dev/null; echo 'LANG=en_US.UTF-8' > /etc/default/locale

echo "== fstab + 4 GB swap file"
cat > /etc/fstab <<EOF
UUID=$ROOT_UUID  /  ext4  defaults,noatime,errors=remount-ro  0 1
/swapfile  none  swap  sw  0 0
EOF
fallocate -l 4G /swapfile; chmod 600 /swapfile; mkswap /swapfile >/dev/null

echo "== network: match the ASUS Ethernet MAC, DHCP with MAC client id, WOL on"
rm -f /etc/netplan/*.yaml
cat > /etc/netplan/01-g53.yaml <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    lan:
      match:
        macaddress: "aa:bb:cc:dd:ee:ff"
      set-name: eth0
      dhcp4: true
      dhcp-identifier: mac
      addresses: [10.53.53.53/24]
      wakeonlan: true
EOF
chmod 600 /etc/netplan/01-g53.yaml
# second WOL arm, in case the .link file is ignored.
# Updated after the install: the first version only ran ethtool, and Wake-on-LAN then failed after
# an Ubuntu shutdown until the NIC's PCIe root port was allowed to wake too (docs/server-setup.md).
cat > /etc/systemd/system/g53-wol.service <<'EOF'
[Unit]
Description=Arm Wake-on-LAN (magic packet) on eth0
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
# card + the PCIe root port above it (RP06, 00:1c.5) must both be allowed to wake the machine
ExecStart=/bin/sh -c "for d in /sys/class/net/eth0/device /sys/class/net/eth0/device/..; do echo enabled > $d/power/wakeup; done"
ExecStart=/usr/sbin/ethtool -s eth0 wol g
ExecStop=/bin/sh -c "for d in /sys/class/net/eth0/device /sys/class/net/eth0/device/..; do echo enabled > $d/power/wakeup; done"
ExecStop=/usr/sbin/ethtool -s eth0 wol g
[Install]
WantedBy=multi-user.target
EOF
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf.new

echo "== SSH: key only"
mkdir -p /root/.ssh; chmod 700 /root/.ssh
cp /tmp/g53/authorized_keys /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/10-g53.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
# same host identity as the diag stick, so the PC's known_hosts keeps working
cp /tmp/g53/ssh_host_* /etc/ssh/; chmod 600 /etc/ssh/ssh_host_*_key; chmod 644 /etc/ssh/ssh_host_*_key.pub

echo "== console root password (for HDMI + keyboard only; SSH stays key-only)"
echo "root:$(cat /tmp/g53/rootpw)" | chpasswd

echo "== safety guards for the unattended first boot"
# 1) hardware watchdog: reboot if the system hangs
mkdir -p /etc/systemd/system.conf.d
printf '[Manager]\nRuntimeWatchdogSec=2min\n' > /etc/systemd/system.conf.d/10-watchdog.conf
# 2) if nobody confirms SSH within 12 minutes, reboot (the stick then boots diag)
touch /etc/g53-unconfirmed
cat > /etc/systemd/system/g53-firstboot-guard.service <<'EOF'
[Unit]
Description=Reboot if the first boot was never confirmed over SSH
ConditionPathExists=/etc/g53-unconfirmed
[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl reboot
EOF
cat > /etc/systemd/system/g53-firstboot-guard.timer <<'EOF'
[Unit]
Description=First-boot guard timer
ConditionPathExists=/etc/g53-unconfirmed
[Timer]
OnBootSec=12min
[Install]
WantedBy=timers.target
EOF
systemctl enable g53-wol.service g53-firstboot-guard.timer systemd-networkd systemd-resolved systemd-timesyncd ssh >/dev/null

echo "== kernel options + GRUB on the SSD itself"
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=""/; s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="panic=10 nomodeset consoleblank=0"/; s/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/; s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
echo "grub-probe says: $(grub-probe -t fs /)"
grub-install --target=i386-pc "$SSD_DEV"
update-grub 2>&1 | tail -3
update-initramfs -u -k all 2>&1 | tail -1

rm -f /usr/sbin/policy-rc.d
mv -f /etc/resolv.conf.new /etc/resolv.conf
echo "== result"
ls -l /boot/vmlinuz /boot/initrd.img
dpkg -l linux-image-generic openssh-server grub-pc | awk '/^ii/{print $2, $3}'
apt-cache policy linux-modules-nvidia-390-generic 2>/dev/null | sed -n 1,3p
echo CHROOT_OK
