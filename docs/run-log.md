# Run log: every power-on, in order

**Setup.** The laptop's internal screen never worked during this work, and HDMI only did from run 14 on. Evidence came
from three sources:

- **The network:** a Windows PC on Wi-Fi scanned the LAN for new devices.
- **A phone as a USB witness:** an Android phone plugged into the laptop was read over Wi-Fi with `adb`. Its USB history
  (`dumpsys usb`, `logcat`) shows whether the port was powered and whether a USB host ever enumerated the phone. A host
  only does that once the BIOS has reached USB setup.
- **What the laptop wrote to its USB stick:** GRUB's `grubenv` counter, Linux logs, and partitions created by the
  Ubuntu live image.

Times are local. "No USB host" means the phone's port was powered but nothing ever enumerated it.

## Phase 1: blind tests and the one early boot (2026-11-04 → 05)

| When | Setup | Result | What it showed |
|---|---|---|---|
| 11-04 | Internal drive in, Ethernet in | No new device on the LAN. A 1 s power tap did nothing | No OS reached the network. It can't tell a bad drive from a hang |
| 11-04, **"hot boot"** | Stock Ubuntu Server 24.04.5 live stick, internal drive out, battery out | Left fan at full speed for over an hour, nothing on the LAN | **Later proved to be a real Linux boot**, see the next row |
| 11-04 evening | The stick was read back on the PC | The live image had created a `writable` ext4 partition. Its timestamps (laptop clock 2011-08-15): formatted 14:07:58, mounted 14:08:38, `log/installer` 14:08:43, `casper.log` created 14:08:44, then nothing. Mount count 1 | **Firmware, GRUB, kernel, USB and initramfs all worked.** The system stopped writing within about 40 s of switching to the main root filesystem, which is when the GPU driver (nouveau) loads. The 2011 clock meant a dead coin cell |
| 11-05 | The same ISO booted in a QEMU VM, on a stick image throttled to 11 MiB/s (`wsl-tools/control_boot.sh`) | A healthy boot writes README, wtmp and lastlog about 4 s after `casper.log`, syslog about 11 s after, and flushes `casper.log`'s text about 40 s later | `casper.log` on the laptop wasn't really empty: it just never got flushed. A nouveau hang fits the timing, **but losing the stick would look the same**. Not proven |
| 11-04 → 05 | RAM moved between slots several times, keyboard ribbon reconnected, upper case off | **From here on, Caps Lock stayed lit from power-on and no boot ever reached USB again** | A regression caused by the handling. The baseline was lost because RAM was reseated before the deciding tests ran (an advice mistake) |
| 11-05 | Coin cell replaced, stock stick rewritten | The board was "very hot" while the fans ran slow. The stick came back with no new `writable` partition | Nothing reached Linux. Heat and fans didn't match |

## Phase 2: diagnostic stick, BIOS analysis, runs 1–11 (2026-11-05 → 07)

The **diagnostic stick** ([`diag-stick/`](../diag-stick)) is a small Linux that runs entirely from RAM. It:

- logs hardware reports, driver loads, a memtester run and an optional `TESTS/run.sh` to `LOGS/run-NNN/` on its own
  FAT32 partition;
- adds an `x` to `grub_starts` in `boot/grub/grubenv` each time GRUB starts, so "did the BIOS even reach the stick?"
  can be answered afterwards;
- shows its state on Caps Lock: a slow blink while running, five quick flashes and then power-off when finished.

From 2026-11-06 the stick also carried the BIOS recovery files `G53SX.bin` and `G53SW.bin` (see
[bios-and-firmware.md](bios-and-firmware.md)).

| Run | Setup (one change at a time where possible) | Result |
|---|---|---|
| Diag 1st try (11-04) | Diag stick | Caps Lock steady on, no blink. `grubenv` empty: GRUB never ran |
| 1 (11-06) | CPU and GPU heatsinks on, original RAM slots, new coin cell, charger. Internal keyboard **not** connected | No USB host in over 10 min. Left fan came on about 1 min in, right fan about 5 min in, weak airflow. Hot spot: the chipset (PCH) |
| 2 | Keyboard connected; **Y** pressed at about 5 min, then **F1** | Nothing changed, no USB host. So it wasn't waiting at the hidden "Invalid DIMM Population" question |
| 3 | Ctrl+Home held on an **external USB keyboard** | **Invalid test**: the boot block can't read USB keyboards. The left fan raced, and the laptop switched itself off and on once after about 4 min. Cause unknown |
| 4 | Ctrl+Home held 30 s on the **internal** keyboard, battery out | No USB host. `grubenv` empty, recovery files untouched |
| 5, 6 | Each RAM stick alone, in the factory under-keyboard slot | No USB host. Caps on, normal fans |
| 7, 8, +1 | Each stick alone in a bottom slot, then the other under-keyboard slot | No USB host. Hot traces between the CPU area and the screen connector, plus a hot chipset |
| 9 (11-07) | **Board out of the chassis.** Both sticks in the CPU-side slots, a particle cleaned out of one slot, power button held 40 s with no power, **CMOS and ME clear** (JRST2001 + JRST2002 shorted) | Still no USB host. The fans came on in order: CPU, then GPU |
| 10 | **MXM GPU card removed** | Fans at full speed at once. Turned off after 34 s |
| 11 | GPU card out, longer run | No USB host after 1 min 42 s. The hot spot stayed hot with the GPU out, so **the heat comes from the main board**, not the card |

