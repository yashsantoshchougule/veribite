$f1 = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$f2 = "C:\Users\Yash chougule\.gemini\antigravity\brain\3f62960b-3eed-412d-a1a3-128e70230046\01_onboarding_v2_refined_1793675911661.jpg"

Write-Host "=== File Exists Check ==="
Write-Host "Target: $(Test-Path $f1)"
Write-Host "Brain: $(Test-Path $f2)"

Write-Host "`n=== Hash Comparison ==="
Get-FileHash -Path $f1, $f2 -Algorithm SHA256 | Format-List

Write-Host "`n=== Image Dimension & Pixel Check ==="
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($f1)
$bmp = New-Object System.Drawing.Bitmap($img)
Write-Host "Width: $($bmp.Width), Height: $($bmp.Height)"
Write-Host "Aspect Ratio: $([math]::Round($bmp.Height / $bmp.Width, 4)) (Target 16:9 = 1.7778)"

# Check corners and background color to verify 2D flat artboard vs physical chassis/presentation border
$cTL = $bmp.GetPixel(0, 0)
$cTR = $bmp.GetPixel($bmp.Width - 1, 0)
$cBL = $bmp.GetPixel(0, $bmp.Height - 1)
$cBR = $bmp.GetPixel($bmp.Width - 1, $bmp.Height - 1)
Write-Host "Corner pixels (RGB):"
Write-Host "Top-Left (0,0): $($cTL.R), $($cTL.G), $($cTL.B)"
Write-Host "Top-Right (Width-1,0): $($cTR.R), $($cTR.G), $($cTR.B)"
Write-Host "Bottom-Left (0,Height-1): $($cBL.R), $($cBL.G), $($cBL.B)"
Write-Host "Bottom-Right (Width-1,Height-1): $($cBR.R), $($cBR.G), $($cBR.B)"

# Measure card horizontal bounds at y = 600
$y = 600
$cardLeft = -1
$cardRight = -1
for ($x = 0; $x -lt $bmp.Width; $x++) {
    $p = $bmp.GetPixel($x, $y)
    if ($p.R -gt 245 -and $p.G -gt 245 -and $p.B -gt 245) {
        if ($cardLeft -eq -1) { $cardLeft = $x }
        $cardRight = $x
    }
}
Write-Host "Card bounds at y=${y}: Left=${cardLeft}, Right=${cardRight}, Width=$($cardRight - $cardLeft) px ($([math]::Round(($cardRight - $cardLeft) / $bmp.Width * 100, 1))% of canvas)"

# Measure primary CTA button bounds at y = 1180
$y = 1180
$ctaLeft = -1
$ctaRight = -1
for ($x = 0; $x -lt $bmp.Width; $x++) {
    $p = $bmp.GetPixel($x, $y)
    # Dark green button: R < 50, G > 100, B < 100
    if ($p.G -gt 100 -and $p.R -lt 50 -and $p.B -lt 100) {
        if ($ctaLeft -eq -1) { $ctaLeft = $x }
        $ctaRight = $x
    }
}
Write-Host "Primary CTA at y=${y}: Left=${ctaLeft}, Right=${ctaRight}, Width=$($ctaRight - $ctaLeft) px ($([math]::Round(($ctaRight - $ctaLeft) / $bmp.Width * 100, 1))% of canvas)"

$bmp.Dispose()
$img.Dispose()
