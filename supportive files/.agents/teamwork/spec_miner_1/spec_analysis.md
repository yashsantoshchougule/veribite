# Specification Analysis: Page 1 — Starter Screen / Onboarding

**Project**: Smart Packaged Product Ingredient, Toxicology & Safe Consumption Dosage Scanner  
**Document Author**: `spec_miner_1` (teamwork_spec_miner)  
**Date**: 2026-11-03  
**Status**: Authoritative Specification Extracted  

---

## 1. Executive Summary & Specification Sources

This document provides a comprehensive, rigorous extraction of all functional requirements, UI architecture, design tokens, interaction behaviors, and verification criteria for **Page 1: Starter Screen / Onboarding**.

### Authoritative Specification Sources Consulted
1. **`PROJECT_SPECIFICATION.md`** (Project Workspace Root):
   - §1: Plain-Language Overview & Consumer Problem Definition (Lines 8–18)
   - §2: Motive & Core Objectives (Lines 20–35)
   - §3: Application Screen Architecture — Table row `Page 1: Starter Page` (Lines 41–43)
   - §4.4: Feature 4: Precision Safe Consumption Dosage & Frequency Engine (Lines 79–90)
   - §5: Technology Stack & Tools (Lines 92–102)
2. **`ORIGINAL_REQUEST.md`** (`.agents/teamwork/ORIGINAL_REQUEST.md`):
   - R1: First Page UI Mockup Asset (`01_onboarding_v2_refined.jpg`, 9:16 mobile aspect ratio) (Lines 16–18)
   - R2: Page 1 Component Specifications (Lines 19–26)
   - Acceptance Criteria (Lines 27–39)
3. **`docs/plans/master-project-plan.md`**:
   - Task 3.2: Page 1 — Onboarding & Body-Weight Setup Screen (Lines 253–265)
4. **`rules/03-architecture-and-techstack.md` & `rules/04-safety-and-scoring-algorithms.md`**:
   - Flutter Material 3, Riverpod, GoRouter, JECFA ADI body-weight scaling formulas
5. **`mobile_app/lib/main.dart` & `mobile_app/lib/core/scoring/dosage_engine.dart`**:
   - Seed color `Color(0xFF0F9D58)` (Material 3 Green), 65kg Adult baseline, 20kg Child baseline, weight ratio formulas.

---

## 2. Page 1 Architectural Purpose & Functional Context

In the Smart Packaged Product Safety Scanner ecosystem, Page 1 is not merely a generic welcome screen; it serves as the **critical biological calibrator** for the application's core toxicological engine:
- **Dosage Engine Calibration**: Acceptable Daily Intake (ADI) and the 20% WHO single-snack portion limits rely strictly on user body weight:
  $$\text{Adjusted Safe Portion (g)} = \text{Base Safe Portion} \times \left(\frac{\text{User\_Weight\_kg}}{65\text{ kg}}\right)$$
- **Child Sensitivity Guardrails**: Toggling to "Child" mode activates specialized pediatric toxicity alerts (such as Southampton synthetic azo dye hyperactivity warnings per EFSA guidelines) and alters baseline portion tolerances.
- **Regional Linguistic Accessibility**: 5-language selector chips ensure that consumers across diverse Indian linguistic demographics (English, Hindi, Marathi, Tamil, Telugu) receive instant visual and text-to-speech (`flutter_tts`) voice alerts.
- **Zero-Friction Entry**: Features dual CTAs allowing users to either save preferences and proceed to the Home Dashboard or immediately initiate an instant camera scan without mandatory account registration.

---

## 3. Detailed Component & UI State Specifications

### 3.1 Adult / Child Mode Toggle
- **Component Type**: Material 3 Segmented Button / Dual Tab Selector (`SegmentedButton<UserMode>` or Pill Switch).
- **Options**:
  1. **Adult Mode**:
     - Visual Icon: Person / Adult silhouette (`Icons.person` or Material Symbol).
     - Label: "Adult"
     - Subtitle/Badge: "Baseline: 65 kg" (Standard WHO/JECFA adult benchmark).
     - Default State: Selected by default on initial application launch.
  2. **Child Mode**:
     - Visual Icon: Child / Family silhouette (`Icons.child_care` or `Icons.face`).
     - Label: "Child"
     - Subtitle/Badge: "Baseline: 20 kg" (Pediatric benchmark).
     - Default State: Unselected initially.