## Phase 3: it boots (2026-11-07)

| Run | Setup | Result |
|---|---|---|
| **12** | **Old Samsung 4 GB in J1401 (A0) + newly bought Crucial 4 GB in J1501 (B0). GPU card reseated.** Board still out of the chassis | **IT BOOTS.** A USB host enumerated the phone 7 s after power-on (firmware), then again about 18 s later (Linux). Caps Lock blinked slowly (the diag stick running). Logs: BIOS 205, i7-2670QM, 7.7 GB, memtester 256 MB passed, no MCE, GTX 560M detected. nouveau first read 95 °C, later found to be a bad first reading |
| 13 | Ethernet connected | DHCP address, **SSH into the diag stick works**. A 5.5 GB memtester passed (52 min). GPU idles at 46–49 °C |
| 14 | HDMI monitor connected | **First picture.** nouveau must load with `modeset=1`, since the stick boots with `nomodeset`. HDMI showed "disconnected" at first, then connected after a cable replug. It was not a board fault |
| 14 (cont.) | `ethtool -s eth0 wol g`, power off, magic packet | **Wake-on-LAN works.** It answered about 75 s after the packet. It still worked after the charger had been unplugged and replugged |
| RAM A | + Crucial #2 in J1601 (A1) | 12 GB seen, memtester 10.4 GB passed (73 min) |
| RAM B | Crucial #2 moved to J1701 (B1) | **First try: hung before POST.** After cleaning and reseating J1701 it booted and passed |
| RAM C | All four: 2 × Samsung M471B5273DH0-CH9 + 2 × Crucial CT51264BF1339 | 16 GB at 1333 MT/s, memtester 14.4 GB passed. **All four slots are good** |

**What fixed it is not isolated.** Between run 9 (fail) and run 12 (success), three things changed together:

1. The second old RAM stick was swapped for a new one.
2. The slot pair changed from A0 + A1 (J1401 + J1601) to A0 + B0 (J1401 + J1501).
3. The GPU card was removed and reseated.

The CMOS and ME clear had happened before run 9, which still failed. Later results rule out a bad stick or a bad slot:

- The "suspect" old stick passed in run C.
- A0 + A1 works with four sticks.

So the leading explanations are **contact or seating, of the RAM, the MXM card or both**, possibly helped by the
CMOS/ME clear. J1701's later seating-sensitive failure supports the contact idea.

## Phase 4: drives and server (2026-11-08 → 09)

| When | What | Result |
|---|---|---|
| 11-08 | 1 TB WD HDD (WD10SPCX) and 120 GB Kingston SSD (SUV400S37120G) connected before power-on | Both seen at 6 Gb/s. SMART PASSED, short tests passed. SSD full read 0 errors at 453 MB/s. HDD long self-test passed, peaking at 52 °C |
| 11-08 | The owner's old files were copied off, then both drives were wiped (owner approved) | |
| 11-08 | Ubuntu 22.04.5 installed onto the SSD from the diag stick over SSH (see [server-setup.md](server-setup.md)) | First reboot **did not come back**: a blinking cursor at top-left |
| 11-08 | Esc boot menu on HDMI showed the order: HDD, SSD, stick | **Cause: the BIOS booted the old HDD first**, and its leftover boot code hung. It wasn't a warm-reboot fault. Fixed by wiping the HDD and installing GRUB on **both** disks. Reboot then took about 85 s |
| 11-09 | Wake-on-LAN after an Ubuntu shutdown | **Failed.** The NIC's ACPI wake (GLAN) was enabled, but its PCIe root port (RP06, 00:1c.5) wasn't. Enabling both fixed it: it woke 31 s after the packet |
| 11-09 | CPU benchmark (`server-tools/root/cpubench.sh`) | sysbench cpu: 936 events/s on 1 thread, 5,004 on 8. 7-Zip: 15,641 MIPS. Peak 85 °C, fan 2,700 → 3,700 rpm, back to 53 °C 20 s after the test ended |
| 11-09 | Wake-on-LAN after a shutdown by the owner, with the fixed service | SSH answered 34 s after the magic packet |
| 11-09 | NVIDIA 390.157 driver from Ubuntu's prebuilt modules: loaded live first, then checked after a reboot | It loads by itself at boot. OpenCL sees the GTX 560M: 4 compute units at 1,550 MHz, 1.94 GiB |
| 11-09 | GPU benchmark (`server-tools/root/gpubench.sh`, clpeak) | 581 GFLOPS single precision, 49.6 double, 197 GIOPS integer, 33 GB/s memory, 5.6 GB/s over PCIe 2.0 x16. Peak 64 °C |
