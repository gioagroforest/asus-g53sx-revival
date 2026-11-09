#!/bin/bash
# Run on the live system over SSH. Prints what the G53 settings actually did.
echo "== cmdline"; cat /proc/cmdline
echo "== nomodeset honoured"; sudo dmesg | grep -i 'nomodeset' | head -3
echo "== nouveau must be refused"; sudo modprobe nouveau 2>&1; echo "modprobe exit $?"; echo "loaded: $(lsmod | grep -c '^nouveau')"
echo "== sleep targets"; systemctl is-enabled sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target 2>&1 | sort | uniq -c
echo "== logind lid"; systemd-analyze cat-config systemd/logind.conf | grep -i '^HandleLid'
echo "== disks"; lsblk -o NAME,SIZE,TYPE,RO,FSTYPE,LABEL,MOUNTPOINTS | grep -v loop
echo "== journal"; ls -d /var/log/journal/*; journalctl --disk-usage
echo "== report service"; systemctl is-active g53-report; ls -la /var/log/g53/; tail -4 /var/log/g53/heartbeat.txt
echo "== snapshot sample"; grep -A4 '^== dmi' /var/log/g53/start.txt
echo "== net"; ip -br addr | grep -v '^lo'
echo "== failed units"; systemctl --failed --no-pager --no-legend
echo "== installer"; systemctl is-active snap.subiquity.subiquity-server.service; ls /autoinstall.yaml 2>&1
