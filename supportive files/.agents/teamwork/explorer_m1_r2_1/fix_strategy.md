# Iteration 2 UI Fix Strategy & Prompt Engineering Architecture
## Target Asset: `01_onboarding_v2_refined.jpg` (Page 1: Starter Screen / Onboarding)
**Author:** `explorer_m1_r2_1` (teamwork_explorer)  
**Date:** 2026-11-03T03:15:00Z  
**Status:** Approved Fix Strategy for Iteration 2 Implementation  

---

## 1. Executive Summary & Failure Analysis

In Iteration 1, the generated visual mockup `01_onboarding_v2_refined.jpg` was rejected following adversarial review by `challenger_2`. While the asset successfully demonstrated Material 3 styling tokens, hero scanning aesthetics, and functional color palettes, empirical analysis revealed four critical and medium defects that violated acceptance criteria:

| # | Defect Observed in Iteration 1 | Severity | Root Cause in Prompt / Generation | Iteration 2 Fix Architecture |
|---|--------------------------------|:--------:|-----------------------------------|------------------------------|
| **1** | **Telugu chip (`తెలుగు`) truncated & clipped** at right card boundary; text clipped to `"తెలుగ"` with missing vowel sign `ు` and sliced pill border. | **CRITICAL** | Prompt requested "sleek bezel-less smartphone screen mockup", causing model to generate a phone chassis floating in pale studio padding (`#EDF6F1`). Actual usable screen width was squeezed to ~535px out of 768px (30.3% horizontal loss), forcing 5 chips on 1 row to overflow. | **Full-Bleed 2D Artboard Framing**: Eliminate phone chassis, bezels, and studio padding (100% canvas utilization).<br>**2-Row Wrap Chip Layout**: 3 chips in Row 1, 2 chips in Row 2 with generous pill padding. |
| **2** | **Generative text stutter ("JECFA JECFA")**: Slider caption read `"Scales WHO 20% single-snack sugar limits & JECFA \n JECFA additive ADI."` | **HIGH** | Semantic line break token looping across conjunction `& JECFA` triggered repeated token generation at the start of line 2. | **Token Stream Smoothing**: Simplify copy to a single cohesive sentence without repetitive triggers: `"Calibrated to WHO daily sugar limits and JECFA ADI standards."`<br>**Negative Prompting**: Explicitly ban repeated words, stutter, and duplicated acronyms. |
| **3** | **Redundant mini toggle switch** in the "Adult / Child Mode" header row (in OFF state) directly above the Segmented Button. | **MEDIUM** | Prompt labeled the section `"MODE TOGGLE: Material 3 Segmented Button"`. Diffusion model latched onto "TOGGLE" and generated an iOS-style toggle switch in addition to the segmented button. | **Disambiguated Component Naming**: Rename to `"PROFILE SELECTION: A single Material 3 Segmented Button (no switch toggles)"`.<br>**Negative Prompting**: Explicitly forbid switch toggles, iOS switches, and duplicate controls. |
| **4** | **Card bottom boundary abrupt cutoff** with 0dp bottom padding below chips and missing bottom rounded squircle corners. | **MEDIUM** | Prompt did not specify container closure, internal bottom padding, or 4-corner squircle symmetry, causing the card to terminate flush with the chip bottom. | **Explicit Box Model Styling**: Mandate 24px squircle on all 4 corners, symmetric 24px bottom internal padding, and 20px clear vertical separation gap before CTAs. |

---

## 2. Issue 1 Fix Strategy: Full-Bleed Framing & Telugu Chip Integrity

### 2.1 The Framing Problem: Frame-in-Frame Space Penalty
In Iteration 1:
- Image dimensions: `768 x 1376` px.
- Left background margin (`#EDF6F1`): `x = 0` to `x = 104` (104 px).
- Right background margin (`#EDF6F1`): `x = 667` to `x = 768` (101 px).
- Usable UI width: `535 px` (only 69.7% of canvas).
- Card container inside UI width: `~475 px`.
- 5 chips in a single row require at least:
  $$(85\text{px (English)} + 65\text{px (Hindi)} + 70\text{px (Marathi)} + 75\text{px (Tamil)} + 85\text{px (Telugu)}) + (4 \times 12\text{px gap}) + (2 \times 20\text{px card padding}) = 478\text{px}$$.
- Result: Chip 5 collided with the phone bezel at `x = 646` and was truncated.

