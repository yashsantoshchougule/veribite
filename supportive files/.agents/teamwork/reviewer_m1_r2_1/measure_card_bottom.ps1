Add-Type -AssemblyName System.Drawing
$imgPath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$bmp = New-Object System.Drawing.Bitmap($imgPath)

Write-Output "Scanning from bottom of chip (y=1040) down to Primary CTA button at x=384..."
for ($y = 1040; $y -lt 1160; $y += 5) {
    $p = $bmp.GetPixel(384, $y)
    Write-Output ("y={0,4}: R={1,3} G={2,3} B={3,3}" -f $y, $p.R, $p.G, $p.B)
}

$bmp.Dispose()
