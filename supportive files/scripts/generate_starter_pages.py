"""
Generate high-fidelity Material 3 Starter / Onboarding Walkthrough Mobile Screens (1080x1920)
in the 'pages' directory.
"""

import os
from PIL import Image, ImageDraw, ImageFont

PAGES_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "pages")
os.makedirs(PAGES_DIR, exist_ok=True)

# Color Palette (Material 3 Emerald Theme)
BG_LIGHT = (248, 249, 250)
SURFACE_WHITE = (255, 255, 255)
PRIMARY_GREEN = (15, 157, 88)       # #0F9D58
PRIMARY_DARK = (11, 107, 60)
ACCENT_GREEN = (230, 244, 234)      # Light green tint
TEXT_PRIMARY = (32, 33, 36)
TEXT_SECONDARY = (95, 99, 104)
CARD_BORDER = (222, 226, 230)
CARD_BG = (255, 255, 255)
RED_ACCENT = (217, 48, 37)          # Material Red #D93025
RED_LIGHT = (254, 237, 236)
ORANGE_ACCENT = (232, 113, 10)
AMBER_ACCENT = (244, 180, 0)
PURPLE_ACCENT = (142, 36, 170)
BLUE_ACCENT = (26, 115, 232)
BLUE_LIGHT = (232, 240, 254)

WIDTH, HEIGHT = 1080, 1920

def get_font(size: int, bold: bool = False):
    font_names = ["arialbd.ttf" if bold else "arial.ttf", "segoeuib.ttf" if bold else "segoeui.ttf"]
    for fn in font_names:
        try:
            return ImageFont.truetype(fn, size)
        except Exception:
            pass
    return ImageFont.load_default()

FONT_TITLE = get_font(52, bold=True)
FONT_SUBTITLE = get_font(32, bold=False)
FONT_CARD_TITLE = get_font(36, bold=True)
FONT_BODY = get_font(28, bold=False)
FONT_BODY_BOLD = get_font(28, bold=True)
FONT_SMALL = get_font(24, bold=False)
FONT_SMALL_BOLD = get_font(24, bold=True)
FONT_BUTTON = get_font(34, bold=True)
FONT_BADGE = get_font(22, bold=True)
FONT_SCORE = get_font(72, bold=True)

def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)

def draw_status_bar(draw):
    # Time, battery, wifi mock
    font_status = get_font(24, bold=True)
    draw.text((60, 30), "9:41", fill=TEXT_PRIMARY, font=font_status)
    # Right icons
    draw.rounded_rectangle([920, 35, 960, 55], radius=4, outline=TEXT_PRIMARY, width=2)
    draw.rectangle([923, 38, 950, 52], fill=TEXT_PRIMARY)
    draw.rectangle([961, 41, 964, 49], fill=TEXT_PRIMARY)
    draw.text((860, 32), "5G", fill=TEXT_PRIMARY, font=font_status)

def draw_top_nav(draw, current_step, total_steps=4, show_back=True):
    font_skip = get_font(30, bold=True)
    if show_back and current_step > 1:
        # Back arrow
        draw.text((60, 100), "← Back", fill=PRIMARY_GREEN, font=font_skip)
    else:
        # Logo text
        draw.text((60, 100), "🛡️ NutriGuard", fill=PRIMARY_GREEN, font=font_skip)
    
    # Skip button
    if current_step < total_steps:
        draw.text((950, 100), "Skip", fill=TEXT_SECONDARY, font=font_skip)

def draw_dots(draw, active_index, total=4, y=1700):
    start_x = 540 - ((total * 40) // 2)
    for i in range(total):
        cx = start_x + (i * 40) + 15
        if i == active_index:
            # Active pill
            draw_rounded_rect(draw, [cx - 20, y - 6, cx + 20, y + 6], radius=6, fill=PRIMARY_GREEN)
        else:
            # Inactive dot
            draw.ellipse([cx - 6, y - 6, cx + 6, y + 6], fill=(200, 204, 209))

def create_base_canvas():
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_LIGHT)
    draw = ImageDraw.Draw(img)
    draw_status_bar(draw)
    return img, draw

