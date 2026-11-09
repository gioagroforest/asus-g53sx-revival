# Tiles the same crop from many frames into one labelled image, to compare them over time.
param(
    [Parameter(Mandatory)][string]$Dir,
    [Parameter(Mandatory)][string]$Out,
    [int]$X, [int]$Y, [int]$W, [int]$H,
    [int]$Cols = 3,
    [double]$Scale = 1,
    [string]$From = '',
    [string]$To = 'zzz'
)
Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem $Dir -Filter 'frame-*.png' | Where-Object { $_.Length -gt 100000 -and $_.BaseName.Substring(6) -ge $From -and $_.BaseName.Substring(6) -le $To } | Sort-Object Name
$tw = [int]($W * $Scale); $th = [int]($H * $Scale); $label = 18
$rows = [math]::Ceiling($files.Count / $Cols)
$sheet = New-Object System.Drawing.Bitmap ($tw * $Cols), (($th + $label) * $rows)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::Black)
$font = New-Object System.Drawing.Font 'Arial', 10
$i = 0
foreach ($f in $files) {
    try { $src = [System.Drawing.Image]::FromFile($f.FullName) } catch { continue }
    $cx = ($i % $Cols) * $tw
    $cy = [math]::Floor($i / $Cols) * ($th + $label)
    $g.DrawString($f.BaseName.Substring(6), $font, [System.Drawing.Brushes]::Yellow, [single]$cx, [single]$cy)
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle $cx, ($cy + $label), $tw, $th), (New-Object System.Drawing.Rectangle $X, $Y, $W, $H), [System.Drawing.GraphicsUnit]::Pixel)
    $src.Dispose()
    $i++
}
$sheet.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $sheet.Dispose()
"saved $Out with $i tiles"
