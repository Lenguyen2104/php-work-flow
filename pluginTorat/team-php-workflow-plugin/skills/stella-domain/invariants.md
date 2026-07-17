# Stella Plan — Domain invariants (API-relevant)

Distilled business rules the API MUST enforce, from the system-overview
(`tongquathethong.md`). Companion to [`SKILL.md`](./SKILL.md). Line refs
(`L####`) point back to the source doc. These are **confirmed** rules; things
still undecided live in [`open-questions.md`](./open-questions.md) — treat any
rule here that a task depends on but that is contradicted by an open question
as a Risk, not a fact.

## Authentication & accounts

- Admin/teacher login = **email + password + school code (Mã trường)** — all
  three (L92–94). Not email+password alone.
- **5 consecutive failures → account locked**; unlock only via support
  (L94, L3319). Login attempts are logged.
- Student login = **User ID (= Số IEP) + password + school code** (L868).
- **Số IEP** is the student's User ID: auto-assigned at registration,
  **immutable** (L2214, L6768).
- Some users have **no email** — must be supported (L6771).
- 2FA via authenticator app (6-digit OTP); a device may hold multiple
  accounts (L121, L127). *Exact method (Passkey/OTP/PIN, on/off) is an open
  question.*

## RBAC — the 3-axis model (the dominant source of authz bugs)

Effective permission = **Role × School (trực thuộc) × Class (lớp)** (L68).

- One person may belong to **multiple schools** and **multiple classes**
  (L66–67); membership is stored in separate join tables, not a column.
- Every data-returning or state-changing endpoint must scope by the caller's
  school (and class where relevant), never by client-supplied school/class.
- Per-role **permission matrix** = function × operation (View/Create/Edit/
  Delete) (slide 21). Authorization is per-operation, not per-page.
- **Master điểm đánh giá** (score master): by default only System Admin; may
  be granted to School Admin via role config (L963).
- **Psych-test / WISC data**: only the *Chuyên gia* (expert, "level-C") role
  may view it — hidden from ordinary teachers (L2351, L5471).
- **GVCN** (homeroom) = creates IEP + daily + end-term evaluation.
  **Phó chủ nhiệm** (assistant, **max 5** per class) = daily evaluation only
  (L1837, L1954, L2014).
- **Parents** may only see their **linked** students (L6222).
- IEP create/operate screens show **Số IEP instead of name** (privacy)
  (L3848) — response payloads for those contexts must not leak names.

## Year / term & batch processing (idempotency-critical)

- **End-of-term processing (Xử lý cuối học kỳ)**: press **exactly once**,
  wait for completion, no repeated clicks (L345, L433) → the endpoint must be
  **idempotent / locked** against double-submit.
- Precondition: **all classes** must have submitted their end-term evaluation
  before it runs (L347, L5997).
- **Must switch year/term only after** end-of-term processing completes
  (L255) — ordering constraint enforced server-side.
- End-of-term processing **copies finalized goals + end-term evals** for the
  next term (L427); reports **record count + error count** (slide 13).
- **Goal inheritance (Kế thừa mục tiêu)**:
  - First-half → second-half: **overwrites** the target term entirely
    (L529, L588). Destructive — confirm + guard.
  - Second-half → next-year first-half: done by **School Admin for the whole
    school** at once (L545). Per-class inheritance by GVCN is allowed **only**
    first-half → second-half (L544).
  - **Only approval-completed data is inherited**; incomplete data is
    excluded ("loại trừ một phần") with a viewable reason (L527, L594,
    L7724, L7736, L7773, L7825, L7880).

## IEP lifecycle & approval

- IEP is **never physically deleted** — managed by status: `Bản nháp` /
  `Chờ phê duyệt` / `Đã phê duyệt` / `Trả lại` / `Hủy` / `Vô hiệu`
  (L7547, L8600).
- On **finalize (chốt)**: edit-mode → view-mode; student frame flips
  "Chưa tạo" → "Đã chốt" (L4754, L4808). A finalized IEP is not freely
  editable.
- **Approval workflow**: approvers freely configured, **count not fixed**; if
  no order is specified, it completes when **all** approve (L7385, L7465).
- After approval: **generate the IEP PDF asynchronously**, store to external
  storage e.g. S3 (L7387). App e-stamp is embedded into the PDF; no e-stamp
  at the approval step itself (L7388).
- **Teacher evaluation applies only after `<Gửi>` (submit); once applied it
  cannot be changed or cancelled** (L5667, L5704).
- **Support measures (biện pháp hỗ trợ): max 4** (L2798, L4682).
- Score scale is a fixed internal 4/5-level map: `null=― / 25=× / 50=△ /
  75=〇 / 100=◎` (L2648, L5405).

## Immutability, history & concurrency

- Immutable identifiers: **Số IEP**, **Mã trường** (school code, 7 chars,
  L1129), cannot change (L2214, L6768).
- **Questionnaire / daily-input records: not editable after submit**; history
  is kept across repeated inputs; the **latest input is the valid one**
  (L7152, L7181, L7228, L8347, L8398).
- IEP edits use **optimistic locking** for concurrent-edit control (L8451,
  L8600) — expect a 409 conflict path (`lock_version`).

## Import / export

- **Parent bulk import: max 300 per run**, via `ParentExcelSample`
  (L1413, L1519).
- **Teacher import**: `TeacherExcelSample`; role mapping Quản lý→`manager`,
  Chuyên gia→`expert`, Giáo viên thông thường→`teacher` (L1351–1352).
- **Student import** + separate **WISC import** (L2161).
- Imports return **partial success with per-row errors** (row + reason),
  e.g. "created 42 / updated 3 / error 1" (slides 28, 31) — never all-or-
  nothing silently.
- **Export is OneRoster-based**; exact fields still being confirmed
  (L8091, L8148, L7921).

## Cross-cutting technical constraints

- **Single database**; tenant (school) separation is by **logical control**
  on membership + permission, not physical DB split (L8599). → every query
  needs an explicit tenant scope.
- **Notifications: in-app by default**; email only for first-password /
  reset, via external SMTP (no in-house mail server) (L3458, L6203, L8601).
- **Audit**: IEP edits log who / when / what (before→after); other logging is
  minimal (L3384, L8450).
- **Performance target**: 10,000–30,000 concurrent at evaluation-input peaks
  (L3168, L8602) — batch/aggregation must be async (L3230).
