#!/bin/bash
# usage: run_logged.sh <log file> <command...>
# Keeps full output in the log and prints only the end, with the exit code.
log=$1
shift
mkdir -p "$(dirname "$log")"
"$@" > "$log" 2>&1
rc=$?
tail -40 "$log"
echo "EXIT CODE: $rc"
exit "$rc"
