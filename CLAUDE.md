# CLAUDE.md — AssetCare Lite

> **This file is the single source of truth for the AssetCare Lite project.**
> Every coding session — with Claude or any other tool — must read this file first and follow it exactly.
> If something here conflicts with a request, this file wins unless I (Faiz) explicitly say "override CLAUDE.md for this".
> When in doubt, re-read this file. Do not improvise outside these rules.

---

## 0. How to use this file

- **At the start of every session**, read this entire file before writing a single line of code.
- **Before building any feature**, find it in the Roadmap (Section 9) and confirm which phase it belongs to.
- **Never skip phases.** Finish the current phase fully (code + tests + commit) before starting the next.
- **Never add a feature that is not in the Roadmap** without first adding it to the Roadmap and getting my okay.
- If I ask for something that breaks a rule here, remind me of the rule, then do what I decide.
- At the end of every session, update Section 12 (Progress Log). When a design decision is made, record it in Section 13 (Decisions Log).

---

## 1. Project identity

| Field | Value |
|---|---|
| **Project name** | AssetCare Lite (branding only — see Decision D1) |
| **One-line pitch** | Lightweight preventive maintenance and asset tracking for Salesforce SMBs — no Field Service license required. |
| **Type** | Portfolio project on Salesforce DX. AppExchange packaging is a *possible future*, not a current constraint. |
| **Primary goal** | Prove senior-level Salesforce development skill for job hunting. |
| **Budget** | ₹0 / $0. Every tool must be free. No paid services, ever. |
| **Owner** | Faiz Sheikh — Salesforce Developer |
| **Dev org** | Developer Edition (URL kept local — never commit it, repo is public) |
| **Naming** | **No prefix.** Keep existing API names. Match existing code style for new components. |
| **Target buyer (story)** | Manufacturing ops, equipment rental, facilities management teams (SMB). |
| **GitHub** | Public repo (renamed from FieldOps 360 to AssetCare Lite branding). |

---

## 2. The golden rules (never break these)

1. **Zero spend.** If a solution requires money, it is not allowed. Find the free path or skip it.
2. **Evolve, don't rewrite.** Salesforce cannot cleanly rename API names. We extend the existing schema; we never rebuild working code for cosmetic reasons.
3. **Security-compliant from line one.** User-mode DML on all side-effect DML. `with sharing` declared on every class. Bind variables in every SOQL.
4. **Tests are not optional.** No class is "done" until it has meaningful tests (real assertions, negative cases, bulk cases) and the full suite is green.
5. **One thing at a time.** Finish the current task completely (code + test + commit) before moving on.
6. **Commit after every working unit.** Format in Section 8.
7. **No magic.** Every design decision must be explainable in an interview. If I can't explain why, we don't build it that way.
8. **Bulkify everything.** All Apex must handle 200+ records. No SOQL or DML inside loops. Ever.
9. **The README is a deliverable.** It is updated alongside code, not at the end.
10. **Stick to this file.** When unsure, this file decides.

---

## 3. Tech stack (all free)

| Layer | Tool | Notes |
|---|---|---|
| Org | Salesforce Developer Edition | Free forever. Main build org. |
| IDE | VS Code + Salesforce Extension Pack / Dev Console | Free. |
| CLI | Salesforce CLI (`sf`) | Deploy/retrieve/test. |
| Version control | Git + GitHub (public) | Portfolio-visible. |
| Static analysis | Salesforce Code Analyzer (`sf scanner`) | Run before major pushes. |
| Diagrams | draw.io | ERD + architecture for README. |
| Demo video | Loom free tier / OBS Studio | 3-min demo (Phase 5). |
| API version | One version everywhere | Match `sfdx-project.json` sourceApiVersion. Never mix versions across meta.xml files. |

---

## 4. Coding standards — Apex (STRICT)

### 4.1 Naming conventions (match existing code)

| Element | Convention | Existing example |
|---|---|---|
| Trigger | `<Object>Trigger` | `MachineAssetTrigger` |
| Handler | `<Object>TriggerHandler` | `MachineAssetTriggerHandler` |
| Service | `<Domain>Service` | `MachineAssetService`, `PMSchedulerService` |
| Batch/Schedulable | `<Domain>Batch` | `PMSchedulerBatch` |
| Test class | Target class + `Test` | `MachineAssetServiceTest` |
| Method | camelCase, verb-first | `processDueSchedules()` |
| Boolean | `is`/`has`/`can`/`should` prefix | `isInsert`, `shouldCreate` |
| Constant | UPPER_SNAKE_CASE | `NIGHTLY_CRON` |
| Variable | camelCase, honest names | A list holds many → plural name. A schedule is not an `asset`. |

