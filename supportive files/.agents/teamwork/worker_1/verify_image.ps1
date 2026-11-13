Add-Type -AssemblyName System.Drawing
$filePath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
if (Test-Path $filePath) {
    $img = [System.Drawing.Image]::FromFile($filePath)
    $w = $img.Width
    $h = $img.Height
    $ratio = $w / $h
    $target = 9.0 / 16.0
    Write-Host "File: $filePath"
    Write-Host "Width: $w"
    Write-Host "Height: $h"
    Write-Host "Aspect Ratio: $ratio (Expected 9/16 = $target)"
    $diff = [Math]::Abs($ratio - $target)
    Write-Host "Diff: $diff"
    Write-Host "Is 9:16 exact: $($diff -lt 0.005)"
    $img.Dispose()
} else {
    Write-Host "File not found: $filePath"
}
