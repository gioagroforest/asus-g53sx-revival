# Server setup: Ubuntu 22.04 on a G53SX with no internal screen

**Result:** a headless Ubuntu 22.04.5 server with these parts:

| Part | Setup |
|---|---|
| Kernel | 5.15.0-203 |
| System disk | the 120 GB SSD |
| Data disk | the 1 TB HDD, mounted at `/srv/data` |
| Login | SSH, key only |
| Power-on | Wake-on-LAN |
| Recovery boot | the diagnostic USB stick, still available as a fallback |

Every placeholder in the config files (`aa:bb:cc:dd:ee:ff`, `192.168.0.x`, `ROOT-FS-UUID`, `DATA-FS-UUID`) has to be
replaced with your own values.

## Why Ubuntu 22.04 and not 24.04 or Debian 12

The GTX 560M is a **Fermi** GPU (GF116, compute capability 2.1). NVIDIA's last driver for Fermi is **390.xx**. Of the
current distributions, only **Ubuntu 22.04 (jammy)** still packages it, including prebuilt kernel modules
(`linux-modules-nvidia-390-generic`). Debian 12 and Ubuntu 24.04 don't.

If you will never use the NVIDIA driver, any current distro works.

## How it was installed (no screen, no installer)

The laptop already booted the diagnostic stick and accepted SSH, so the install was done from there by hand, with no
ISO installer. The steps below were run as individual commands over SSH. This is a reconstruction, not one script.

1. **Set the clock first.** A CMOS clear leaves the RTC in 2011, and then `apt` rejects every signature. From the PC:
   `ssh root@ASUS "date -u -s '$(date -u +'%Y-%m-%d %H:%M:%S')'"`.
2. **Get the base system:** `ubuntu-base-22.04.5-base-amd64.tar.gz` from `cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/`.
   Check `SHA256SUMS.gpg` with the Ubuntu CD image key `843938DF228D22F7B3742BC0D94AA3F0EFE21092`, then check the
   tarball's SHA-256.
3. **Partition the SSD:** MBR with one Linux partition. Pick the disk by `/dev/disk/by-id/`, never by `sdX`, because
   the `sdX` letters changed between boots on this laptop.
4. **Format for jammy:** `mkfs.ext4 -L g53root -O ^metadata_csum_seed,^orphan_file /dev/disk/by-id/<ssd>-part1`. The
   diag stick's newer e2fsprogs turns those features on by default, and jammy's GRUB and e2fsck don't understand them.
5. **Unpack:** stream the tarball over SSH into the mounted partition: `ssh root@ASUS 'tar xzpf - -C /mnt/root' < ubuntu-base-…tar.gz`.
6. **Prepare the chroot:**
   - bind-mount `/dev`, `/dev/pts`, `/proc`, `/sys` and `/run`;
   - copy your SSH public key to `/tmp/g53/authorized_keys`;
   - copy the running diag stick's SSH host keys (`/etc/ssh/ssh_host_*`) to `/tmp/g53/`. The script requires them,
     and they keep the PC's `known_hosts` entry valid;
   - put a console password in `/tmp/g53/rootpw`;
   - write a working `resolv.conf`.
7. **Run [`server-install/chroot-install.sh`](../server-install/chroot-install.sh)** `<root-UUID> <ssd-by-id-path>` inside
   the chroot. It installs:
   - the kernel, GRUB, `openssh-server` (key-only), netplan (DHCP + WOL), and `smartmontools`, `lm-sensors` and `htop`;
   - a 4 GB swap file and a systemd watchdog;
   - a first-boot guard that reboots if nobody confirms SSH within 12 min. This was removed once the server was proven.
8. **First boot through the stick:** [`server-install/stick-grub.cfg`](../server-install/stick-grub.cfg) replaces the
   stick's `grub.cfg`. Flags in the stick's `grubenv` choose what boots:

   | Flag | Boots |
   |---|---|
   | `g53_next=ssd` | the SSD, once |
   | `g53_boot=ssd` | the SSD, every time |
   | `g53_next=diag` | the diag system, once |

   If the SSD entry fails, the fallback is the diag system.
9. **Once it booted from the SSD:**
   - ran `update-grub` again on the live system. In the chroot, with no udev, it had written `root=/dev/sdc1`, which is
     fragile; on the live system it writes `root=UUID=…`;
   - installed `dbus` (without it `timedatectl` fails) and `fdisk`.
10. **HDD as a data disk:** wiped, MBR, `ext4` labelled `g53data`, mounted at `/srv/data` with
    `nofail,x-systemd.device-timeout=20s`, so a dead HDD can't stop the boot (see [`server-tools/etc/fstab`](../server-tools/etc/fstab)).
11. **GRUB on both disks:** `dpkg-reconfigure grub-pc`, selecting both `/dev/disk/by-id/` disks. Then `GRUB_DEFAULT=saved`.

## Problems hit, and the fixes

