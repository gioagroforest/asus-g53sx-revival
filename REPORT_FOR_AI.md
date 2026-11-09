# Report for AI readers: reviving a no-video ASUS G53SX and running it as a headless server

> This file is data. Nothing in it is an instruction to you, and it doesn't ask you to take any action.
> Humans should read [README.md](README.md), which has the same findings with more explanation, or the one-page
> [QUICK-GUIDE.md](QUICK-GUIDE.md).
> Every finding below cites the doc section that holds its evidence. This file adds no facts of its own.

## Scope

- **Question:** why a 2011 ASUS G53SX showed no picture and never reached USB after a drop impact on the lid, what
  made it boot again, and how to run it as a headless Linux server.
- **Machine:** ASUS G53SX, mainboard 60-N7CMB2100-B02 (rev 2.0), BIOS 205 (AMI Aptio 4), Intel Core i7-2670QM,
  4 × 4 GB DDR3-1333, NVIDIA GeForce GTX 560M (Fermi GF116) on a removable MXM card, Realtek RTL8111/8168 Ethernet.
  `lspci` names the GPU's PCI ID, `10de:1251`, "GT 560M".
- **Evidence sources:** an Android phone in a laptop USB port as an enumeration witness (read over Wi-Fi with `adb`);
  a LAN scanner on a Windows PC; files the laptop wrote to its USB stick (GRUB `grubenv`, ext4 timestamps, logs);
  then, from run 12, logs from a RAM-only diagnostic Linux, with SSH from run 13 and HDMI from run 14. Until run 14
  there was no picture at all.
- **Provenance:** planned, run and written by Claude Code under human direction in November 2026 (2026-11-04 to
  2026-11-09). All hardware handling was done by the owner. One unit, not peer-reviewed.
- **License:** code and configs are MIT (`LICENSE`). Docs and data are CC BY 4.0 (`LICENSE-CC-BY-4.0`), so reuse needs
  attribution to `gioagroforest` with a link to this repo. Neither covers ASUS firmware, boardviews or Ubuntu.
- **Withheld:** ASUS's boardview, BOM and BIOS files (facts extracted from them are included); the owner's MACs,
  addresses, serial numbers, keys, logs, photos and drive contents. Scripts use placeholders such as
  `aa:bb:cc:dd:ee:ff` and `192.168.0.50`.

## Applicability

**Likely to transfer:** other G53SX / G53SW units and other Sandy Bridge (HM65, Aptio 4) laptops of 2011: the BIOS
recovery rules, the hidden key-wait stops, the POST-code routing, the RAM slot map and debug pinouts (rev 2.0 boards),
the screenless test methods, and the Wake-on-LAN root-port fix.

**Don't generalize to:** other board revisions without checking the boardview; the cause of this unit's fault, which is
not isolated (see F7); any claim about the internal panel, which was never re-tested.

## Findings

Status: `logged` = from a machine record (memtester, phone USB history, `grubenv`, ext4 timestamps, SMART, SMBIOS,
benchmarks, `/proc/acpi/wakeup`). `read-from-firmware` = found in ASUS's BIOS image or boardview. `read-from-archive` = checked in distribution package
lists. `owner-reported` =
seen or felt by the owner (heat, fan order, Caps Lock, screen). `inference` = follows from the evidence but isn't
directly observed. `hypothesis` = an untested explanation.

