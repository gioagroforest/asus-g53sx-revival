# Board facts: ASUS G53SX mainboard rev 2.0

These facts come from the plain-text boardview export (eM-Test ASC format, board `G53SX-R20`) for mainboard part
**60-N7CMB2100-B02**. The boardview files themselves are ASUS property and are **not** in this repo. Repair forums
share them, and OpenBoardView (MIT licensed) opens the ASC set without a key. The `.fz` version is encrypted and needs a
key that this repo doesn't include.

Coordinates are in inches, as in the file. **Side T** and **side B** are the file's own "top" and "bottom" labels.

- **Side T** is the CPU side, the one you reach through the service panel. It holds the CPU socket, the MXM GPU slot
  and the CMOS-clear pads.
- **Side B** is the keyboard side. It holds the chipset (PCH), the EC and the BIOS chip.

The marked-up picture is [board-map.png](board-map.png), or [board-map.svg](board-map.svg) for zooming. It shows pad
positions only, with my labels and no wiring.

## RAM slots (4 slots, dual channel, 16 GB max)

| Slot | Channel / DIMM | Side | Confirmed by |
|---|---|---|---|
| **J1401** | channel A, DIMM0 (CS0/1) | T | SMBIOS `ChannelA-DIMM0` in run 12 |
| **J1601** | channel A, DIMM1 (CS2/3) | T | SMBIOS `ChannelA-DIMM1` in RAM run A |
| **J1501** | channel B, DIMM0 | B | SMBIOS `ChannelB-DIMM0` in run 12 |
| **J1701** | channel B, DIMM1 | B | SMBIOS `ChannelB-DIMM1` in RAM run B |

- **One stick:** use J1401.
- **Two sticks in dual channel:** use J1401 + J1501.
- All four slots passed a full memtester with 4 × 4 GB DDR3-1333.
- **J1701 needed cleaning and reseating once.** Before that, it caused a hang with no POST.

## Service and debug points

| Ref | What | Where | Pins |
|---|---|---|---|
| **JRST2001** | RTCRST#, CMOS clear | side T, about (-1.38, 0.8), next to J1401 | short the two pads, all power out |
| **JRST2002** | SRTCRST#, ME / suspend-well reset | next to JRST2001 | same |
| **JDEBUG1** | 12-pin FPC debug port, the **POST-code tap** (LPC) | side B, (1.99, 0.60), next to the EC | 1, 3 = +3VS; 2, 4, 6, 8 = LPC_AD0–3; 10 = LPC_FRAME#; 12 = CLK_DEBUG; 9, 11 = GND |
| **J2802** | 2×4 header, 2.54 mm, wired to the BIOS chip | side B, (-0.15, -1.08) | 1 = +3VM_SPI, 2 = GND, 3 = CS#, 4 = CLK, 5 = SO, 6 = SI |
| **U2801** | BIOS SPI flash, SOIC-8 | side B | read or write it through J2802 with every power source out |
| **U3001** | EC (keyboard, fans, power) | side B | |
| **U2001** | PCH (Intel HM65 chipset) | side B | Runs hot with the board out of the chassis, where its cooling pad is missing |

POST codes go to the LPC bus by default (see [bios-and-firmware.md](bios-and-firmware.md#post-codes)), so a logic
analyzer on JDEBUG1 can read them. A Mini PCIe POST card would see nothing unless a hidden BIOS option is changed.

## Graphics and display

- **The GPU is a removable MXM card on J7001** (side T). Nothing switches the outputs to Intel graphics: every video
  output, including the internal panel's LVDS lines, comes from the MXM card. The PCH's own LVDS pins aren't used.
- MXM card power:
  - AC_BAT_SYS_MXM, 19 V, through jumper JP7001;
  - +5VS_MXM through JP7002;
  - +3VS_MXM through JP7004.

  The card sends back VGA_PWRGD.
- **Internal panel connector J4501** (side B):

  | Pins | Signal |
  |---|---|
  | 1–3 | +3VS_LCD, from +3VSUS through Q4502 and L4501 |
  | 4 | +3VS |
  | 5 | +5VS |
  | 6, 7 | EDID |
  | 35 | LCD_PWM |
  | 36 | backlight enable, through U4501, with LCD_BACKOFF# from the EC |
  | 38–40 | backlight power, 19 V: AC_BAT_SYS → Q4570 → AC_BAT_INV → L4503 |

- **HDMI** is J4803, with 5 V through fuse F4801. Hot-plug detect uses J4803 pin 19, R4804, D4802 and net HDMI_HPD.
  **VGA** is J4601.

## Main power coils

| Coil | Rail |
|---|---|
| PL8001, PL8002, PL8003 | +VCORE (CPU) |
| PL8100 | +3VO |
| PL8101 | +5VO |
| PL8200 | +VTT_CPU (1.05 V) |
| PL8300 | +1.5VO (RAM) |
| PL8400 | +1.8VO |
| PL8700 | +0.8VSO |
| PL8800 | charger |

To check for a shorted rail, measure each coil's output side to ground **with every power source out, including the
battery and the coin cell**, and compare it with a known-good board or with the other rails.

## SATA

Both drive bays are on the small IO board:

- **J7202** = SATA port 0, **J7203** = SATA port 1. The IO board's own label for port 1 is 4.
- The bays reach the mainboard through J5102 and J7201.
- J5101 carries SATA2, most likely the optical drive.
- Both bays negotiated 6.0 Gb/s.

**Connect the drives before power-on.** With no drive attached at boot, the AHCI controller reported `0x0 impl`, with
every port as a dummy.