- **Interaction Behavior**:
  - Selecting "Adult" automatically animates the body weight slider thumb to **65 kg** (if currently set to child baseline).
  - Selecting "Child" automatically animates the body weight slider thumb to **20 kg** and enables pediatric risk filters.
  - Active segment displays filled container styling (`colorScheme.primaryContainer` with `colorScheme.onPrimaryContainer`), high-contrast border, and bold label. Inactive segment is outlined or low-elevation tonal.

### 3.2 Interactive Body Weight Slider
- **Component Type**: Material 3 Slider with numerical digital readout badge (`Slider` / custom M3 thumb).
- **Range & Constraints**:
  - Minimum value: **15 kg** (Minimum child threshold).
  - Maximum value: **120 kg** (Upper adult calibration ceiling).
  - Step interval: 1 kg (discrete increments) or smooth continuous with integer rounding.
- **Visual Presentation**:
  - Prominent real-time display card / badge showing the active numerical weight: e.g. **"65 kg"** or **"20 kg"**.
  - Dynamic explanatory caption below the readout:
    - E.g., *"Calibrates WHO safe consumption grams and JECFA chemical additive limits for your body mass."*
  - Track styling: Active track in Emerald Green (`#0F9D58`), inactive track in soft tonal neutral (`#E1E4DF` / `surfaceContainerHighest`).
  - Min/Max boundary labels clearly indicated at track terminals (`15 kg` at start, `120 kg` at end).

### 3.3 5-Language Selector Chips
- **Component Type**: Material 3 Choice Chips / Filter Chips (`ChoiceChip` / `InputChip`).
- **Language Options (5 Indian Regional Languages)**:
  1. **English**: Label `"English"`
  2. **Hindi**: Label `"हिन्दी (Hindi)"`
  3. **Marathi**: Label `"मराठी (Marathi)"`
  4. **Tamil**: Label `"தமிழ் (Tamil)"`
  5. **Telugu**: Label `"తెలుగు (Telugu)"`
- **Selection Semantics**:
  - Single-select radio behavior (exactly one active language at any time).
  - Default selection: **English** (or device system locale if matching one of the 5).
  - Visual State:
    - **Selected**: Filled background (`primaryContainer`), bold text, visible checkmark icon (`Icons.check`).
    - **Unselected**: Outlined border (`outlineVariant`), neutral background, standard font weight.
- **System Integration**:
  - Directly sets the locale for app strings and initializes `flutter_tts` regional voice synthesis engine for audio health verdicts.

### 3.4 Primary CTA Button: "Save & Open Dashboard"
- **Label**: **"Save & Open Dashboard"** (or `"Save & Continue to Dashboard"`).
- **Component Type**: Material 3 High-Emphasis Filled Button (`FilledButton` / `ElevatedButton`).
- **Visual Styling**:
  - Background color: Primary Emerald Green (`#0F9D58` / M3 Primary).
  - Text/Icon color: High-contrast white (`#FFFFFF` / `onPrimary`).
  - Shape: Rounded pill (corner radius 24–28dp) or M3 large rounded rectangle.
  - Sizing: Full-width (with 24dp horizontal margins) or hero elevation, minimum height 52–56dp.
  - Trailing Icon: Arrow forward (`Icons.arrow_forward_rounded`).
- **Functional Action**:
  - Commits selected Mode (Adult/Child), calibrated Weight (kg), and Language preference to local persistent storage (`SharedPreferences` / SQLite).
  - Navigates user to Page 4: Home Dashboard (`/dashboard`).

### 3.5 Secondary CTA Button: "Instant Scan Now"
- **Label**: **"Instant Scan Now"** (or `"Instant Scan Without Account"`).
- **Component Type**: Material 3 Medium-Emphasis Tonal or Outlined Button (`FilledButton.tonal` or `OutlinedButton`).
- **Visual Styling**:
  - Background color: Primary tonal container (`#D4F0E1` / `primaryContainer`) or outlined transparent with green border (`#0F9D58`).
  - Text/Icon color: Dark emerald green (`#005134` / `onPrimaryContainer` or `primary`).
  - Leading Icon: Camera / Barcode scan glyph (`Icons.qr_code_scanner_rounded` or `Icons.camera_alt_outlined`).
  - Sizing: Full-width matching primary CTA, minimum height 48–52dp.
- **Functional Action**:
  - Bypasses dashboard setup and immediately opens Page 5: Smart Camera (`/camera`) for zero-friction scanning using the currently configured baseline weight.

### 3.6 Header, Branding & Value Proposition Content
- **App Title / Brand**:
  - Logo / Glyph: Health Shield with Scanner Beam / Leaf motif.
  - Title: **"NutriScan AI"** / **"Smart Food & Toxicology Scanner"**.