### 2.2 Framing Directives for Iteration 2
The asset must be framed as a **pure flat 2D edge-to-edge UI artboard**:
- **Positive Prompt Directives**:
  - `"Flat 2D mobile UI screen layout, full-bleed edge-to-edge app screenshot artboard, borderless digital interface filling the entire image frame from margin to margin."`
  - `"The digital UI canvas spans exactly edge to edge with zero phone bezel, zero physical hardware frame, zero phone chassis, and zero outer background padding."`
  - `"Status bar elements ('9:41', signal, battery) sit directly at the top canvas edge (y=0 to y=60). Bottom home indicator sits directly at bottom edge."`
- **Negative Prompt Directives**:
  - `"phone chassis, smartphone body, physical device frame, black bezel, outer phone border, angled perspective, 3D device mockup, floating phone, studio background padding, tabletop surface, drop shadow outside phone, external bezel margin."`

### 2.3 Component Arrangement: 2-Row Wrap Chip Layout
To provide foolproof clearance and ensure complete pill capsules with unclipped Indic typography across all scripts:
- **Wrap Architecture**:
  - **Row 1 (3 chips)**:
    1. `[✓ English]` — Selected state, Mint container (`#8CF7C8`), dark green text (`#002114`), checkmark icon.
    2. `[हिंदी]` — Unselected state, white container, crisp outline, native Hindi Devanagari script.
    3. `[मराठी]` — Unselected state, white container, crisp outline, native Marathi Devanagari script.
  - **Row 2 (2 chips)**:
    4. `[தமிழ்]` — Unselected state, white container, crisp outline, native Tamil script.
    5. `[తెలుగు]` — Unselected state, white container, crisp outline, complete native Telugu script with intact vowel sign (`తెలుగు`, complete pill capsule with rounded ends on both sides).
- **Alternative Single-Row Strict Constraint** (if model defaults to single row):
  - If placed in a single row, chips must have compact horizontal padding (`8dp` horizontal padding, `6dp` gap) and minimum `24dp` card side margins so `[తెలుగు]` has at least `32dp` clearance from the right card border.
- **Explicit Glyph Assurance**:
  - The prompt must explicitly state: `"All 5 language chips have complete, unbroken pill capsule borders with generous margins; the Telugu chip displays the full word 'తెలుగు' with the complete vowel diacritic without edge clipping."`

---

## 3. Issue 2 Fix Strategy: Generative Text Stutter Elimination

### 3.1 Root Cause Mechanism
Generative text encoders in diffusion models (e.g. T5-XXL / CLIP) can suffer from repetition penalties when rare clinical acronyms (`JECFA`) are positioned immediately adjacent to punctuation (`& JECFA`) and split across visual line wraps. In Iteration 1, the model rendered:
`... limits & JECFA` on line 1, and repeated `JECFA additive ADI.` on line 2.

### 3.2 Copy Optimization
Replace the vulnerable compound phrase with a single, clear, syntactically clean sentence:
- **Target Text**:
  `"Calibrated to WHO daily sugar limits and JECFA ADI standards."`
- **Prompt Directive**:
  `"Helper text below slider: a single concise caption reading exactly 'Calibrated to WHO daily sugar limits and JECFA ADI standards.' rendered with zero word duplication, zero token repetition, and clean single-instance phrasing."`
- **Negative Prompt Directives**:
  `"word duplication, text stutter, repeated words, duplicated 'JECFA', double acronyms, repeating sentences, repeating phrases, hallucinated duplicated words, glitched copy."`

---

## 4. Issue 3 Fix Strategy: Elimination of Redundant Header Toggle Switch

### 4.1 Root Cause Mechanism
In Iteration 1, the prompt section heading was:
`MODE TOGGLE: Material 3 Segmented Button with two options...`
The dual presence of "TOGGLE" and "BUTTON" prompted the diffusion model to satisfy both keywords by generating:
1. An iOS-style binary switch toggle on the title line (rendered in the OFF state).
2. A Material 3 Segmented Button below it.
This created UX ambiguity and a glaring contradiction on the card.

### 4.2 Disambiguation Strategy
1. **Never use the word "toggle" or "switch"** anywhere in the prompt!
2. **Designate exclusively as "Segmented Button"**:
   - `"SECTION HEADER: Plain text title 'Profile Type'. Beneath it, exactly ONE Material 3 Segmented Button with two segments: left segment '[person icon] Adult (65 kg)' [ACTIVELY SELECTED with solid emerald green fill and white text], right segment '[child icon] Child (20 kg)' [UNSELECTED with white background and outline]. Do NOT render any toggle switch, slide switch, or icon switch next to the title."`
