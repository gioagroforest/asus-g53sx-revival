G53 diagnostic stick

What it does: boots a small Linux from RAM, records the laptop's hardware and how
far it got, then turns the laptop off. It never writes to any disk except this stick.

How to use it:
1. Plug it into the laptop and power on. Press nothing.
2. Wait until the laptop turns itself off, or for 20 minutes.
3. Move the stick to the PC.

What you may see:
- Caps Lock blinking slowly (1 s on, 1 s off): the program is running.
- Five quick flashes, then the laptop turns itself off: everything finished.
- Five quick flashes, then a steady fast blink: finished, but POWEROFF=0 is set
  or the power-off failed. It is safe to pull the stick.
- A fast blink with no five flashes before it: Linux probably crashed.

Files:
- LOGS/run-NNN/    results of each run. SUMMARY.txt and progress.txt come first.
- config.txt       settings.
- TESTS/run.sh     optional: any extra commands to run. Output is saved.
- grub-extra.cfg   optional: extra Linux start options.
- wifi.conf        optional: Wi-Fi details in wpa_supplicant format. Stored unencrypted.
- boot/grub/grubenv  grub_starts gains one x each time the laptop starts this stick.
