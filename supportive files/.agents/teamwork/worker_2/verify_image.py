import os
from PIL import Image

image_path = r"c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
if not os.path.exists(image_path):
    print(f"Error: {image_path} does not exist")
    exit(1)

file_size = os.path.getsize(image_path)
print(f"File size: {file_size} bytes")

with Image.open(image_path) as img:
    width, height = img.size
    aspect_ratio = height / width
    expected_ratio = 16 / 9
    print(f"Dimensions: {width} x {height}")
    print(f"Aspect Ratio: {aspect_ratio:.4f} (Target 16/9: {expected_ratio:.4f})")
    print(f"Format: {img.format}, Mode: {img.mode}")

    # Inspect edge pixels to check canvas fill
    # sample corners and borders
    top_left = img.getpixel((5, 5))
    top_right = img.getpixel((width - 6, 5))
    mid_left = img.getpixel((5, height // 2))
    mid_right = img.getpixel((width - 6, height // 2))
    bottom_left = img.getpixel((5, height - 6))
    bottom_right = img.getpixel((width - 6, height - 6))

    print(f"Pixel at (5, 5): {top_left}")
    print(f"Pixel at ({width-6}, 5): {top_right}")
    print(f"Pixel at (5, {height//2}): {mid_left}")
    print(f"Pixel at ({width-6}, {height//2}): {mid_right}")
    print(f"Pixel at (5, {height-6}): {bottom_left}")
    print(f"Pixel at ({width-6}, {height-6}): {bottom_right}")
