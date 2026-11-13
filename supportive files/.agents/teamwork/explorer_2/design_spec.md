# Production Material 3 UI Design Specification
## Page 1: Starter Screen / Onboarding (`01_onboarding_v2_refined.jpg`)
**Project:** Smart Packaged Product Ingredient, Toxicology & Safe Consumption Dosage Scanner  
**Document Status:** Complete & Verified  
**Target Asset:** `01_onboarding_v2_refined.jpg` (Aspect Ratio 9:16)  
**Author:** Explorer 2 (`teamwork_explorer`)  

---

## Executive Summary

This specification establishes the comprehensive Material 3 (M3) design system tokens, layout architecture, component anatomies, state representations, and visual prompt engineering blueprints for generating the production UI design mockup `01_onboarding_v2_refined.jpg`.

The Starter / Onboarding Screen serves as the gateway to the application, establishing user trust through clinical bio-safety aesthetics, collecting essential metabolic parameters (Adult/Child mode, exact body weight in kg), configuring regional accessibility (5 Indian languages), and providing dual conversion funnels (Profile Configuration vs. Instant Scan bypass).

---

## 1. Material 3 Design System Tokens & Color Architecture

The application requires a clinical, authoritative, and welcoming bio-safety palette that communicates scientific precision, non-toxic living, and daily wellness.

### 1.1 Tonal Color Palette (M3 Seed: `#006C4C` - Clinical Forest Green)

| M3 Token Role | Hex Code | Light Theme Application | Dark Theme Equivalent |
| :--- | :--- | :--- | :--- |
| **Primary** | `#006C4C` | Primary CTA button ("Save & Open Dashboard"), active slider track, active slider thumb, active toggle indicator | `#8CF7C8` |
| **On-Primary** | `#FFFFFF` | Text on Primary Button, text inside floating slider callout pin | `#003825` |
| **Primary Container** | `#8CF7C8` | Selected language chip container, selected toggle segment container, active badge pill | `#005138` |
| **On-Primary Container** | `#002114` | High-contrast label on selected chips and active toggle | `#8CF7C8` |
| **Secondary** | `#4D6357` | Supporting category icons, inactive slider ticks, subtle metadata | `#B4CCBE` |
| **On-Secondary** | `#FFFFFF` | Text on secondary elements | `#1F352B` |
| **Secondary Container** | `#D0E8D9` | Tonal button background ("Instant Scan Now"), hero badge accents | `#364B40` |
| **On-Secondary Container**| `#092016` | Text on tonal secondary buttons and filter chips | `#D0E8D9` |
| **Tertiary (Alert/Caution)**| `#7D5700` | Toxicology caution indicator, hidden sugar alerts | `#FABC3E` |
| **Tertiary Container** | `#FFDEAB` | Caution alert banners, mild risk badges | `#5E4000` |
| **Error / Red Hazard** | `#BA1A1A` | Banned chemicals, Red-tier toxic additives, severe risk cap | `#FFB4AB` |
| **Surface** | `#FBFDF9` | Main screen background canvas (ultra-clean, medical-grade white) | `#191C1A` |
| **Surface Container Low** | `#F5F7F3` | Background of configuration cards and input groups | `#1D201E` |
| **Surface Container** | `#EFF2EE` | Secondary cards, hero illustration container | `#212522` |
| **Surface Container High**| `#E9ECE8` | Elevated floating panels, modal sheets | `#282B28` |
| **Surface Variant** | `#DCE5DD` | Inactive slider track background, subtle dividers | `#414943` |
| **On-Surface** | `#191C1A` | Primary typography (headlines, titles, input labels) | `#E1E3DF` |
| **On-Surface Variant** | `#414943` | Secondary typography (helper copy, unselected chips, units) | `#C0C9C2` |
| **Outline** | `#717973` | Unselected chip borders, outlined button border, card outlines | `#8B938D` |
| **Outline Variant** | `#C0C9C2` | Subtle section dividers, disabled borders | `#414943` |

### 1.2 Surface Elevation, Shadows & Corner Radius Standards
- **Corner Radii Hierarchy:**
  - Extra Large (Cards & Panels): `24dp` (smooth squircle / rounded rectangle)
  - Full Stadium (Buttons & Segmented Toggles): `28dp` (full pill radius)
  - Medium (Filter & Language Chips): `10dp`
  - Small (Badge Callouts & Slider Pin): `8dp`