# ==============================================================================
# Screen 1: Point & Scan Backside Food Label
# ==============================================================================
def render_screen_1():
    img, draw = create_base_canvas()
    draw_top_nav(draw, current_step=1, show_back=False)

    # Hero Card (Camera Scanner Viewfinder Simulation)
    card_bbox = [60, 180, 1020, 1200]
    draw_rounded_rect(draw, card_bbox, radius=32, fill=(24, 28, 36), outline=(40, 48, 60), width=2)

    # Scanner Reticle
    reticle_bbox = [180, 300, 900, 940]
    draw_rounded_rect(draw, reticle_bbox, radius=24, outline=PRIMARY_GREEN, width=4)

    # Simulated Food Label inside reticle
    label_bbox = [240, 360, 840, 880]
    draw_rounded_rect(draw, label_bbox, radius=16, fill=(255, 255, 255))
    draw.text((280, 400), "NUTRITION FACTS (per 100g)", fill=TEXT_PRIMARY, font=FONT_BODY_BOLD)
    draw.line([(280, 440), (800, 440)], fill=(200, 200, 200), width=2)
    draw.text((280, 460), "Energy: 480 kcal", fill=TEXT_SECONDARY, font=FONT_SMALL)
    draw.text((280, 500), "Total Sugars: 32.0 g ⚠️ (High)", fill=RED_ACCENT, font=FONT_SMALL_BOLD)
    draw.text((280, 540), "Saturated Fat: 14.0 g", fill=TEXT_SECONDARY, font=FONT_SMALL)
    draw.text((280, 580), "Sodium: 220 mg", fill=TEXT_SECONDARY, font=FONT_SMALL)
    draw.line([(280, 620), (800, 620)], fill=(200, 200, 200), width=2)
    draw.text((280, 640), "INGREDIENTS:", fill=TEXT_PRIMARY, font=FONT_SMALL_BOLD)
    draw.text((280, 680), "Refined Wheat Flour, Sugar, Palm Oil,", fill=TEXT_SECONDARY, font=FONT_SMALL)
    draw.text((280, 715), "Liquid Glucose, INS 110 (Azo Dye),", fill=RED_ACCENT, font=FONT_SMALL_BOLD)
    draw.text((280, 750), "Maltodextrin, Emulsifiers.", fill=TEXT_SECONDARY, font=FONT_SMALL)

    # Barcode graphics at bottom of label
    for bx in range(300, 780, 16):
        bw = 6 if bx % 32 == 0 else 3
        draw.rectangle([bx, 800, bx + bw, 850], fill=(0, 0, 0))

    # Real-time scan laser line
    draw.line([(180, 620), (900, 620)], fill=(0, 230, 118), width=4)

    # Scanner Badge on top of hero card
    badge_bbox = [300, 220, 780, 280]
    draw_rounded_rect(draw, badge_bbox, radius=20, fill=PRIMARY_GREEN)
    draw.text((340, 235), "⚡ 100% Offline AI Scanner", fill=SURFACE_WHITE, font=FONT_BODY_BOLD)

    # Content Section
    step_pill = [60, 1260, 250, 1310]
    draw_rounded_rect(draw, step_pill, radius=12, fill=ACCENT_GREEN)
    draw.text((80, 1272), "STEP 1 OF 4", fill=PRIMARY_DARK, font=FONT_BADGE)

    draw.text((60, 1340), "Point & Scan Food Packet", fill=TEXT_PRIMARY, font=FONT_TITLE)
    draw.text(
        (60, 1420),
        "Instantly scan backside nutrition tables, barcodes, and\n"
        "ingredient lists on any packaged snack or beverage.\n"
        "Works completely offline with zero mobile data or Wi-Fi.",
        fill=TEXT_SECONDARY,
        font=FONT_SUBTITLE,
        spacing=12,
    )

    # Navigation Dots & Primary CTA
    draw_dots(draw, active_index=0)
    btn_bbox = [60, 1760, 1020, 1860]
    draw_rounded_rect(draw, btn_bbox, radius=28, fill=PRIMARY_GREEN)
    draw.text((450, 1785), "Next Step →", fill=SURFACE_WHITE, font=FONT_BUTTON)

    out_path = os.path.join(PAGES_DIR, "01_starter_step1_scan.png")
    img.save(out_path, quality=95)
    print("Saved:", out_path)