- **Value Proposition Banner / Tagline**:
  - Headline: *"Scan the Real Truth Behind Packaged Food"*
  - Subhead: *"Uncover hidden sugars, decoded INS chemicals, and your personalized safe daily consumption dosage."*
- **Privacy & Offline Trust Badge**:
  - Indicator: *"🔒 100% On-Device Offline Capable · Zero Tracking"*

---

## 4. Theme, Typography, Color Palette & Material 3 Directives

### 4.1 Color Palette Tokens (Derived from `main.dart` & Material 3 Spec)
| Design Token | Hex Code | Material 3 Semantic Role | Application Context |
| :--- | :--- | :--- | :--- |
| `primary` | `#0F9D58` | Primary Brand & Safety | Primary CTA button, active slider track, selected chip accent |
| `onPrimary` | `#FFFFFF` | Text on Primary | Primary CTA text, selected toggle text |
| `primaryContainer` | `#CEE9DB` / `#D4F0E1` | Primary Soft Tint | Selected chip background, active segmented button container |
| `onPrimaryContainer` | `#002114` / `#003822` | Text on Primary Container | Selected chip label text |
| `surface` | `#FFFFFF` / `#F8FAF9` | App Background Surface | Clean card surfaces, main screen scaffold |
| `surfaceContainerLow` | `#F2F5F3` | Elevated Card Fill | Container cards for Slider, Mode selector, Language grid |
| `outlineVariant` | `#C0C9C2` / `#E1E4DF` | Subtle Borders | Unselected chip borders, slider inactive track |
| `onSurface` | `#191C1B` | High-Contrast Dark Text | Screen title, weight digital readout, section labels |
| `onSurfaceVariant` | `#404944` / `#5A605C` | Medium-Contrast Text | Value proposition subtitle, helper notes, min/max labels |
| `error / alert` | `#BA1A1A` | Red Toxicity Cap Reference | Visual cue for Red-tier toxic additive warnings |

### 4.2 Typography Hierarchy (Material 3 Scale)
| Text Element | M3 Token | Font Weight | Recommended Size | Content Example |
| :--- | :--- | :--- | :--- | :--- |
| Screen Title | `HeadlineMedium` | Bold (700) | 26–28 sp | "Personalize Your Safety Profile" |
| Value Prop | `BodyMedium` | Regular (400) | 14 sp | "Calculates exact safe dosage based on your weight." |
| Section Headings | `TitleMedium` | SemiBold (600) | 16 sp | "Who is this for?", "Body Weight", "Language" |
| Weight Readout | `DisplaySmall` | ExtraBold (800) | 36–40 sp | "65 kg" (or "20 kg") |
| Slider Boundaries | `LabelSmall` | Medium (500) | 11–12 sp | "15 kg (Child Min)" / "120 kg (Adult Max)" |
| Chip Labels | `LabelLarge` | Medium/SemiBold | 13–14 sp | "हिन्दी", "English", "தமிழ்" |
| Primary CTA | `LabelLarge` | SemiBold (600) | 15–16 sp | "Save & Open Dashboard" |
| Secondary CTA | `LabelLarge` | Medium (500) | 14–15 sp | "Instant Scan Now" |

### 4.3 Material 3 Component & Layout Specifications
- **Grid & Margins**: 8dp baseline grid, 20–24dp horizontal margins on mobile screen.
- **Card Styling**: Elevated cards (`elevation: 1` or `surfaceContainerLow`) with 16–20dp border radius and 1dp border outline (`outlineVariant`).
- **Touch Target Ergonomics**: Minimum 48x48 dp touch targets for all interactive controls (slider thumb, chips, buttons, toggles).
- **Aspect Ratio Requirement**: 9:16 mobile aspect ratio viewport (1080 x 1920 logical proportions).

---

## 5. Specification Mining Tables

