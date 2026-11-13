# Complete Project Master Blueprint & Specification

## Smart Packaged Product Ingredient, Toxicology & Safe Consumption Dosage Scanner
**A-to-Z Guide for Readers, Evaluators, and Developers**

---

## 1. What Is This Project? (Plain-Language Overview)

Whenever a consumer buys a packet of biscuits, chips, instant noodles, cereal, cold drink, or everyday packaged food, the front of the packet is covered with attractive marketing claims like *"Multigrain"*, *"Baked Not Fried"*, *"Rich in Vitamins"*, or *"No Added Sugar"*. Meanwhile, the real truth about what the product contains is hidden on the backside of the packet in tiny 4-point font filled with complex chemical names, cryptic code numbers (such as `INS 211`, `INS 102`, or `E320`), and misleadingly small artificial serving sizes.

This project is a **Cross-Platform Mobile Application (Android & iOS)** that enables any user to point their smartphone camera at the backside (or barcode) of any packaged product. Within seconds, the application:
1. Extracts the complete ingredient list and nutrition table.
2. Analyzes every single ingredient individually to explain whether it is beneficial or harmful for human health.
3. Computes a transparent **Overall Verdict (0–100 Health Score)** on whether the product should be consumed or avoided.
4. Calculates the **Exact Safe Consumption Dosage and Frequency** (informing the user exactly how many grams or pieces they can safely eat per day, per week, or once a month based on their body weight and World Health Organization limits).

---

## 2. Motive & Core Objectives

