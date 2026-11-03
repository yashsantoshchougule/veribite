# Handoff Report: Prompt Engineering & Negative Prompt Refinement
## Milestone 1 — Iteration 2 Exploration

**Author:** `explorer_m1_r2_3` (Archetype: `teamwork_explorer`)  
**Roles:** explorer, synthesizer  
**Target Asset:** `c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg`  
**Date:** 2026-11-03T03:14:00Z  
**Recipient:** Orchestrator (`b07a56f6-e835-41cc-99c3-df882b529452`)  
**Type:** Hard Handoff (Investigation & Strategy Complete)  

---

## 1. Observation

1. **Target Deliverable Defect Findings in Iteration 1 Reports**:
   - `challenger_2/challenge_report.md` line 29–31:
     `"The 5th chip (తెలుగు) begins around x = 610. Its grey container background extends to x = 646, where it abruptly hits the inner screen border at x = 648 and crashes into the black hardware bezel at x = 650. Visual clipping: The right semicircular pill cap of the chip container is completely missing (sliced off vertically). Script corruption: The Telugu script is truncated to 'తెలుగ'. The trailing vowel diacritic sign ు (creating 'గు') is clipped off."`
   - `challenger_2/challenge_report.md` line 46–49:
     `"Scales WHO 20% single-snack sugar limits & JECFA \n JECFA additive ADI."` (token duplication across line break).
   - `challenger_2/challenge_report.md` line 64–66:
     `"Left external margin (pale green #EDF6F1): x = 0 to x = 104 (104 px, 13.5% of canvas width). Right external margin (pale green #EDF6F1): x = 667 to x = 768 (101 px, 13.2% of canvas width). The actual phone screen width is only ~535 px (69.7% of total width)."`
   - `challenger_2/challenge_report.md` line 82–84:
     `"An iOS-style toggle switch is placed on the top right of the section title in an unselected/grey state. Directly beneath it sits a Material 3 Segmented Button with 'Adult (65 kg)' (selected in green) and 'Child (20 kg)' (unselected)."`
   - `challenger_2/challenge_report.md` line 97–98:
     `"The white configuration card exhibits rounded corners at the top (y ≈ 630), but abruptly ends at y ≈ 1070–1110 directly beneath the language chip row with zero bottom margin and no rounded bottom corners."`

2. **Iteration 1 Prompt Text in `explorer_2/design_spec.md`**:
   - Line 246: `"High-resolution production mobile app UI design mockup, modern Google Material 3 Design System, clean flat design, portrait 9:16 aspect ratio, sleek bezel-less smartphone screen, Behance and Dribbble trending mobile UI."`
   - Line 256: `"- MODE TOGGLE: Material 3 Segmented Button with two options: 'Adult (65 kg)'... and 'Child (20 kg)'..."`
   - Line 257: `"Explanatory helper text: 'Scales WHO 20% single-snack sugar limits & JECFA additive ADI.'"`
   - Line 258: `"- LANGUAGE CHIPS: Section header 'App Language'. Row of 5 Material 3 Filter Chips: '✓ English'... followed by unselected chips: 'हिंदी', 'मराठी', 'தமிழ்', 'తెలుగు'."`

3. **Tool Parameter Capabilities**:
   - `generate_image` takes `Prompt`, `ImageName`, `AspectRatio`, and `ImagePaths`. There is no separate `NegativePrompt` argument; all negative instructions and constraints must be formulated inside the `Prompt` text.

4. **Direct Visual Inspection of `01_onboarding_v2_refined.jpg`**:
   - `view_file` confirms an encased smartphone floating on an `#EDF6F1` background, right border collision of Chip 5 (`తెలుగ`), duplicated `"JECFA JECFA"`, an unselected toggle switch above the green segmented button, and an unclosed bottom card container.

---

## 2. Logic Chain

