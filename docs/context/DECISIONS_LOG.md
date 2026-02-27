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