# ==============================================================================
# Screen 2: Detect Hidden Sugars & 39/100 Hard Red Cap
# ==============================================================================
def render_screen_2():
    img, draw = create_base_canvas()
    draw_top_nav(draw, current_step=2, show_back=True)

    # Hero Card (Verdict & Toxicology Alert)
    card_bbox = [60, 180, 1020, 1200]
    draw_rounded_rect(draw, card_bbox, radius=32, fill=SURFACE_WHITE, outline=CARD_BORDER, width=2)

    # Circular Gauge graphic
    gauge_center = (540, 380)
    draw.arc([360, 200, 720, 560], start=135, end=405, fill=RED_ACCENT, width=28)
    draw.text((470, 310), "22", fill=RED_ACCENT, font=FONT_SCORE)
    draw.text((460, 410), "Score / 100", fill=TEXT_SECONDARY, font=FONT_SMALL)

    # Hard Red Cap Badge
    cap_bbox = [240, 490, 840, 560]
    draw_rounded_rect(draw, cap_bbox, radius=18, fill=RED_LIGHT, outline=RED_ACCENT, width=2)
    draw.text((280, 508), "🔒 39/100 Hard Red Cap Triggered", fill=RED_ACCENT, font=FONT_BODY_BOLD)

    # Split Sugar Cluster Card
    sugar_box = [110, 600, 970, 790]
    draw_rounded_rect(draw, sugar_box, radius=20, fill=(255, 248, 240), outline=(255, 218, 185), width=2)
    draw.text((140, 620), "🍬 Split-Sugar Hidden Sweetener Cluster", fill=ORANGE_ACCENT, font=FONT_BODY_BOLD)
    draw.text((140, 665), "Manufacturers split sugar across multiple aliases to push it down", fill=TEXT_SECONDARY, font=FONT_SMALL)
    draw.text((140, 700), "the ingredient list. We aggregate them all:", fill=TEXT_SECONDARY, font=FONT_SMALL)
    draw.text((140, 735), "• Sugar • Liquid Glucose • Invert Syrup • Maltodextrin (32%)", fill=TEXT_PRIMARY, font=FONT_SMALL_BOLD)

    # Additive Risk Card
    tox_box = [110, 820, 970, 1010]
    draw_rounded_rect(draw, tox_box, radius=20, fill=RED_LIGHT, outline=RED_ACCENT, width=2)
    draw.text((140, 840), "⚠️ Dangerous Additive Detected: INS 110", fill=RED_ACCENT, font=FONT_BODY_BOLD)
    draw.text((140, 885), "Sunset Yellow FCF (Synthetic Azo Dye)", fill=TEXT_PRIMARY, font=FONT_SMALL_BOLD)
    draw.text((140, 920), "Banned in EU schools. Clinical links to child hyperactivity,", fill=TEXT_SECONDARY, font=FONT_SMALL)
    draw.text((140, 955), "allergies & cellular DNA mutations [JECFA 2011].", fill=TEXT_SECONDARY, font=FONT_SMALL)

    # Nova Tag
    nova_box = [110, 1040, 480, 1100]
    draw_rounded_rect(draw, nova_box, radius=14, fill=RED_ACCENT)
    draw.text((140, 1055), "NOVA 4 — Ultra-Processed", fill=SURFACE_WHITE, font=FONT_BADGE)

    # Content Section
    step_pill = [60, 1260, 250, 1310]
    draw_rounded_rect(draw, step_pill, radius=12, fill=ACCENT_GREEN)
    draw.text((80, 1272), "STEP 2 OF 4", fill=PRIMARY_DARK, font=FONT_BADGE)

    draw.text((60, 1340), "Unmask Hidden Sugars & Toxins", fill=TEXT_PRIMARY, font=FONT_TITLE)
    draw.text(
        (60, 1420),
        "Our deterministic toxicology database flags 1,200+ chemical\n"
        "additives and clusters 56+ hidden sugar aliases.\n"
        "If a harmful chemical is present, a 39/100 Cap locks the score.",
        fill=TEXT_SECONDARY,
        font=FONT_SUBTITLE,
        spacing=12,
    )

    # Navigation Dots & Action Row
    draw_dots(draw, active_index=1)
    # Back button + Next button
    back_btn = [60, 1760, 360, 1860]
    draw_rounded_rect(draw, back_btn, radius=28, fill=SURFACE_WHITE, outline=PRIMARY_GREEN, width=2)
    draw.text((160, 1785), "← Back", fill=PRIMARY_GREEN, font=FONT_BUTTON)

    next_btn = [400, 1760, 1020, 1860]
    draw_rounded_rect(draw, next_btn, radius=28, fill=PRIMARY_GREEN)
    draw.text((640, 1785), "Next Step →", fill=SURFACE_WHITE, font=FONT_BUTTON)

    out_path = os.path.join(PAGES_DIR, "02_starter_step2_toxicology.png")
    img.save(out_path, quality=95)
    print("Saved:", out_path)

