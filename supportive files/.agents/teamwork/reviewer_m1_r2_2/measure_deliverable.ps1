Add-Type -AssemblyName System.Drawing

$src = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$img = [System.Drawing.Image]::FromFile($src)
$bmp = New-Object System.Drawing.Bitmap($img)

Write-Host "Target Deliverable Dimensions: $($bmp.Width) x $($bmp.Height)"

# 1. Card horizontal span at y = 600
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
Write-Host "Card bounds at y=${y}: Left=${cardLeft}, Right=${cardRight}, Width=$($cardRight - $cardLeft) px"

# 2. Card vertical span at x = 384 (center)
$x = 384
$cardTop = -1
$cardBottom = -1
for ($y = 400; $y -lt 1200; $y++) {
    $p = $bmp.GetPixel($x, $y)
    if ($p.R -gt 245 -and $p.G -gt 245 -and $p.B -gt 245) {
        if ($cardTop -eq -1) { $cardTop = $y }
        $cardBottom = $y
    }
}
Write-Host "Card vertical bounds at x=${x}: Top=${cardTop}, Bottom=${cardBottom}, Height=$($cardBottom - $cardTop) px"

# 3. Primary CTA button bounds at y = 1180
$y = 1180
$ctaLeft = -1
$ctaRight = -1
for ($x = 0; $x -lt $bmp.Width; $x++) {
    $p = $bmp.GetPixel($x, $y)
    if ($p.G -gt 100 -and $p.R -lt 50 -and $p.B -lt 100) {
        if ($ctaLeft -eq -1) { $ctaLeft = $x }
        $ctaRight = $x
    }
}
Write-Host "Primary CTA at y=${y}: Left=${ctaLeft}, Right=${ctaRight}, Width=$($ctaRight - $ctaLeft) px"

# 4. Secondary CTA button bounds at y = 1250 (outlined button)
$y = 1250
$secLeft = -1
$secRight = -1
for ($x = 0; $x -lt $bmp.Width; $x++) {
    $p = $bmp.GetPixel($x, $y)
    # Check for white interior / outline
    if ($p.R -gt 240 -and $p.G -gt 240 -and $p.B -gt 240) {
        if ($secLeft -eq -1) { $secLeft = $x }
        $secRight = $x
    }
}
Write-Host "Secondary CTA at y=${y}: Interior Left=${secLeft}, Right=${secRight}, Width=$($secRight - $secLeft) px"

# 5. Chip rows content span
function Get-ContentSpan($rowY) {
    $pLeft = -1
    $pRight = -1
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $p = $bmp.GetPixel($x, $rowY)
        if ($p.R -lt 220 -or $p.G -lt 220 -or $p.B -lt 220) {
            if ($pLeft -eq -1) { $pLeft = $x }
            $pRight = $x
        }
    }
    Write-Host "Content at y=${rowY}: Left=${pLeft}, Right=${pRight}, Width=$($pRight - $pLeft) px"
}

Get-ContentSpan 735
Get-ContentSpan 840

$bmp.Dispose()
$img.Dispose()
