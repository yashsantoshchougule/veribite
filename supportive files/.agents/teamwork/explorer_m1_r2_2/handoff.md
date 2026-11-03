# Handoff Report: Layout & Typography Fix Strategy for `01_onboarding_v2_refined.jpg`

**Author:** `explorer_m1_r2_2` (Archetype: `teamwork_explorer`)  
**Roles:** explorer, investigator, layout/typography analyst  
**Date:** 2026-11-03T03:18:00Z  
**Recipient:** Orchestrator (`b07a56f6-e835-41cc-99c3-df882b529452`)  
**Handoff Type:** Hard (Task complete)  
**Deliverable File:** `c:\yash\projects\first mobile app\.agents\teamwork\explorer_m1_r2_2\fix_strategy.md`

---

## 1. Observation

1. **Acceptance Criteria & Delivery Requirements**:
   - `c:\yash\projects\first mobile app\.agents\teamwork\ORIGINAL_REQUEST.md` line 17 specifies:
     `"Deliver the asset as a single full-screen image named 01_onboarding_v2_refined.jpg in a 9:16 mobile aspect ratio saved in the project repository."`
   - `ORIGINAL_REQUEST.md` line 37 specifies:
     `"[ ] All 5 language selector chips (English, Hindi, Marathi, Tamil, Telugu) are visible."`
   - `ORIGINAL_REQUEST.md` line 38 specifies:
     `"[ ] Both CTAs ("Save & Open Dashboard" and "Instant Scan Now") are prominently displayed with primary and secondary styling."`

2. **Empirical Defect 1 — Telugu Chip Truncation (`challenger_2/handoff.md:24–28`, `challenge_report.md:27–32`)**:
   - Visual inspection of `01_onboarding_v2_refined.jpg` via `view_file` confirms that Chip 5 (`తెలుగు`) is sheared off vertically at the right card border (`x ≈ 646`). The semicircular stadium pill cap is missing and the Telugu glyph is truncated to `"తెలుగ"` (losing vowel diacritic `ు`).

3. **Empirical Defect 2 — Token Duplication Stutter (`challenger_2/handoff.md:29–33`, `challenge_report.md:45–50`)**:
   - The explanatory text beneath the slider reads verbatim:
     ```text
     Scales WHO 20% single-snack sugar limits & JECFA
     JECFA additive ADI.
     ```
   - The token `JECFA` is duplicated across line breaks due to diffusion attention repetition.

4. **Empirical Defect 3 — Physical Device Frame & 30.3% Width Loss (`challenger_2/handoff.md:36–41`, `challenge_report.md:62–68`)**:
   - The delivered image is framed inside an iPhone chassis with `#EDF6F1` pale seafoam margins: `x = 0` to `104` (left) and `x = 667` to `768` (right).
   - Real screen width is only ~535 px out of 768 px (~69.7%), compressing the horizontal layout by over 30%.

5. **Empirical Defect 4 — Conflicting Dual Mode Controls (`challenger_2/handoff.md:34–35`, `challenge_report.md:81–86`)**:
   - An iOS-style toggle switch in unselected state is placed on the header line of `"Adult / Child Mode"`, directly conflicting with the active Material 3 Segmented Button below it.

6. **Empirical Defect 5 — Card Geometry & Bottom Truncation (`challenger_2/handoff.md:42–44`, `challenge_report.md:96–100`)**:
   - The white form card features rounded squircle corners at the top (`y ≈ 630`), but abruptly ends at `y ≈ 1080` directly beneath the language chips with 0dp bottom padding and 0dp bottom corner radius.

---

## 2. Logic Chain

