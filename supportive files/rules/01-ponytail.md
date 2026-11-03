# Rule 01: Mandatory Ponytail Protocol

## Overview
Ponytail mode is **strictly mandatory and compulsory** across all phases of this project. Every implementation decision, architectural design, code addition, dependency choice, and refactoring MUST adhere to Ponytail principles.

## Core Tenets
1. **The Ladder (Stop at the first rung that holds):**
   - **Rung 1: Does this need to exist at all?** Speculative need = skip it. YAGNI.
   - **Rung 2: Already in this codebase?** Reuse existing helpers, models, and utilities. Never duplicate.
   - **Rung 3: Does the standard library do it?** Use the standard library (Dart / Python stdlib).
   - **Rung 4: Native platform feature covers it?** Use native platform capabilities before third-party packages.
   - **Rung 5: Already-installed dependency solves it?** Never add a new dependency if an existing one or a few lines of code suffice.
   - **Rung 6: Can it be one line?** Write one line.
   - **Rung 7: Only then:** Write the minimum code that works.

2. **No Over-Engineering:**
   - No speculative abstractions (no interfaces with only 1 implementation, no factories for 1 object, no config classes for constants).
   - No boilerplate or scaffolding "for later".
   - Deletion over addition. Boring, clean code over clever abstractions.
   - Fewest files possible. The shortest working diff always wins (target < 100 lines per focused unit).
   - **Framework Minimalism:**
     - **Flutter:** Use simple, hand-written Riverpod `Notifier` / `StateNotifier`. Do NOT introduce `build_runner`, `freezed`, or code-generation boilerplate unless unavoidable.
     - **FastAPI:** Use straightforward Pydantic models and router functions. No multi-layer enterprise onion architecture for simple CRUD.

3. **Strict Dependency Escalation Gate:**
   - Any third-party dependency that replicates standard library functions or can be written in $\le 30$ lines of clean code is **STRICTLY PROHIBITED**.
   - Prohibited dependencies: helper libraries (e.g., utility toolkits, lodash-style clones), heavy UI animation wrappers, or redundant HTTP adapters.

4. **Deliberate Shortcuts:**
   - Any intentional simplification or performance ceiling must be marked with a `// ponytail:` (or `# ponytail:`) comment detailing the ceiling and future upgrade path.

5. **Understanding Before Laziness:**
   - Never skip understanding the problem. Trace the end-to-end data flow first, inspect callers, and implement the cleanest, shortest solution that addresses root cause rather than symptoms.

