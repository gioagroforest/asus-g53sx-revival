# BIOS and firmware facts: ASUS G53SX / G53SW

Everything here was read from ASUS's official BIOS images. They are AMI Aptio 4. The repo's
[`firmware-tools/`](../firmware-tools) unpack and search them. The images themselves are ASUS property and are **not**
in this repo: download them from ASUS and check them against the hashes below.

## Downloads

ASUS's support API lists them at `https://www.asus.com/support/api/product.asmx/GetPDBIOS?website=global&model=G53SX`
(or `model=G53SW`). The files are at `https://dlcdnets.asus.com/pub/ASUS/nb/<MODEL>/<file>`.

| Model | File | Date | Image inside | Image SHA-256 |
|---|---|---|---|---|
| G53SX | `G53SXAS209.zip` | 2012-01-13, also updates the EC firmware | `G53SXAS.209`, 2,621,440 bytes | `c0caa35a206d4311716e8691f524bc618aec2d13933d2e78e1fcf3f6486655c7` |
| G53SX | `G53SXAS205.zip`, `G53SXAS203.zip` | older | | |
| G53SW | `G53SWAS203.zip` | 2011-03-28, the only one listed | `G53SWAS.203` | `32e3c2022332849b161d684da95f9cccc87d25bacb23dc258aae75c30d654aa0` |

The repaired laptop reported **BIOS 205** in SMBIOS. It was never flashed during this work.

## How to unpack the images

- AMI's LZMA sections here are **raw LZMA1** with a 13-byte header.
- Decode them with Python's `lzma` using `FORMAT_RAW` and an LZMA1 filter. `FORMAT_ALONE` fails on them.
- `firmware-tools/ffs.py` walks the firmware volumes and decompresses the modules.
- `dump_module.py`, `find_owner.py`, `post_strings*.py` and `diff_headers.py` search and compare the modules.
- Run them from inside `firmware-tools/`, because several load `ffs.py` by a relative path. Use `python -I`, keep the
  images in another folder, and pass the image's path.

## BIOS recovery (boot block)

- The boot block's `Recovery` module looks for exactly **`G53SX.bin`** on a G53SX or **`G53SW.bin`** on a G53SW. Each
  model ignores the other's file, so one stick can carry both.
- Path: `PchUsb` → `UsbBotPeim` → `Recovery`. **Recovery is USB-only.** The boot block has no SATA, IDE or ATAPI driver,
  so there is no CD recovery path.
- The chipset's USB (Cougar Point) is USB 2.0. Use the **USB 2.0 ports**, on the small side boards, not the USB 3.0 port.
- Recovery can read FAT, NTFS and ISO9660 / El Torito.
- **The boot block has no USB keyboard (HID) driver.** Ctrl+Home must be pressed on the **internal** keyboard. Holding
  it on a USB keyboard does nothing. This project lost one test run to that.
- Recovery needs working RAM, because a 2.5 MB image can't be loaded before memory is up. It can't fix a RAM or slot fault.
- **ASUS EZ Flash refuses to write unless the AC adapter is plugged in AND the battery is above 20 %**
  ("Please plug-in Battery and Battery capacity needs more then 20%!!"). It also:
  - refuses older builds ("Build Date is too Old!!");
  - checks the model name ("Model Name doesn't match!!");
  - asks "Do you want to update BIOS?", so a blind run can stall at a question nobody can see.

Recovery was never needed in the end. The laptop booted with its own BIOS once the hardware fault was cleared, as
described in the README.

## Startup stops that wait for a key

All of these were found in the main firmware's text. **With no screen, each looks like a dead laptop.**

- **RAM layout**, in the Intel memory code "SandyBridge SystemAgent RC":
  - "Slot 0 can't be populated when Slot 1 is not populated on the same channel" (or the reverse);
  - then "Error...! Invalid DIMM Population." and "Press <Y> to Continue. <N> to Shutdown".
- "Press F1 to Resume..." (its trigger isn't visible in the text).
- No boot device: "Reboot and Select proper Boot device…", or "Boot disk missing, please insert boot disk and press ENTER".
- "System Halt!!", in the password-screen module.
- **Not found:** any fan-error or keyboard-error stop. Fans are the EC's job.

On this unit, pressing Y and F1 blind never changed anything, so it wasn't stuck at either question.

## POST codes

- The PEI module `Redirect80P` reads a Setup option. Only if that option is set does it set bit 2 (RPR) of the chipset
  register GCS (RCBA + 0x3410 = `0xFED1F410`), which sends port-80 codes to PCI. Otherwise it clears the bit, and the
  codes go to **LPC**, which is also the power-on default.
- So POST codes are readable with a fast logic analyzer on LPC: LAD0–3, LFRAME# and LCLK, exposed on **JDEBUG1** (see
  [board-facts.md](board-facts.md)). A Mini PCIe POST card would see nothing.

## Boot-block PEI modules (G53SXAS.209)

S3Resume, PchS3Peim, StartWatchDog, PchUsb, UsbBotPeim, Recovery, Redirect80P, PlatformInfoPei, SBPEI, NBPEI,
MemoryInit, CORE_PEI, CpuPeiBeforeMem, SaPeiPolicyInit, SaInitPeim, PchInitPeim, PchSpiPeim, WdtPei, HeciPei, PchMeUma,
WdtAppPei, ASUSPei, CpuPei, OEMPEI.

## BIOS options that mattered for a headless server

- **Wake On LAN** (ASUS option): works on AC only ("Wake-on LAN doesn't enable in Battery Mode"). On this unit it was
  ON after a CMOS clear.
- **Boot order**: with no screen, Setup can't be seen. It showed as black on HDMI on this unit. The **Esc boot menu**
  (blue, text mode) **does** show on HDMI.
- After a CMOS clear, the RTC year resets to 2011. Fix the clock before running `apt`.
