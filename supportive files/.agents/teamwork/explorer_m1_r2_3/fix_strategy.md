# Fix Strategy: Prompt Engineering & Negative Prompt Formulation
## Milestone 1 — Iteration 2: Page 1 Onboarding Mockup Refinement

**Author:** `explorer_m1_r2_3` (Archetype: `teamwork_explorer`)  
**Target Asset:** `c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg`  
**Date:** 2026-11-03T03:13:00Z  
**Recipient:** Orchestrator (`b07a56f6-e835-41cc-99c3-df882b529452`)  

---

## 1. Executive Summary & Root Cause Analysis

Adversarial inspection by `challenger_2` and visual review of `01_onboarding_v2_refined.jpg` identified 5 empirical defects in the Iteration 1 asset. Our prompt engineering analysis traces each defect directly to specific lexical triggers and structural ambiguities in the Iteration 1 prompt:

| # | Observed Defect | Iteration 1 Prompt Root Cause | Lexical / Structural Mechanism |
|---|-----------------|-------------------------------|--------------------------------|
| **1** | **Physical Bezel & 30.3% Canvas Loss** (Screen width squeezed from 768px to 535px) | Keywords: `"mobile app UI design mockup"`, `"smartphone screen"`, `"Behance and Dribbble trending mobile UI"` | Diffusion text encoders treat "mockup" and "smartphone screen" as physical objects placed on presentation surfaces, adding chassis bezels, hardware buttons, and external background padding (`#EDF6F1`). |
| **2** | **Telugu Chip Truncation & Glyph Loss** (`[తెలుగ]` cut off at `x=646`) | Prompt directive: `"Row of 5 Material 3 Filter Chips: '✓ English'... 'हिंदी', 'मराठी', 'தமிழ்', 'తెలుగు'"` | Enforcing a single horizontal row for 5 chips (430px text + 40px gaps + 48px padding = 518px) inside a squeezed 535px container leaves 0px margin of safety, forcing the 5th chip into the border. |
| **3** | **Text Stutter / Word Duplication** (`"JECFA JECFA"`) | Prompt copy: `"Scales WHO 20% single-snack sugar limits & JECFA additive ADI."` | Multi-line text splitting immediately before an uppercase multi-letter acronym (`JECFA`) triggered autoregressive attention re-sampling across the line break. |
| **4** | **Conflicting Controls** (iOS toggle switch + Segmented Button) | Prompt phrase: `"- MODE TOGGLE: Material 3 Segmented Button..."` | The keyword `"TOGGLE"` triggered an iOS `UISwitch` in the header row, while `"Segmented Button"` rendered below it, resulting in dual contradictory controls. |
| **5** | **Abrupt Card Bottom Termination** (Card sliced open beneath chips) | Lack of explicit card boundary closure and bottom padding specification | The model rendered card contents but did not close the bottom border before the CTA action zone, terminating the container at `y ≈ 1110`. |

---

## 2. Negative Prompt Refinement Architecture

Because the `generate_image` tool accepts a single unified text `Prompt` string without an independent `NegativePrompt` parameter, negative constraints must be encoded as an explicit, high-priority exclusionary directive block within the prompt itself.

### 2.1 Categorical Negative Prompt Rules

#### Rule Set A: Device & Framing Suppression (Zero-Tolerance Bezel Ban)
Eliminate all physical phone chassis, cases, bezels, desk backgrounds, and angled views:
- **Forbidden Keywords:** `phone case`, `device frame`, `physical smartphone`, `phone chassis`, `bezel`, `black bezel`, `outer border`, `surrounding margin`, `studio table`, `wooden desk`, `tabletop`, `hand holding phone`, `fingers`, `angled perspective`, `isometric view`, `tilted view`, `3D device mockup`, `floating phone`, `perspective distortion`.
- **Affirmative Replacement:** `"Pure flat 2D mobile user interface artboard, direct screen graphic, 100% full-bleed edge-to-edge UI canvas, Figma UI artboard export, flat digital screenshot, UI canvas begins at pixel (0,0) and extends to all four canvas edges without outer borders."`

