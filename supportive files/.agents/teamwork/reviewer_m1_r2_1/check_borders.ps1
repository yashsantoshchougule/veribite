Add-Type -AssemblyName System.Drawing
$imgPath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$bmp = New-Object System.Drawing.Bitmap($imgPath)
$w = $bmp.Width
$h = $bmp.Height

Write-Output "Finding vertical borders across Y=30, 80, 500, 1000..."

foreach ($y in @(30, 80, 300, 700, 1150)) {
    # Check left edge transition
    $leftBg = $bmp.GetPixel(5, $y)
    $leftBorder = 0
    for ($x = 5; $x -lt 300; $x++) {
        $p = $bmp.GetPixel($x, $y)
        $diff = [math]::Abs($p.R - $leftBg.R) + [math]::Abs($p.G - $leftBg.G) + [math]::Abs($p.B - $leftBg.B)
        if ($diff -gt 15) {
            $leftBorder = $x
            break
        }
    }

    # Check right edge transition
    $rightBg = $bmp.GetPixel($w - 6, $y)
    $rightBorder = $w - 1
    for ($x = $w - 6; $x -gt 400; $x--) {
        $p = $bmp.GetPixel($x, $y)
        $diff = [math]::Abs($p.R - $rightBg.R) + [math]::Abs($p.G - $rightBg.G) + [math]::Abs($p.B - $rightBg.B)
        if ($diff -gt 15) {
            $rightBorder = $x
            break
        }
    }

    Write-Output ("y={0,4}: Left border at x={1,3} (p={2},{3},{4}), Right border at x={5,3} (p={6},{7},{8}) -> Inner Width={9}" -f `
        $y, $leftBorder, $leftBg.R, $leftBg.G, $leftBg.B, `
        $rightBorder, $rightBg.R, $rightBg.G, $rightBg.B, ($rightBorder - $leftBorder))
}

$bmp.Dispose()