- **Elevation & Lighting:**
  - Elevation 0: Canvas background (`#FBFDF9`)
  - Elevation 1: Configuration cards (ambient diffuse shadow: `offset: (0, 2)`, `blur: 8px`, `color: rgba(0,0,0,0.04)`)
  - Elevation 2: Floating slider thumb & active weight pin (direct shadow: `offset: (0, 4)`, `blur: 12px`, `color: rgba(0,108,76,0.18)`)
  - Elevation 3: Primary CTA button (subtle lift: `offset: (0, 4)`, `blur: 16px`, `color: rgba(0,108,76,0.25)`)

---

## 2. Typography Scale (Material 3 Type System)

Primary Typeface: **Plus Jakarta Sans** / **Inter** / **Roboto** (Clean geometric sans-serif optimized for mobile legibility).

| Role | Token Name | Size (sp) | Line Height | Weight | Tracking | UI Usage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Display Small** | `displaySmall` | 32sp | 40sp | 700 (Bold) | -0.25sp | Hero Headline ("Know What You Eat") |
| **Headline Medium**| `headlineMedium` | 24sp | 32sp | 700 (Bold) | 0.0sp | Page Title ("Safe Consumption Setup") |
| **Headline Small** | `headlineSmall` | 20sp | 28sp | 600 (Semi-Bold) | 0.0sp | Card Section Titles |
| **Title Large** | `titleLarge` | 22sp | 28sp | 700 (Bold) | 0.0sp | Floating Slider Value ("65 kg") |
| **Title Medium** | `titleMedium` | 16sp | 24sp | 600 (Semi-Bold) | +0.15sp | Section Headers ("Body Weight Baseline") |
| **Title Small** | `titleSmall` | 14sp | 20sp | 600 (Semi-Bold) | +0.1sp | Segmented Toggle Labels ("Adult (65 kg)") |
| **Body Medium** | `bodyMedium` | 14sp | 20sp | 400 (Regular) | +0.25sp | Contextual Subtitle & Explanations |
| **Body Small** | `bodySmall` | 12sp | 16sp | 400 (Regular) | +0.4sp | Disclaimer / WHO & JECFA Formula Note |
| **Label Large** | `labelLarge` | 15sp | 20sp | 600 (Semi-Bold) | +0.1sp | CTA Buttons ("Save & Open Dashboard") |
| **Label Medium** | `labelMedium` | 13sp | 18sp | 500 (Medium) | +0.5sp | Language Chips ("English", "हिंदी") |
| **Label Small** | `labelSmall` | 11sp | 16sp | 500 (Medium) | +0.5sp | Slider Min/Max Bounds ("15 kg", "120 kg") |

---

## 3. Detailed Component Specifications & States

### 3.1 Segmented Button / Mode Toggle
- **Purpose:** Instantly switches between standard Adult reference profile (65 kg ICMR/WHO reference) and Pediatric Child profile (20 kg safe dosage baseline).
- **Placement:** Top control inside the Profile Configuration Card.
- **Dimensions:** Height `48dp`, Width `100%` of card width (~320dp on mobile), Corner Radius `24dp` (stadium shape).
- **Container Styling:** Inset container with `1.5dp` border in `Outline` (`#C0C9C2`) and background `Surface Container Low` (`#F5F7F3`).
- **Segment 1 — Adult Mode (Selected State):**
  - Label: `"Adult (65 kg)"`
  - Icon: Leading person silhouette icon (`Icons.person`, 18dp)
  - Background: Filled with `Primary` (`#006C4C`) or `Primary Container` (`#8CF7C8`)
  - Foreground: `On-Primary` (`#FFFFFF`) or `On-Primary Container` (`#002114`)
  - Elevation: Level 1 soft shadow
- **Segment 2 — Child Mode (Unselected State):**
  - Label: `"Child (20 kg)"`
  - Icon: Leading child/family icon (`Icons.child_care` or `Icons.escalator_warning`, 18dp)
  - Background: Transparent / `Surface Container Low`
  - Foreground: `On-Surface Variant` (`#414943`, 600 weight)
- **Interaction Coupling:**
  - Selecting "Adult" sets slider value to `65 kg` with smooth spring animation.
  - Selecting "Child" sets slider value to `20 kg` with smooth spring animation.

### 3.2 Discrete/Continuous Interactive Body Weight Slider
- **Purpose:** Allows fine-tuning of exact body weight from 15 kg to 120 kg. Crucial because Safe Consumption Dosage scales proportionally:
  $$\text{Dosage} = \text{Base Portion} \times \left(\frac{\text{Weight (kg)}}{65\text{ kg}}\right)$$
