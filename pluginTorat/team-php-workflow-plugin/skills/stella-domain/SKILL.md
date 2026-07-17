---
name: stella-domain
description: >
  Product/domain knowledge for the Stella Plan school system (admin + IEP
  functionality): the confirmed business rules the API must enforce and the
  spec items still undecided. Use this skill whenever planning or reviewing
  work on a Stella Plan feature — especially in the API phase — to ground the
  plan in real constraints and to surface open questions before coding. Read
  it during task-planning (stage 1); consult it in security and API review
  when authorization, IEP lifecycle, batch, or import endpoints are involved.
---

# Stella Plan — Domain

Distilled from the system-overview deck (`tongquathethong.md`, 178 slides).
This skill exists so a plan is grounded in **what the system actually
requires** instead of generic CRUD assumptions — the deck carries ~45 hard
constraints and ~30 explicitly-undecided items, and missing one is how edge
cases ship broken.

It captures **rules and open questions only** — not the screen-by-screen UI.
Two reference files hold the detail:

- **[`invariants.md`](./invariants.md)** — confirmed rules the API MUST
  enforce, grouped by area (auth, RBAC, year/term batch, IEP lifecycle &
  approval, immutability/concurrency, import/export, cross-cutting tech).
- **[`open-questions.md`](./open-questions.md)** — the "Cần xác nhận" items
  that must be confirmed with the client **before** the affected code is
  written.

## The one model to internalize: 3-axis RBAC

Every authorization decision is **Role × School × Class**, not role alone.
One user can belong to many schools and many classes (join tables, not
columns). The system runs on a **single database** with tenant separation by
**logical scoping** — so *every* query needs an explicit school (and often
class) scope, and authorization is per-operation (View/Create/Edit/Delete),
per-object, not per-page. This is the dominant source of real bugs in this
domain; see `invariants.md` → *RBAC* and the `php-security` skill's two-layer
rule.

## How task-planner must use this (stage 1)

When planning a Stella Plan ticket, after normalizing acceptance criteria:

1. **Match the feature area to `invariants.md`** and pull every rule that
   touches the endpoints/tables in scope. Fold them into the *Impact map* and
   into the criteria (e.g. "batch endpoint must be idempotent",
   "response must not leak student name", "scope by school+class").
2. **Check `open-questions.md`.** If the ticket depends on an undecided item
   (approval order, 2FA method, goal-count limit, OneRoster mapping, …),
   record it under *Risks & open questions* and mark the affected criterion
   as needing client confirmation — **never pick a default and code past it**
   (this is exactly what the anti-loop escalation in `agent-pipeline` is for).
3. **Flag the destructive / irreversible operations** the domain defines —
   end-of-term processing (idempotent, once-only), goal inheritance
   (overwrites the target term), finalize (locks editing), post-submit
   evaluation (cannot change) — as risks requiring explicit handling.

## Highest-value invariants at a glance

(full list + line refs in `invariants.md`)

- **Auth**: login = email/ID **+ password + school code**; 5 fails → lock;
  `Số IEP` and `Mã trường` are immutable.
- **Batch**: end-of-term = press-once/idempotent, precondition "all classes
  submitted"; switch term only after it completes.
- **Inheritance**: overwrites the target term; **only approval-completed data**
  is inherited, rest excluded with a reason.
- **IEP**: never hard-deleted (status machine); finalize locks editing;
  approval → **async PDF**; teacher eval is **immutable after submit**;
  optimistic locking (expect 409).
- **Import**: partial success with per-row errors; parent import max 300/run.
- **Privacy**: IEP screens show `Số IEP`, not names; psych/WISC data =
  expert role only; parents see linked students only.

## Scope note

The deck's second half (teacher/IEP side) and the master/log/system-settings
section carry most of the IEP-lifecycle and approval rules; the admin half
carries auth, RBAC, year/term, and user/school/teacher/parent management.
Both are folded into `invariants.md` by topic, not by slide order. UI-only
detail (layouts, button placement) was intentionally left out per the agreed
scope — add a `screens/` reference file later if screen specs are needed.