# ==============================================================================
# Screen 3: Personalized Safe Dosage & Portion Math
# ==============================================================================
def render_screen_3():
    img, draw = create_base_canvas()
    draw_top_nav(draw, current_step=3, show_back=True)

    # Hero Card (Portion Prescribing & Guardrails)
    card_bbox = [60, 180, 1020, 1200]
    draw_rounded_rect(draw, card_bbox, radius=32, fill=SURFACE_WHITE, outline=CARD_BORDER, width=2)

    # Active Profile Banner
    prof_box = [110, 220, 970, 320]
    draw_rounded_rect(draw, prof_box, radius=20, fill=BLUE_LIGHT, outline=BLUE_ACCENT, width=2)
    draw.text((150, 240), "👤 Active Profile: Child (20 kg) • Guardrails Active", fill=BLUE_ACCENT, font=FONT_BODY_BOLD)
    draw.text((150, 275), "Diabetic Guard | Hyperactivity Guard | Hypertension Guard", fill=TEXT_SECONDARY, font=FONT_SMALL)

    # Prescribed Portion Big Card
    dose_box = [110, 350, 970, 680]
    draw_rounded_rect(draw, dose_box, radius=24, fill=(240, 249, 244), outline=PRIMARY_GREEN, width=2)
    draw.text((150, 380), "PRESCRIBED SAFE PORTION CEILING", fill=PRIMARY_DARK, font=FONT_SMALL_BOLD)
    draw.text((150, 420), "16 Grams (1 Piece)", fill=TEXT_PRIMARY, font=FONT_SCORE)
    draw.text((150, 510), "Frequency Schedule: Max 2-3 Times / Week", fill=PRIMARY_DARK, font=FONT_BODY_BOLD)
    draw.text((150, 550), "Limiting Factor: 20% WHO Single-Snack Free Sugar Ceiling", fill=RED_ACCENT, font=FONT_SMALL_BOLD)
    draw.text((150, 590), "Single biscuit contains 6.4g sugar (32% of child's daily limit!)", fill=TEXT_SECONDARY, font=FONT_SMALL)

    # Child vs Adult Comparison Bar
    bar_box = [110, 710, 970, 960]
    draw_rounded_rect(draw, bar_box, radius=20, fill=BG_LIGHT, outline=CARD_BORDER, width=2)
    draw.text((150, 735), "JECFA Daily Chemical ADI Intake Comparison", fill=TEXT_PRIMARY, font=FONT_BODY_BOLD)
    
    # Child Bar
    draw.text((150, 780), "Child (20 kg): Max 80 mg/day", fill=RED_ACCENT, font=FONT_SMALL_BOLD)
    draw_rounded_rect(draw, [150, 815, 930, 835], radius=6, fill=(220, 224, 230))
    draw_rounded_rect(draw, [150, 815, 380, 835], radius=6, fill=RED_ACCENT) # 30% width

    # Adult Bar
    draw.text((150, 860), "Adult (65 kg): Max 260 mg/day", fill=PRIMARY_GREEN, font=FONT_SMALL_BOLD)
    draw_rounded_rect(draw, [150, 895, 930, 915], radius=6, fill=(220, 224, 230))
    draw_rounded_rect(draw, [150, 895, 780, 915], radius=6, fill=PRIMARY_GREEN) # 75% width

    # Today's Budget Meter
    budget_box = [110, 990, 970, 1160]
    draw_rounded_rect(draw, budget_box, radius=20, fill=(255, 255, 255), outline=CARD_BORDER, width=2)
    draw.text((150, 1015), "Today's Safe Sugar Budget Log", fill=TEXT_PRIMARY, font=FONT_BODY_BOLD)
    draw.text((750, 1015), "26% Used", fill=PRIMARY_GREEN, font=FONT_BODY_BOLD)
    draw_rounded_rect(draw, [150, 1060, 930, 1080], radius=6, fill=(220, 224, 230))
    draw_rounded_rect(draw, [150, 1060, 350, 1080], radius=6, fill=PRIMARY_GREEN)
    draw.text((150, 1100), "6.4g / 25.0g consumed today • 1 Product Logged", fill=TEXT_SECONDARY, font=FONT_SMALL)

    # Content Section
    step_pill = [60, 1260, 250, 1310]
    draw_rounded_rect(draw, step_pill, radius=12, fill=ACCENT_GREEN)
    draw.text((80, 1272), "STEP 3 OF 4", fill=PRIMARY_DARK, font=FONT_BADGE)

    draw.text((60, 1340), "Personalized Safe Dosage Math", fill=TEXT_PRIMARY, font=FONT_TITLE)
    draw.text(
        (60, 1420),
        "Never guess portion sizes again. Our math engine dynamically\n"
        "scales safe gram limits and piece counts based on exact body\n"
        "weight (Child 20kg vs Adult 65kg) and disease conditions.",
        fill=TEXT_SECONDARY,
        font=FONT_SUBTITLE,
        spacing=12,
    )

    # Navigation Dots & Action Row
    draw_dots(draw, active_index=2)
    back_btn = [60, 1760, 360, 1860]
    draw_rounded_rect(draw, back_btn, radius=28, fill=SURFACE_WHITE, outline=PRIMARY_GREEN, width=2)
    draw.text((160, 1785), "← Back", fill=PRIMARY_GREEN, font=FONT_BUTTON)

    next_btn = [400, 1760, 1020, 1860]
    draw_rounded_rect(draw, next_btn, radius=28, fill=PRIMARY_GREEN)
    draw.text((640, 1785), "Next Step →", fill=SURFACE_WHITE, font=FONT_BUTTON)

    out_path = os.path.join(PAGES_DIR, "03_starter_step3_safe_dosage.png")
    img.save(out_path, quality=95)
    print("Saved:", out_path)