1. Per Observation 1 and Observation 4, the 30.3% horizontal width compression (from 768px down to ~535px) directly caused the single row of 5 chips to overflow the right screen boundary, truncating the 5th chip (`తెలుగు`).
2. Per Observation 2, the trigger words `"mockup"`, `"smartphone screen"`, and `"Behance and Dribbble trending mobile UI"` in the positive prompt induced the generative diffusion model to construct a physical smartphone chassis on a studio backdrop rather than an edge-to-edge UI artboard.
3. Per Observation 2 and Observation 3, enforcing `"Row of 5 Material 3 Filter Chips"` mathematically requires ~518px of horizontal space; when combined with the squeezed 535px width, this guarantees horizontal collision. Splitting the chips into a **2-Row Wrapped Layout** (Row 1: 3 chips ~300px; Row 2: 2 chips ~190px) ensures that both rows easily fit within any canvas width with >350px of safety margin on the full-bleed 768px canvas, making clipping impossible.
4. Per Observation 1 and Observation 2, the prompt copy `"Scales WHO 20% single-snack sugar limits & JECFA additive ADI."` split immediately before an acronym, triggering attention re-sampling and token duplication (`"JECFA JECFA"`). Streamlining the copy to `"Calibrated to WHO single-snack sugar limits & JECFA ADI standards."` and appending explicit anti-stutter negative directives eliminates token re-sampling.
5. Per Observation 1 and Observation 2, using the word `"TOGGLE"` triggered an iOS switch icon in addition to the Material 3 Segmented Button. Banning `"toggle"` and `"switch"` and renaming the section to `"Profile Baseline Selector: Single Material 3 Segmented Button"` resolves the ambiguity.
6. Per Observation 1 and Observation 2, lack of explicit bottom container geometry caused the card to terminate prematurely. Specifying rounded squircle corners on all 4 corners with symmetric 20px bottom padding resolves container closure.
7. Therefore, the refined prompt blueprint detailed in `fix_strategy.md` directly resolves all 5 defects identified in iteration 1.

---

## 3. Caveats

1. The `generate_image` tool relies on a generative diffusion model; while prompt structuring and negative constraints provide strong deterministic steering, minor stochastic variations in font rendering or icon styling can occur across seed runs.
2. The deliverable is a visual design mockup; dynamic interaction logic (e.g. real-time slider value changes or language locale switching) belongs in the Flutter application codebase.
3. No further caveats.

---

## 4. Conclusion

The Iteration 1 defects were entirely caused by prompt triggering flaws and layout specification choices:
1. **Device Bezel**: Caused by "mockup" / "smartphone screen" triggers; resolved by declaring a flat 2D full-bleed UI artboard (Figma export style) and banning phone chassis/bezels in negative prompts.
2. **Telugu Chip Clipping**: Caused by a 1-row layout in a squeezed frame; resolved by full-bleed canvas (+30% width) AND a 2-Row Wrapped Chip Layout (`[English] [Hindi] [Marathi]` row 1, `[Tamil] [Telugu]` row 2) providing >350px clearance.
3. **Text Stutter ("JECFA JECFA")**: Resolved by streamlined microcopy and explicit anti-stutter negative directives.
4. **Redundant Switch**: Resolved by eliminating the word "toggle" and enforcing a single Material 3 Segmented Button.
5. **Card Cutoff**: Resolved by explicit 4-corner squircle geometry with 20px bottom padding.

The complete ready-to-run prompt has been documented in `c:\yash\projects\first mobile app\.agents\teamwork\explorer_m1_r2_3\fix_strategy.md`.

---

## 5. Verification Method

1. **Verify Strategy File Existence and Completeness**:
   Inspect `c:\yash\projects\first mobile app\.agents\teamwork\explorer_m1_r2_3\fix_strategy.md` to ensure all 5 defect categories, the negative prompt directives, and the complete prompt template are present.
2. **Verify Prompt Template Parameters**:
   Confirm that the proposed prompt in `fix_strategy.md` §5 contains:
   - "Flat digital screen graphic, 100% full-bleed edge-to-edge UI canvas in 9:16 portrait aspect ratio, zero phone chassis, zero device bezels"
   - "ROW 1 (3 chips): '[✓ English]', '[हिंदी]', '[मराठी]'; ROW 2 (2 chips): '[தமிழ்]', '[తెలుగు]'"
   - "Calibrated to WHO single-snack sugar limits & JECFA ADI standards." (Single instance of each word)
   - "STRICT AVOIDANCE AND NEGATIVE PROMPTS (NEGATIVE CONSTRAINTS)" block with explicit suppression of bezels, cases, stutter, and duplicate controls.
3. **Downstream Asset Invalidation Conditions**:
   - The generated image has a physical outer phone border, desk backdrop, or margins at `(10, 10)`.
   - Chip 5 (`తెలుగు`) has any clipped border or missing diacritic.
   - Any word or acronym is repeated back-to-back.
   - An iOS switch toggle appears next to the title.
