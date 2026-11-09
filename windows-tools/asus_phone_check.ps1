# One status check of the ASUS, using the phone plugged into its USB port, plus a LAN sweep.
# Reads only. Appends one block to asus_status.log, next to this script, and prints it.
# What the phone can tell: is the port powered, and did a USB host ever talk to the phone.
param(
    [string]$Target = 'PHONE_IP:PORT',
    [string]$Log = "$PSScriptRoot\asus_status.log"
)
$adb = "$PSScriptRoot\platform-tools\adb.exe"
# Baseline: devices already on YOUR network, IP = MAC (from: arp -a). Example entries:
$known = @{
    '192.168.0.1'='00-00-00-00-00-01'; '192.168.0.10'='00-00-00-00-00-02'
}
$lines = New-Object System.Collections.ArrayList
function Add($s) { [void]$lines.Add($s) }
Add "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

& $adb connect $Target > $null 2>&1
$remote = @'
echo "phoneTime=$(date +%H:%M:%S)"
dumpsys battery | grep -E 'AC powered|USB powered|Max charging current| level:| status:'
dumpsys usb | grep -E ' (connected|configured|current_mode|power_role|data_role)=' | head -n 5
echo "func=$(getprop sys.usb.state)"
echo "lastUevent=$(dumpsys usb | grep 'USB UEVENT' | tail -n 1 | cut -c1-90)"
echo "portEvents:"
logcat -d -b all | grep updateHostState | grep -v adbd | cut -c1-14,70-100 | tail -n 6
logcat -d -b all | grep updateHostState | grep -v adbd | grep -oE '^.{14}|connected=[a-z]+, currentMode=[a-z]+, currentPowerRole=[a-z-]+' | paste - - | tail -n 6
'@
$out = & $adb -s $Target shell ($remote -replace "`r","") 2>&1
if ($LASTEXITCODE -ne 0 -or -not $out) {
    Add 'PHONE: NOT REACHABLE (off, flat battery, restarted, or left the Wi-Fi)'
    $verdict = 'unknown: phone not reachable'
} else {
    $txt = ($out | ForEach-Object { "$_" }) -join "`n"
    $g = { param($rx) if ($txt -match $rx) { $Matches[1].Trim() } else { '?' } }
    $ac = & $g 'AC powered: (\w+)'; $usb = & $g 'USB powered: (\w+)'
    $mA = & $g 'Max charging current: (\d+)'; if ($mA -ne '?') { $mA = [int]($mA / 1000) }
    $lvl = & $g ' level: (\d+)'; $st = & $g ' status: (\d+)'
    $cable = 'false'; $hostSeen = 'false'; $conf = 'false'
    $conn = [regex]::Matches($txt, 'connected=(\w+)')
    if ($conn.Count -ge 1) { $hostSeen = $conn[0].Groups[1].Value }
    if ($conn.Count -ge 2) { $cable = $conn[1].Groups[1].Value }
    $conf = & $g 'configured=(\w+)'; $role = & $g 'power_role=([\w-]+)'
    $func = & $g 'func=(\S*)'; $phone = & $g 'phoneTime=(\S+)'
    Add "PHONE: time=$phone battery=$lvl% status=$st ac=$ac usb=$usb maxmA=$mA cable=$cable role=$role"
    Add "USB HOST: seen=$hostSeen configured=$conf func=$func"
    if ($txt -match 'lastUevent=(.*)') { Add "last host event: $($Matches[1].Trim())" }
    $ev = $out | Where-Object { "$_" -match 'connected=' -and "$_" -match '^\d\d-\d\d' }
    foreach ($e in $ev) { Add "  port: $e" }
    if ($hostSeen -eq 'true' -or $conf -eq 'true') { $verdict = 'USB HOST TALKING TO THE PHONE: firmware or an OS is handling USB' }
    elseif ($ac -eq 'true') { $verdict = 'phone is on a wall charger, so it says nothing about the ASUS' }
    elseif ($usb -eq 'true' -or $cable -eq 'true') { $verdict = 'port powered, no USB host talking: ASUS likely ON, not enumerating' }
    else { $verdict = 'port has no power: ASUS likely OFF or phone unplugged' }
    if ($lvl -ne '?' -and [int]$lvl -le 5) { Add "WARNING: phone battery $lvl%" }
}

# LAN: flag any IP+MAC pair not in the list, even behind a known MAC.
$tasks = 1..254 | ForEach-Object { $p = New-Object System.Net.NetworkInformation.Ping; @{ip="192.168.0.$_"; t=$p.SendPingAsync("192.168.0.$_",800)} }
[void][System.Threading.Tasks.Task]::WaitAll(@($tasks | ForEach-Object { $_.t }), 12000)
$new = @()
foreach ($row in (arp -a | Select-String '^\s*192\.168\.0\.\d+\s')) {
    $x = $row.ToString().Trim() -split '\s+'
    if ($x[0] -match '\.255$' -or $x[0] -eq '192.168.0.10') { continue }
    if ($known[$x[0]] -ne $x[1]) { $new += "$($x[0]) $($x[1])" }
}
if ($new.Count) {
    Add "LAN: NEW: $($new -join '; ')"
    foreach ($n in $new) {
        $ip = ($n -split ' ')[0]; $c = New-Object Net.Sockets.TcpClient; $r = $c.BeginConnect($ip,22,$null,$null)
        if ($r.AsyncWaitHandle.WaitOne(800) -and $c.Connected) { Add "  $ip has SSH open" }; $c.Close()
    }
} else { Add 'LAN: nothing new' }
Add "VERDICT: $verdict"
$lines | Tee-Object -FilePath $Log -Append
