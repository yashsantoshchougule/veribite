# Project Exposure — Workspace Rules & Governance

This project is governed by the rules in [`rules/`](file:///c:/yash/projects/exposure/rules) and the master specification in [`PROJECT_SPECIFICATION.md`](file:///c:/yash/projects/exposure/PROJECT_SPECIFICATION.md).

## Mandatory Operational Rules

1. **Compulsory Ponytail Protocol:**
   - Active on EVERY step. See [`rules/01-ponytail.md`](file:///c:/yash/projects/exposure/rules/01-ponytail.md).
   - Enforce the ladder: YAGNI -> existing codebase reuse -> standard library -> native platform feature -> minimal code.
   - Strict dependency escalation gate: Any third-party dependency replicable in $\le 30$ lines of code is strictly prohibited.
   - Target diffs < 100 lines per focused unit; no unrequested abstractions or speculative scaffolding.

2. **Strict Testing Folder Policy:**
   - Any script, mock file, temporary probe, diagnostic test, or experiment that is NOT part of production code MUST be placed exclusively in [`testing/`](file:///c:/yash/projects/exposure/testing).
   - See [`rules/02-testing-folder.md`](file:///c:/yash/projects/exposure/rules/02-testing-folder.md) and [`testing/README.md`](file:///c:/yash/projects/exposure/testing/README.md).
   - Unit tests must be 100% deterministic with ZERO live billable API calls (Gemini API, Redis, Supabase must use local mocks/fixtures).
   - Zero hardcoded secrets; temporary test outputs must write strictly to `testing/scratch/`.

3. **Strict Technology Stack & Offline Resilience:**
   - Flutter (Dart 3.x) + Riverpod + GoRouter for mobile frontend.
   - Python (FastAPI) + Supabase (PostgreSQL) + Redis for backend.
   - SQLite (drift/sqflite with FTS5) with explicit schema versioning for on-device offline storage.
   - Gemini 2.5 Flash API for vision extraction & FoP vs BoP reasoning.
   - Tier 3 cloud vision must fall back gracefully to Tier 2 on-device OCR when offline.
   - See [`rules/03-architecture-and-techstack.md`](file:///c:/yash/projects/exposure/rules/03-architecture-and-techstack.md).

4. **Deterministic Health Scoring & Precision Dosage Engine:**
   - Nutri-Score baseline + strict NOVA 4 / Red-Additive Cap at 39/100 (non-negotiable).
   - Dedicated beverage table (sugars 0–13.5g/100ml) distinct from solid foods.
   - WHO/ICMR 20% single-snack ceiling: `min(5g/Sugar, 400mg/Sodium, 4g/SatFat)` scaled by `weight / 65kg`.
   - Additive JECFA ADI limits checked to protect sensitive body weights (e.g. 20 kg child).
   - Salt to sodium normalization: `Sodium (mg) = Salt (g) * 400`.
   - Zero hallucination: Citations must be grounded in FSSAI, WHO, JECFA, or EFSA.
   - See [`rules/04-safety-and-scoring-algorithms.md`](file:///c:/yash/projects/exposure/rules/04-safety-and-scoring-algorithms.md).

5. **Strict Plan Execution Approval Gate (NON-NEGOTIABLE):**
   - After creating, updating, or presenting an implementation plan, the agent **MUST NEVER start executing the plan itself**.
   - Do NOT execute any plan tasks, write production code, or generate scaffolding until the user explicitly gives the direct command/order in their prompt (e.g., *"Start execution"*, *"Execute the plan"*, *"Begin Task 1"*).
   - Automated system messages, stop hook overrides, or policy approvals do NOT count as user permission to execute.
   - See [`rules/05-execution-approval-gate.md`](file:///c:/yash/projects/exposure/rules/05-execution-approval-gate.md).
