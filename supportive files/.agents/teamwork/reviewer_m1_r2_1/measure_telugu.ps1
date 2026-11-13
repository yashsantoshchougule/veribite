Add-Type -AssemblyName System.Drawing
$imgPath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$bmp = New-Object System.Drawing.Bitmap($imgPath)
$w = $bmp.Width
$h = $bmp.Height

# Measure Telugu chip in Row 2
# y is approximately 950-1050
Write-Output "Scanning Telugu chip region (Row 2, y=960 to y=1040)..."

# Find Telugu chip bounds
$teluguLeft = -1
$teluguRight = -1
$teluguTop = -1
$teluguBottom = -1

# Let's inspect a horizontal slice across Row 2 at y=1000
for ($x = 250; $x -lt 500; $x++) {
    $p = $bmp.GetPixel($x, 1000)
    # Check for dark border of Telugu chip
    if ($p.R -lt 100 -and $p.G -lt 100 -and $p.B -lt 100) {
        Write-Output ("Dark border pixel at x={0}: ({1},{2},{3})" -f $x, $p.R, $p.G, $p.B)
    }
}

$bmp.Dispose()
