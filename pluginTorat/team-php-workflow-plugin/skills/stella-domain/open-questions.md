# Stella Plan — Open questions ("Cần xác nhận")

Things the system-overview (`tongquathethong.md`) explicitly leaves
**undecided**. Companion to [`SKILL.md`](./SKILL.md). The doc itself states
these "will be fixed in basic design / separate discussion" (L8575).

**Rule for task-planner:** if a ticket's implementation depends on any item
below, the plan MUST list it under *Risks & open questions* and the criterion
it affects is `blocked` / needs client confirmation — **do not pick a default
and code past it.** Line refs (`L####`) point back to the source doc.

## Authentication

- **2FA**: on/off, and which method — Passkey / biometric / OTP / PIN
  (L3754, L6116, L8487). Also who may toggle 2FA.

## Approval workflow (highest-impact — touches IEP APIs directly)

- **Approver config**: count / order / **parallel approval** handling
  (L3755, L6107, L8494).
- **Return & re-approval flow**: after a return, does it restart from level 1?
  Plus duplicate-approval prevention (L5187, L7389, L8501).
- **Editing while pending approval**: allowed or not (besides the return
  case)? (L5115).
- **Change after submit**: may a submitted IEP be changed? (L5784).

## PDF generation

- **Async generation method** + how the electronic stamp is affixed
  (L3763, L6115, L8506).
- **Per-school PDF templates / form layouts** (L8511, L8205).

## IEP content rules

- **Goal count limit**: requirement says "unlimited", current UI caps at 3 —
  to be fixed at design time (L4696, L6106).
- **Display/judgement logic** conditions for evaluation (L4631).
- **Assignment scope**: per-term vs per-year (L6124).
- **Latest-valid aggregation**: whether repeated daily inputs are aggregated
  (L8348).

## Data integration & migration

- **OneRoster mapping** ↔ Stella DB fields (external ID / login ID / name /
  user type) (L7921, L7972, L8023, L8541).
- **L-Gate link items** — full list (L8547).
- **Final CSV export fields** (L8555, L8091).
- **Dual-DB merge**: how to merge/convert the existing `school_mng` DB
  (L3746, L8562).
- **Data migration policy** for current data (L8567).

## Operations

- **Paper distribution** of initial ID/password: print template + reissue
  flow (L871, L7251).
- **Support function** (Diversity Code, 2-tier; conversational): detailed
  spec + what the system handles as first-line vs handoff to Tratto
  (L6538, L6579, L8255).
- **Input format / item spec** for student bulk register/update (L2352,
  L6085).

## Tech stack & infrastructure (mostly out of app scope)

- **PHP / Laravel / MySQL versions** — "planned", confirm each (L3745, L8480).
- **Production infrastructure** / server topology — decided by management
  (L8572).
