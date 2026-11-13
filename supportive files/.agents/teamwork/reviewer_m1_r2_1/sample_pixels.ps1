Add-Type -AssemblyName System.Drawing
$imgPath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$bmp = New-Object System.Drawing.Bitmap($imgPath)
$w = $bmp.Width
$h = $bmp.Height

Write-Output "Dimensions: $w x $h"

function SampleRow($y) {
    Write-Output "=== Row y=$y ==="
    for ($x = 0; $x -lt $w; $x += 40) {
        $p = $bmp.GetPixel($x, $y)
        Write-Output ("x={0,3}: R={1,3} G={2,3} B={3,3}" -f $x, $p.R, $p.G, $p.B)
    }
}

SampleRow 30
SampleRow 80
SampleRow 200
SampleRow 450
SampleRow 700
SampleRow 1150
SampleRow 1300

$bmp.Dispose()
