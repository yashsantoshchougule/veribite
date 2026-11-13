# Phase 4 Implementation Plan: 3-Tier Self-Scaling Hybrid Capture Pipeline (Camera, Barcode, Local OCR & Cloud Vision)

**Goal:** Build the complete 3-Tier hybrid capture pipeline specified in Section 4 of the Master Blueprint:
1. **Tier 1 (Barcode & Offline Cache):** Barcode validation, local SQLite `local_product_cache`, and `GET /api/v1/product/{barcode}` with Open Food Facts v2 proxy + Phase 2/3 toxicology enrichment.
2. **Tier 2 (On-Device OCR & Glare Detection):** ML Kit OCR text parser for nutrition tables and ingredient lists, INS code extraction, and specular foil glare luminance detection.
3. **Tier 3 (Multi-Angle Cloud Gemini 2.5 Vision):** Strict Pydantic `VisionExtractionSchema`, `POST /api/v1/scan/vision` endpoint, auto-caching write-through, and ingredient reformulation hashing.
4. **Fallback System:** Offline/timeout fallback to Tier 2 + Manual Macro Slider data contract.

---

## Tasks

- [ ] **Task 1: Local Product Cache Schema & Barcode Normalizer (Tier 1 Local)**
  - Schema for `local_product_cache` with barcode indexing, nutrition JSON, additive list, and ingredient hash.
  - Barcode normalizer (EAN-13, EAN-8, UPC-A, GS1 DataMatrix check-digit validation).
  - TDD: `testing/unit/phase4/test_barcode_cache.py`.

- [ ] **Task 2: Tier 1 Cloud API & Open Food Facts v2 Enrichment Proxy**
  - Implement `backend/api/products.py` with `GET /api/v1/product/{barcode}`.
  - Multi-layer lookup: Local/Redis cache -> Supabase/DB -> Open Food Facts v2 -> Phase 2/3 toxicology & scoring enrichment -> Cache write-through.
  - TDD: `testing/unit/phase4/test_tier1_api.py`.

- [ ] **Task 3: Tier 2 On-Device OCR Parser & Specular Glare Detection**
  - Implement `backend/core/ocr_parser.py` and `mobile_app/lib/core/vision/ocr_parser.dart` parsing raw OCR text into macros, INS codes, and ingredients.
  - Specular glare detector (luminance analysis $L > 248$ in $>18\%$ of pixels $\implies$ glare alert).
  - TDD: `testing/unit/phase4/test_ocr_parser.py`.

- [ ] **Task 4: Tier 3 Strict Gemini 2.5 Flash Vision Schema & Reformulation Detector**
  - Implement `backend/core/vision_schema.py` (`VisionExtractionSchema`).
  - Implement `backend/api/vision.py` (`POST /api/v1/scan/vision`).
  - Reformulation detector comparing 60-character ingredient hash against cached record.
  - TDD: `testing/unit/phase4/test_tier3_vision.py`.

- [ ] **Task 5: Cross-Platform Dart Vision & Cache Client for Flutter**
  - Implement `mobile_app/lib/core/vision/barcode_scanner_service.dart`.
  - Implement `mobile_app/lib/core/vision/capture_pipeline.dart` managing Tier 1 -> Tier 2 -> Tier 3 escalation and timeouts.
  - TDD: `mobile_app/test/capture_pipeline_test.dart`.

- [ ] **Task 6: Phase 4 Master Release Gate Suite**
  - Implement `testing/unit/phase4/test_phase4_gate.py` validating 3-tier escalation, glare detection, reformulation tracking, and offline fallback.

