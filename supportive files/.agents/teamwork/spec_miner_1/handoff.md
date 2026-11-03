# Handoff Report: Page 1 Starter Screen / Onboarding Specification Mining

**Agent**: `spec_miner_1` (teamwork_spec_miner)  
**Parent / Recipient**: `b07a56f6-e835-41cc-99c3-df882b529452` (teamwork_orchestrator)  
**Date**: 2026-11-03  
**Handoff Type**: Hard (Task Complete)  

---

## 1. Observation
Directly extracted from the workspace specification files:

1. **`ORIGINAL_REQUEST.md` (Lines 16–26, 30–38)**:
   - Asset target: *"Deliver the asset as a single full-screen image named `01_onboarding_v2_refined.jpg` in a 9:16 mobile aspect ratio saved in the project repository."*
   - Component requirements:
     - *"Adult / Child mode toggle with baseline values (Adult 65kg / Child 20kg)"*
     - *"Interactive body weight slider covering the 15–120 kg range"*
     - *"5-language selector chips (English, Hindi, Marathi, Tamil, Telugu)"*
     - *"Primary CTA button: 'Save & Open Dashboard'"*
     - *"Secondary CTA button: 'Instant Scan Now'"*

2. **`PROJECT_SPECIFICATION.md`**:
   - Screen Architecture (Line 43): *"Page 1: Starter Page | Onboarding | Visual introduction, value proposition, body-weight baseline slider (15–120 kg), regional language selection, and 'Get Started' entry point. | ✅ Mockup Ready (`01_onboarding_v2_refined.jpg`)"*
   - Regional Language Support (Line 33): *"instant Indian regional voice read-outs (Hindi, Marathi, Tamil, Telugu, English)"*
   - Body-Weight JECFA Scaling Formula (Line 83):
     $$\text{Scaled Portion} = \text{Base Safe Portion} \times \left(\frac{\text{User\_Weight\_kg}}{65\text{ kg}}\right)$$
   - Child Profile Baseline (Line 54): Reference to *"manage family member profiles (e.g. Child 20 kg profile)"*.

3. **`mobile_app/lib/main.dart` (Lines 16–19)**:
   - Theme configuration: `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F9D58)), useMaterial3: true)` establishing Emerald Green `#0F9D58` as the primary brand seed color and Material 3 design system.

4. **`mobile_app/lib/core/scoring/dosage_engine.dart` (Lines 97–130, 180–185)**:
   - Verifies Adult default baseline: `double userWeightKg = 65.0`.
   - Verifies Child baseline & sensitive handling: `bool isChild = false`, triggering pediatric hyperactivity flags (Southampton / EFSA) for synthetic azo dyes.

5. **`docs/plans/master-project-plan.md` (Lines 253–265)**:
   - Task 3.2: Page 1 — Onboarding & Body-Weight Setup Screen specifying interactive body-weight slider, age/mode toggle, regional language chips, and offline entry.

---

## 2. Logic Chain
- **Step 1 (Biological Calibration Relevance)**: From `PROJECT_SPECIFICATION.md` §4.4 and `dosage_engine.dart`, the app's core value proposition is personalized safe consumption dosage calculated from body mass against WHO/JECFA limits. Therefore, Page 1's weight slider and adult/child toggle are core functional inputs, not mere cosmetic questions.
- **Step 2 (Baseline Default Mechanics)**: Because the JECFA ADI formula anchors adult standard dosage to 65 kg and pediatric safety to 20 kg, selecting "Adult" mode must set/default the slider to 65 kg, while selecting "Child" mode sets the slider to 20 kg.
- **Step 3 (Slider Bounds Definition)**: From `PROJECT_SPECIFICATION.md` Line 43 and `ORIGINAL_REQUEST.md` Line 22, the slider interval is strictly defined as 15 kg (minimum pediatric weight) to 120 kg (maximum adult weight).
- **Step 4 (Regional Accessibility)**: From `PROJECT_SPECIFICATION.md` Line 33 and `ORIGINAL_REQUEST.md` Line 23, the 5 languages (English, Hindi, Marathi, Tamil, Telugu) must be presented as single-select choice chips, which directly configure the UI and TTS voice engine.
- **Step 5 (Dual CTAs)**: `ORIGINAL_REQUEST.md` lines 24–25 mandates two distinct actions:
  - Primary CTA: "Save & Open Dashboard" (filled green pill button committing settings and navigating to `/dashboard`).
  - Secondary CTA: "Instant Scan Now" (tonal/outlined button enabling frictionless 100% offline scanning via `/camera`).
- **Step 6 (Design Language)**: From `main.dart` line 17 and Material 3 guidelines, the UI mockup must utilize `#0F9D58` as the primary seed color, clean elevated cards with 16–20dp corner radii, M3 typography tokens (HeadlineMedium, DisplaySmall, TitleMedium, LabelLarge), and 9:16 mobile aspect ratio.

---

## 3. Caveats
- **Post-MVP Multi-Profile Management**: While Page 1 configures the initial primary profile (Adult 65kg or Child 20kg), full multi-family profile switching (e.g., toggling between multiple kids or diabetic elderly relatives) is architected for Page 12 (Profile & Preferences Screen).
- **Image Generation Scope**: As `spec_miner_1`, this role discovers and extracts specifications; actual image generation and file placement of `01_onboarding_v2_refined.jpg` is handled by the worker/design generator agent as dispatched by the orchestrator.

---

## 4. Conclusion
All functional requirements, component specifications, state interactions, edge cases, theme tokens, and verification criteria for **Page 1: Starter Screen / Onboarding** have been fully probed, mapped, and documented in:
`c:\yash\projects\first mobile app\.agents\teamwork\spec_miner_1\spec_analysis.md`.

The downstream image generator worker can immediately construct the visual mockup `01_onboarding_v2_refined.jpg` adhering precisely to:
1. 9:16 mobile aspect ratio.
2. Material 3 design system with Emerald Green `#0F9D58` primary theme.
3. Adult (65kg) / Child (20kg) segmented mode toggle.
4. Interactive 15–120 kg body weight slider with bold digital readout badge.
5. 5 regional language chips (English, Hindi, Marathi, Tamil, Telugu).
6. Dual prominent CTAs: "Save & Open Dashboard" (Primary) and "Instant Scan Now" (Secondary).

---

## 5. Verification Method
To independently verify this specification analysis:
1. **Inspect specification document**:
   `view_file` at `c:\yash\projects\first mobile app\.agents\teamwork\spec_miner_1\spec_analysis.md`.
2. **Cross-check against source authority**:
   - `view_file` on `c:\yash\projects\first mobile app\PROJECT_SPECIFICATION.md` at line 43 and lines 79–90.
   - `view_file` on `c:\yash\projects\first mobile app\.agents\teamwork\ORIGINAL_REQUEST.md` at lines 16–38.
   - `view_file` on `c:\yash\projects\first mobile app\mobile_app\lib\main.dart` at line 17.
   - `view_file` on `c:\yash\projects\first mobile app\mobile_app\lib\core\scoring\dosage_engine.dart` at line 97 and line 128.
3. **Invalidation condition**: Any change to baseline weights (e.g. if adult baseline were changed from 65kg or child from 20kg), slider range (if not 15–120kg), or language roster would invalidate specific tokens documented herein.