# ==============================================================================
# Screen 4: 1-Tap Healthier Swaps & AI Advisor
# ==============================================================================
def render_screen_4():
    img, draw = create_base_canvas()
    draw_top_nav(draw, current_step=4, show_back=True)

    # Hero Card (Swaps & Personal AI Chat)
    card_bbox = [60, 180, 1020, 1200]
    draw_rounded_rect(draw, card_bbox, radius=32, fill=SURFACE_WHITE, outline=CARD_BORDER, width=2)

    # Recommended Clean Swap Box
    swap_box = [110, 220, 970, 600]
    draw_rounded_rect(draw, swap_box, radius=24, fill=(240, 249, 244), outline=PRIMARY_GREEN, width=2)
    draw.text((150, 250), "🔄 RECOMMENDED HEALTHIER SWAP", fill=PRIMARY_DARK, font=FONT_SMALL_BOLD)
    
    # Score Pill
    pill_bbox = [760, 245, 930, 290]
    draw_rounded_rect(draw, pill_bbox, radius=14, fill=PRIMARY_GREEN)
    draw.text((780, 255), "Score 88/100", fill=SURFACE_WHITE, font=FONT_BADGE)

    draw.text((150, 305), "Quaker 100% Wholegrain Rolled Oats", fill=TEXT_PRIMARY, font=FONT_CARD_TITLE)
    draw.text((150, 360), "✓ 85% Less Sugar per 100g", fill=PRIMARY_DARK, font=FONT_BODY_BOLD)
    draw.text((150, 400), "✓ Zero Red Additives • NOVA 1 Clean Unprocessed", fill=PRIMARY_DARK, font=FONT_BODY_BOLD)
    draw.text((150, 440), "✓ Rich in Beta-Glucan Soluble Heart Fiber", fill=PRIMARY_DARK, font=FONT_BODY_BOLD)

    # 1-Tap Delivery Buttons
    draw.text((150, 495), "1-Tap Order via Quick Commerce:", fill=TEXT_SECONDARY, font=FONT_SMALL_BOLD)
    q_x = 150
    partners = [("Blinkit", AMBER_ACCENT), ("Zepto", PURPLE_ACCENT), ("Instamart", ORANGE_ACCENT), ("BigBasket", RED_ACCENT)]
    for name, col in partners:
        q_box = [q_x, 530, q_x + 180, 580]
        draw_rounded_rect(draw, q_box, radius=12, fill=BG_LIGHT, outline=col, width=2)
        draw.text((q_x + 35, 545), name, fill=TEXT_PRIMARY, font=FONT_BADGE)
        q_x += 200

    # Personal AI Advisor Chat Mockup
    chat_box = [110, 630, 970, 1160]
    draw_rounded_rect(draw, chat_box, radius=24, fill=BG_LIGHT, outline=CARD_BORDER, width=2)
    draw.text((150, 660), "🤖 Grounded Personal AI Advisor (Gemini 2.5)", fill=TEXT_PRIMARY, font=FONT_BODY_BOLD)
    
    # User Question Bubble
    user_bubble = [320, 720, 930, 820]
    draw_rounded_rect(draw, user_bubble, radius=18, fill=PRIMARY_GREEN)
    draw.text((350, 740), "Is this biscuit safe for my diabetic mother?", fill=SURFACE_WHITE, font=FONT_BODY)
    draw.text((350, 775), "She is 58 years old and on Metformin.", fill=SURFACE_WHITE, font=FONT_SMALL)

    # AI Citation Response Bubble
    ai_bubble = [150, 850, 930, 1120]
    draw_rounded_rect(draw, ai_bubble, radius=18, fill=SURFACE_WHITE, outline=CARD_BORDER, width=2)
    draw.text((180, 875), "⚠️ Unsafe Recommendation:", fill=RED_ACCENT, font=FONT_BODY_BOLD)
    draw.text(
        (180, 915),
        "Per [WHO_SUGAR_2015] & [IDF_DIABETES_2021], this biscuit\n"
        "contains 32g total sugars with high-glycemic liquid glucose.\n"
        "It will trigger an immediate blood glucose spike.\n"
        "We recommend swapping to 100% Rolled Oats or Chia Seeds.",
        fill=TEXT_PRIMARY,
        font=FONT_SMALL,
        spacing=8,
    )
    draw.text((180, 1070), "Grounding Citations: [WHO_2015] [JECFA_110] [FSSAI_2022]", fill=BLUE_ACCENT, font=FONT_BADGE)

    # Content Section
    step_pill = [60, 1260, 250, 1310]
    draw_rounded_rect(draw, step_pill, radius=12, fill=ACCENT_GREEN)
    draw.text((80, 1272), "STEP 4 OF 4", fill=PRIMARY_DARK, font=FONT_BADGE)

    draw.text((60, 1340), "Healthier Swaps & AI Advisor", fill=TEXT_PRIMARY, font=FONT_TITLE)
    draw.text(
        (60, 1420),
        "Never feel trapped by unhealthy options. Discover certified\n"
        "clean swaps with 1-tap quick-commerce delivery, and chat\n"
        "with our zero-hallucination citation-grounded AI advisor.",
        fill=TEXT_SECONDARY,
        font=FONT_SUBTITLE,
        spacing=12,
    )

    # Navigation Dots & Final Primary CTA
    draw_dots(draw, active_index=3)
    back_btn = [60, 1760, 300, 1860]
    draw_rounded_rect(draw, back_btn, radius=28, fill=SURFACE_WHITE, outline=PRIMARY_GREEN, width=2)
    draw.text((130, 1785), "← Back", fill=PRIMARY_GREEN, font=FONT_BUTTON)

    start_btn = [340, 1760, 1020, 1860]
    draw_rounded_rect(draw, start_btn, radius=28, fill=PRIMARY_GREEN)
    draw.text((450, 1785), "Get Started & Sign In →", fill=SURFACE_WHITE, font=FONT_BUTTON)

    out_path = os.path.join(PAGES_DIR, "04_starter_step4_swaps_and_ai.png")
    img.save(out_path, quality=95)
    print("Saved:", out_path)

