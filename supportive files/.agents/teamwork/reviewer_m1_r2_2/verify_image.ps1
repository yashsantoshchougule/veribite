Add-Type -AssemblyName System.Drawing
$imgPath = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$img = [System.Drawing.Image]::FromFile($imgPath)
$fileInfo = Get-Item $imgPath
[PSCustomObject]@{
    Length = $fileInfo.Length
    LastWriteTime = $fileInfo.LastWriteTime
    Width = $img.Width
    Height = $img.Height
    PixelFormat = $img.PixelFormat.ToString()
    HorizontalResolution = $img.HorizontalResolution
    VerticalResolution = $img.VerticalResolution
    AspectRatio = [math]::Round($img.Height / $img.Width, 4)
    Expected9to16 = [math]::Round(16.0 / 9.0, 4)
} | Format-List
$img.Dispose()
