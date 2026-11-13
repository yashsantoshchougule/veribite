Add-Type -AssemblyName System.Drawing

$src = "C:\Users\Yash chougule\.gemini\antigravity\brain\3f62960b-3eed-412d-a1a3-128e70230046\01_onboarding_v2_refined_1793675911661.jpg"
$img = [System.Drawing.Image]::FromFile($src)
$bmp = New-Object System.Drawing.Bitmap($img)

Write-Output "Dimensions: $($bmp.Width) x $($bmp.Height)"

# Find left and right bounds of the white card at y = 600
$y = 600
$leftX = -1
$rightX = -1
for ($x = 0; $x -lt $bmp.Width; $x++) {
    $p = $bmp.GetPixel($x, $y)
    # Check if pixel is white or near white (card)
    if ($p.R -gt 245 -and $p.G -gt 245 -and $p.B -gt 245) {
        if ($leftX -eq -1) { $leftX = $x }
        $rightX = $x
    }
}
Write-Output "Card at y=$($y): left=$leftX, right=$rightX, width=$($rightX - $leftX)"

# Find left and right bounds of primary CTA at y = 1180
$y = 1180
$ctaLeft = -1
$ctaRight = -1
for ($x = 0; $x -lt $bmp.Width; $x++) {
    $p = $bmp.GetPixel($x, $y)
    # Check if pixel is green (CTA)
    if ($p.G -gt 100 -and $p.R -lt 50 -and $p.B -lt 100) {
        if ($ctaLeft -eq -1) { $ctaLeft = $x }
        $ctaRight = $x
    }
}
Write-Output "Primary CTA at y=$($y): left=$ctaLeft, right=$ctaRight, width=$($ctaRight - $ctaLeft)"

# Check language chips bounds at y = 735 (Row 1) and y = 840 (Row 2)
function Check-ChipRow($rowY) {
    $pLeft = -1
    $pRight = -1
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $p = $bmp.GetPixel($x, $rowY)
        # Non-background pixel
        if ($p.R -lt 220 -or $p.G -lt 220 -or $p.B -lt 220) {
            if ($pLeft -eq -1) { $pLeft = $x }
            $pRight = $x
        }
    }
    Write-Output "Content at y=$($rowY): left=$pLeft, right=$pRight, width=$($pRight - $pLeft)"
}

Check-ChipRow 735
Check-ChipRow 840

$bmp.Dispose()
$img.Dispose()