# ==============================================================================
# Overview Showcase: Composite of All 4 Steps
# ==============================================================================
def render_overview():
    s1 = Image.open(os.path.join(PAGES_DIR, "01_starter_step1_scan.png"))
    s2 = Image.open(os.path.join(PAGES_DIR, "02_starter_step2_toxicology.png"))
    s3 = Image.open(os.path.join(PAGES_DIR, "03_starter_step3_safe_dosage.png"))
    s4 = Image.open(os.path.join(PAGES_DIR, "04_starter_step4_swaps_and_ai.png"))

    thumb_w, thumb_h = 540, 960
    comp = Image.new("RGB", (thumb_w * 4 + 100, thumb_h + 200), (240, 243, 246))
    draw = ImageDraw.Draw(comp)

    # Title Banner
    font_banner = get_font(48, bold=True)
    font_sub = get_font(28, bold=False)
    draw.text((50, 40), "NutriGuard — Complete Starter Walkthrough & Onboarding Carousel", fill=TEXT_PRIMARY, font=font_banner)
    draw.text((50, 100), "Interactive step-by-step guidance shown to users before sign-in (Tap Next → Next to explore all steps)", fill=TEXT_SECONDARY, font=font_sub)

    screens = [
        (s1, "Step 1: Point & Scan Label"),
        (s2, "Step 2: 39/100 Red Cap & Toxins"),
        (s3, "Step 3: Personalized Safe Dosage"),
        (s4, "Step 4: Healthier Swaps & AI"),
    ]

    for idx, (s, label) in enumerate(screens):
        resized = s.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        x = 50 + (idx * (thumb_w + 20))
        y = 160
        # Shadow
        draw_rounded_rect(draw, [x - 4, y - 4, x + thumb_w + 4, y + thumb_h + 4], radius=20, fill=(210, 215, 222))
        comp.paste(resized, (x, y))
        # Label below
        draw.text((x + 20, y + thumb_h + 20), label, fill=PRIMARY_DARK, font=FONT_BODY_BOLD)

    out_path = os.path.join(PAGES_DIR, "00_starter_carousel_flow_overview.png")
    comp.save(out_path, quality=95)
    print("Saved:", out_path)

if __name__ == "__main__":
    render_screen_1()
    render_screen_2()
    render_screen_3()
    render_screen_4()
    render_overview()
    print("All 5 Starter Page images successfully generated in 'pages' directory!")

