# Smart Packaged Product Ingredient, Toxicology & Safe Consumption Dosage Scanner

Cross-platform mobile application and resilient backend for decoding 6,450+ food additives, flagging 56+ hidden split sugars, enforcing a strict 39/100 toxic additive cap, and prescribing personalized safe consumption dosages.

## Monorepo Architecture

- `data_pipeline/`: Offline database compilation (`toxicology_master.db`) with FTS5 trigram indexing.
- `backend/`: FastAPI cloud services (Supabase PostgreSQL, Redis caching, Gemini 2.5 Flash Vision RAG).
- `mobile_app/`: Cross-platform Flutter 3.x client with Riverpod and GoRouter.
- `testing/`: Strictly isolated test directory (`testing/unit/`, `testing/integration/`, `testing/scratch/`).
- `rules/`: Project governance, Ponytail protocol, and scoring invariants.
- `docs/`: Plans, specifications, and architecture audits.
