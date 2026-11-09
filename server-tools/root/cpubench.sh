#!/bin/bash
# CPU benchmark with a heat guard: kills the test if the CPU package passes 92 C.
LOG=/root/cpubench-$(date +%F-%H%M).log
temp(){ sensors coretemp-isa-0000 | awk '/Package/{gsub(/[+°C]/,"",$4); print int($4)}'; }
fan(){ sensors asus-isa-0000 | awk '/cpu_fan/{print $2}'; }
( max=0; while sleep 1; do t=$(temp); [ "$t" -gt "$max" ] && max=$t; echo "$max $(fan)" > /tmp/bench_max
  if [ "$t" -ge 92 ]; then echo "HEAT STOP at ${t}C" | tee -a $LOG; pkill -f sysbench; pkill -x 7z; fi; done ) &
G=$!
{
echo "== start: $(temp)C fan $(fan) rpm"
echo "== sysbench 1 thread (20 s)";  sysbench cpu --threads=1 --time=20 run | grep -E "events per second"
echo "   temp $(temp)C"
echo "== sysbench 8 threads (30 s)"; sysbench cpu --threads=8 --time=30 run | grep -E "events per second"
echo "   temp $(temp)C, fan $(fan) rpm, mhz: $(grep MHz /proc/cpuinfo | awk '{s+=$4}END{printf "%d avg", s/NR}')"
echo "== 7-Zip benchmark (all threads)"; 7z b 2>&1 | grep -E "^(Avr|Tot):"
echo "   temp $(temp)C"
echo "== max temp / last fan: $(cat /tmp/bench_max)"
sleep 20; echo "== after 20 s rest: $(temp)C fan $(fan)"
} 2>&1 | tee $LOG
kill $G
