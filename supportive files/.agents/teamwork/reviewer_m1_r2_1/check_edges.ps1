Add-Type -AssemblyName System.Drawing
$imgPath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$bmp = New-Object System.Drawing.Bitmap($imgPath)
$w = $bmp.Width
$h = $bmp.Height

Write-Output "Top 40 pixels at center (x=384):"
for ($y = 0; $y -lt 40; $y += 5) {
    $p = $bmp.GetPixel(384, $y)
    Write-Output ("y={0,3}: R={1,3} G={2,3} B={3,3}" -f $y, $p.R, $p.G, $p.B)
}

Write-Output "Bottom 40 pixels at center (x=384):"
for ($y = $h - 40; $y -lt $h; $y += 5) {
    $p = $bmp.GetPixel(384, $y)
    Write-Output ("y={0,3}: R={1,3} G={2,3} B={3,3}" -f $y, $p.R, $p.G, $p.B)
}

# Check corner pixels
Write-Output "Corners:"
Write-Output ("(0,0): {0}" -f $bmp.GetPixel(0, 0))
Write-Output ("(767,0): {0}" -f $bmp.GetPixel($w - 1, 0))
Write-Output ("(0,1375): {0}" -f $bmp.GetPixel(0, $h - 1))
Write-Output ("(767,1375): {0}" -f $bmp.GetPixel($w - 1, $h - 1))

$bmp.Dispose()
