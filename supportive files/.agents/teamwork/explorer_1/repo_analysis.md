# Repository Asset and UI Design Analysis Report

**Date**: 2026-11-03  
**Investigator**: `explorer_1` (teamwork_explorer)  
**Target Repository**: `c:\yash\projects\first mobile app`  
**Target Artifact**: `01_onboarding_v2_refined.jpg` (Page 1: Starter Screen / Onboarding)

---

## 1. Executive Summary

A comprehensive investigation of the project repository (`c:\yash\projects\first mobile app`), its git commit history across all branches, and configuration documents was conducted to establish asset conventions, design specifications, and requirements for `01_onboarding_v2_refined.jpg`.

Key findings:
1. **Existing Image Files**: Currently, **zero** image/mockup files (`.jpg`, `.png`, `.webp`, `.svg`) exist in the repository filesystem or in git history. The repository is in an active phase of asset and mockup generation.
2. **Mockup Architecture in Specifications**: In `PROJECT_SPECIFICATION.md` (lines 41–56), 6 core screens have designated mockup filenames marked with `✅ Mockup Ready`:
   - Page 1: Starter Page (`01_onboarding_v2_refined.jpg`)
   - Page 4: Home Page (`02_home_dashboard_v1.jpg`)
   - Page 5: Smart Camera (`03_smart_camera_v2_refined.jpg`)
   - Page 6: Master Verdict (`04_master_verdict_v2_refined.jpg`)
   - Page 7: Ingredients Page (`05_ingredient_breakdown_v2_refined.jpg`)
   - Page 8: Ingredients Deep Dive Page (`06_ingredient_deep_dive_v2_refined.jpg`)
3. **Asset Conventions & Location**:
   - Location: Direct repository root (`c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg`) to align with `PROJECT_SPECIFICATION.md` and `ORIGINAL_REQUEST.md`.
   - Naming Convention: `XX_<screen_name>_v<version>[_refined].jpg` with zero-padded 2-digit screen prefix, lowercase snake_case, and `.jpg` extension.
   - Format: Single full-screen JPEG image with a **9:16 mobile aspect ratio** (e.g. 1080x1920 or native 9:16 portrait resolution).
4. **Codebase UI Reference**:
   - The Flutter implementation in `mobile_app/lib/main.dart` configures `useMaterial3: true` with primary seed color `Color(0xFF0F9D58)` (Google Green / Health Emerald).
   - In branch `backup-phase6-complete:mobile_app/lib/features/onboarding/presentation/starter_screen.dart` and `mobile_app/test/starter_screen_test.dart`, the complete widget tree for Page 1 is already implemented and tested.

---

## 2. Mockup & Image Inventory

| Search Scope | Pattern / Query | Results | Details |
| :--- | :--- | :---: | :--- |
| Filesystem (all directories) | `*.jpg, *.png, *.webp, *.svg, *.jpeg` | **0** | No image assets found in repo tree |
| Git History (`master` & `backup-phase6-complete`) | `\.(jpg\|jpeg\|png\|webp\|svg\|gif)$` | **0** | No historical image commits |
| `PROJECT_SPECIFICATION.md` | Table in Section 3 (Lines 41–56) | **6 named mockups** | Listed as target mockup references for Pages 1, 4, 5, 6, 7, 8 |
| `ORIGINAL_REQUEST.md` | Requirement R1 & Acceptance Criteria | **1 target** | `01_onboarding_v2_refined.jpg` |

### Catalog of Screen Mockup Names in Specification:
- `01_onboarding_v2_refined.jpg` — Page 1: Starter Page / Onboarding
- `02_home_dashboard_v1.jpg` — Page 4: Home Dashboard
- `03_smart_camera_v2_refined.jpg` — Page 5: Smart Camera Viewfinder
- `04_master_verdict_v2_refined.jpg` — Page 6: Master Verdict & Safe Portion Card
- `05_ingredient_breakdown_v2_refined.jpg` — Page 7: Ingredients & Split Sugar Breakdown
- `06_ingredient_deep_dive_v2_refined.jpg` — Page 8: Toxicology Deep Dive Modal

---

## 3. Repository Conventions & Asset Standards

### 3.1 Asset Location & Pathing
- **Root Repository Placement**: `PROJECT_SPECIFICATION.md` (line 43) references the mockup as `01_onboarding_v2_refined.jpg` directly. `ORIGINAL_REQUEST.md` explicitly specifies saving in the project repository root: `c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg`.
- **Flutter App Bundle Placement**: In `mobile_app/pubspec.yaml`:
  ```yaml
  flutter:
    uses-material-design: true
    assets:
      - assets/db/
      - assets/mlkit/
  ```
  Runtime mobile assets are placed in `mobile_app/assets/`. Presentation mockups are stored at the repository root level for project documentation, design reviews, and README integration.

### 3.2 Naming Standards
- Two-digit prefix matching screen sequence: `01_`, `02_`, `03_`, etc.
- Descriptive identifier: `onboarding`, `home_dashboard`, `smart_camera`, etc.
- Version iteration indicator: `v1`, `v2`.
- Refinement suffix: `_refined`.
- Extension: `.jpg` (JPEG format).

### 3.3 Aspect Ratio & Resolution Standards
- **Aspect Ratio**: 9:16 portrait mobile aspect ratio.
- **Recommended Resolutions**:
  - High fidelity: `1080 x 1920` (standard 9:16 FHD mobile viewport).
  - Production generation: 9:16 aspect ratio output directly supported by modern image generation tools.