No abbreviations except universal ones (`Id`, `SLA`, `PM`, `WO`). Correct `__c` casing (lowercase c).

### 4.2 Sharing — declared on EVERY class

- Every class MUST explicitly declare `with sharing`, `without sharing`, or `inherited sharing`.
- Default to `with sharing`. `without sharing` only with a documented reason in the class header.

### 4.3 Security + DML patterns (the project's proven patterns)

**Pattern A — user-facing trigger DML** (a human is saving a record):
- `insert as user records;` in try/catch.
- Catch `System.SecurityException` FIRST (proven — D6), then `DmlException`.
- On failure: `addError()` on the originating records with a friendly message (what happened + why + what to do).

**Pattern B — background job DML** (no human watching, e.g. nightly scheduler):
- `Database.insert(records, false, AccessLevel.USER_MODE);` → partial success (D10).
- Loop the `SaveResult` list **by index** — result[i] matches input[i].
- Winners → continue their flow (e.g. stamp). Losers → add a message to a `List<String> errors`.
- `addError()` is NEVER used in background jobs (no screen to show it on).
- The calling batch emails the admin ONLY when errors exist. Silence = success (D11).

### 4.4 SOQL — strict rules

- Bind variables ALWAYS. Never string concatenation in queries.
- SOQL date literals (like `TODAY`) in capitals, used intentionally.
- No SOQL inside loops. Query once into a Map/Set/List before looping.
- Selective WHERE filters; `LIMIT` on any query that could return many rows.
- **If a field is used in code, it must be in the SELECT list.**
- Self-exclusion on update-context duplicate checks: `AND Id NOT IN :incomingIds`.

### 4.5 DML — strict rules

- No DML inside loops. Collect, then one DML after the loop.
- Bulk-safe for 1 or 200 records identically.
- Update-only records pattern: `new PM_Schedule__c(Id = x.Id, Field__c = value)` — Id + only the fields you change.

### 4.6 Exception & error strategy

- User-facing failure → `addError()` with a friendly, specific message.
- Background failure → collect into `List<String>`, return it; batch emails admin.
- Specific catches before general. No empty catch blocks — ever.
- Deliberately-uncovered defensive catches are acceptable **if documented** in the Decisions Log (see D7).
- System emails: calm tone, one `!` max, facts only: what happened, when, what happens next.

### 4.7 What is FORBIDDEN in Apex

- ❌ `System.debug()` in committed code. ❌ Chat/hint comments pasted into code.
- ❌ Hardcoded IDs, usernames, emails, URLs. Use queries / Custom Metadata.
- ❌ SOQL or DML inside `for` loops. ❌ Empty catch blocks. ❌ `@SeeAllData=true`.
- ❌ Business logic inside triggers. ❌ String concatenation in SOQL.

---

## 5. Coding standards — Triggers

- **One trigger per object**, no logic inside — delegate to `<Object>TriggerHandler`.
- Flow: **Trigger → Handler → Service.** Always these three layers.
- **Validation** (addError) runs in **before** context — both insert AND update where applicable.
- **Side-effect DML** (other records) runs in **after** context (validated, committed, has Id).
- `addError()` in after context rolls back the whole transaction — intended behavior.
- Current live pattern on `Machine_Asset__c`: before insert = prepare + validate serials; before update = validate serials; after insert/update = handleAssetUpdate.

---

## 6. Coding standards — Tests (STRICT)

- `Test.startTest()` / `Test.stopTest()` around the action under test.
- **Test data must satisfy ALL org validation rules:**
  - Service_Ticket: High priority requires `Description__c`; Closed requires `Resolution_Notes__c`.
  - Machine_Asset: `Installation_Date__c` not in future; `Warranty_End__c >= Warranty_Start__c`.
- Positive AND negative tests. Bulk test (50–200 records) for trigger paths.
- Security tests: `System.runAs()` with restricted-profile user; wrap User insert in `runAs(current user)` (MIXED_DML); timestamp usernames.
- Assert outcome (`isSuccess() == false`) BEFORE reading `getErrors()[0]`.
- Trace setup data by hand before asserting counts.
- Many tests fail at once → suspect `@TestSetup`. One fails → suspect its own math. **Read the error message first.**
- Coverage target: 90%+ per class, meaningful assertions.

---

## 7. Data model (current, real)

### Live objects

