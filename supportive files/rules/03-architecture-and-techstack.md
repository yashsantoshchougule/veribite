# Rule 03: Architecture, Frameworks & Tech Stack Rules

## Overview
All development must adhere strictly to the approved technology stack specified in the Project Master Blueprint. Do not introduce alternative frameworks or unnecessary third-party abstractions without prior alignment.

## Approved Tech Stack
1. **Cross-Platform Mobile Application:**
   - **Framework:** Flutter (Dart 3.x)
   - **State Management:** Riverpod
   - **Routing:** GoRouter (handling the 10-screen navigation structure)
   - **Camera & Scanning:** `mobile_scanner` (barcodes) + `flutter_scalable_ocr` + Google ML Kit Text Recognition v2
   - **Local Cache & Offline DB:** SQLite (`sqflite` or `drift` with FTS5 enabled)
   - **Voice & Accessibility:** `flutter_tts` (regional voice output: Hindi, Marathi, Tamil, Telugu, English)
   - **Export:** `pdf` and `printing` packages for 1-tap PDF summary report generation

2. **Backend Services & Caching:**
   - **Framework:** Python (FastAPI)
   - **Primary Database:** PostgreSQL (via Supabase)
   - **Cache Layer:** Redis (caching barcode lookups, hash digests, and Gemini vision responses)
   - **AI SDK:** `google-genai` SDK for Google Gemini 2.5 Flash Vision API

3. **Public Datasets & External APIs:**
   - Open Food Facts API (4M+ global barcodes)
   - SuhasDissa/E-Number-Database & rootsbymenda/food-mcp-server (6,450+ additive INS codes)
   - FSSAI Compendium & JECFA/EFSA monographs

4. **3-Tier Scan Pipeline & Offline Fallback Discipline:**
   - Always route scans sequentially:
     - **Tier 1:** Local SQLite Cache / Redis / Open Food Facts (~0.15s, $0 cost).
     - **Tier 2:** On-Device ML Kit OCR Viewport Recognition (~0.30s, $0 cost, 100% offline).
     - **Tier 3:** Cloud Gemini 2.5 Flash Vision with auto-cache write-back (~1.5s).
   - **Offline Graceful Degradation:** If the device has no internet connectivity, Tier 3 automatically degrades to Tier 2 on-device OCR, alerting the user with an *"Offline Mode — local analysis only"* badge.
   - **Cache TTL Policies:** Static barcode metadata cached for 30 days in Redis / local SQLite; image hash digests cached for 90 days.

5. **Database Migration & Schema Versioning:**
   - SQLite tables on-device must maintain an explicit schema version integer and migration handlers to prevent app crashes across app updates.
   - Mobile and backend communication must use strict JSON contracts matching defined schemas.