- **Range & Step:** Range `15 kg` to `120 kg`, continuous drag with `1 kg` increments and discrete tick marks at 15 kg milestone intervals.
- **Track Specifications:**
  - Total Height: `8dp`
  - Active Track (15 kg to current 65 kg): Color `Primary` (`#006C4C`), corner radius `4dp`.
  - Inactive Track (65 kg to 120 kg): Color `Surface Variant` (`#DCE5DD`), corner radius `4dp`.
- **Thumb Specifications:**
  - Diameter: `24dp` circular puck.
  - Color: Solid `Primary` (`#006C4C`) with a crisp `3dp` white concentric inner dot.
  - Elevation: Level 2 shadow (`blur: 10px`, `color: rgba(0, 108, 76, 0.35)`).
- **Floating Value Pin / Callout Badge:**
  - Position: Floating directly above the slider thumb (`8dp` offset above track).
  - Shape: Rounded tooltip pill (`32dp` height, `64dp` width, `16dp` corner radius) with a subtle inverted triangle pointer anchored to the thumb center.
  - Background: Solid `Primary` (`#006C4C`).
  - Text: `"65 kg"` in bold `TitleLarge` (`15sp`, `#FFFFFF`).
- **Tick Marks & Boundary Labels:**
  - Left Terminus Label: `"15 kg (Min)"` in `LabelSmall` (`#717973`).
  - Right Terminus Label: `"120 kg (Max)"` in `LabelSmall` (`#717973`).
  - Discrete milestone dots along the track at: `15`, `30`, `45`, `60`, `75`, `90`, `105`, `120 kg`.
- **Explanatory Context Subtitle:**
  - *"Used for WHO single-snack sugar/sodium limits & JECFA mg/kg additive ADI calculations."* (BodySmall, `#717973`).

### 3.3 5-Language Selector Chips
- **Purpose:** Regional language accessibility across India for voice read-outs, toxicology alerts, and label explanations.
- **Languages Required:**
  1. **English** (Default / Active)
  2. **Hindi** (`हिंदी`)
  3. **Marathi** (`मराठी`)
  4. **Tamil** (`தமிழ்`)
  5. **Telugu** (`తెలుగు`)
- **Chip Dimensions:** Height `36dp`, Corner Radius `10dp`, Horizontal Padding `14dp`, Gap `8dp`.
- **State Specifications:**
  - **Selected Chip ("English"):**
    - Container: `Primary Container` (`#8CF7C8`)
    - Border: None (or subtle `1dp` `#006C4C`)
    - Leading Icon: `Icons.check` (`18dp`, color `#002114`)
    - Label Text: `"English"` in `On-Primary Container` (`#002114`, 14sp, Semi-Bold)
  - **Unselected Chips (Hindi, Marathi, Tamil, Telugu):**
    - Container: `Surface Container Low` (`#F5F7F3`) or White (`#FFFFFF`)
    - Border: `1dp` solid `Outline` (`#C0C9C2`)
    - Leading Icon: None
    - Label Text: Native script with bilingual clarity:
      * `"हिंदी (Hindi)"` or `"हिंदी"`
      * `"मराठी (Marathi)"` or `"मराठी"`
      * `"தமிழ் (Tamil)"` or `"தமிழ்"`
      * `"తెలుగు (Telugu)"` or `"తెలుగు"`
    - Text Styling: `On-Surface Variant` (`#414943`, 13sp, Medium)
- **Layout Arrangement:** Multi-chip flex row or 2-row grid fitting neatly within card bounds.

### 3.4 Call-To-Action (CTA) Buttons
Both CTAs must be prominently displayed in the bottom pinned action zone:
- **Primary CTA: "Save & Open Dashboard"**
  - Visual Hierarchy: Highest priority filled button.
  - Dimensions: Height `56dp`, Full Card Width (~328dp), Corner Radius `28dp` (full pill).
  - Background: `Primary` (`#006C4C`).
  - Text: `"Save & Open Dashboard"` in `On-Primary` (`#FFFFFF`, 16sp, Semi-Bold, letter-spacing +0.2sp).
  - Leading / Trailing Icon: Trailing arrow icon (`Icons.arrow_forward`, 20dp, `#FFFFFF`).
  - Elevation: Level 2 (`offset: (0, 4)`, `blur: 16px`, `color: rgba(0, 108, 76, 0.28)`).
  - Function: Commits user's baseline weight and language to local storage and transitions to Page 4: Home Dashboard.
