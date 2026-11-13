Add-Type -AssemblyName System.Drawing

$filePath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
if (-not (Test-Path $filePath)) {
    Write-Error "File not found: $filePath"
    exit 1
}

$fileItem = Get-Item $filePath
Write-Output "File Name: $($fileItem.Name)"
Write-Output "File Size: $($fileItem.Length) bytes"
Write-Output "Last Write Time: $($fileItem.LastWriteTime)"

$img = [System.Drawing.Image]::FromFile($filePath)
$width = $img.Width
$height = $img.Height
$ratio = [math]::Round($height / $width, 4)
$expected = [math]::Round(16 / 9, 4)

Write-Output "Dimensions: $width x $height"
Write-Output "Aspect Ratio: $ratio (Expected 16:9 = $expected)"

$bmp = New-Object System.Drawing.Bitmap($img)
$pTopLeft = $bmp.GetPixel(5, 5)
$pTopRight = $bmp.GetPixel($width - 6, 5)
$pMidLeft = $bmp.GetPixel(5, [int]($height / 2))
$pMidRight = $bmp.GetPixel($width - 6, [int]($height / 2))
$pBottomLeft = $bmp.GetPixel(5, $height - 6)
$pBottomRight = $bmp.GetPixel($width - 6, $height - 6)

Write-Output "Pixel (5,5): R=$($pTopLeft.R), G=$($pTopLeft.G), B=$($pTopLeft.B)"
Write-Output "Pixel ($($width-6),5): R=$($pTopRight.R), G=$($pTopRight.G), B=$($pTopRight.B)"
Write-Output "Pixel (5,$([int]($height/2))): R=$($pMidLeft.R), G=$($pMidLeft.G), B=$($pMidLeft.B)"
Write-Output "Pixel ($($width-6),$([int]($height/2))): R=$($pMidRight.R), G=$($pMidRight.G), B=$($pMidRight.B)"
Write-Output "Pixel (5,$($height-6)): R=$($pBottomLeft.R), G=$($pBottomLeft.G), B=$($pBottomLeft.B)"
Write-Output "Pixel ($($width-6),$($height-6)): R=$($pBottomRight.R), G=$($pBottomRight.G), B=$($pBottomRight.B)"

$bmp.Dispose()
$img.Dispose()
