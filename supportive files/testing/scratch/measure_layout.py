import numpy as np
from PIL import Image

ASSET_PATH = r"c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"

def analyze_layout():
    img = Image.open(ASSET_PATH)
    arr = np.array(img)
    h, w, c = arr.shape
    print(f"Image shape: {w}x{h}, channels: {c}")

    # Let's check row brightness and color profiles
    # Mean color along rows
    row_means = arr.mean(axis=1) # (h, 3)
    col_means = arr.mean(axis=0) # (w, 3)

    # Let's inspect the card boundaries
    # The card is a white container on a light greenish background.
    # Let's find rows where y is in the middle of the screen: y in [450, 1050]
    # Let's print colors across x at y = 600, 700, 800, 900
    for y in [460, 500, 600, 720, 800, 950, 1040, 1080, 1160, 1260, 1350]:
        row = arr[y]
        # find where it is white (R>245, G>245, B>245) or near white
        white_mask = (row[:, 0] > 248) & (row[:, 1] > 248) & (row[:, 2] > 248)
        white_indices = np.where(white_mask)[0]
        if len(white_indices) > 0:
            print(f"y={y}: White region x=[{white_indices[0]}, {white_indices[-1]}], width={white_indices[-1]-white_indices[0]+1}")
        else:
            print(f"y={y}: No pure white pixels; min RGB={row.min(axis=0)}, max RGB={row.max(axis=0)}")

    # Let's find the card container bounding box
    # White card typically has background (255, 255, 255) or close to it, whereas canvas background is ~ (230, 235, 235)
    # Let's create a mask of pixels where R > 250, G > 250, B > 250
    card_mask = (arr[:, :, 0] > 250) & (arr[:, :, 1] > 250) & (arr[:, :, 2] > 250)
    # The card is in the vertical range [450, 1100]
    sub_mask = card_mask[450:1100, :]
    y_indices, x_indices = np.where(sub_mask)
    if len(y_indices) > 0:
        card_top = y_indices.min() + 450
        card_bottom = y_indices.max() + 450
        card_left = x_indices.min()
        card_right = x_indices.max()
        print(f"\nEstimated Card Container Bounding Box:")
        print(f"  Top: {card_top}, Bottom: {card_bottom}, Height: {card_bottom - card_top + 1}")
        print(f"  Left: {card_left}, Right: {card_right}, Width: {card_right - card_left + 1}")
        print(f"  Left margin: {card_left} px, Right margin: {w - 1 - card_right} px")

    # Let's inspect the Primary CTA (Green button)
    # Primary CTA is green. Let's find green pixels (G > 100, G > R + 30, G > B + 30) below y=1100
    green_mask = (arr[:, :, 1] > 90) & (arr[:, :, 1] > arr[:, :, 0] + 30) & (arr[:, :, 1] > arr[:, :, 2] + 20)
    cta_primary_mask = green_mask[1100:1220, :]
    py_indices, px_indices = np.where(cta_primary_mask)
    if len(py_indices) > 0:
        btn1_top = py_indices.min() + 1100
        btn1_bottom = py_indices.max() + 1100
        btn1_left = px_indices.min()
        btn1_right = px_indices.max()
        print(f"\nPrimary CTA (Green Button) Bounding Box:")
        print(f"  Top: {btn1_top}, Bottom: {btn1_bottom}, Height: {btn1_bottom - btn1_top + 1}")
        print(f"  Left: {btn1_left}, Right: {btn1_right}, Width: {btn1_right - btn1_left + 1}")
        print(f"  Left margin: {btn1_left} px, Right margin: {w - 1 - btn1_right} px")

    # Let's inspect Secondary CTA (Outlined Button) around y=1220..1320
    # Let's find dark outline pixels in y=1220..1320
    # Button is outlined with green/dark border and has camera icon
    btn2_mask = (arr[1220:1320, :, 1] > arr[1220:1320, :, 0] + 15) & (arr[1220:1320, :, 1] < 150)
    sy_indices, sx_indices = np.where(btn2_mask)
    if len(sy_indices) > 0:
        btn2_top = sy_indices.min() + 1220
        btn2_bottom = sy_indices.max() + 1220
        btn2_left = sx_indices.min()
        btn2_right = sx_indices.max()
        print(f"\nSecondary CTA (Outlined Button) Bounding Box:")
        print(f"  Top: {btn2_top}, Bottom: {btn2_bottom}, Height: {btn2_bottom - btn2_top + 1}")
        print(f"  Left: {btn2_left}, Right: {btn2_right}, Width: {btn2_right - btn2_left + 1}")
        print(f"  Left margin: {btn2_left} px, Right margin: {w - 1 - btn2_right} px")

    # Let's inspect Home Bar at the bottom
    # Home bar is black/dark horizontal pill near y=1340..1370
    home_mask = (arr[1340:1370, :, 0] < 50) & (arr[1340:1370, :, 1] < 50) & (arr[1340:1370, :, 2] < 50)
    hy_indices, hx_indices = np.where(home_mask)
    if len(hy_indices) > 0:
        home_top = hy_indices.min() + 1340
        home_bottom = hy_indices.max() + 1340
        home_left = hx_indices.min()
        home_right = hx_indices.max()
        print(f"\nHome Bar Indicator Bounding Box:")
        print(f"  Top: {home_top}, Bottom: {home_bottom}, Height: {home_bottom - home_top + 1}")
        print(f"  Left: {home_left}, Right: {home_right}, Width: {home_right - home_left + 1}")

    # Let's inspect Profile Type Segmented Button
    # Inside the card, between y=470 and 560
    # Active segment (Adult 65kg) is filled green
    adult_seg_mask = green_mask[470:560, :]
    ay_indices, ax_indices = np.where(adult_seg_mask)
    if len(ay_indices) > 0:
        seg_top = ay_indices.min() + 470
        seg_bottom = ay_indices.max() + 470
        seg_left = ax_indices.min()
        seg_right = ax_indices.max()
        print(f"\nSegmented Button - Adult Segment (Green):")
        print(f"  Top: {seg_top}, Bottom: {seg_bottom}, Height: {seg_bottom - seg_top + 1}")
        print(f"  Left: {seg_left}, Right: {seg_right}, Width: {seg_right - seg_left + 1}")

    # Let's inspect Language Chips
    # Chips are between y=880 and 1060
    # Active chip (English) has light green/mint fill or checkmark
    # Let's find chip boundaries
    print("\n--- Inspecting Language Chips Region (y=880..1060) ---")

if __name__ == "__main__":
    analyze_layout()