- **Secondary CTA: "Instant Scan Now"**
  - Visual Hierarchy: Secondary outlined or tonal button.
  - Dimensions: Height `52dp`, Full Card Width (~328dp), Corner Radius `26dp` (pill).
  - Background: Transparent with `1.5dp` solid border in `Primary` (`#006C4C`), or Tonal `Secondary Container` (`#D0E8D9`).
  - Text: `"Instant Scan Now"` in `Primary` (`#006C4C`, 15sp, Semi-Bold).
  - Leading Icon: Barcode / Camera Viewfinder icon (`Icons.document_scanner` or `Icons.qr_code_scanner`, 20dp, `#006C4C`).
  - Function: Zero-friction camera bypass jumping straight into Page 5: Smart Camera for immediate barcode / backside OCR scanning.

---

## 4. Screen Layout Hierarchy in 9:16 Mobile Aspect Ratio

Total Viewport: `1080 x 1920` (or `1440 x 2560` / `9:16` ratio).

```
+-------------------------------------------------------------+ [0% - 4%]
|  9:41                          5G [Icon]  WiFi  Battery 100%| Status Bar (24-40dp)
+-------------------------------------------------------------+ [4% - 10%]
|  [Shield Logo] SafeBite AI                      [Help ?]    | App Bar (56dp)
+-------------------------------------------------------------+ [10% - 34%]
|                                                             |
|           [ 3D / VECTOR HERO ILLUSTRATION ]                 |
|       Smartphone scanning packaged snack with               | Hero Scanner
|      green laser beam & floating health score "88"          | Section (~230dp)
|                                                             |
|   "Safe Consumption & Toxicology Scanner"                   | Title (22sp Bold)
|   Detect hidden sugars, toxic additives & safe gram limits  | Subtitle (13sp)
+-------------------------------------------------------------+ [34% - 80%]
| +---------------------------------------------------------+ |
| |  CARD: USER PROFILE & DOSAGE BASELINE                   | | Configuration
| |                                                         | | Container Card
| |  [ Adult (65 kg) *SELECTED* ]  [ Child (20 kg) ]        | | (Rounded 24dp)
| |                                                         | |
| |  Body Weight Baseline                                   | |
| |                   [ 65 kg (Pin) ]                       | |
| |  15 kg  ==========( O )------------------------ 120 kg  | | Weight Slider
| |  Used for WHO 20% limits & JECFA toxic additive scaling | |
| |                                                         | |
| |  Select Language                                        | |
| |  [✓ English]  [हिंदी]  [मराठी]  [தமிழ்]  [తెలుగు]       | | Language Chips
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+ [80% - 98%]
|                                                             |
|  [=== Save & Open Dashboard ===========================-> ] | Primary CTA (56dp)
|                                                             |
|  [ [O] Instant Scan Now                                   ] | Secondary CTA (52dp)
|                                                             |
+-------------------------------------------------------------+ [98% - 100%]
|                         ______                              | Home Indicator
+-------------------------------------------------------------+
```

### Detailed Vertical Metric Breakdown (Based on 1920px Height Grid):
1. **0 to 76px (0.0% – 4.0%): System Status Bar**
   - High-contrast black status icons (`#191C1A`): Digital clock "9:41" at top left, cellular signal bars, WiFi icon, and battery pill at top right.
2. **76 to 184px (4.0% – 9.6%): Top App Bar**
   - Left: Bio-Safety Shield brand badge with vibrant emerald leaf (`#006C4C`), brand name `"SafeBite AI"` in Bold 18sp.
   - Right: Subtle circular info/help icon button.
3. **184 to 650px (9.6% – 33.8%): Hero Visual & Value Proposition**
   - Central Hero Illustration: Sleek smartphone scanning a packaged snack with a soft glowing emerald OCR boundary box, floating holographic data chips displaying `"0 Hidden Sugars"`, `"NOVA 1 Clean"`, and `"Safe Portion: 45g"`.
   - Title Header: `"Smart Toxicology & Safe Dosage Scanner"` in 22sp Bold (`#191C1A`).
   - Descriptive Copy: `"Detect hidden sugars, toxic additives, and get personalized daily consumption limits based on your body weight."` in 13sp (`#414943`).
