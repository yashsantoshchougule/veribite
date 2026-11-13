Add-Type -AssemblyName System.Drawing

$filePath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$img = [System.Drawing.Image]::FromFile($filePath)
$bmp = New-Object System.Drawing.Bitmap($img)

# Let's inspect horizontal scanline at y = 100 (hero/header area), y = 500 (card area), y = 800 (chips area), y = 1180 (CTA area)
function Scan-Line($y) {
    Write-Output "--- Scanline at y = $y ---"
    $samples = @(0, 10, 20, 40, 60, 80, 100, 150, 384, 600, 660, 680, 700, 720, 740, 755, 767)
    foreach ($x in $samples) {
        $p = $bmp.GetPixel($x, $y)
        Write-Output "  x=$x : R=$($p.R), G=$($p.G), B=$($p.B)"
    }
}

Scan-Line 100
Scan-Line 420
Scan-Line 750
Scan-Line 850
Scan-Line 1180

$bmp.Dispose()
$img.Dispose()