### Features Discovered
| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Profile / Calibration | Mode Toggle (Adult / Child) | Segments user profile into Adult (65kg standard) or Child (20kg standard) | User tap on segment | Updates active mode state, resets slider to mode baseline | Non-selectable state prevented; defaults to Adult | `PROJECT_SPECIFICATION.md` §3 (Line 43) & `ORIGINAL_REQUEST.md` R2 |
| 2 | Dosage Engine | Body Weight Slider | Continuous/stepped slider adjusting body mass between 15kg and 120kg | Slider drag / touch | Updates `userWeightKg` state; displays live numeric readout | Values clamped strictly to [15.0, 120.0] kg | `PROJECT_SPECIFICATION.md` §3 (Line 43), §4.4 (Line 83) |
| 3 | Accessibility / I18n | 5-Language Selector | Choice chips allowing user to pick preferred language for UI and TTS audio | Chip tap | Updates `selectedLocale`; highlights active chip with checkmark | Single-select enforced; cannot deselect all languages | `PROJECT_SPECIFICATION.md` §2.2 (Line 33), §3 (Line 43) |
| 4 | Navigation / Persistence | Primary CTA ("Save & Open Dashboard") | Commits profile settings to local storage and navigates to Page 4 Home Dashboard | User tap | Writes SharedPreferences; executes GoRouter `/dashboard` | Disables button during state write; handles storage fallback | `ORIGINAL_REQUEST.md` R2, `master-project-plan.md` Task 3.2 |
| 5 | Navigation / Scanner | Secondary CTA ("Instant Scan Now") | Immediate entry point to Page 5 Smart Camera without requiring account registration | User tap | Executes GoRouter `/camera` with active baseline profile | Fallback to default 65kg if profile uninitialized | `ORIGINAL_REQUEST.md` R2, `PROJECT_SPECIFICATION.md` Line 44 |
| 6 | Brand & Trust | Value Proposition Header | Communicates health score, chemical INS decoding, and dosage calculation value | Visual render | Renders logo, headline, and privacy badge | Responsive scaling on small screens | `PROJECT_SPECIFICATION.md` §1 (Line 10-17), §2 (Line 29-33) |

### Edge Cases
| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | Mode Toggle -> Slider Sync | User toggles from Child (20kg) to Adult | Slider automatically snaps/animates to 65 kg default baseline. |
| 2 | Mode Toggle -> Slider Sync | User toggles from Adult (65kg) to Child | Slider automatically snaps/animates to 20 kg default baseline. |
| 3 | Custom Weight Preservation | User sets Adult mode to 85 kg, toggles Child (jumps to 20 kg), then toggles back to Adult | System either restores previous custom weight (85 kg) or resets to baseline (65 kg); default baseline ensures predictable dosage safety. |
| 4 | Slider Boundary Clamping | User drags thumb past minimum boundary (< 15 kg) | Thumb clamped at exactly 15.0 kg; digital display reads "15 kg". |
| 5 | Slider Boundary Clamping | User drags thumb past maximum boundary (> 120 kg) | Thumb clamped at exactly 120.0 kg; digital display reads "120 kg". |
| 6 | Language Chip Selection | User taps currently selected language chip | Chip remains selected (cannot uncheck to null/zero state). |
| 7 | Offline Direct Scanning | User taps "Instant Scan Now" without network connectivity | Screen navigates immediately to camera; Tier 2 local ML Kit OCR activates offline without blocking on cloud auth. |
| 8 | Aspect Ratio Compliance | Mockup generated or rendered on 9:16 canvas | Content scales cleanly without vertical overflow, maintaining 24dp padding and 48dp minimum touch targets. |

---

## 6. Verification & Acceptance Criteria Checklist

| ID | Category | Requirement / Acceptance Criteria | Status / Verification Method |
| :---: | :--- | :--- | :---: |
| **AC-1** | Asset Delivery | Single full-screen image named `01_onboarding_v2_refined.jpg` created and saved in repository | File existence inspection in project root / assets |
| **AC-2** | Aspect Ratio | Image strictly formatted to 9:16 mobile aspect ratio (e.g. 1080x1920 or equivalent) | Image header metadata analysis |
| **AC-3** | M3 Theming | Material 3 design directives followed: Emerald Green (`#0F9D58`) primary seed, tonal containers, rounded pill buttons, M3 typography | Visual inspection against M3 design specifications |
| **AC-4** | Mode Toggle | Adult / Child mode toggle visibly present with explicit Adult (65kg) and Child (20kg) baseline indicators | Visual verification of toggle cards/segments |
| **AC-5** | Weight Slider | Interactive body weight slider visibly spanning 15–120 kg with prominent digital readout badge | Visual verification of slider track, thumbs, min/max labels |
| **AC-6** | Language Selector | All 5 regional language chips visible: English, Hindi, Marathi, Tamil, Telugu with active selection styling | Visual verification of all 5 chips and language scripts |
| **AC-7** | Primary CTA | Prominently styled primary button labeled "Save & Open Dashboard" | Visual verification of filled green CTA button |
| **AC-8** | Secondary CTA | Prominently styled secondary button labeled "Instant Scan Now" | Visual verification of tonal/outlined secondary CTA |
| **AC-9** | Value Proposition | Clear headline/tagline conveying packaged product ingredient & toxicology scanning | Visual verification of header copy |