3. **Negative Prompt Directives**:
   - `"toggle switch, switch toggle, slider switch, iOS toggle, on/off switch, redundant toggle, double controls, conflicting switches, switch button next to title."`

---

## 5. Issue 4 Fix Strategy: Card Container Bottom Padding & Geometry

### 5.1 Root Cause Mechanism
The prompt instructed:
`3. FORM CONFIGURATION CARD (White elevated rounded card with 24px radius): ... 4. BOTTOM ACTION BUTTONS:`
Because no internal bottom padding or container closure rules were specified, the model collapsed the bottom of the card immediately beneath the chip row, resulting in:
- `0dp` bottom padding below chips.
- Sharp, cut-off bottom corners instead of smooth 24px rounded corners.
- Lack of visual separation between the card container and the primary CTA button.

### 5.2 Container Geometry Directives
- **Card Styling Specifications**:
  - **Container Shape**: White (`#FFFFFF`) elevated surface with **symmetrical 24px rounded squircle corners on all four corners** (top-left, top-right, bottom-left, bottom-right).
  - **Internal Padding**: Uniform `20-24px` padding on all four inner sides: top, left, right, and bottom.
  - **Bottom Clearance**: Ample `24px` internal padding below the language chips before the bottom edge of the white card.
  - **External Separation**: A distinct `20px` vertical space / gap between the bottom rounded border of the white card and the primary CTA button ("Save & Open Dashboard").
- **Negative Prompt Directives**:
  - `"abrupt card cutoff, missing bottom card border, card touching buttons, zero bottom padding, incomplete card box, broken container corners, square bottom corners."`

---

## 6. Complete Master Prompt Blueprint for Iteration 2

Below is the production-ready prompt formulation and negative prompt for `worker_1` (or assigned worker) to execute in Milestone 1 Iteration 2.

### 6.1 Primary Generation Prompt

```text
Full-bleed edge-to-edge mobile app UI screenshot artboard, flat 2D graphic design, portrait 9:16 aspect ratio, Google Material 3 Design System, clean modern health tech mobile application interface, Behance and Dribbble portfolio award-winning design, crystal-clear typography, pixel-perfect layout.

Screen Artboard Framing Directives:
Pure flat 2D UI screen layout filling 100% of the canvas from edge to edge. Borderless digital interface with zero external phone chassis, zero phone bezel, zero physical hardware frame, and zero outer background padding. The digital screen pixels touch all four image boundaries completely.

Screen Theme & Colors:
"SafeBite AI: Smart Toxicology & Safe Dosage Scanner" - Onboarding & Profile Setup screen. Medical emerald green (#006C4C) primary color, soft mint container (#8CF7C8), pristine medical white (#FFFFFF), neutral slate card surface (#F5F7F3), dark charcoal typography (#191C1A).

Screen Layout Architecture (Top to Bottom):
1. TOP STATUS BAR (0% - 4%): Minimalist black mobile status bar icons directly at the top edge showing digital clock "9:41", full WiFi, 5G signal, and battery indicator.
2. APP HEADER & HERO (4% - 32%):
   - Brand title: Green shield logo with text "SafeBite AI".
   - Hero visual: Clean 3D vector illustration of a smartphone scanning a packaged snack with an emerald laser OCR beam, accompanied by floating data badges reading "Safe Dosage 45g" and "0 Toxic Additives".
   - Headline: "Safe Consumption Setup" in bold 22sp.
   - Subtitle: "Detect hidden sugars, toxic additives & calculate personalized safe dosage based on body weight."
3. FORM CONFIGURATION CARD (32% - 78%):
   - Elevated pure white (#FFFFFF) card with uniform 24px rounded squircle corners on ALL FOUR corners, soft ambient drop shadow, and generous 24px internal padding on all sides.
   - SECTION 1: PROFILE TYPE: Clean section title "Profile Type" (plain text, NO toggle switch). Below it, a single Material 3 Segmented Button with two segments:
     * Left segment: "[person icon] Adult (65 kg)" [ACTIVELY SELECTED with solid emerald green fill and white text].
     * Right segment: "[child icon] Child (20 kg)" [UNSELECTED with white background, dark outline, and grey text].
   - SECTION 2: BODY WEIGHT BASELINE: Title "Body Weight Baseline". Horizontal slider bar spanning "15 kg" on left to "120 kg" on right. Active emerald track filled to 65 kg, circular thumb with a floating pill badge directly above it displaying "65 kg". Helper caption below reading exactly: "Calibrated to WHO daily sugar limits and JECFA ADI standards." with zero word duplication.
   - SECTION 3: LANGUAGE SELECTION: Section title "Select Language". Clean 2-row wrapped arrangement of Material 3 Filter Chips with generous spacing:
     * Row 1: "[✓ English]" (actively selected in mint green container with checkmark), "[हिंदी]" (Hindi), "[मराठी]" (Marathi).
     * Row 2: "[தமிழ்]" (Tamil), "[తెలుగు]" (Telugu with complete native script and full unbroken pill capsule border).
   - CARD BOTTOM: Card fully closes with 24px internal bottom padding below the chips and smooth rounded bottom corners.
4. ACTION ZONE (78% - 96%):
   - Clear 20px vertical gap separating the card from the bottom action buttons.
   - Primary CTA: Full-width filled emerald green (#006C4C) pill button with white bold text reading "Save & Open Dashboard ->".
   - Secondary CTA: Full-width outlined pill button with camera icon reading "[scanner icon] Instant Scan Now".
5. NAVIGATION (96% - 100%): Centered iOS/Android home indicator bar at the bottom edge.

Aesthetic: Ultra-crisp vector rendering, flawless typography across English and Indic scripts, no cropped components, no duplicate words, professional enterprise health UI.
```