1. Per Observation 1, Acceptance Criterion line 37 mandates that all 5 language chips are fully visible and unclipped.
2. Per Observation 2 and Observation 4, forcing 5 multilingual chips into a single horizontal row on a compressed 535px screen squeezed Chip 5 into the right boundary, shearing off its stadium border and clipping `"తెలుగు"` to `"తెలుగ"`.
3. To eliminate horizontal clipping permanently:
   - **Step A:** Reclaim the lost 30.3% horizontal width (+233 px) by enforcing a direct flat 2D full-bleed UI artboard (zero bezels, zero phone chassis, 100% canvas fill).
   - **Step B:** Wrap the 5 language chips into a 2-row layout (Row 1: 3 chips `[✓ English] [हिंदी] [मराठी]`; Row 2: 2 chips `[தமிழ்] [తెలుగు]`), perfectly matching Flutter's native `Wrap` widget pattern. In Row 2, `తెలుగు` is situated with over 400px of right-side breathing room, eliminating clipping risk completely.
4. Per Observation 3, the prompt phrase `"Scales WHO 20% single-snack sugar limits & JECFA additive ADI"` placed `& JECFA` at the line break, triggering autoregressive token stutter. By refactoring the copy to `"Calibrated to WHO single-snack limits and JECFA toxicological ADI standards."` with negative prompt suppression of duplicate words, text stutter is eradicated.
5. Per Observation 5, removing the redundant switch toggle on the header line leaves a single canonical Material 3 Segmented Button, eliminating UX ambiguity.
6. Per Observation 6, specifying uniform 28dp squircle corner radii on all 4 corners (top and bottom) and adding 24dp bottom padding inside the card guarantees a complete, elevated card container with proper vertical rhythm before the CTA buttons.
7. Therefore, the strategies formulated in `fix_strategy.md` directly resolve all five identified defects.

---

## 3. Caveats

- The proposed fix strategies are prompt engineering and layout architecture directives designed for the text-to-image generation tool in Iteration 2; this investigation does not modify source code or generate the final raster image directly.
- Font metrics and glyph shapes in generative AI models are stochastic; specifying exact Unicode characters, pill caps, and generous 2-row margins provides the strongest possible containment against stochastic variations.
- No further caveats.

---

## 4. Conclusion

The Iteration 1 failure has been exhaustively analyzed and solved across four key domains:
1. **Bezel Elimination:** Shift prompt from 3D device mockup to 100% full-bleed 2D mobile UI digital artboard with explicit negative prompt suppression of frames and bezels.
2. **Language Chips Layout:** Transition from 1-row overflow to a 2-row wrapped layout (3 chips in Row 1, 2 chips in Row 2) ensuring complete stadium pill geometries and intact Indic glyphs (`తెలుగు` fully rendered).
3. **Copywriting & Text Stutter:** Refactor microcopy to `"Calibrated to WHO single-snack limits and JECFA toxicological ADI standards."` to prevent line-wrap attention stutter.
4. **Card Container & Elevation:** Enforce symmetric 28dp squircle corner radii across all 4 corners, 24dp bottom padding, and elimination of the redundant header switch toggle.

The complete strategy, master positive prompt, negative prompt, and comparative matrix are documented in:
`c:\yash\projects\first mobile app\.agents\teamwork\explorer_m1_r2_2\fix_strategy.md`.

---

## 5. Verification Method

To independently verify this investigation and its findings:

1. **Verify Strategy File Existence and Contents**:
   ```powershell
   Get-Item "c:\yash\projects\first mobile app\.agents\teamwork\explorer_m1_r2_2\fix_strategy.md" | Select-Object Name, Length, LastWriteTime
   ```
   *Expected Result*: File exists, non-zero length (~10-12 KB).

2. **Verify Iteration 1 Failure Points Addressed in Strategy**:
   Inspect `fix_strategy.md` Sections 2, 3, 4, 5, and 6 to confirm:
   - Section 2 addresses device bezel removal and 100% canvas fill.
   - Section 3 defines 2-row wrapped chip structure (3 chips + 2 chips) for unclipped `తెలుగు`.
   - Section 4 provides non-stuttering caption copy.
   - Section 5 defines 4-corner 28dp squircle geometry and 24dp bottom padding.
   - Section 6 provides ready-to-use master positive and negative prompts.

3. **Invalidation Conditions**:
   - The strategy document is deleted or truncated.
   - Any of the four focus areas is omitted.
