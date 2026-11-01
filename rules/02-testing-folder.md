# Rule 02: Strict Testing and Scratch File Isolation

## Overview
All files, scripts, mock datasets, exploratory experiments, diagnostic checks, or temporary verification code created to test, inspect, or prototype behavior that are NOT permanent production project code MUST strictly reside inside the `testing/` directory.

## Strict Rules
1. **Zero Pollution of Production Source:**
   - No temporary test scripts, sandbox files, throwaway runners, or experimental mocks may be placed in `lib/`, `src/`, `app/`, `backend/`, or root directories.
   - Every file created to "test to see through", verify an API response, test OCR extraction, or benchmark INS matching MUST be placed inside `testing/`.

2. **Structure Within `testing/`:**
   - `testing/unit/`: Formal unit tests (deterministic, fast, zero network calls).
   - `testing/integration/`: Integration & API verification scripts (using mock network adapters or simulated responses by default).
   - `testing/scratch/`: Quick one-off scripts, sanity checks, test images, or temporary inspection code.
   - `testing/fixtures/`: Sample barcodes, mock labels, OCR raw dumps for testing.

3. **External Network & API Mocking Invariant:**
   - Unit tests in `testing/unit/` MUST NEVER execute live network calls to paid or quota-limited external APIs (Google Gemini API, live Supabase, live Redis).
   - All external network interfaces must be mocked using local fixtures or in-memory equivalents.

4. **Secrets & Security Invariant:**
   - NEVER commit API keys, tokens, or live production credentials inside any file in `testing/`. Use environment variables or a local git-ignored `.env.test`.

5. **Test Artifact Hygiene & Sanitation:**
   - Any runtime files generated during test runs (temporary SQLite database files, generated test PDFs, processed images) MUST be created in `testing/scratch/` or system temp directories.
   - Production builds, package trees, and app bundles MUST NEVER bundle files from `testing/`.
   - Any runner script in `testing/` must be self-contained or explicitly reference project modules without side effects.