---

## 4. UI Design Style & Component Mapping for Page 1

### 4.1 Design Framework & Theme
- **Framework**: Material 3 (Material Design 3 / Material You).
- **Primary Color Palette**:
  - Primary / Brand Accent: `Color(0xFF0F9D58)` (Health Emerald Green / Google Green)
  - Dark Neutral / Text: `#1A1C1E` / `#212121`
  - Surface Background: Clean off-white / light neutral (`#F8F9FA` or `#FFFFFF`)
  - Surface Containers / Cards: Rounded cards (`16dp` - `24dp` border radius) with subtle tonal surface elevation
  - Outline / Dividers: Light gray `#E0E2EC` / `#E0E0E0`
  - Secondary Accent / Selection: Mint green tint (`#E8F5E9` / `#C8E6C9`) for active selector chips and toggle states

### 4.2 Exact Component Architecture for Page 1 (`01_onboarding_v2_refined.jpg`)

Based on `ORIGINAL_REQUEST.md`, `PROJECT_SPECIFICATION.md`, and the Flutter source code in `starter_screen.dart`:

```
+-------------------------------------------------------------+
| [9:16 Mobile Screen - Modern Status Bar (Time, Wifi, Batt)] |
|                                                             |
| App Bar: "Safety Profile Setup"                             |
|                                                             |
| Hero Visual / Header:                                       |
| - Health Scanner shield / nutrition icon                    |
| - Headline: "Personalize Your Safe Dosage"                  |
| - Subtitle: "Calculate exact consumption limits based on    |
|   your body weight & WHO guidelines"                        |
|                                                             |
| Component 1: Adult / Child Mode Toggle (SegmentedButton)    |
|   [  [✓] Adult (65 kg)   |   [ ] Child (20 kg)  ]           |
|                                                             |
| Component 2: Body Weight Slider                             |
|   Label: "Body Weight"             Value: "65.0 kg"         |
|   (---O---------------------------------------------)       |
|   Range Indicators: "15 kg"                "120 kg"         |
|                                                             |
| Component 3: 5-Language Selector Chips (Wrap / FilterChips) |
|   Label: "Preferred Language"                               |
|   [✓ English]  [ हिंदी ]  [ मराठी ]  [ தமிழ் ]  [ తెలుగు ]   |
|                                                             |
| Component 4: Primary Action CTA (ElevatedButton)            |
|   [       Save & Open Dashboard       ]  (Solid Green)      |
|                                                             |
| Component 5: Secondary Action CTA (OutlinedButton)          |
|   [          Instant Scan Now         ]  (Outlined Green)   |
|                                                             |
| Helper Link: "Sign In or Setup Guardrails"                  |
+-------------------------------------------------------------+
```

### 4.3 Component Verification Checklist against Requirements

| Requirement ID | Component | Specification | Source Reference |
| :--- | :--- | :--- | :--- |
| **R1** | Asset Delivery | `01_onboarding_v2_refined.jpg`, 9:16 mobile aspect ratio | `ORIGINAL_REQUEST.md` (R1) |
| **R2.1** | Adult / Child Toggle | Dual SegmentedButton with baseline values: "Adult (65 kg)" and "Child (20 kg)" | `ORIGINAL_REQUEST.md`, `starter_screen.dart:25-28` |
| **R2.2** | Body Weight Slider | Interactive slider spanning 15–120 kg, current value readout (65.0 kg) | `ORIGINAL_REQUEST.md`, `starter_screen.dart:33-47` |
| **R2.3** | Language Selector Chips | 5 regional language chips: English, Hindi (हिंदी), Marathi (मराठी), Tamil (தமிழ்), Telugu (తెలుగు) | `ORIGINAL_REQUEST.md`, `starter_screen.dart:51-64` |
| **R2.4** | Primary CTA Button | "Save & Open Dashboard" with primary filled button styling (`#0F9D58`) | `ORIGINAL_REQUEST.md`, `starter_screen.dart:67-79` |
| **R2.5** | Secondary CTA Button | "Instant Scan Now" with secondary outlined button styling | `ORIGINAL_REQUEST.md`, `starter_screen.dart:82-93` |

---

## 5. Downstream Recommendations for Asset Creation

1. **Generation Tool**: Use `generate_image` tool with `AspectRatio: "9:16"` and save directly as `01_onboarding_v2_refined.jpg` in repo root `c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg`.
2. **Prompt Construction**:
   - Explicitly instruct Material 3 design system, modern clean mobile app screenshot mockup.
   - Describe each UI widget in strict position and typography:
     - Header: "Safety Profile Setup" with nutrition shield / scanner icon.
     - Mode toggle: Segmented button displaying "Adult (65 kg)" (selected) and "Child (20 kg)".
     - Slider section: "Body Weight" with bold emerald green badge "65.0 kg", smooth slider track with min "15 kg" and max "120 kg".
     - Language chips: Rounded chips with "English" (selected with checkmark), "हिंदी", "मराठी", "தமிழ்", "తెలుగు".
     - Primary button: Large rounded button in emerald green (#0F9D58) labeled "Save & Open Dashboard".
     - Secondary button: Outlined button labeled "Instant Scan Now".
   - Crisp UI elements, clean typography, photorealistic mobile UI mockup presentation.
3. **Verification**: After creation, inspect image file path, file size, aspect ratio, and verify all visual acceptance criteria.
