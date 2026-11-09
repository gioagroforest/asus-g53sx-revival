# Pings every address 192.168.0.1-254 at once, then looks for the ASUS by its network card ID (MAC).
# Usage: right-click > "Run with PowerShell", or: powershell -ExecutionPolicy Bypass -File find_asus.ps1
$mac = 'aa-bb-cc-dd-ee-ff'
$tasks = 1..254 | ForEach-Object { (New-Object System.Net.NetworkInformation.Ping).SendPingAsync("192.168.0.$_", 1000) }
[void][System.Threading.Tasks.Task]::WaitAll($tasks)
$up = $tasks | Where-Object { $_.Result.Status -eq 'Success' } | ForEach-Object { $_.Result.Address.ToString() }
Write-Host "Devices answering: $($up -join ', ')"
$hit = arp -a | Select-String $mac
if ($hit) { Write-Host "ASUS FOUND: $(($hit.Line.Trim() -split '\s+')[0])" -ForegroundColor Green }
else      { Write-Host "ASUS not on the network (it is off, or the cable is out)." -ForegroundColor Yellow }
Read-Host "Press Enter to close"
