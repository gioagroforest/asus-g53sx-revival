# Runs elevated. Only reads: copies partition 4 of the G53 stick to a file on C:.
param(
    [Parameter(Mandatory)][string]$Reader,
    [Parameter(Mandatory)][string]$Out,
    [Parameter(Mandatory)][string]$Log
)
$ErrorActionPreference = 'Stop'
Start-Transcript -LiteralPath $Log -Force | Out-Null
$exit = 1
try {
    $candidates = @(Get-Disk | Where-Object { $_.FriendlyName -eq 'General UDisk' -and $_.BusType -eq 'USB' })
    if ($candidates.Count -ne 1) { throw "Expected exactly one USB 'General UDisk', found $($candidates.Count)" }
    $disk = $candidates[0]
    $part = Get-Partition -DiskNumber $disk.Number -PartitionNumber 4
    if ($part.GptType -ne '{0fc63daf-8483-4772-8e79-3d69d8477de4}') { throw "Partition 4 is not a Linux partition: $($part.GptType)" }
    "Source: disk $($disk.Number), partition 4, $($part.Size) bytes at offset $($part.Offset)"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
    & python -I $Reader $disk.Number $part.Offset $part.Size $Out | ForEach-Object { "$_" }
    $exit = $LASTEXITCODE
}
catch {
    "ERROR: $_"
}
finally {
    "EXIT CODE: $exit"
    Stop-Transcript | Out-Null
}
exit $exit
