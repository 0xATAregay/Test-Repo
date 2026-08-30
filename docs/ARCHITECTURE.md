# Architecture decisions

## ADR-001: Local-first before cloud sync
EdgeLab must remain useful with no paid provider or credentials. Structured learning state is persisted locally, while the cloud relational schema is kept separate. This prevents a fake “connected” backend and makes guest/demo mode real.

## ADR-002: Process scoring is deterministic and transparent
Blind cases are graded on context, rubric classification, checklist adherence, written reasoning, uncertainty/invalidation, and recorded confidence. Later price movement is excluded from the score. The scoring function is pure and testable.

## ADR-003: Playbooks are append-only versions
Revising an active playbook creates a new immutable version with a mandatory reason. Decisions store the exact version ID. Historical analytics therefore remain attached to the rules that existed when evidence was created.

## ADR-004: XP is an idempotent ledger
XP is never a mutable total. It is derived from unique events. Domain logic rejects duplicate event keys and the cloud schema enforces a unique `(user_id,event_key)` index.

## ADR-005: Synthetic charts are deterministic
All 48 seeded cases use deterministic OHLC generation. Tests and educational rubrics can therefore rely on stable data without a paid market-data source or licensing ambiguity.

## ADR-006: Native accessibility over custom-widget cleverness
Forms, buttons, selects, checkboxes, fieldsets, tables and details elements remain native wherever possible. Custom ARIA is reserved for dialogs/status. This reduces keyboard and screen-reader failure modes.

## ADR-007: Planning is deliberately constrained
Today surfaces no more than three missions and Comeback Mode temporarily hides backlog. The system does not reward roadmap editing, streak preservation, simulated profits, or future account planning.