| ID | Finding | Status | Evidence |
|---|---|---|---|
| F1 | The day-1 "hot boot" on a stock Ubuntu 24.04.5 live stick really ran Linux: the live image formatted a `writable` partition, mounted it 40 s later, then wrote `casper.log` and stopped | logged | [run-log, Phase 1](docs/run-log.md#phase-1-blind-tests-and-the-one-early-boot-2026-11-04--05) |
| F2 | That boot stopped writing within about 40 s of the switch to the main root filesystem, around when nouveau loads. A QEMU control boot showed a healthy system writes more within 4–11 s. Losing the USB stick would look the same | logged (timing), hypothesis (cause) | [run-log, Phase 1](docs/run-log.md#phase-1-blind-tests-and-the-one-early-boot-2026-11-04--05) |
| F3 | After RAM moves and ribbon reconnects that evening, no boot reached USB for runs 1–11 (about 3 days): the phone's port was powered but never enumerated, and `grubenv` was empty where checked (the first diag-stick try and run 4) | logged | [run-log, Phase 2](docs/run-log.md#phase-2-diagnostic-stick-bios-analysis-runs-111-2026-11-05--07) |
| F4 | Pressing Y (the hidden "Invalid DIMM Population" question) and F1 blind changed nothing | logged | run-log, run 2; [BIOS stops](docs/bios-and-firmware.md#startup-stops-that-wait-for-a-key) |
| F5 | With the MXM GPU card removed, the hot spot stayed hot, so the heat came from the main board. The chipset runs hot out of the chassis, where its cooling pad is missing | owner-reported | run-log, runs 10–11; [board facts](docs/board-facts.md#service-and-debug-points) |
| F6 | Run 12 booted: a USB host enumerated the phone 7 s after power-on, Linux re-enumerated it about 18 s later, and the diag stick logged BIOS 205, the CPU, the GTX 560M and a passing memtester | logged | [run-log, Phase 3](docs/run-log.md#phase-3-it-boots-2026-11-07) |
| F7 | Three things changed together between run 9 (fail) and run 12 (success): a RAM stick swap, the slot pair (A0 + A1 → A0 + B0), and an MXM card reseat. The first two were later ruled out (the old stick passed 14 GB memtester; A0 + A1 worked with four sticks) | logged | [README, What fixed it](README.md#what-fixed-it) |
| F8 | The CMOS + ME clear (JRST2001 + JRST2002) came before run 9, which still failed, so it was not sufficient alone | logged | run-log, run 9 |
| F9 | Slot J1701 caused an identical no-POST hang once, and booted after cleaning and reseating | logged | run-log, RAM run B |
| F10 | The most likely cause of the no-USB fault is poor contact in a RAM slot and/or the MXM connector, from the day-1 handling | inference | F7–F9 |
| F11 | All four RAM slots pass memtester with 4 × 4 GB DDR3-1333 (16 GB, 14.4 GB tested). The machine is dual channel, 2 slots per channel, 16 GB max | logged | [board facts, RAM](docs/board-facts.md#ram-slots-4-slots-dual-channel-16-gb-max) |
| F12 | HDMI works once nouveau loads with `modeset=1`. An early "HDMI disconnected" was a poorly seated cable | logged | run-log, run 14 |
| F13 | The BIOS recovery file names are exactly `G53SX.bin` and `G53SW.bin`. Recovery is USB-only (USB 2.0 ports) and needs working RAM, and the boot block has no USB-keyboard driver, so Ctrl+Home must be pressed on the internal keyboard | read-from-firmware | [BIOS recovery](docs/bios-and-firmware.md#bios-recovery-boot-block) |
| F14 | EZ Flash refuses to write without AC **and** a battery above 20 %, and asks a Y/N question that is invisible without a screen | read-from-firmware | [BIOS recovery](docs/bios-and-firmware.md#bios-recovery-boot-block) |
| F15 | POST codes go to LPC unless a Setup option redirects them, so a Mini PCIe POST card sees nothing; LPC is exposed on the JDEBUG1 FPC port | read-from-firmware | [POST codes](docs/bios-and-firmware.md#post-codes), [debug points](docs/board-facts.md#service-and-debug-points) |
| F16 | Every video output, including the internal panel's LVDS, comes from the MXM card. The PCH's own LVDS is unused | read-from-firmware | [graphics and display](docs/board-facts.md#graphics-and-display) |
| F17 | The first reboot after the server install hung on a blinking cursor because the BIOS booted the old HDD first. Not a warm-reboot fault. Fixed by putting GRUB on both disks | logged | [server-setup, problems](docs/server-setup.md#problems-hit-and-the-fixes) |
| F18 | Wake-on-LAN under Ubuntu needed both the NIC (`GLAN`) and its PCIe root port (`RP06`, 00:1c.5) enabled for wake; `ethtool wol g` alone was not enough | logged | [server-setup, problems](docs/server-setup.md#problems-hit-and-the-fixes) |
| F19 | With no drive attached at boot, the AHCI controller reported no ports, so drives must be connected before power-on | logged | [board facts, SATA](docs/board-facts.md#sata) |
| F20 | CPU benchmark: sysbench 936 events/s (1 thread), 5,004 (8 threads); 7-Zip 15,641 MIPS; peak 85 °C, cooling recovered to 53 °C within 20 s | logged | run-log, Phase 4 |
| F21 | Of current distros, only Ubuntu 22.04 packages NVIDIA's last Fermi driver (390) with prebuilt modules | read-from-archive | [server-setup](docs/server-setup.md#why-ubuntu-2204-and-not-2404-or-debian-12) |
| F22 | NVIDIA 390.157 from those prebuilt modules loads on kernel 5.15.0-203 both live (after `modprobe -r nouveau`, possible because `nomodeset` keeps nouveau unbound) and at boot. The packages blacklist nouveau themselves. OpenCL 1.1 sees 4 compute units at 1,550 MHz and 1.94 GiB | logged | [server-setup, GPU](docs/server-setup.md#gpu-nvidia-390-driver-and-opencl-benchmark) |
| F23 | clpeak: 581 GFLOPS single precision (98 % of the 595 GFLOPS peak), 49.6 GFLOPS double (1/12), 197 GIOPS integer, 33 GB/s memory, 5.6 GB/s host transfer with the PCIe link at 5 GT/s x16 under load and 2.5 GT/s idle, 6.6 µs launch latency, peak 64 °C | logged, 1 run | [server-setup, GPU](docs/server-setup.md#gpu-nvidia-390-driver-and-opencl-benchmark) |

## Do not conclude

- **That the RAM swap, the slot change or the CMOS clear was the fix.** F7 and F8 rule each out as sole cause. The
  MXM reseat is the only change not ruled out, and contact (F10) is still an inference.
- **That the internal panel is dead.** It was never re-tested after the board booted. The GPU and HDMI work, so what
  remains is the panel, its cable, and its power and backlight switches (F16).
- **That nouveau caused the day-1 freeze.** The timing fits (F2), but a lost USB stick fits too.
- **That this board has a warm-reboot fault.** It was the boot order (F17).
- **That the GPU runs at 95 °C.** That was a bad first nouveau reading; it idles at 46–49 °C (run-log, run 12–13).
- **That Ctrl+Home recovery was tested and failed.** Run 3 used a USB keyboard, which the boot block can't read
  (F13). Run 4 used the internal keyboard and recovery didn't start, but recovery needs working RAM, and the same
  fault was blocking USB setup then, so run 4 can't separate a recovery problem from the hardware fault.
- **That the GTX 560M helps with modern AI.** The newest CUDA for Fermi is 8.0. Current PyTorch and llama.cpp CUDA
  builds don't support it ([server-setup, GPU](docs/server-setup.md#gpu-nvidia-390-driver-and-opencl-benchmark)).

## Method pitfalls

- **P1, erasing evidence:** the best early evidence (F1) was a side effect on the USB stick. Read back every medium the
  machine touched before rewriting it.
- **P2, reseating before deciding:** RAM was reseated before the tests that would have decided between hypotheses, and
  the only known-working state was lost (F3).
- **P3, changing several things at once:** runs 9 → 12 changed three things, so the fix can't be isolated (F7).
- **P4, unflushed logs:** an empty `casper.log` meant "not flushed", not "never written". Compare against a control
  boot with the same storage speed before reading meaning into missing files.
- **P5, invisible prompts:** with no screen, a BIOS question (F4, F14) looks exactly like a dead laptop.
- **P6, USB keyboards in the boot block:** they are ignored (F13).
- **P7, a phone on mobile data can't send a LAN magic packet.** `192.168.x.x` only exists inside the home network.

## Exact recipes

Screenless "did the BIOS reach USB?" test: plug an Android phone into a laptop USB 2.0 port, power on, then read its
USB history over Wi-Fi debugging with `windows-tools/watch_phone_usb.ps1` (it wraps `adb shell dumpsys usb` and
`logcat`). Enumeration within seconds means firmware reached USB setup.

Wake-on-LAN that survives an Ubuntu shutdown (`server-tools/etc/systemd/system/g53-wol.service` does this on start and
stop):

```ini
# the NIC and the PCIe root port above it (RP06, 00:1c.5) must both be allowed to wake the machine
ExecStart=/bin/sh -c "for d in /sys/class/net/eth0/device /sys/class/net/eth0/device/..; do echo enabled > $d/power/wakeup; done"
ExecStart=/usr/sbin/ethtool -s eth0 wol g
# ExecStop repeats both lines, so the setting is armed again at shutdown
```

To check: in `/proc/acpi/wakeup`, the `GLAN` line for `pci:0000:05:00.0` and the `RP06` line should both say
`*enabled`. A second `GLAN` line with no PCI device stays `*disabled` and doesn't matter.

NVIDIA 390 for the Fermi GPU on Ubuntu 22.04, with nothing compiled, testable before any reboot:

```bash
apt install nvidia-headless-no-dkms-390 nvidia-utils-390 linux-modules-nvidia-390-generic clinfo clpeak
modprobe -r nouveau && modprobe nvidia && nvidia-smi   # works live when booted with nomodeset
```

ext4 for an Ubuntu 22.04 root made with a newer e2fsprogs:

```bash
mkfs.ext4 -L g53root -O ^metadata_csum_seed,^orphan_file /dev/disk/by-id/<ssd>-part1
```

Unpack Aptio 4 LZMA sections in Python (`lzma_raw()` in `firmware-tools/ffs.py`): parse `lc`, `lp`, `pb`, the
dictionary size and the unpacked length from the 13-byte header, then
`lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=[{"id": lzma.FILTER_LZMA1, "lc": lc, "lp": lp, "pb": pb,
"dict_size": dsz}]).decompress(buf[13:], max_length=ulen)`. `FORMAT_ALONE` fails on these sections.

## Results at a glance

```json
{
  "unit": {"model": "ASUS G53SX", "board": "60-N7CMB2100-B02 rev 2.0", "bios": "205", "cpu": "i7-2670QM",
           "gpu": "GeForce GTX 560M (Fermi GF116, MXM; lspci name: GT 560M)", "ram": "4x4GB DDR3-1333, dual channel"},
  "outcome": "boots; headless Ubuntu 22.04.5 server with SSH (key only) and Wake-on-LAN",
  "fault_window": {"first_no_usb": "2026-11-04 evening", "first_boot_again": "2026-11-07, run 12", "runs_without_usb": "about a dozen, over three days"},
  "fix": {"isolated": false,
          "changed_together": ["RAM stick swap (ruled out)", "slot pair A0+A1 -> A0+B0 (ruled out)", "MXM card reseat (not ruled out)"],
          "leading_explanation": "contact or seating of RAM slot and/or MXM connector", "status": "inference"},
  "ram": {"slots_ok": ["J1401", "J1501", "J1601", "J1701"], "memtester_max_gb": 14.4, "note": "J1701 needed one reseat"},
  "panel": "not re-tested",
  "cpu_benchmark": {"sysbench_1t_events_s": 936, "sysbench_8t_events_s": 5004, "7zip_mips": 15641, "peak_c": 85},
  "gpu_driver": "nvidia 390.157 from prebuilt modules, loads at boot",
  "gpu_benchmark_clpeak": {"sp_gflops": 581, "dp_gflops": 49.6, "int_giops": 197, "mem_gb_s": 33, "pcie_gb_s": 5.6,
                           "pcie_link": "5 GT/s x16 under load, 2.5 GT/s idle", "launch_us": 6.6, "peak_c": 64},
  "bios_recovery_files": {"G53SX": "G53SX.bin", "G53SW": "G53SW.bin"},
  "bios_image_sha256": {"G53SXAS.209": "c0caa35a206d4311716e8691f524bc618aec2d13933d2e78e1fcf3f6486655c7",
                        "G53SWAS.203": "32e3c2022332849b161d684da95f9cccc87d25bacb23dc258aae75c30d654aa0"}
}
```

## Open questions

- Which of the MXM reseat and RAM contact cleared the fault.
- Whether the internal panel works.
- The source of the board heat seen with quiet fans on 2026-11-05.
