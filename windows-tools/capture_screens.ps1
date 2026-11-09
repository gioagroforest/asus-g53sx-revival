# Saves screenshots of the phone's screen, with the time in each file name, while the
# camera app is open. cmd handles the redirect because PowerShell 5.1 would corrupt PNG data.
param(
    [string]$Target = 'PHONE_IP:PORT',
    [int]$Seconds = 170,
    [Parameter(Mandatory)][string]$Dir
)

$adb = "$PSScriptRoot\platform-tools\adb.exe"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$deadline = (Get-Date).AddSeconds($Seconds)
$n = 0
while ((Get-Date) -lt $deadline) {
    $name = Join-Path $Dir ("frame-" + (Get-Date -Format 'HHmmss-f') + ".png")
    cmd /c "`"$adb`" -s $Target exec-out screencap -p > `"$name`" 2>nul"
    $n++
}
"$(Get-Date -Format 'HH:mm:ss') saved $n frames in $Dir"
