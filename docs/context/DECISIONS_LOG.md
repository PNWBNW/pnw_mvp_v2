# Decisions Log

Use this file for durable architectural/process decisions.

Format:
- `YYYY-MM-DD` — **Decision**
  - **Why**
  - **Impact**

---

- `2026-02-27` — **Create centralized context hub in `docs/context/`**
  - **Why:** Reduce context loss when conversations are interrupted and resumed in new threads.
  - **Impact:** Future PRs should update phase status, decisions, and next actions in one place.

- `2026-02-27` — **Keep adapters as the only execution boundary**
  - **Why:** Preserves planner-only workflow/router architecture.
  - **Impact:** No direct CLI/network execution from workflows/routers.

- `2026-03-01` — **Adopt a canonical Phase A scenario payload contract for test + future app execution**
  - **Why:** Avoid format drift between operator test-deploy artifacts and React/backend-triggered execution paths.
  - **Impact:** Scenario files in `config/scenarios/` become the shared input surface; test runners and future dispatch tooling should consume this format directly.