| Object | Relationship | Purpose |
|---|---|---|
| `Customer_Site__c` | Master | Physical location. Rollup: `Total_Installed_Assets__c`. |
| `Machine_Asset__c` | Master-Detail → Customer_Site__c | A machine. `Serial_Number__c` unique. |
| `Service_Ticket__c` | Lookup → Machine_Asset__c (SetNull) | Maintenance/repair task. Auto-named by Flow `Auto_Set_Service_Ticket_Name`. |
| `PM_Schedule__c` | Lookup → Machine_Asset__c | **NEW (Phase 2).** Recurring maintenance rule per machine. Record Name: Auto Number `PM-{0000}`. |

### PM_Schedule__c fields (live)
- `Machine_Asset__c` (Lookup, required) · `Interval_Days__c` (Number, required) · `Frequency__c` (Picklist — human label only, math uses Interval_Days)
- `Last_Run__c` (Date/Time — stamped by scheduler on SUCCESS only)
- `Next_Run__c` (Formula, Date): `IF(ISBLANK(Last_Run__c), TODAY(), DATEVALUE(Last_Run__c) + Interval_Days__c)` — blank = new schedule = due today (intentional)
- `Active__c` (Checkbox, default checked — deactivate, don't delete) · `Assigned_To__c` (User, optional) · `Description__c` (optional)

### Key field decisions
- `Machine_Asset__c.Last_Maintenance_Date__c` → planned/PM work only (drives `Next_Maintenance_Due__c`, blank-safe formula).
- `Machine_Asset__c.Last_Service_Date__c` → any completed work.
- `Warranty_Status__c` blank-safe → "No Warranty Info".
- `Service_Ticket__c.Status__c` includes `Open` (initial state for auto-created tickets).
- PM-generated tickets: `Ticket_Type__c='Maintenance'`, `Status__c='Open'`, `Priority__c='Medium'` (Medium keeps the High-priority validation rule out of play).

### Planned
- `PM_Alert__e` Platform Event (Phase 2, after tests — optional stretch).

---

## 8. Git workflow (STRICT)

- `main` — only stable, phase-complete code. One branch per phase.
- Commit format: `<type>: <present-tense description>` — `feat`, `fix`, `test`, `refactor`, `docs`, `chore`.
- Commit after every logical unit. Retrieve org changes (`sf project retrieve start --source-dir force-app`) BEFORE committing.

---

## 9. The Roadmap

### Phase 1 — Foundation hardening ✅ COMPLETE
All bugs fixed, user-mode DML security proven with runAs test, trigger contexts corrected, suite green, ~94% coverage. Details in git history + Progress Log.

### Phase 2 — PM Scheduler (CURRENT)
- [x] `PM_Schedule__c` object + fields + blank-safe Next_Run formula
- [x] `PMSchedulerService.processDueSchedules()` — query due → build Maintenance tickets → **partial-success insert** (`Database.insert(..., false, AccessLevel.USER_MODE)`) → stamp winners only → report losers → return `List<String>` errors
- [x] `PMSchedulerBatch` (implements `Schedulable`) — calls service; if errors exist, emails admin (queried, not hardcoded); silence = success
- [ ] **Verify final fix deployed + committed** (duplicate `schedulesToStamp` line removed; optional renames: `activeSchedules`, `serviceTickets`)
- [ ] **Register the nightly job** — Anonymous Apex: `System.schedule('PM Scheduler - Nightly', '0 0 2 * * ?', new PMSchedulerBatch());` (cron expression explanation owed to Faiz)
- [ ] **Tests**: due schedule → ticket + stamp; not-due → nothing; inactive → nothing; bulk (50); Schedulable execute path; email path (errors present)
- [ ] Wire D3: on Maintenance ticket close → update asset `Last_Maintenance_Date__c` (decide: Flow or trigger — record decision)
- [ ] Optional stretch: `PM_Alert__e` platform event
**Done when:** nightly job registered, tests green ≥90%, committed, README updated.

### Phase 3 — LWC Dashboard + SLA automation
- SLA via Custom Metadata (tier → hours) replacing hardcoded 48h/Bronze · Site link formula on ticket · `Is_Overdue__c` formula · LWCs (asset health dashboard, ticket list + quick-create, PM schedule manager, overdue alert bar) · Permission sets.

### Phase 3.5 — Approved enhancements (only after Phase 3)
- Flexible PM rule types (`Rule_Type__c`: Time / Usage first; Strategy pattern)
- Failure tracking (`Failure_Reason__c`, `Failure_Category__c` + report)
- `Error_Log__c` object for error history (Faiz's idea — approved as candidate)
- Retry limit / circuit breaker: `Failed_Attempts__c` counter, auto-deactivate after 3 failures + admin email (Faiz's idea — approved as candidate)

### Phase 4 — Security scan + polish · Phase 5 — README + demo + portfolio
(unchanged)

---

## 10. Definition of "Done" (every task)

1. ✅ Follows Sections 4–6. 2. ✅ Deploys clean. 3. ✅ Meaningful tests, suite green. 4. ✅ No debug/hardcoding/dead code. 5. ✅ Headers + comments in place. 6. ✅ Org retrieved, committed with proper message. 7. ✅ Roadmap checkbox ticked + Progress Log updated. 8. ✅ Any decision recorded in Decisions Log.

---

## 11. When blocked (protocol)

1. Read the actual error message fully — first, always.
2. Reproduce minimally; check the Decisions Log and this file.
3. Timebox 30 minutes. Write down what was tried.
4. Still stuck → stop, note state in Progress Log, bring the exact error + attempts to the next session. No thrash-coding.

---

## 12. Progress log (newest first)

- **[Session 5 — PM Scheduler build]** Created `PM_Schedule__c` (all fields + blank-safe Next_Run formula — Faiz wrote it). Built `PMSchedulerService` with partial-success pattern (D10) and stamp-on-success-only (D9). Built `PMSchedulerBatch` (Schedulable) with admin error email (D11). Last known issue: duplicate `schedulesToStamp` declaration — fix instructed, **verify deployed + committed at next session start.** Next: register nightly cron, then tests. Open thread: Faiz said he "has a plan in mind" — ask him what it is!
- **[Session 4 — Foundation close-out]** Security runAs test passing; proved `SecurityException` fires for user-mode object-CRUD violations (D6, D7). Suite green, ~94% coverage. CLAUDE.md v2.
- **[Session 3 — Test debugging]** AssetQueryServiceTest 8/8 failures root-caused (validation rules in @TestSetup) + two assertion data-math bugs fixed. Suite green.
- **[Session 2 — Foundation hardening]** Formula blank-handling, Open status, in-batch duplicates, self-exclusion, after-context DML, user-mode DML + double catch.
- **[Session 1 — Strategy]** Evolve in place; rebrand only (D1/D2). Full audit → Phase 1 bug list.

---

## 13. Decisions log (why we did what we did)

- **D1 — Branding vs API names.** "AssetCare Lite" is branding only. API names stay. Old `ACL_`-prefixed starter code is obsolete — never deploy it.
- **D2 — No namespace / no prefix.** Portfolio-first; decide namespace only if AppExchange ever happens.
- **D3 — Two date fields, two roles.** `Last_Maintenance_Date__c` = planned PM only; `Last_Service_Date__c` = any work. Wiring pending in Phase 2.
- **D4 — Flow owns ticket naming.** Apex never sets `ticket.Name`.
- **D5 — Side-effect DML in after context.** Validation in before.
- **D6 — Empirical: user-mode DML throws `System.SecurityException`** for missing object-create permission (proven via runAs + Minimum Access profile). Catch order: SecurityException, then DmlException.
- **D7 — `DmlException` catch in trigger path deliberately uncovered.** Documented trade-off.
- **D8 — Ticket survives asset deletion** (Lookup SetNull): service history preserved.
- **D9 — Stamp `Last_Run__c` only on successful insert.** Failed schedules stay due → automatic retry next night. Self-healing; the database itself is the "failed records list" (no in-memory retry list — Apex memory dies when the run ends).
- **D10 — Partial-success insert in the scheduler.** `Database.insert(tickets, false, AccessLevel.USER_MODE)` + SaveResult loop by index. One bad ticket must not block the other 49. Winners stamped; losers reported.
- **D11 — Repeated daily admin email for unresolved errors is intentional.** Daily nag = visibility. Silence = success (email only when errors exist). Alert-fatigue is not a risk at our scale.

---

## 14. Quick command reference

```bash
# Retrieve org changes into repo (BEFORE committing)
sf project retrieve start --source-dir force-app

# Deploy repo to org
sf project deploy start --source-dir force-app

# Run one test class / full suite with coverage
sf apex run test --class-names PMSchedulerServiceTest --result-format human --code-coverage
sf apex run test --result-format human --code-coverage

# Static security analysis
sf scanner run --target force-app --category Security --format table
```

```apex
// Register the nightly job (run once, Anonymous Apex) — Phase 2 pending task
System.schedule('PM Scheduler - Nightly', '0 0 2 * * ?', new PMSchedulerBatch());
```

---

## 15. Final reminder

**This file is the law of this project.** Read it first, follow it always, update the logs as we go.
We are proving senior-level judgment on a zero budget: clean architecture, proven security, honest tests, documented decisions. Stay disciplined. Stick to the plan.