### 6.2 Negative Prompt Directives

```text
phone body, physical smartphone chassis, black phone bezel, external device frame, device mockups on desks, floating phone in studio, studio background padding, pale border around phone, 3D tilted perspective, angled device, hands holding phone, isometric rendering,
clipped chips, truncated Telugu text, missing pill border, cut-off buttons, text colliding with card edge,
word duplication, text stutter, repeated words, duplicated "JECFA", stuttering acronyms, double sentences,
toggle switch, switch toggle, slider switch, on/off switch next to header, redundant switches, conflicting controls,
abrupt card cutoff, missing bottom card border, card touching buttons, zero bottom padding, incomplete card container, square bottom corners,
blurry text, fuzzy icons, misspelled words, garbled gibberish text, low resolution, dark mode, clashing colors.
```

### 6.3 Technical Tool Invocation Parameters
When invoking `generate_image`:
- `AspectRatio`: `"9:16"`
- `ImageName`: `"01_onboarding_v2_refined"`
- `Prompt`: *[The verbatim prompt from §6.1]*

---

## 7. Verification & Acceptance Checklist for Iteration 2

To ensure zero regression and 100% pass rate in Iteration 2, the implementer and verification agents must validate against the following empirical criteria:

| Verification Target | Acceptance Criteria | Empirical Verification Method |
|---------------------|---------------------|-------------------------------|
| **1. Full-Bleed Framing** | 0% studio padding; UI pixels extend to `x = 0` and `x = 768`. No black phone bezels or outer pale background. | Sample pixels at `(5, 5)`, `(5, 700)`, `(763, 700)`: should contain UI elements (app background/card), NOT pale studio margins (`#EDF6F1`). |
| **2. Telugu Chip (`తెలుగు`) Integrity** | Chip 5 has complete pill capsule border on both left and right; text verbatim reads `"తెలుగు"` with intact vowel diacritic `ు`; no clipping at right margin. | Visual inspection via `view_file` and pixel scan of right chip border. |
| **3. Text Stutter Elimination** | Helper copy verbatim reads `"Calibrated to WHO daily sugar limits and JECFA ADI standards."` with exactly ONE instance of "JECFA" and zero repeated tokens. | Visual inspection of text lines under weight slider. |
| **4. Single Mode Control** | Header contains only plain text `"Profile Type"`. Exactly one Segmented Button (Adult 65kg / Child 20kg). Zero toggle switches. | Visual inspection of Profile card header row. |
| **5. Card Bottom Padding & Closure** | White card container has smooth rounded squircle corners at bottom; minimum 20px padding between chip row and bottom card border; clear gap before primary CTA. | Visual inspection of card bottom boundary. |
| **6. Core Component Compliance** | Adult 65kg & Child 20kg indicators; 15-120 kg slider with 65 kg badge; 5 language chips; Dual CTAs ("Save & Open Dashboard" and "Instant Scan Now"). | Inspection against `ORIGINAL_REQUEST.md` line 34-38. |
| **7. Dimensions & File Path** | Saved at `c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg` with 9:16 aspect ratio (~768x1376). | PowerShell script execution (`System.Drawing`). |
