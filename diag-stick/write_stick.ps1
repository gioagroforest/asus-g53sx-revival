# Runs elevated. Erases ONLY a disk matching every check below, then writes the image.
# Expected contents are the Ubuntu installer or an earlier copy of this stick.
# It refuses if it finds any other files, so it cannot wipe a stick swapped in by mistake.
param(
    [Parameter(Mandatory)][string]$Image,
    [Parameter(Mandatory)][string]$Writer,
    [Parameter(Mandatory)][string]$Log,
    [string]$Reader,
    [string]$SaveHeader
)
$ErrorActionPreference = 'Stop'
Start-Transcript -LiteralPath $Log -Force | Out-Null
$exit = 1
try {
    $expectedName = 'General UDisk'
    $candidates = @(Get-Disk | Where-Object { $_.FriendlyName -eq $expectedName })
    if ($candidates.Count -ne 1) { throw "Expected exactly one '$expectedName' disk, found $($candidates.Count)" }
    $disk = $candidates[0]
    $gb = $disk.Size / 1GB

    if ($disk.BusType -ne 'USB')  { throw "Refusing: bus type is $($disk.BusType), not USB" }
    if ($disk.IsBoot -or $disk.IsSystem) { throw 'Refusing: disk is a boot or system disk' }
    if ($disk.IsReadOnly)         { throw 'Refusing: disk is read-only' }
    if ($gb -lt 7 -or $gb -gt 8)  { throw "Refusing: size is $([math]::Round($gb,2)) GB, expected about 7.5 GB" }
    if ((Get-Item -LiteralPath $Image).Length -ge $disk.Size) { throw 'Refusing: image is larger than the disk' }

    $allowed = 'boot','casper','dists','EFI','install','pool','preseed','.disk','boot.catalog','md5sum.txt','ubuntu',
               'diag','LOGS','TESTS','config.txt','README.txt','grub-extra.cfg','wifi.conf','System Volume Information'
    foreach ($p in @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object DriveLetter)) {
        $root = "$($p.DriveLetter):\"
        $items = @()
        try { $items = @(Get-ChildItem -LiteralPath $root -Force -ErrorAction Stop) } catch { "($root is not readable, treated as no user files)" }
        $unknown = @($items | Where-Object { $allowed -notcontains $_.Name })
        if ($unknown.Count -gt 0) { throw "Refusing: unexpected files on ${root}: $(($unknown | Select-Object -First 5 -ExpandProperty Name) -join ', ')" }
    }

    "Target: disk $($disk.Number), $($disk.FriendlyName), $($disk.BusType), $([math]::Round($gb,2)) GB"
    "Partitions before erasing:"
    Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | ForEach-Object { "  $($_.PartitionNumber) $($_.Type) offset=$($_.Offset) size=$($_.Size)" }
    # Keeps the old partition tables as evidence, before they are erased.
    if ($Reader -and $SaveHeader) {
        & python -I $Reader $disk.Number 0 1048576 $SaveHeader | ForEach-Object { "$_" }
        if ($LASTEXITCODE -ne 0) { throw 'Could not save the old partition tables, not erasing' }
    }
    Clear-Disk -Number $disk.Number -RemoveData -RemoveOEM -Confirm:$false
    Start-Sleep -Seconds 2
    & python -I $Writer $Image $disk.Number | ForEach-Object { "$_" }
    $exit = $LASTEXITCODE
    Update-Disk -Number $disk.Number -ErrorAction SilentlyContinue
}
catch {
    "ERROR: $_"
}
finally {
    "EXIT CODE: $exit"
    Stop-Transcript | Out-Null
}
exit $exit