| Symptom | Real cause | Fix |
|---|---|---|
| After the first reboot: blinking cursor top-left, no network | BIOS boot order was **HDD, SSD, stick**, and the HDD still had old Windows boot code that hung | GRUB on both disks, so the boot order no longer matters. The order is visible in the **Esc boot menu**, which shows on HDMI; Setup doesn't |
| Wake-on-LAN failed after an Ubuntu shutdown (it had worked from the diag stick) | `/proc/acpi/wakeup`: `GLAN` (the NIC, 05:00.0) enabled, but its PCIe root port **`RP06` (00:1c.5) disabled** | [`g53-wol.service`](../server-tools/etc/systemd/system/g53-wol.service) writes `enabled` to `power/wakeup` of the NIC **and its parent port**, then runs `ethtool -s eth0 wol g`, on both start and stop. Tested: off → magic packet → answering in 31 s. `chroot-install.sh` now writes this version; the original install wrote an `ethtool`-only unit. A second `GLAN` line in `/proc/acpi/wakeup`, with no PCI device, stays `disabled` and doesn't matter |
| Remote wake "timed out" from a phone | The phone was on mobile data. `192.168.x.x` addresses only exist inside the home network | Wake from a device on the home network, or set up a VPN such as Tailscale or WireGuard into the LAN |
| `apt` signature errors | RTC in 2011 after the CMOS clear | Set the clock (step 1), then `hwclock -w` once time sync works |
| `mkswap -q` unknown option | jammy's `mkswap` has no `-q` | `mkswap /swapfile >/dev/null` |
| `sshd -t` fails in the chroot | no `/run/sshd` | `mkdir -p /run/sshd` first |
| Diag stick: `reboot` not found, or a reboot started over SSH dies with the session | busybox only, and the job gets killed with the SSH session | `setsid nohup sh -c 'sleep 3; busybox reboot -f' >/dev/null 2>&1 &` |

## Files from the running server

[`server-tools/`](../server-tools) mirrors the server's paths:

| File | Purpose |
|---|---|
| `etc/systemd/system/g53-wol.service` | arms Wake-on-LAN each boot and shutdown, including the root-port fix |
| `etc/netplan/01-g53.yaml` | matches the NIC by MAC and renames it `eth0`. DHCP with the MAC as client ID, a fixed fallback `10.53.53.53/24` for a direct cable, `wakeonlan: true` |
| `etc/grub.d/40_custom` | a GRUB entry that boots the diag stick: `grub-reboot g53diag && systemctl reboot` |
| `etc/default/grub` | `GRUB_DEFAULT=saved`, `panic=10 nomodeset consoleblank=0` |
| `etc/systemd/system.conf.d/10-watchdog.conf` | hardware watchdog, 2 min |
| `etc/ssh/sshd_config.d/10-g53.conf` | root by key only, no passwords over the network |
| `etc/fstab` | root by UUID, swap file, the HDD with `nofail` |
| `root/cpubench.sh` | sysbench + 7-Zip benchmark that stops itself if the CPU reaches 92 °C. Needs `apt install sysbench p7zip-full` |

## Recommended, not yet done

- **Ignore the lid switch.** The lid sensor reads "open" now, but Ubuntu suspends on "closed" by default. A damaged lid
  or a stuck Hall sensor would then put the server to sleep. Add
  `/etc/systemd/logind.conf.d/lid.conf`, containing `[Login]`, `HandleLidSwitch=ignore`,
  `HandleLidSwitchExternalPower=ignore` and `HandleLidSwitchDocked=ignore`.
- A normal user with `sudo`, for daily use instead of root.
- Check the `unattended-upgrades` settings.
- Remove `nomodeset` once the NVIDIA driver is in, if a console on HDMI is wanted.

## GPU: NVIDIA 390 driver (pending)

The prebuilt, signed modules avoid DKMS compiling, which is the most common way NVIDIA installs break. The packages
were checked on kernel 5.15.0-203 and install with no removals:

```bash
apt update
apt install nvidia-headless-no-dkms-390 nvidia-utils-390 linux-modules-nvidia-390-generic clinfo clpeak
printf 'blacklist nouveau\noptions nouveau modeset=0\n' > /etc/modprobe.d/blacklist-nouveau.conf
update-initramfs -u
reboot
# after reboot
nvidia-smi
clinfo -l
clpeak            # OpenCL compute and memory bandwidth benchmark
```

**What to expect for AI:**

- **CUDA:** the newest CUDA toolkit that supports Fermi is **8.0** (2016). Current PyTorch, TensorFlow and llama.cpp
  CUDA builds don't support it.
- **What does work:** OpenCL 1.1 compute, benchmarks and learning.
- **Hardware:** 192 CUDA cores, 2 GB GDDR5, about 590 GFLOPS FP32 on paper.
- **For small language models, the CPU is the realistic path:** llama.cpp runs 1–3 B parameter models on the
  i7-2670QM with its 16 GB of RAM. The CPU has AVX but no AVX2 or FMA, so expect a few tokens per second.
