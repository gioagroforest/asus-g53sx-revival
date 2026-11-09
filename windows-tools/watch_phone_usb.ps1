# Records the phone's USB and charging state, one line per change, over wireless debugging.
# Reads only USB and battery status. Changes nothing on the phone.
param(
    [string]$Target = 'PHONE_IP:PORT',
    [int]$Minutes = 9,
    [Parameter(Mandatory)][string]$Log
)

$adb = "$PSScriptRoot\platform-tools\adb.exe"
$remote = "dumpsys battery | grep -E 'AC powered|USB powered|Max charging current'; dumpsys usb | grep -E ' (connected|configured|current_mode|power_role|data_role)='; getprop sys.usb.state"
$deadline = (Get-Date).AddMinutes($Minutes)
$last = ''
"$(Get-Date -Format 'HH:mm:ss') recording until $($deadline.ToString('HH:mm:ss'))" | Tee-Object -FilePath $Log -Append

while ((Get-Date) -lt $deadline) {
    $out = & $adb -s $Target shell $remote 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $out) {
        $state = 'phone not reachable'
        & $adb connect $Target > $null 2>&1
    } else {
        $ac = ''; $usb = ''; $amps = ''; $gadget = ''; $conf = ''; $port = ''; $mode = ''; $power = ''; $data = ''; $usbState = ''
        foreach ($raw in $out) {
            $l = $raw.Trim()
            if ($l -match '^AC powered: (.+)')             { $ac = $Matches[1] }
            elseif ($l -match '^USB powered: (.+)')        { $usb = $Matches[1] }
            elseif ($l -match '^Max charging current: (\d+)') { $amps = [math]::Round([double]$Matches[1] / 1000) }
            elseif ($l -match '^connected=(.+)') {
                if ($gadget -eq '') { $gadget = $Matches[1] } elseif ($port -eq '') { $port = $Matches[1] }
            }
            elseif ($l -match '^configured=(.+)' -and $conf -eq '')     { $conf = $Matches[1] }
            elseif ($l -match '^current_mode=(.+)' -and $mode -eq '')   { $mode = $Matches[1] }
            elseif ($l -match '^power_role=(.+)' -and $power -eq '')    { $power = $Matches[1] }
            elseif ($l -match '^data_role=(.+)' -and $data -eq '')      { $data = $Matches[1] }
            elseif ($l -match '^[a-z_,]+$')                             { $usbState = $l }
        }
        $state = "AC=$ac USB=$usb maxmA=$amps hostSeen=$gadget hostConfigured=$conf cable=$port mode=$mode power=$power data=$data func=$usbState"
    }
    if ($state -ne $last) {
        "$(Get-Date -Format 'HH:mm:ss.f') $state" | Tee-Object -FilePath $Log -Append
        $last = $state
    }
    Start-Sleep -Milliseconds 300
}
"$(Get-Date -Format 'HH:mm:ss') recording ended" | Tee-Object -FilePath $Log -Append
