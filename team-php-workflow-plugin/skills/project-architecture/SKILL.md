---
name: project-architecture
description: >
  Layer structure and dependency rules for this Laravel codebase: no
  Repository pattern, Services call Eloquent directly, Utils purity, HTTP
  layer boundaries. Use this skill whenever creating a new class, deciding
  where logic belongs, planning implementation (task-planner), or reviewing
  architectural placement (convention-reviewer).
---

# Project Architecture

## Layers and dependency direction

```
Route → Controller → Service → Eloquent Model → DB
           ↓             ↓
      FormRequest    app/Utils (pure)
           ↓
      JsonResource (response shaping)
```

Dependencies point downward only. A lower layer never imports an upper
one (a Model never references a Service; a Service never references a
Controller or Request object — it receives validated primitives/DTOs/
arrays, not the Request).

## Confirmed decisions (do not relitigate in reviews)

- **No Repository pattern.** Services call Eloquent directly. Introducing
  a repository/interface indirection is a finding, not an improvement.
- **`app/Utils/` is pure**: business-agnostic, deterministic, static
  helpers. No Eloquent, no facades with state, no `config()`/`auth()`.
  If it knows about IEPs, questionnaires, or roles, it is not a Util —
  it belongs in a Service.
- **Controllers are thin**: authorize → delegate to Service → shape
  response via JsonResource. Business branching in a controller is a
  finding.
- **Validation lives in FormRequests**, authorization object-checks in
  Policies (see php-security skill for the two-layer rule).
- **Domain layering of IEP**: IEPマスタ (school-level catalog / "menu")
  and per-student IEP instances ("ordered dishes") are distinct concepts
  with distinct models — code that conflates them is an architectural
  finding, because this confusion is a known project failure mode.

## Where does this logic go? (decision table)

| Logic | Home |
|---|---|
| Pure calculation/format, no domain knowledge | `app/Utils/` |
| Business rule, workflow transition, multi-model orchestration | Service |
| Input shape/validity | FormRequest |
| "May THIS user act on THIS record" | Policy |
| Output field selection/shape | JsonResource |
| Cross-cutting query constraint (tenant scope, soft delete) | Global scope on the Model |

## Data rules (interact with db-migration-safety skill)

- Schema changes only via migrations.
- Multi-table writes in `DB::transaction()`.
- Optimistic locking on mutable workflow entities.
- Tenant (school) scoping is enforced at the Model (global scope) or
  Policy level — never left to each caller's memory.