#### Rule Set B: Typographical Integrity & Token Stutter Suppression
Eliminate duplicated words, acronym repetition, and corrupted Indic typography:
- **Forbidden Keywords:** `duplicate words`, `repeated words`, `token stutter`, `repeated acronyms`, `'JECFA JECFA'`, `duplicate JECFA`, `stuttering text`, `repeating phrases across lines`, `garbled Indic letters`, `cut off Telugu glyphs`, `truncated script`, `gibberish text`.
- **Affirmative Replacement:** `"Clean, single-instance typography. Each word, number, and acronym appears exactly once with zero repetition. Native Indic glyphs fully formed and complete."`

#### Rule Set C: Layout & Boundary Integrity Suppression
Prevent clipped chips, open card containers, and redundant controls:
- **Forbidden Keywords:** `cropped chips`, `truncated pill containers`, `sliced button caps`, `chips overflowing card border`, `single cramped row of 5 chips`, `open-bottom card`, `cutoff container card`, `card colliding with buttons`, `toggle switch`, `iOS switch`, `header toggle switch`, `checkbox`, `conflicting mode controls`.
- **Affirmative Replacement:** `"Wrapped 2-row chip layout with 3 chips in Row 1 and 2 chips in Row 2, generous 32px inner horizontal clearance, fully enclosed white card container with rounded 24px squircle corners on all four corners and 20px bottom padding, single Material 3 Segmented Button."`

---

## 3. Spatial Layout & Prompt Structuring Engineering

### 3.1 Eliminating Canvas Compression: Pure Full-Bleed Artboard Directives

To guarantee that the generator utilizes 100% of the 768px horizontal width (a full +30.3% space gain over iteration 1):
1. **Never use the words "mockup", "device", or "smartphone screen"** in the introductory sentence.
2. **Explicitly declare the medium as a direct 2D vector artboard:**
   ```text
   A clean flat 2D mobile application UI design artboard, direct full-bleed digital screen graphic, 100% edge-to-edge mobile user interface filling the entire 9:16 canvas from border to border, Figma UI export style, zero phone chassis, zero device bezels, zero external background padding.
   ```

### 3.2 2-Row Wrapped Chip Layout Architecture

To mathematically eliminate any possibility of Chip 5 (`తెలుగు`) clipping, the language selection section must be structured into a 2-row wrapped layout:

```
+-------------------------------------------------------------+
| Card Width (~700px on full-bleed canvas)                    |
|                                                             |
|  Select Language                                            |
|                                                             |
|  [✓ English]       [हिंदी]       [मराठी]                    |  <-- Row 1: 3 Chips
|                                                             |      (~300px total width)
|  [தமிழ்]           [తెలుగు]                                 |  <-- Row 2: 2 Chips
|                                                             |      (~190px total width)
|                                                             |  <-- >350px clearance to right border!
+-------------------------------------------------------------+
```

**Prompt Engineering Directive for Chips:**
```text
LANGUAGE SELECTION (2-Row Wrapped Chip Layout):
Section header: "Select Language".
The 5 language filter chips are arranged across TWO horizontal rows to ensure wide margins and zero clipping:
- ROW 1 (3 chips): "[✓ English]" (actively selected in mint green #8CF7C8 pill container with dark green checkmark), "[हिंदी]" (unselected outlined pill chip), and "[मराठी]" (unselected outlined pill chip).
- ROW 2 (2 chips positioned directly below Row 1): "[தமிழ்]" (unselected outlined pill chip), and "[తెలుగు]" (unselected outlined pill chip).
Both rows have generous 24px margins from the card boundaries. The Telugu chip "[తెలుగు]" is completely visible, centered or left-aligned in row 2 with full rounded stadium caps on both ends and complete unclipped Telugu text.
```

### 3.3 Container Geometry & Squircle Boundary Directives

To prevent Defect 5 (card cutoff), the prompt must explicitly specify:
```text
CONFIGURATION CARD CONTAINER:
An elevated white (#FFFFFF) configuration card with smooth 24px squircle rounded corners on ALL FOUR CORNERS (top-left, top-right, bottom-left, bottom-right) and uniform 20px internal padding. All controls (Mode Segmented Button, Weight Slider, and 2-Row Language Chips) are fully contained inside this single card. The card has a clean, visible, rounded bottom boundary with 20px bottom padding below the second row of chips, separated by a 24px vertical gap before the CTA action buttons.
```