4. **650 to 1540px (33.8% – 80.2%): Core Form Configuration Card**
   - Container: Clean rounded card with `Surface Container Low` (`#F5F7F3`) or white with soft border `Outline Variant` (`#E0E5DF`) and 20dp padding.
   - **Sub-block A (Mode Toggle):** Segmented button featuring `"Adult (65 kg)"` (active, filled emerald) and `"Child (20 kg)"` (inactive, outline).
   - **Sub-block B (Body Weight Slider):** Section title `"Body Weight Baseline"`, horizontal track spanning 15–120 kg, active emerald progress bar to 65 kg, floating elevation tooltip badge displaying `"65 kg"`, and boundary labels `"15 kg"` and `"120 kg"`.
   - **Sub-block C (Language Preference):** Section title `"Select Language"`, 5 horizontal filter chips: `"✓ English"` (selected, mint green container), `"हिंदी"`, `"मराठी"`, `"தமிழ்"`, `"తెలుగు"`.
5. **1540 to 1880px (80.2% – 97.9%): Bottom Pinned Actions**
   - Primary CTA: `"Save & Open Dashboard"` (Height 56dp, filled `#006C4C`, white text, trailing arrow).
   - Secondary CTA: `"Instant Scan Now"` (Height 52dp, outlined or tonal `#D0E8D9`, camera/scanner icon).
6. **1880 to 1920px (97.9% – 100.0%): Navigation Safe Zone**
   - Centered iOS/Android navigation home pill (`134px x 5px`, rounded radius `2.5px`, color `#191C1A`).

---

## 5. Visual Prompt Engineering Directives for Mockup Generation

To generate the photorealistic, production-grade UI design mockup `01_onboarding_v2_refined.jpg`, use the following comprehensive prompt blueprints.

### 5.1 Primary Prompt Formulation (Optimized for Image Generation)

```text
High-resolution production mobile app UI design mockup, modern Google Material 3 Design System, clean flat design, portrait 9:16 aspect ratio, sleek bezel-less smartphone screen, Behance and Dribbble trending mobile UI.

Screen Title & Theme: "Page 1: Starter Screen & Onboarding" for "SafeBite AI: Smart Packaged Product Ingredient, Toxicology & Safe Consumption Dosage Scanner".

Visual Palette & Colors: Clinical emerald green (#006C4C) primary color, fresh mint accents (#8CF7C8), pristine medical white background (#FBFDF9), soft neutral slate containers (#F5F7F3), dark high-contrast charcoal typography (#191C1A).

Screen Layout Architecture (Top to Bottom):
1. TOP STATUS BAR: Android/iOS status bar with "9:41", full WiFi, 5G signal, and battery indicators. Minimalist top bar with emerald shield logo and text "SafeBite AI".
2. HERO SECTION: Clean modern 3D vector illustration of a smartphone scanning a packaged food box with an emerald laser OCR grid, floating holographic badges reading "Safe Dosage 45g" and "0 Toxic Additives". Bold headline: "Smart Toxicology & Safe Dosage Scanner", followed by subtitle: "Personalize your safe consumption limits and detect hidden sugars based on your body weight."
3. FORM CONFIGURATION CARD (White elevated rounded card with 24px radius):
   - MODE TOGGLE: Material 3 Segmented Button with two options: "Adult (65 kg)" [ACTIVELY SELECTED with filled emerald green background and white text] and "Child (20 kg)" [unselected with clean outline].
   - BODY WEIGHT SLIDER: Title "Body Weight Baseline". Horizontal interactive slider bar spanning "15 kg" on left to "120 kg" on right. Active emerald track filled to 65 kg, circular thumb with a floating pill badge directly above it displaying "65 kg". Explanatory helper text: "Scales WHO 20% single-snack sugar limits & JECFA additive ADI."
   - LANGUAGE CHIPS: Section header "App Language". Row of 5 Material 3 Filter Chips: "✓ English" [ACTIVELY SELECTED in mint green container with checkmark], followed by unselected chips: "हिंदी", "मराठी", "தமிழ்", "తెలుగు".
4. BOTTOM ACTION BUTTONS:
   - Primary CTA Button: Large full-width pill button filled with emerald green (#006C4C), white bold text reading "Save & Open Dashboard" with a trailing arrow icon.
   - Secondary CTA Button: Outlined pill button with camera scanner icon reading "Instant Scan Now".
5. BOTTOM NAVIGATION: Centered iOS home indicator bar.

Aesthetic: Ultra-sharp UI typography, crystal clear vector icons, pixel-perfect alignment, Material 3 Expressive styling, soft diffuse ambient shadows, premium health tech app design, 8k resolution, photorealistic screen render.
```

