# Quick guide: what to try on a G53SX with no picture

One page, in order. [README.md](README.md) and [docs/](docs) explain every step. These steps come from one G53SX
(mainboard rev 2.0). They are not guaranteed to work on yours.

**Power off fully before you touch the board:** unplug the charger and take the battery out. For the CMOS clear and
any resistance check, take the coin cell out too.

## 1. Look before you touch

Don't reseat anything yet. Until you change something, the fault is still there to be measured.

- **Do the fans and Caps Lock light come on?** Then the board gets power. The question is how far the BIOS gets.
- **Does it reach USB?** Plug an Android phone into a laptop USB port and power on. With Wireless debugging on, a PC
  can read the phone's USB history with [`watch_phone_usb.ps1`](windows-tools/watch_phone_usb.ps1). If no USB host
  ever talks to the phone, the BIOS never got as far as USB. Restart the phone afterwards to close Wireless debugging.
- **Does it reach the USB stick?** Boot the [diagnostic stick](diag-stick). Each start adds an `x` to
  `boot/grub/grubenv` on the stick. No new `x` means the firmware never reached it.
- **Does it reach the network?** Plug in Ethernet and watch for a new device from a PC with
  [`watch_lan.ps1`](windows-tools/watch_lan.ps1).
- **Read a stick back before you rewrite it.** A Linux that ran with no screen still leaves files behind.

## 2. It never reaches USB: hardware, one change per power-on

Write down each power-on: what changed and what happened.

1. **Clean and reseat the RAM.** Test one stick in **J1401**. For two sticks use **J1401 + J1501**, one per channel
   ([slot map](docs/board-facts.md#ram-slots-4-slots-dual-channel-16-gb-max)).
2. **Reseat the MXM graphics card** (J7001).
3. **Clear CMOS and ME:** with all power out, short the two pads of **JRST2001**, then those of **JRST2002**. They
   sit next to J1401 ([debug points](docs/board-facts.md#service-and-debug-points)).
4. **Connect the drives before power-on.** Otherwise the SATA controller reports no ports.
5. **Answer hidden questions blind:** the BIOS can wait at a RAM question (**Y** continues) or at "Press F1". On this
   unit, pressing Y and F1 changed nothing.

On this unit, these steps, done during a full strip-down with the board out of its case, brought it back. Which one
fixed it is not known. Poor contact in a RAM slot or the MXM connector is the likeliest explanation, but it is an
inference.

## 3. RAM works but the BIOS is bad: USB recovery (untested on this unit)

Recovery needs working RAM, so it can't fix the fault in step 2.

- Download the newest BIOS from ASUS and check its hash ([downloads](docs/bios-and-firmware.md#downloads)).
- Put the image in the root of a FAT stick, named exactly **`G53SX.bin`** (**`G53SW.bin`** on a G53SW).
- Use a **USB 2.0** port, keep the charger in, and have a battery above **20 %**.
- Hold **Ctrl+Home** on the **internal** keyboard while powering on. A USB keyboard is ignored at this stage.

## 4. Once it boots

- **Picture:** HDMI shows a picture once the GPU driver (nouveau) loads. On this BIOS the **Esc** boot menu shows on
  HDMI, but Setup doesn't.
- **Remote access:** build the diagnostic stick with your SSH key. It gets an address over Ethernet and accepts SSH.
- **Server:** install Ubuntu 22.04. Unlike Ubuntu 24.04 and Debian 12, it still packages NVIDIA's driver for this
  Fermi GPU ([server setup](docs/server-setup.md)). Put GRUB on **every** disk, so a wrong boot order can't strand it.
- **Wake-on-LAN:** use [`g53-wol.service`](server-tools/etc/systemd/system/g53-wol.service), which also arms the
  network card's PCIe root port. Wake the laptop from a PC on the same network with
  [`wake_asus.ps1`](windows-tools/wake_asus.ps1). It only wakes when the charger is plugged in.

## Don't

- Don't run `badblocks -w`, `mkfs` or any disk writer on a drive whose data you haven't saved.
- Don't treat a hot chipset on a board outside its case as a fault. It cools through a pad on the case.
- Don't expect the GTX 560M to run current AI frameworks. CUDA support for Fermi ended with CUDA 8.0.