### 3.4 Disambiguating Mode Selection: Ban "Toggle", Enforce "Segmented Button"

To prevent Defect 4 (redundant toggle switch), the prompt must instruct:
```text
PROFILE BASELINE SELECTOR:
Section header title: "Profile Baseline" (clean plain text, NO toggle switch icon, NO iOS switch, NO slider switch).
Below the title is a SINGLE Material 3 Segmented Button with two equal segments:
- Left segment: "[ Adult (65 kg) ]" (actively selected, filled emerald green #006C4C background, white text and person icon).
- Right segment: "[ Child (20 kg) ]" (unselected, white container with outline border, dark charcoal text and child icon).
There are NO other switches or toggles in this section.
```

---

## 4. Clean Wording & Typographical Integrity Strategy

To eliminate Defect 2 (text stutter / "JECFA JECFA"):

### 4.1 Copy Optimization & Microcopy Redesign
Instead of a long, phonetically dense, multi-acronym sentence that prompts line-break repetition, provide clear, bounded copy:

- **Problematic Iteration 1 Copy:**
  `"Scales WHO 20% single-snack sugar limits & JECFA additive ADI."` (caused line break `& JECFA` / `JECFA additive ADI.`)
- **Recommended Iteration 2 Copy:**
  `"Calibrated to WHO single-snack sugar limits & JECFA ADI standards."`
- **Alternative Ultra-Safe Copy (Single-Acronym per line or single line):**
  `"Personalized to WHO sugar limits & safe consumption dosage guidelines."`

### 4.2 Explicit Typographical Anti-Stutter Directives
Include verbatim instruction in the prompt:
```text
Exact helper text beneath slider: "Calibrated to WHO single-snack sugar limits & JECFA ADI standards."
Typography constraint: Every single word and acronym must appear EXACTLY ONCE. Zero duplicate words. Do NOT repeat "JECFA" or "WHO". No text stuttering.
```

---

## 5. Complete Synthesized Prompt Blueprint for Iteration 2

The implementer (`worker`) should execute the `generate_image` tool using the following exact synthesized prompt:

### Prompt String for `generate_image`:

```text
A high-resolution, production-grade 2D mobile application UI design artboard for "SafeBite AI: Smart Packaged Product Ingredient, Toxicology & Safe Consumption Dosage Scanner". Flat digital screen graphic, 100% full-bleed edge-to-edge UI canvas in 9:16 portrait aspect ratio, Figma UI export style, zero phone chassis, zero device bezels, zero external background borders. Google Material 3 Design System.

COLOR ARCHITECTURE:
Primary emerald green (#006C4C), mint container accents (#8CF7C8), pristine medical white canvas (#FBFDF9), soft surface containers (#F5F7F3), high-contrast charcoal typography (#191C1A).

SCREEN LAYOUT (TOP TO BOTTOM):
1. STATUS BAR & APP BAR (Top 8%):
   - Status bar: "9:41", full WiFi, 5G, and battery icons.
   - App bar: Emerald bio-safety shield icon with brand title "SafeBite AI".

2. HERO SCANNER SECTION (Top 8% - 32%):
   - Clean 2.5D vector illustration of a smartphone scanning a packaged snack box with a bright emerald green laser OCR grid. Floating holographic pill badges: "Safe Dosage 45g" and "0 Toxic Additives".
   - Headline (Bold 22sp): "Safe Consumption Setup"
   - Subtitle (13sp): "Personalize your safe consumption limits and detect hidden sugars based on your body weight."

3. FORM CONFIGURATION CARD (32% - 78%):
   - Elevated white (#FFFFFF) card with 24px squircle rounded corners on ALL FOUR CORNERS and uniform 20px padding.
   - SECTION 1: PROFILE MODE SELECTOR
     * Title: "Profile Baseline" (clean text only, NO toggle switch icon).
     * Material 3 Segmented Button: "[ Adult (65 kg) ]" (actively selected, filled emerald green #006C4C, white text & person icon) and "[ Child (20 kg) ]" (unselected, outlined, dark charcoal text & child icon).
   - SECTION 2: BODY WEIGHT SLIDER
     * Title: "Body Weight Baseline"
     * Interactive horizontal slider spanning "15 kg" (left minimum) to "120 kg" (right maximum).
     * Emerald active track filled up to 65 kg, circular thumb with a floating elevation callout pill badge directly above it displaying "65 kg".
     * Helper caption: "Calibrated to WHO single-snack sugar limits & JECFA ADI standards." (Single instance of each word, zero word repetition).
   - SECTION 3: 5-LANGUAGE SELECTOR (2-ROW WRAPPED CHIPS)
     * Section title: "Select Language"
     * ROW 1 (3 chips): "[✓ English]" (selected, mint green #8CF7C8 container with checkmark), "[हिंदी]" (unselected outline chip), "[मराठी]" (unselected outline chip).
     * ROW 2 (2 chips directly below Row 1): "[தமிழ்]" (unselected outline chip), "[తెలుగు]" (unselected outline chip).
     * All 5 chips are fully intact stadium pills with complete rounded caps and generous spacing from card borders. The Telugu chip "[తెలుగు]" is 100% visible with complete Indic typography and no clipping.
   - Clean 20px bottom padding inside the card, completely enclosing all controls with rounded bottom squircle corners.

4. BOTTOM PINNED ACTION BUTTONS (78% - 95%):
   - Primary CTA Button: Full-width pill button filled with emerald green (#006C4C), bold white text "Save & Open Dashboard ->".
   - Secondary CTA Button: Outlined pill button with scanner camera icon, emerald green text "Instant Scan Now".

5. NAVIGATION ZONE (Bottom 5%):
   - Centered horizontal home navigation pill indicator.

STRICT AVOIDANCE AND NEGATIVE PROMPTS (NEGATIVE CONSTRAINTS):
Do NOT include physical smartphone, phone frame, phone case, device chassis, iPhone bezel, Android bezel, black bezel border, outer margin, studio table, desk, tabletop background, hand holding phone, human fingers, angled 3D perspective, isometric view, tilted view, floating phone mockup, external drop shadow on desk, outer background borders.
Do NOT include duplicate words, repeated words, token stutter, repeated acronyms, "JECFA JECFA", duplicate JECFA, repeating WHO, stuttering text, garbled Indic letters, broken Telugu diacritics.
Do NOT include cropped chips, truncated buttons, clipped text, chips overflowing card boundaries, single cramped row of 5 chips, cut off Telugu glyphs.
Do NOT include toggle switch in header, iOS switch, checkbox, conflicting mode switches.
Do NOT include cutoff card, open-bottom card container, card colliding with buttons.
```

---

## 6. Implementation Verification Matrix

| Checklist Item | Expected State in Iteration 2 | Verification Method |
|---|---|---|
| **Canvas Edge-to-Edge** | Pixel (10,10) is pure app background `#FBFDF9`, not studio border `#EDF6F1` | PowerShell pixel sample at `(10, 10)` |
| **No Device Bezel** | 0px black border; usable UI width = 100% of 768px | PowerShell horizontal slice across x=0 to 100 |
| **5th Chip (`తెలుగు`)** | Positioned in Row 2, >150px from right edge, intact rounded cap, full glyph `తెలుగు` | Pixel scan at chip bounds & visual review |
| **Single "JECFA"** | Verbatim text reads `"Calibrated to WHO single-snack sugar limits & JECFA ADI standards."` with no duplicate tokens | Visual OCR / text review |
| **Single Mode Control** | Only the Segmented Button exists; no switch toggle on header line | Visual inspection of Card Section 1 |
| **Card Bottom Squircle** | Card has rounded lower corners and visible 20px bottom padding before CTA zone | Visual boundary check |

---

## 7. Recommendation for Orchestrator

1. **Adopt the Synthesized Prompt Blueprint (§5)** for the upcoming generation task in Iteration 2.
2. **Dispatch Worker** with explicit instructions to pass the complete positive + negative constraint prompt to `generate_image(AspectRatio: "9:16", ImageName: "01_onboarding_v2_refined")`.
3. **Dispatch Reviewer & Challenger** with the automated verification script checking pixel `(10, 10)` and right-edge padding of the Telugu chip.
