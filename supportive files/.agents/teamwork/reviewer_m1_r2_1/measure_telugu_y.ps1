Add-Type -AssemblyName System.Drawing
$imgPath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$bmp = New-Object System.Drawing.Bitmap($imgPath)

Write-Output "Scanning vertical span of Telugu chip around x=350..."
for ($y = 960; $y -lt 1060; $y += 5) {
    $p = $bmp.GetPixel(350, $y)
    Write-Output ("y={0,4}: R={1,3} G={2,3} B={3,3}" -f $y, $p.R, $p.G, $p.B)
}

$bmp.Dispose()
