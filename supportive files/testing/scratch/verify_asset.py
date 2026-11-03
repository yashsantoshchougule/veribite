import os
import struct
from PIL import Image

ASSET_PATH = r"c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"

def verify_file_and_markers(path):
    print("=== 1. FILE & MARKER VERIFICATION ===")
    assert os.path.exists(path), f"File not found: {path}"
    file_size = os.path.getsize(path)
    print(f"File path: {path}")
    print(f"File size: {file_size} bytes ({file_size / 1024:.2f} KB)")
    
    with open(path, "rb") as f:
        data = f.read()
    
    assert len(data) == file_size
    assert data[0:2] == b"\xff\xd8", "Missing SOI (0xFFD8)"
    print("SOI marker (0xFFD8): OK at offset 0")
    
    offset = 2
    markers = [("SOI", 0, 2)]
    sof0_info = {}
    
    while offset < len(data):
        if data[offset] != 0xff:
            # Inside entropy-coded data (SOS)
            offset += 1
            continue
        marker_byte = data[offset + 1]
        if marker_byte == 0x00: # byte stuffing
            offset += 2
            continue
        if marker_byte == 0xd9: # EOI
            markers.append(("EOI", offset, 2))
            print(f"EOI marker (0xFFD9): OK at offset {offset}")
            trailing = len(data) - (offset + 2)
            print(f"Trailing bytes after EOI: {trailing}")
            assert trailing == 0, f"Unexpected trailing bytes: {trailing}"
            break
        
        # Standalone markers without length
        if marker_byte in (0xd8, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7):
            markers.append((f"0xFF{marker_byte:02X}", offset, 2))
            offset += 2
            continue
        
        # Markers with length
        length = struct.unpack(">H", data[offset+2:offset+4])[0]
        marker_name = f"0xFF{marker_byte:02X}"
        if marker_byte == 0xe0:
            marker_name = "APP0 (JFIF)"
            jfif_tag = data[offset+4:offset+9]
            print(f"APP0 JFIF Tag: {jfif_tag.decode('ascii', errors='replace')} at offset {offset}, len {length}")
        elif marker_byte == 0xc0:
            marker_name = "SOF0 (Baseline)"
            precision, height, width, n_comp = struct.unpack(">BHHB", data[offset+4:offset+10])
            sof0_info = {
                "offset": offset,
                "length": length,
                "precision": precision,
                "height": height,
                "width": width,
                "components": n_comp
            }
            print(f"SOF0 Frame: Width={width}, Height={height}, Precision={precision}bpc, Components={n_comp} at offset {offset}")
        elif marker_byte == 0xdb:
            marker_name = "DQT"
        elif marker_byte == 0xc4:
            marker_name = "DHT"
        elif marker_byte == 0xda:
            marker_name = "SOS"
            print(f"SOS (Start of Scan) at offset {offset}, len {length}")
            offset += 2 + length
            continue
        
        markers.append((marker_name, offset, length + 2))
        offset += 2 + length
        
    return file_size, sof0_info

def verify_dimensions_and_ratio(sof0_info):
    print("\n=== 2. DIMENSIONS & ASPECT RATIO ===")
    w = sof0_info["width"]
    h = sof0_info["height"]
    ratio_wh = w / h
    ratio_hw = h / w
    target_wh = 9.0 / 16.0 # 0.5625
    target_hw = 16.0 / 9.0 # 1.7777777777777777
    
    delta_wh = abs(ratio_wh - target_wh)
    pct_err_wh = (delta_wh / target_wh) * 100.0
    
    delta_hw = abs(ratio_hw - target_hw)
    pct_err_hw = (delta_hw / target_hw) * 100.0
    
    print(f"Width: {w} px")
    print(f"Height: {h} px")
    print(f"W / H ratio: {ratio_wh:.6f} (Target 9:16 = {target_wh:.6f})")
    print(f"W / H delta: {delta_wh:.6f} ({pct_err_wh:.3f}% variance)")
    print(f"H / W ratio: {ratio_hw:.6f} (Target 16:9 = {target_hw:.6f})")
    print(f"H / W delta: {delta_hw:.6f} ({pct_err_hw:.3f}% variance)")
    
    return w, h, ratio_wh, pct_err_wh

def verify_canvas_framing(img):
    print("\n=== 3. CANVAS FRAMING & EDGE SAMPLING ===")
    w, h = img.size
    pixels = img.load()
    
    # Check top edge (y = 0..10)
    top_pixels = [pixels[x, 0] for x in range(0, w, 20)]
    # Check bottom edge (y = h-1..h-10)
    bot_pixels = [pixels[x, h - 1] for x in range(0, w, 20)]
    # Check left edge (x = 0..10)
    left_pixels = [pixels[0, y] for y in range(0, h, 40)]
    # Check right edge (x = w-1..w-10)
    right_pixels = [pixels[w - 1, y] for y in range(0, h, 40)]
    
    print(f"Top row sample colors (y=0): {top_pixels[:5]} ... {top_pixels[-3:]}")
    print(f"Bottom row sample colors (y={h-1}): {bot_pixels[:5]} ... {bot_pixels[-3:]}")
    print(f"Left col sample colors (x=0): {left_pixels[:5]} ... {left_pixels[-3:]}")
    print(f"Right col sample colors (x={w-1}): {right_pixels[:5]} ... {right_pixels[-3:]}")
    
    # Check if there are black borders or device bezels
    # A device bezel or chassis typically has black/dark gray borders (<50, <50, <50)
    dark_edges = [p for p in (top_pixels + bot_pixels + left_pixels + right_pixels) if sum(p) < 100]
    print(f"Count of dark/black edge samples (<100 sum RGB): {len(dark_edges)} of {len(top_pixels)+len(bot_pixels)+len(left_pixels)+len(right_pixels)}")
    
    # Check corner pixels
    corners = {
        "top-left (0,0)": pixels[0, 0],
        "top-right (w-1, 0)": pixels[w - 1, 0],
        "bottom-left (0, h-1)": pixels[0, h - 1],
        "bottom-right (w-1, h-1)": pixels[w - 1, h - 1]
    }
    for k, v in corners.items():
        print(f"Corner {k}: RGB={v}")
        
    return corners

def main():
    file_size, sof0_info = verify_file_and_markers(ASSET_PATH)
    w, h, ratio_wh, pct_err_wh = verify_dimensions_and_ratio(sof0_info)
    
    img = Image.open(ASSET_PATH)
    print(f"\nPIL Image open: format={img.format}, size={img.size}, mode={img.mode}")
    verify_canvas_framing(img)

if __name__ == "__main__":
    main()
