#!/bin/bash
# GPU benchmark (OpenCL, clpeak) with a heat guard: stops the test if the GPU reaches 90 C.
# Needs the NVIDIA 390 driver, clinfo and clpeak (see docs/server-setup.md).
LOG=/root/gpubench-$(date +%F-%H%M).log
gtemp(){ t=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null); case $t in ''|*[!0-9]*) echo "?";; *) echo "$t";; esac; }
fan(){ sensors asus-isa-0000 2>/dev/null | awk '/cpu_fan/{print $2}'; }
( max=0; while sleep 1; do t=$(gtemp); [ "$t" != "?" ] && [ "$t" -gt "$max" ] && max=$t; echo "$max $(fan)" > /tmp/gpubench_max
  if [ "$t" != "?" ] && [ "$t" -ge 90 ]; then echo "HEAT STOP at ${t}C" | tee -a "$LOG"; pkill -x clpeak; fi; done ) &
G=$!
{
echo "== start: GPU $(gtemp)C, fan $(fan) rpm"
nvidia-smi --query-gpu=name,driver_version,vbios_version,memory.total --format=csv,noheader
echo "== clpeak (OpenCL), $(date +%T)"; clpeak
echo "== finished $(date +%T). Max GPU temp / last fan rpm: $(cat /tmp/gpubench_max)"
sleep 20; echo "== after 20 s rest: GPU $(gtemp)C, fan $(fan) rpm"
} 2>&1 | tee "$LOG"
kill $G