### 5.2 Negative Prompt Directives (Artifact Suppression)

```text
low quality, blurry, fuzzy text, illegible typography, misspelled words, garbled gibberish text, 3D realistic human photograph, hand holding phone, tilted perspective, isometric mockups on wooden desks, skewed camera angle, distorted UI components, missing buttons, duplicate sliders, dark mode, neon clashing colors, cluttered interface, unaligned icons, cartoonish distortion, cropped buttons.
```

### 5.3 Technical Generation Parameters
- **Aspect Ratio:** `9:16`
- **Output Filename:** `01_onboarding_v2_refined.jpg`
- **Resolution:** `1080 x 1920` (or `1440 x 2560` upscale)
- **Format:** High-quality JPEG (95% quality, sRGB color profile)

---

## 6. Verification & Acceptance Checklist

| Requirement | Acceptance Criteria | Verification Method |
| :--- | :--- | :--- |
| **Asset Format** | File is named `01_onboarding_v2_refined.jpg` and saved in project root. | Filesystem existence check |
| **Aspect Ratio** | Aspect ratio is strictly 9:16 mobile portrait format. | Image metadata verification |
| **Material 3 System** | Uses M3 tonal green palette, pill buttons (28dp), stadium segmented buttons, 8dp grid. | Visual component audit |
| **Adult / Child Toggle**| Visible segmented toggle with Adult (65kg) selected and Child (20kg) unselected. | Visual text inspection |
| **Body Weight Slider**| Horizontal slider spanning 15–120 kg with prominent 65 kg callout badge. | Visual text inspection |
| **5 Language Chips** | All 5 languages clearly visible: English (selected), Hindi, Marathi, Tamil, Telugu. | Visual text inspection |
| **Dual CTAs** | "Save & Open Dashboard" (Filled Primary) and "Instant Scan Now" (Outlined Secondary). | Visual button inspection |

---

## 7. Developer Implementation Mapping (Flutter / Dart)

For frontend developers implementing Page 1 into Flutter (`mobile_app/lib/features/onboarding/onboarding_screen.dart`), the component structure maps directly to:

```dart
// Theme Seed
final theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF006C4C),
    brightness: Brightness.light,
  ),
  useMaterial3: true,
);

// Segmented Button
SegmentedButton<ProfileMode>(
  segments: const [
    ButtonSegment(
      value: ProfileMode.adult,
      label: Text('Adult (65 kg)'),
      icon: Icon(Icons.person),
    ),
    ButtonSegment(
      value: ProfileMode.child,
      label: Text('Child (20 kg)'),
      icon: Icon(Icons.child_care),
    ),
  ],
  selected: {selectedMode},
  onSelectionChanged: (val) => updateMode(val.first),
);

// Body Weight Slider
Slider(
  value: currentWeight,
  min: 15.0,
  max: 120.0,
  divisions: 105,
  label: '${currentWeight.round()} kg',
  onChanged: (val) => setWeight(val),
);

// Language Chips
Wrap(
  spacing: 8.0,
  children: [
    FilterChip(
      label: const Text('English'),
      selected: selectedLang == 'en',
      onSelected: (_) => setLang('en'),
    ),
    FilterChip(
      label: const Text('हिंदी'),
      selected: selectedLang == 'hi',
      onSelected: (_) => setLang('hi'),
    ),
    FilterChip(
      label: const Text('मराठी'),
      selected: selectedLang == 'mr',
      onSelected: (_) => setLang('mr'),
    ),
    FilterChip(
      label: const Text('தமிழ்'),
      selected: selectedLang == 'ta',
      onSelected: (_) => setLang('ta'),
    ),
    FilterChip(
      label: const Text('తెలుగు'),
      selected: selectedLang == 'te',
      onSelected: (_) => setLang('te'),
    ),
  ],
);

// Bottom Action CTAs
FilledButton.icon(
  onPressed: () => saveAndOpenDashboard(),
  icon: const Icon(Icons.arrow_forward),
  label: const Text('Save & Open Dashboard'),
  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
);

OutlinedButton.icon(
  onPressed: () => openInstantScanner(),
  icon: const Icon(Icons.qr_code_scanner),
  label: const Text('Instant Scan Now'),
  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
);
```
