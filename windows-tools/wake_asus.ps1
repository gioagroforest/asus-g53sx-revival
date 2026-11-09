# Sends a Wake-on-LAN "magic packet" to the ASUS G53SX, then watches for it to answer.
# Works only when: the ASUS is on the charger (not battery), the Ethernet cable is in,
# the BIOS "Wake On LAN" option is on, and the last shutdown left the network card armed.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File wake_asus.ps1
param(
    [string]$Mac = 'aa:bb:cc:dd:ee:ff',   # ASUS Ethernet (r8169), from run 12
    [string]$Ip  = '192.168.0.50',       # address the router gave it in run 13
    [int]$WaitSeconds = 120
)
# Magic packet = 6 bytes of 0xFF, then the MAC address repeated 16 times (102 bytes).
$macBytes = $Mac -split '[:-]' | ForEach-Object { [Convert]::ToByte($_, 16) }
$packet = [byte[]](@(0xFF) * 6 + ($macBytes * 16))

$udp = New-Object System.Net.Sockets.UdpClient
$udp.EnableBroadcast = $true
foreach ($target in @('255.255.255.255', '192.168.0.255')) {
    foreach ($port in 7, 9) { [void]$udp.Send($packet, $packet.Length, $target, $port) }
}
$udp.Close()
Write-Host "$(Get-Date -Format HH:mm:ss) magic packet sent to $Mac"

# Linux on the stick takes about 20-60 s to get an address, so ping for a while.
$ping = New-Object System.Net.NetworkInformation.Ping
$end = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $end) {
    try { if ($ping.Send($Ip, 800).Status -eq 'Success') { Write-Host "$(Get-Date -Format HH:mm:ss) ASUS is answering at $Ip"; exit 0 } } catch {}
    Start-Sleep -Seconds 3
}
Write-Host "No answer at $Ip after $WaitSeconds s. It may have woken with a different address (check the router), or Wake-on-LAN is not armed."
exit 1
