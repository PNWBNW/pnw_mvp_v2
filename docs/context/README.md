# PNW Context Hub (Thread-Handoff Friendly)

This folder is the **single review surface** for current status, decisions, and next actions.

Use this first when starting a new Codex thread.

---

## Files

- `PHASE_TRACKER.md`
  - Where we are now by phase
  - Exit criteria checklist
  - Current blockers
- `DECISIONS_LOG.md`
  - Immutable decision history (what/why/date)
- `NEXT_ACTIONS.md`
  - Ordered implementation queue for upcoming PRs
  - Per-item acceptance checks
- `THREAD_HANDOFF_TEMPLATE.md`
  - Copy/paste template for opening a new thread with minimal context loss

---

## Update Rules (important)

When a PR changes roadmap, workflow, execution wiring, testnet posture, or release assumptions:

1. Update the relevant file(s) in this folder **in the same PR**.
2. Keep entries short and dated.
3. Prefer additive updates (append history) over rewriting old decisions.
4. If priorities shift, update `NEXT_ACTIONS.md` ordering explicitly.

This keeps context durable across interrupted conversations.
