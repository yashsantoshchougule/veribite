# Project Exposure — Agent Governance & Directives

All agents interacting with this project must strictly comply with the workspace rules:

- **Ponytail Protocol (Compulsory):** Follow [`rules/01-ponytail.md`](file:///c:/yash/projects/exposure/rules/01-ponytail.md). Minimal code, zero bloat, YAGNI, dependency escalation gate (no packages for $<30$ lines of code), shortest working diffs.
- **Testing Directory (Strict Isolation):** All test, scratch, mock, and experimental scripts must be stored inside [`testing/`](file:///c:/yash/projects/exposure/testing). See [`rules/02-testing-folder.md`](file:///c:/yash/projects/exposure/rules/02-testing-folder.md) and [`testing/README.md`](file:///c:/yash/projects/exposure/testing/README.md). Zero live network calls in unit tests; no hardcoded secrets; temporary artifacts write only to `testing/scratch/`.
- **Architecture & Tech Stack:** Follow [`rules/03-architecture-and-techstack.md`](file:///c:/yash/projects/exposure/rules/03-architecture-and-techstack.md). Flutter + Riverpod + GoRouter, Python FastAPI + PostgreSQL/Redis. Tier 3 degrades gracefully to Tier 2 when offline.
- **Scoring & Safety Engine:** Follow [`rules/04-safety-and-scoring-algorithms.md`](file:///c:/yash/projects/exposure/rules/04-safety-and-scoring-algorithms.md). Nutri-Score + NOVA/Red-Additive cap (39/100 max for red additives), beverage vs solid food tables, WHO 20% snack ceiling, body-weight and additive ADI scaling, salt-to-sodium normalization, zero hallucination.
- **Plan Execution Gate (Compulsory):** Follow [`rules/05-execution-approval-gate.md`](file:///c:/yash/projects/exposure/rules/05-execution-approval-gate.md). After doing planning, NEVER start plan execution until explicit order is given directly in the user prompt.
- **Specification:** Full functional requirements are in [`PROJECT_SPECIFICATION.md`](file:///c:/yash/projects/exposure/PROJECT_SPECIFICATION.md).
