# Reviving an ASUS G53SX with no screen, and turning it into a home server

A 2011 ASUS G53SX gaming laptop stopped showing any picture after a heavy charger fell on its lid. A repair shop
couldn't fix it. This repo records how it was diagnosed **without a working screen**, what finally made it boot, and
how it became a headless Ubuntu server you wake over the network. It includes every tool and script used.

*Short version: [QUICK-GUIDE.md](QUICK-GUIDE.md) is one page of what to try, in order.*

*AI agents: [REPORT_FOR_AI.md](REPORT_FOR_AI.md) has the same findings in a structured, citable form.*

## The short answer

- **It works now.** All four RAM sticks (16 GB) pass memtester, both drives are healthy, the GPU drives an HDMI
  monitor, and it runs Ubuntu 22.04 as a server with SSH and Wake-on-LAN.
- **The fault wasn't the screen damage people expected.** From the evening of the first day, the BIOS never got as
  far as USB. It came back after a full strip-down, with these steps:
  - cleaning and reseating the RAM;
  - a CMOS + ME clear;
  - reseating the removable MXM graphics card;
  - fitting the RAM as one stick per channel.

  **Which of these was the actual fix is not known**, because they changed together. Contact or seating is the leading
  explanation. See [What fixed it](#what-fixed-it).
- **The internal panel itself was never re-tested.** The GPU and HDMI output work, so what remains for the panel is the
  panel, its cable and its power and backlight switches ([board facts](docs/board-facts.md#graphics-and-display)).

## The machine

| Part | Details |
|---|---|
| Model | ASUS G53SX, mainboard 60-N7CMB2100-B02 (rev 2.0), BIOS 205 |
| CPU | Intel Core i7-2670QM, 4 cores / 8 threads, 2.2–3.1 GHz, AVX (no AVX2) |
| RAM | 4 × 4 GB DDR3-1333 SO-DIMM, dual channel (2 slots per channel), 16 GB max |
| GPU | NVIDIA GeForce GTX 560M (Fermi GF116, 2 GB GDDR5) on a removable **MXM** card. Its PCI ID is `10de:1251`, which `lspci` names "GT 560M" |
| Disks | 120 GB SATA SSD (system), 1 TB 5400 rpm HDD (data) |
| Network | Realtek RTL8111/8168 Gigabit Ethernet (PCI 10ec:8168, `r8169` driver), Wake-on-LAN capable |

## What happened, in brief

The full timeline is in **[docs/run-log.md](docs/run-log.md)**.

1. **Day 1, blind tests.** The screen, HDMI and VGA were all dark. A stock Ubuntu live USB stick was booted with no way
   to watch it. It turned out that this boot **did** run Linux: Ubuntu had written a small partition to the stick, and
   its timestamps showed Linux stopped writing about 40 seconds in, around when the graphics driver loads. That was the
   most useful clue of the first days, and it came from a side effect, not a planned test.
2. **Day 1 evening, regression.** After RAM sticks were moved between slots and ribbons reconnected, the laptop
   stopped reaching even the USB stage: Caps Lock was stuck on, and no USB device was ever seen. This lasted through
   about a dozen runs over three days.
3. **Tools built to see inside a laptop with no screen:**
   - a **RAM-only diagnostic Linux stick** that logs everything to itself and blinks Caps Lock;
   - a **phone plugged into the laptop's USB port as a witness**: its USB history shows whether the BIOS ever
     enumerated it;
   - a **LAN watcher** on a PC.
4. **BIOS research.** The official BIOS images were unpacked and searched. That revealed the recovery file names,
   that recovery needs the internal keyboard, a battery above 20 % and USB 2.0, the hidden "press Y" RAM question, and
   where the POST codes go ([docs/bios-and-firmware.md](docs/bios-and-firmware.md)).
5. **Boardview research.** It gave the RAM slot map, the CMOS-clear pads, the POST-code debug port, the BIOS chip header
   and the power rails ([docs/board-facts.md](docs/board-facts.md)).
6. **Day 4, it boots** (run 12), with the board out of the chassis. Ethernet then gave SSH access, HDMI gave a picture,
   and Wake-on-LAN worked. RAM tests passed for every slot.
7. **Day 5, server install.** The drives were tested, the old data was saved, and Ubuntu 22.04 went on without a
   screen or installer, from the diag stick over SSH ([docs/server-setup.md](docs/server-setup.md)).
8. **Day 6.** A Wake-on-LAN bug under Ubuntu was fixed, and the CPU was benchmarked.

## What fixed it

Between the last failure (run 9) and the first success (run 12), three things changed **at the same time**:

| Change | Ruled out later? |
|---|---|
| The second original RAM stick was swapped for a newly bought one | **Yes**: that original stick later passed a 14 GB memtester |
| The RAM slot pair went from A0 + A1 (same channel) to A0 + B0 (one per channel) | **Yes**: A0 + A1 later worked with all four sticks |
| The MXM graphics card was taken out (runs 10–11) and reseated | Not ruled out |

The CMOS + ME clear (shorting JRST2001 and JRST2002) came **before** run 9, which still failed, so it wasn't enough on
its own.

Later, one RAM slot (J1701) caused an identical no-POST until it was cleaned and reseated. So the most likely story is
**poor contact in a RAM slot and/or the MXM connector**. It started with the handling on day 1 and was cleared by the
full strip-down and reseat. That is an inference, not a proven cause.

## Practical lessons for a laptop with no screen

- **Check every medium the machine touched before erasing it.** The best early evidence came from what Ubuntu had
  written to the USB stick, not from any planned test.
- **Change one thing per power-on, and don't reseat parts before running the tests that decide something.** An early
  reseat here destroyed the only known-working state.
- **A phone is a cheap USB witness.** If no USB host ever enumerates the phone, the BIOS never got as far as USB setup.
  Its history can be read later over Wi-Fi with `adb`
  ([`windows-tools/watch_phone_usb.ps1`](windows-tools/watch_phone_usb.ps1)). Remember to restart the phone afterwards
  so Wireless debugging closes.
- **Ctrl+Home BIOS recovery needs the internal keyboard.** The boot block can't read USB keyboards.
- **Connect SATA drives before power-on.** Otherwise the controller reports no ports.
- **Hot chips on a board out of its case aren't automatically a fault.** The chipset relies on a pad touching the
  case for cooling.
- **On this BIOS, the Esc boot menu shows on HDMI but Setup doesn't.** Use the boot menu to see the boot order.
- **Put the bootloader on every disk** of a headless machine, so a wrong boot order can't strand it.
- **Wake-on-LAN needs the NIC's PCIe root port to allow wake too.** Check `/proc/acpi/wakeup`, not only `ethtool`.

## Things we got wrong first

These corrections are kept on purpose. They are the likeliest traps for the next person.

| First conclusion | What it really was |
|---|---|
| "Linux froze: `casper.log` is empty" | It was never flushed to disk. Losing the USB stick would have looked the same |
| "The Ethernet has no link" | The report was ambiguous. Link state was unknown |
| "The HDMI hot-plug circuit is faulty" | The cable wasn't fully seated. A replug fixed it |
| "The GPU runs at 95 °C" | A bad first reading. It idles at 46–49 °C |
| "Ctrl+Home recovery was tried" | It was pressed on a USB keyboard, which the recovery code can't read |
| "The laptop can't warm-reboot" | The BIOS was booting the old HDD first, which hung |
| "Wake-on-LAN works" (from the diag stick) | Under Ubuntu it needed the PCIe root port's wake enabled as well |

## What's in this repo

| Folder | Contents |
|---|---|
| [`docs/`](docs) | [run log](docs/run-log.md), [board facts](docs/board-facts.md) + [board map](docs/board-map.png), [BIOS and firmware](docs/bios-and-firmware.md), [server setup](docs/server-setup.md) |
| [`diag-stick/`](diag-stick) | Sources for the RAM-only diagnostic Linux USB stick. It's built as root in WSL from a minimal Ubuntu 24.04 (`debootstrap --variant=minbase noble`) plus the stock kernel, trimmed to the drivers this laptop needs. See [`README-stick.txt`](diag-stick/README-stick.txt) and the comments in `build_rootfs.sh`, `make_image.sh` and `init`. The built image is **not** included, because it would contain SSH keys. Build your own with your key. `write_stick.ps1` only writes to a USB disk named `General UDisk` of about 7.5 GB, so edit `$expectedName` and the size check for your stick. `windows-tools/read_stick.ps1` has the same name check |
| [`server-install/`](server-install) | The chroot installer and the stick GRUB menu used to install Ubuntu 22.04 without a screen |
| [`server-tools/`](server-tools) | Config files from the finished server: Wake-on-LAN service, netplan, GRUB, fstab, watchdog, SSH, CPU benchmark |
| [`server-stick/`](server-stick) | An earlier, **unused** approach: a remastered Ubuntu 24.04 live ISO with SSH, plus an autoinstall file sent over SSH. It was dropped because 24.04 lacks the Fermi GPU driver |
| [`windows-tools/`](windows-tools) | PowerShell tools for the Windows PC: `wake_asus.ps1` (magic packet), `find_asus.ps1` (finds the laptop by MAC), `watch_lan.ps1` (flags new devices), `read_stick.ps1`, the phone-witness scripts, `connect_asus.cmd` |
| [`wsl-tools/`](wsl-tools) | WSL scripts: the QEMU control boot, and readers for the partition Ubuntu wrote to the stick |
| [`firmware-tools/`](firmware-tools) | Python tools that unpack AMI Aptio 4 BIOS images and search their modules |
| [`boardview-tools/`](boardview-tools) | `boardmap.py`, which draws [`docs/board-map.svg`](docs/board-map.svg) from your own ASC boardview export (not included) |

**Before using any script**, replace the placeholders with your own values:

| Placeholder | Your value |
|---|---|
| `aa:bb:cc:dd:ee:ff` / `aa-bb-cc-dd-ee-ff` | the laptop's Ethernet MAC |
| `192.168.0.50` | its LAN address |
| `192.168.0.10` | the Windows PC's own address, which the LAN scripts skip |
| `192.168.0.x` | your subnet. `watch_lan.ps1` and `asus_phone_check.ps1` also contain it in regex form, `192\.168\.0\.` |
| `00-00-00-00-00-01`, `00-00-00-00-00-02` | the MACs of devices already on your LAN: the baseline in those two scripts |
| `PHONE_IP:PORT` | the phone's Wireless debugging address |
| `ROOT-FS-UUID`, `DATA-FS-UUID` | your filesystem UUIDs |
| `KEY`, `PROJECT` environment variables | your SSH public key and project folder |
| `Etc/UTC` | your timezone |

**Safety rules the write tools enforce, and that you should keep:**

- Pick the target disk by model **and** bus type, and require exactly one match.
- Never write the PC's system disk.
- Never use `badblocks -w/-n` or `mkfs` on a drive whose data you haven't saved.

## Not included, on purpose

- **ASUS's own files:** the boardview (`.fz` and ASC), the BOM and the BIOS images. Get the BIOS from ASUS (links and
  hashes are in [docs/bios-and-firmware.md](docs/bios-and-firmware.md)). Boardviews circulate on repair forums.
- **Anything identifying the owner, their network or their devices:** MACs, addresses, serial numbers, keys,
  passwords, photos, logs and the contents of the old drives. Those are replaced with placeholders or left out.
- **Third-party binaries:** ISOs, Android platform-tools, OpenBoardView. Download them from their publishers.

## Credits and license

Planned, run and written by Claude Code (Anthropic) under the direction of the laptop's owner, in November 2026. All
hardware work was done by the owner. Not peer-reviewed.

- **Code** (scripts and configs): MIT, see [`LICENSE`](LICENSE).
- **Documentation and data**: CC BY 4.0, see [`LICENSE-CC-BY-4.0`](LICENSE-CC-BY-4.0). Reuse needs attribution to
  `gioagroforest` with a link to this repo.
- Neither license covers ASUS firmware, boardviews, Ubuntu or any other third-party software.
