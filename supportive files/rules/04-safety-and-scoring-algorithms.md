# Rule 04: Scoring Formulas, Safe Dosage Engine & Citation Invariants

## Overview
All calculations for product health scores, additive toxicity, and consumption limits must follow strict deterministic mathematical rules without arbitrary heuristics or AI hallucination.

## 1. Dual-Axis Overall Health Score (0–100)
- **Baseline Calculation:** Validated Nutri-Score algorithm:
  - Favorable points (P): Protein, dietary fiber, whole grains, fruits/nuts/pulses percentage.
  - Negative points (N): Calorie density, total sugars, saturated fats, sodium per 100g.
- **Beverage vs Solid Food Distinction:**
  - Solid foods use standard thresholds (sugars 0–45g/100g, energy 0–3350 kJ).
  - **Beverages** (juices, sodas, flavored milks) MUST use the strict beverage scoring table (sugars 0–13.5g/100ml, energy 0–270 kJ), penalizing free sugar density 3x more heavily.
- **NOVA & Red-Additive Cap (NON-NEGOTIABLE):**
  - If a product contains **ANY** Red-tier toxic additive (e.g., prohibited synthetic azo dye, harmful preservative) or trans fats:
  - **The final score MUST be hard-capped at 39/100 (Harmful — Avoid / Rare)**, regardless of added vitamins, whole grains, or high protein content.

## 2. Hidden Sugar & Sweetener Aggregation
- Cross-check against the 56+ hidden sugar aliases (Maltodextrin, Liquid Glucose, Invert Sugar Syrup, Dextrose, High-Fructose Corn Syrup, etc.).
- When $\ge 2$ aliases appear, merge them into a unified **Total Sweetener Cluster** and display the Split-Sugar Warning Banner.
- **Dual Sweetener Classification:** Distinguish between *Caloric Sugars* (driving glycemic burden) and *Intense Non-Nutritive Sweeteners* (Sucralose INS 955, Aspartame INS 951, Acesulfame K INS 950, etc.). Flag products claiming "No Sugar" that substitute intense artificial sweeteners.

## 3. Label Text Extraction & Ingestion Invariants
- **Complex Text Extraction:** The engine must parse full unstructured ingredient sentences containing parenthetical, bracketed, or prefix notations (e.g., `"Food Colour (INS 102)"`, `"Raising Agents [INS 503(ii), INS 500(ii)]"`, `"Preservative (211)"`).
- **Sub-Code Fallback:** If a specific sub-code or Roman numeral variant (e.g., `INS 322(i)`, `INS 500(ii)`) lacks an explicit monograph entry, it must resolve cleanly to the parent family code (`INS 322`, `INS 500`).
- **Salt vs. Sodium Normalization:** If a label reports "Salt" (g) instead of Sodium (mg), calculate:
  $$\text{Sodium (mg)} = \text{Salt (g)} \times 400$$
- **Liquid Volume Normalization:** For beverages declared in milliliters (ml), assume $1\text{ ml} \approx 1\text{ g}$ density for water-based items.
- **Safe Value Ingestion:** Incomplete nutrition labels where optional nutrients (like fiber) are missing or `None` must safely default to 0.0 without throwing runtime exceptions.

## 4. Safe Consumption Dosage & Frequency Engine
Every product evaluation must compute:
1. **20% WHO/ICMR Single-Snack Ceiling:**
   $$\text{Base Safe Portion (g)} = \min\left(\frac{5\text{g}}{\text{Sugar\_per\_g}}, \frac{400\text{mg}}{\text{Sodium\_per\_g}}, \frac{4\text{g}}{\text{SatFat\_per\_g}}\right)$$
2. **Body-Weight & Additive ADI Scaling:**
   $$\text{Adjusted Safe Portion (g)} = \text{Base Safe Portion} \times \left(\frac{\text{User\_Weight\_kg}}{65\text{ kg}}\right)$$
   Cross-checked against JECFA mg/kg Acceptable Daily Intake (ADI) for detected additives (e.g., Sodium Benzoate 5 mg/kg, Tartrazine 10 mg/kg) to ensure sensitive groups (e.g., 20 kg child) never exceed daily safety limits.
3. **4-Tier Frequency Schedule:**
   - **Score 75–100 & NOVA 1–2:** *Daily Safe*
   - **Score 50–74 & NOVA 3:** *3–4x Per Week*
   - **Score 25–49 & NOVA 4:** *Strict 1–2x Per Week Cap*
   - **Score 0–24 or Red-Tier Additive:** *Once a Month / Complete Avoidance*

## 5. Zero-Hallucination Citation Grounding
- Every health risk warning or additive explanation must be tagged with a verifiable citation ID from:
  - FSSAI (Food Safety and Standards Authority of India)
  - WHO (World Health Organization)
  - JECFA (Joint FAO/WHO Expert Committee on Food Additives)
  - EFSA (European Food Safety Authority)
- If no official monograph exists, mark with `NO_OFFICIAL_SOURCE` badge; NEVER invent or hallucinate toxicity evidence.
