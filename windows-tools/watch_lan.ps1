# Watches the LAN and reports every new IP+MAC pair, including new IPs behind a known MAC.
# Reads SSH banners only; never logs in. Stops early on an Ubuntu banner from a new address.
param([int]$Minutes = 9)

$known = @{}
# Baseline: every device already on YOUR network, as 'IP|MAC' (from: arp -a). Example entries:
foreach ($pair in @(
    '192.168.0.1|00-00-00-00-00-01',
    '192.168.0.10|00-00-00-00-00-02'
)) { $known[$pair] = $true }

$deadline = (Get-Date).AddMinutes($Minutes)
$round = 0
$hit = $false
"$(Get-Date -Format HH:mm:ss) watching until $($deadline.ToString('HH:mm:ss'))"

while ((Get-Date) -lt $deadline -and -not $hit) {
    $round++
    $tasks = 1..254 | ForEach-Object {
        $p = New-Object System.Net.NetworkInformation.Ping
        @{ ip = "192.168.0.$_"; t = $p.SendPingAsync("192.168.0.$_", 1000) }
    }
    [void][System.Threading.Tasks.Task]::WaitAll(($tasks | ForEach-Object { $_.t }), 15000)
    $alive = @($tasks | Where-Object { $_.t.IsCompleted -and $_.t.Result.Status -eq 'Success' } | ForEach-Object { $_.ip })

    $rows = @(arp -a | Select-String "^\s*192\.168\.0\.\d+\s" | Where-Object { $_ -notmatch "\.255\s" } | ForEach-Object {
        $x = $_.ToString().Trim() -split '\s+'
        [pscustomobject]@{ ip = $x[0]; mac = $x[1] }
    })

    foreach ($r in $rows) {
        $key = "$($r.ip)|$($r.mac)"
        if ($known.ContainsKey($key)) { continue }
        $known[$key] = $true
        $first = [Convert]::ToInt32($r.mac.Substring(0, 2), 16)
        $kind = if ($first -band 2) { 'randomized or shared MAC' } else { 'factory MAC' }
        "$(Get-Date -Format HH:mm:ss) NEW $($r.ip)  $($r.mac)  ($kind)  answers ping: $($alive -contains $r.ip)"
        $c = New-Object Net.Sockets.TcpClient
        try {
            $res = $c.BeginConnect($r.ip, 22, $null, $null)
            if ($res.AsyncWaitHandle.WaitOne(1500) -and $c.Connected) {
                $s = $c.GetStream()
                $s.ReadTimeout = 2500
                $b = New-Object byte[] 200
                $n = $s.Read($b, 0, 200)
                $banner = [Text.Encoding]::ASCII.GetString($b, 0, $n).Trim()
                "    ssh banner: $banner"
                if ($banner -match 'Ubuntu') {
                    "    LIKELY THE ASUS"
                    $hit = $true
                }
            } else {
                "    port 22 closed"
            }
        } catch {
            "    port 22 error: $($_.Exception.Message)"
        } finally {
            $c.Close()
        }
    }

    if ($round % 5 -eq 0) { "$(Get-Date -Format HH:mm:ss) round $round, alive: $($alive -join ', ')" }
    if (-not $hit) { Start-Sleep -Seconds 20 }
}

if (-not $hit) { "$(Get-Date -Format HH:mm:ss) window ended after $round rounds, no Ubuntu banner from a new address" }