### 2.1 Why Are We Building This? (The Motive)
The motive of this project is to bridge the massive gap between legal food label printing and real-world human understanding, backed by hard medical and epidemiological evidence:
- **56.4% of India's Disease Burden is Diet-Driven:** According to the Indian Council of Medical Research – National Institute of Nutrition (ICMR-NIN) cited in a 2025 Pan-India Scoping Review ([NIH/PMC12608109](https://pmc.ncbi.nlm.nih.gov/articles/PMC12608109/)), unhealthy diets account for 56.4% of total disease burden in India, driving an epidemic of Type-2 diabetes, hypertension, and childhood obesity.
- **Over 90% of Shoppers Fail to Use Ingredient Labels:** Peer-reviewed Indian surveys reveal that 52.5% of consumers never read the ingredients list and 57.7% do not understand food labels at all ([Goyal & Deshmukh, PMC5903167](https://pmc.ncbi.nlm.nih.gov/articles/PMC5903167/)). In community surveys, while 75.65% check price and 55.21% check expiry dates, only 8.91% inspect ingredients and 74.99% find labels physically difficult to read ([Chellamuthu et al., PMC12156081](https://pmc.ncbi.nlm.nih.gov/articles/PMC12156081/)).
- **Industrial Obfuscation & The Dosage Void:** Manufacturers hide synthetic dyes and preservatives behind FSSAI INS numbers, split sugar across 56+ hidden aliases (such as maltodextrin and liquid glucose) so "Sugar" does not appear first, print nutrition facts for tiny 20g "servings" on 90g single-person packs, and never inform the buyer how much or how often the product is safe to consume.

### 2.2 Specific Objectives
1. **Eliminate Physical & Optical Reading Barriers:** Replace manual reading of tiny, curved, or glossy backside labels with a fast 3-Tier Hybrid Scanner (Barcode + On-Device ML Kit OCR + Cloud Gemini 2.5 Flash Vision).
2. **Decode Chemical Jargon & Hidden Sugars Instantly:** Translate 6,450+ international additives/INS codes and 56+ split sweetener aliases into plain, everyday language offline in under 5 milliseconds.
3. **Provide an Unbiased, Citation-Grounded Overall Health Verdict:** Weigh beneficial nutrients against harmful ultra-processed additives to generate a deterministic 0–100 Health Score and NOVA (1–4) Processing Grade backed by official WHO, FSSAI, JECFA, and EFSA citations.
4. **Calculate Precision Safe Consumption Dosage & Frequency:** Translate per-100g nutrition data and body-weight Acceptable Daily Intake (ADI) limits into concrete gram/piece portions and explicit schedules (*Daily Safe*, *3–4x/Week*, *1–2x/Week*, or *Once a Month / Avoid*).
5. **Empower Actionable Healthier Choices in Regional Languages:** Provide instant Indian regional voice read-outs (Hindi, Marathi, Tamil, Telugu, English) and 1-tap healthier product swaps on Blinkit, Zepto, Swiggy Instamart, and BigBasket.

---

## 3. Application Screen Architecture

The application UI is structured into modular user journey flows: Onboarding/Auth, Core Scanning & Toxicology Engine, Product Discovery & Categories, Personal AI Advisor, Profile & Preferences, and Subscription Management.

| Screen # & Name | Category | Primary Purpose & Key Components | Status |
| :--- | :--- | :--- | :---: |
| **Page 1: Starter Page** | Onboarding | Visual introduction, value proposition, body-weight baseline slider (15–120 kg), regional language selection, and "Get Started" entry point. | ✅ Mockup Ready (`01_onboarding_v2_refined.jpg`) |
| **Page 2: Login Page** | Authentication | Clean credentials entry (Email / Mobile OTP / Google 1-Tap) with a prominent *"Continue Offline Without Account"* button ensuring 100% privacy. | 📋 Queued for Design |
| **Page 3: Sign In / Sign Up Page** | Authentication | New user registration, dietary preferences profile (Diabetic, Child-Safe, Hypertension, Low Sugar), passwordless OTP setup, and profile creation. | 📋 Queued for Design |
| **Page 4: Home Page** | Dashboard | Central command hub: Hero "Point & Scan Backside Label" CTA, Today's Safe Sugar & Additive budget meter (WHO 20% limit), Recent Scans carousel, and Quick Actions. | ✅ Mockup Ready (`02_home_dashboard_v1.jpg`) |
| **Page 5: Smart Camera** | Optical Engine | Zero-config adaptive viewfinder: real-time AI auto-detection for curved bottles, foil gloss/glare auto-compensation, barcode & backside OCR, and manual shutter trigger. | ✅ Mockup Ready (`03_smart_camera_v2_refined.jpg`) |
| **Page 6: Master Verdict** | Scanner Result | Core report: Circular 0–100 Health Score gauge (with 39/100 red cap), NOVA classification, Serving Multiplier toggle (1 Serving vs Whole Pack), and Prescribed Safe Consumption Portion badge. | ✅ Mockup Ready (`04_master_verdict_v2_refined.jpg`) |
| **Page 7: Ingredients Page** | Toxicology Breakdown | Granular breakdown: Split-Sugar Hidden Sweetener cluster banner (e.g. 38% hidden sugars), safety filter chips (`All`, `Red`, `Caution`, `Safe`), and color-coded ingredient cards. | ✅ Mockup Ready (`05_ingredient_breakdown_v2_refined.jpg`) |
| **Page 8: Ingredients Deep Dive Page** | Toxicology Modal | Deep chemical modal: INS / E-number expansion, why manufacturers add it, health risks, JECFA Acceptable Daily Intake (ADI) scaled to child/adult weights, and verified EFSA/FSSAI citations. | ✅ Mockup Ready (`06_ingredient_deep_dive_v2_refined.jpg`) |
| **Page 9: Search Page** | Discovery | Global instant product search: Search by brand, product name, barcode number, or chemical INS code with search history and popular healthy queries. | 📋 Queued for Design |
| **Page 10: Categories Page** | Discovery | Category exploration grid: Browse packaged foods by category (Biscuits & Cookies, Beverages, Chips & Snacks, Instant Noodles, Cereals, Chocolates, Condiments) with category health averages. | 📋 Queued for Design |
| **Page 11: Personal AI** | AI Health Advisor | Conversational AI nutrition assistant powered by Gemini 2.5 Flash: Ask questions about scanned products (*"Is this safe for my diabetic mother?"*, *"Why is maltodextrin bad for kids?"*), grounded strictly in verified citations. | 📋 Queued for Design |
| **Page 12: Profile Page** | Account & Health | User profile and health guardrails: Edit body weight, manage family member profiles (e.g. Child 20 kg profile), view saved Green/Red lists, change TTS voice language, and export 7-day health PDF reports. | 📋 Queued for Design |
| **Page 13: Subscription Page** | Monetization | Free vs. Premium plan comparison: Unlimited cloud Gemini vision scans, advanced family multi-profile dosage tracking, continuous glucose monitor integration, and priority quick-commerce swap discounts. | 📋 Queued for Design |
| *Additional Pages (14+)* | Post-MVP / Extended | *To be expanded as additional page specifications are provided by the user (e.g., Truth-O-Meter, Healthier Swaps, 1v1 VS Battle, Weekly Ledger).* | ⏳ Awaiting User Inputs |

---

## 4. Core Feature Specifications

### 4.1 Feature 1: 3-Tier Self-Scaling Hybrid Capture Pipeline
1. **Tier 1 — Instant Barcode, GS1 2D Digital Link & SHA-256 Hash Lookup (~0.15s, $0 Cost):**
   Checks local SQLite cache, cloud Redis/PostgreSQL database, or the 4M+ Open Food Facts API.
2. **Tier 2 — On-Device Cropped Viewport OCR (~0.30s, $0 Cost, 100% Offline):**
   If no barcode match exists, Google ML Kit Text Recognition v2 reads text in the camera ROI box and matches ingredients against the embedded SQLite database.
3. **Tier 3 — Multi-Angle Cloud Gemini 2.5 Flash Vision + Auto-Caching (~1.5s):**
   Handles crinkled, glossy, bilingual, or curved labels (up to 4 stitched photos), extracts structured JSON, and auto-caches into Tier 1.

### 4.2 Feature 2: Ingredient Analyzer, INS Decoder & Sugar Aggregator
- **Deterministic SQLite INS / E-Number Decoder:** Pre-bundles 6,450+ additives from SuhasDissa/E-Number-Database, rootsbymenda/food-mcp-server, and the FSSAI Compendium. Expands codes (e.g., INS 102 Tartrazine, INS 211 Sodium Benzoate, INS 621 MSG) and flags international bans.
- **Anti-Splitting Hidden Sugar Detector:** Cross-checks against 56+ sweetener aliases. Merges split sugars (e.g., Maltodextrin, Liquid Glucose, Invert Syrup) into a single Total Sweetener Cluster.

### 4.3 Feature 3: Dual-Axis Overall Verdict (0–100) & Citation-Grounded RAG
- **Dual-Axis Scoring Formula:** Computes baseline Nutri-Score (rewarding protein, fiber, whole grains; penalizing calories, sugar, sat-fat, sodium per 100g).
- **Strict NOVA & Red-Additive Cap:** If any Red-tier toxic additive, trans fat, or synthetic azo dye is present, the maximum possible score is capped at **39/100 (Harmful — Avoid / Rare)**.
- **Zero-Hallucination Citation Grounding:** Explanations cite verified passage IDs from WHO, FSSAI, JECFA, or EFSA.

### 4.4 Feature 4: Precision Safe Consumption Dosage & Frequency Engine
1. **20% WHO/ICMR Single-Snack Ceiling:**
   $$\text{Base Safe Portion (g)} = \min\left(\frac{5\text{g}}{\text{Sugar\_per\_g}}, \frac{400\text{mg}}{\text{Sodium\_per\_g}}, \frac{4\text{g}}{\text{SatFat\_per\_g}}\right)$$
2. **Body-Weight JECFA Additive Scaling:**
   Multiplies safe portion by $(\text{User\_Weight\_kg} / 65\text{ kg})$ and checks JECFA mg/kg Acceptable Daily Intake limits.
3. **4-Tier Frequency Prescription:**
   - **Daily Safe:** Score 75–100, NOVA 1–2
   - **3–4x Per Week:** Score 50–74, NOVA 3
   - **Strict 1–2x Per Week Cap:** Score 25–49, NOVA 4
   - **Once a Month / Complete Avoidance:** Score 0–24 or Red-tier additives

---

## 5. Technology Stack & Tools

- **Mobile Frontend:** Flutter (Dart 3.x) + Riverpod (State) + GoRouter
- **Camera & Local OCR:** `mobile_scanner` + `flutter_scalable_ocr` + Google ML Kit Text Recognition v2
- **On-Device Storage:** SQLite (`sqflite` / `drift` with FTS5)
- **Cloud Vision & AI Reasoning:** Google Gemini 2.5 Flash API (`google-genai` SDK)
- **Backend & Cache:** Python (FastAPI) + PostgreSQL (Supabase) + Redis
- **Voice & Export:** `flutter_tts` (or Sarvam AI TTS) + `pdf` / `printing`
- **Datasets & APIs:** Open Food Facts API + E-Number Database + JECFA/EFSA MCP Corpus + FSSAI Compendium

---

## 6. Phase 2 Scope (Post-MVP)
- Personalized Medical, Family & Allergy Guardrails (Type-2 Diabetes, Hypertension, Child-Safe, Pregnancy, Allergies).
- Food × Medication Interaction Alerts (e.g., Statins + Grapefruit, Warfarin + Vitamin K).
- Real-Time AR Pill Overlay & GS1 Sunrise 2027 Support.
- Wearable & Continuous Glucose Monitor (CGM) Sync.
