Add-Type -AssemblyName System.Drawing
$imgPath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$bmp = New-Object System.Drawing.Bitmap($imgPath)

Write-Output "Sampling pixels around left transition (x=75 to 90) at y=200, 600, 1000:"
foreach ($y in @(200, 600, 1000)) {
    Write-Output "--- y=$y ---"
    for ($x = 75; $x -le 90; $x++) {
        $p = $bmp.GetPixel($x, $y)
        Write-Output ("x={0,3}: R={1,3} G={2,3} B={3,3}" -f $x, $p.R, $p.G, $p.B)
    }
}

Write-Output "Sampling pixels around right transition (x=675 to 695) at y=200, 600, 1000:"
foreach ($y in @(200, 600, 1000)) {
    Write-Output "--- y=$y ---"
    for ($x = 675; $x -le 695; $x++) {
        $p = $bmp.GetPixel($x, $y)
        Write-Output ("x={0,3}: R={1,3} G={2,3} B={3,3}" -f $x, $p.R, $p.G, $p.B)
    }
}

$bmp.Dispose()
