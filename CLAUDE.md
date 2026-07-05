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
| **Project name** | AssetCare Lite (branding only — see Decisions Log D1) |
| **One-line pitch** | Lightweight preventive maintenance and asset tracking for Salesforce SMBs — no Field Service license required. |
| **Type** | Portfolio project on Salesforce DX. AppExchange packaging is a *possible future*, not a current constraint. |
| **Primary goal** | Prove senior-level Salesforce development skill for job hunting. |
| **Budget** | ₹0 / $0. Every tool must be free. No paid services, ever. |
| **Owner** | Faiz Sheikh — Salesforce Developer |
| **Dev org** | playful-badger-l2hssu-dev-ed.trailblaze.my.salesforce.com |
| **Naming** | **No prefix.** Keep existing API names. Match existing code style for new components. |
| **Target buyer (story)** | Manufacturing ops, equipment rental, facilities management teams (SMB). |
| **GitHub** | Public repo (renamed from FieldOps 360 to AssetCare Lite branding). |

---

## 2. The golden rules (never break these)

1. **Zero spend.** If a solution requires money, it is not allowed. Find the free path or skip it.
2. **Evolve, don't rewrite.** Salesforce cannot cleanly rename API names. We extend the existing schema; we never rebuild working code for cosmetic reasons.
3. **Security-compliant from line one.** User-mode DML (`insert as user`, etc.) on side-effect DML. `with sharing` declared on every class. Bind variables in every SOQL.
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
| Service | `<Domain>Service` | `MachineAssetService`, `AssetQueryService` |
| Batch/Schedulable | `<Domain>Batch` | `PMSchedulerBatch` (planned) |
| Test class | Target class + `Test` | `MachineAssetServiceTest` |
| Method | camelCase, verb-first | `validateSerialNumbers()` |
| Boolean | `is`/`has`/`can`/`should` prefix | `isInsert`, `shouldCreate` |
| Constant | UPPER_SNAKE_CASE | `NIGHTLY_CRON` |

No abbreviations except universal ones (`Id`, `SLA`, `PM`, `WO`). Correct `__c` casing (lowercase c) even though Apex is case-insensitive.

### 4.2 Sharing — declared on EVERY class

- Every class MUST explicitly declare `with sharing`, `without sharing`, or `inherited sharing`.
- Default to `with sharing`. `without sharing` only with a documented reason in the class header.

### 4.3 Security — user-mode DML (the project's proven pattern)

- **Side-effect DML** (records created/updated on behalf of a user action) uses user-mode: `insert as user records;`
- Wrap in try/catch. **Catch `System.SecurityException` first** (proven: this is what fires for object-CRUD violations — see Decision D6), **then `DmlException`**.
- On failure, `addError()` on the *originating* records with a friendly message: what happened + why + what to do. Never raw exception dumps to users.
- Keep parallel lists when needed so the catch block knows which originating records to block.

### 4.4 SOQL — strict rules

- Bind variables ALWAYS. Never string concatenation in queries.
- No SOQL inside loops. Query once into a Map/Set before looping.
- Selective WHERE filters; `LIMIT` on any query that could return many rows.
- Only query fields you use. `ORDER BY` when order matters; remember `NULLS LAST` where nulls exist.
- Self-exclusion on update-context duplicate checks: `AND Id NOT IN :incomingIds`.

### 4.5 DML — strict rules

- No DML inside loops. Collect, then one DML after the loop.
- Bulk-safe for 1 or 200 records identically.
- `Database.insert(records, false)` + SaveResult checks where partial success is the right behavior (and in tests asserting failures).

### 4.6 Exception & error strategy

- User-facing failure → `addError()` with a friendly, specific message.
- System/background failure (batch jobs) → accumulate errors, log a summary, notify admin (email) in `finish()`. 
- Specific catches before general. No empty catch blocks — ever.
- Deliberately-uncovered defensive catches are acceptable **if documented** in the Decisions Log with the reason (see D7).

### 4.7 What is FORBIDDEN in Apex

- ❌ `System.debug()` in committed code.
- ❌ Hardcoded IDs, usernames, emails, URLs. Use queries / Custom Metadata.
- ❌ SOQL or DML inside `for` loops.
- ❌ Empty catch blocks.
- ❌ `@SeeAllData=true` in tests.
- ❌ Business logic inside triggers (triggers only delegate).
- ❌ String concatenation in SOQL.

---

## 5. Coding standards — Triggers (codified from what we built)

- **One trigger per object**, no logic inside — delegate to `<Object>TriggerHandler`.
- Flow: **Trigger → Handler → Service.** Always these three layers.
- **Validation** (addError on the records being saved) runs in **before** context — both `before insert` AND `before update` where applicable.
- **Side-effect DML** (creating/updating OTHER records) runs in **after** context — `after insert` and `after update`. Reason: the record is validated, committed, and has an Id. (Interview answer — own it.)
- `addError()` in after context rolls back the whole transaction — that is intended behavior for blocking saves.
- Current live pattern on `Machine_Asset__c`:
  - before insert: `prepareAssets` (defaults) + `validateSerialNumbers`
  - before update: `validateSerialNumbers`
  - after insert: `handleAssetUpdate(isInsert=true)`
  - after update: `handleAssetUpdate(isInsert=false)`

---

## 6. Coding standards — Tests (STRICT — learned the hard way)

- `Test.startTest()` / `Test.stopTest()` around the action under test.
- **Test data must satisfy ALL org constraints** — validation rules fire in tests. Current rules to respect:
  - Service_Ticket: High priority requires `Description__c`; Closed requires `Resolution_Notes__c`.
  - Machine_Asset: `Installation_Date__c` not in future; `Warranty_End__c >= Warranty_Start__c`.
- Positive AND negative tests for every feature. Bulk test (50–200 records) for trigger paths.
- Security tests: `System.runAs()` with a restricted-profile user. Remember: wrap User insert in `runAs(current user)` to avoid MIXED_DML; timestamp usernames for uniqueness.
- Assert order matters: assert the outcome (`isSuccess() == false`) BEFORE reading `getErrors()[0]`.
- Data-math discipline: before asserting a count, trace the setup data by hand. Wrong expected counts were our #1 test-bug source.
- When many tests fail at once → suspect `@TestSetup`. When one fails → suspect its own math. **Always read the actual error message first.**
- Coverage target: 90%+ per class, meaningful assertions. Coverage display resets when a class is saved — re-run tests before judging red lines.

---

## 7. Data model (current, real)

> Extend only via the Roadmap. Record schema decisions in the Decisions Log.

### Live objects

| Object | Relationship | Purpose |
|---|---|---|
| `Customer_Site__c` | Master | Physical location holding assets. Rollup: `Total_Installed_Assets__c` (count). |
| `Machine_Asset__c` | Master-Detail → Customer_Site__c | A machine being maintained. `Serial_Number__c` unique. |
| `Service_Ticket__c` | Lookup → Machine_Asset__c (SetNull) | A maintenance/repair task. Auto-named by Flow `Auto_Set_Service_Ticket_Name`. |

### Key field decisions (see Decisions Log)
- `Machine_Asset__c.Last_Maintenance_Date__c` → updated ONLY by **planned/PM** work. Drives `Next_Maintenance_Due__c` formula (blank-safe: `IF(ISBLANK(...), DATEVALUE(""), ... + 90)`).
- `Machine_Asset__c.Last_Service_Date__c` → updated by **any** completed work (PM or repair).
- `Warranty_Status__c` formula is blank-safe → "No Warranty Info" when `Warranty_End__c` is blank.
- `Service_Ticket__c.Status__c` includes `Open` (initial state for auto-created tickets).

### Planned (Phase 2 — PM Scheduler)

| Object | Relationship | Key fields |
|---|---|---|
| `PM_Schedule__c` | Lookup → Machine_Asset__c | `Frequency__c` (picklist), `Interval_Days__c` (number), `Last_Run__c` (datetime), `Next_Run__c` (formula date, blank-safe: blank = due today), `Active__c`, `Assigned_To__c` (User), `Description__c` |
| `PM_Alert__e` | Platform Event | Asset/Schedule ids + names, `Alert_Type__c`, `Triggered_At__c` |

PM-generated tickets are `Service_Ticket__c` with `Ticket_Type__c = 'Maintenance'`, `Status__c = 'Open'`, `Priority__c = 'Medium'` (keeps High-priority validation rule out of play).

---

## 8. Git workflow (STRICT)

- `main` — only stable, phase-complete code.
- One branch per phase (`phase-2-pm-scheduler`). Merge to `main` when the phase is 100% done.
- Commit format: `<type>: <present-tense description>` — types: `feat`, `fix`, `test`, `refactor`, `docs`, `chore`.
- Commit after every logical unit. Repo must be deployable at every commit. Retrieve org-side changes (`sf project retrieve start --source-dir force-app`) BEFORE committing — org and repo must never drift.

---

## 9. The Roadmap

### Phase 1 — Foundation hardening ✅ COMPLETE
- [x] Formula bugs fixed (`Next_Maintenance_Due__c`, `Warranty_Status__c` blank handling)
- [x] Date-fields decision made and documented (both kept, distinct roles)
- [x] `Open` status added; auto-tickets start as Open; test suite agreement restored
- [x] In-batch duplicate serial detection (`!set.add()` pattern) + test
- [x] Serial validation on update with self-exclusion (`Id NOT IN :incomingIds`)
- [x] Side-effect DML moved to after contexts; dead handler method removed
- [x] User-mode DML security (`insert as user`) + double catch + friendly errors
- [x] Restricted-user `runAs` security test — proves the block end-to-end
- [x] `with sharing` on all classes; casing cleanup; `ticket.Name` conflict resolved (Flow owns naming)
- [x] AssetQueryServiceTest fixed (validation-rule-compliant setup, corrected count/warranty data-math)
- [x] Suite green, ~94% overall coverage

### Phase 2 — PM Scheduler (CURRENT)
Goal: automated preventive maintenance — the differentiator.
- [ ] `PM_Schedule__c` object + fields (per Section 7)
- [ ] `PMSchedulerService` — query due schedules (Active, `Next_Run__c <= TODAY`), build Maintenance tickets in bulk, stamp `Last_Run__c`
- [ ] `PMSchedulerBatch` — implements `Database.Batchable` + `Schedulable`; nightly cron; duplicate-job guard; error summary + admin email in `finish()`
- [ ] `PM_Alert__e` platform event published on ticket creation
- [ ] On PM ticket close → update asset `Last_Maintenance_Date__c` (Flow or trigger — decide and record)
- [ ] Full tests: due/not-due/inactive schedules, bulk, batch execution, schedulable registration + dedupe
**Done when:** nightly job schedulable, tests green ≥90%, committed, README updated.

### Phase 3 — LWC Dashboard + SLA automation
- [ ] SLA via Custom Metadata (`SLA_Config__mdt`: tier → response/resolution hours) replacing hardcoded 48h
- [ ] Site link formula on ticket (`Machine_Asset__r.Customer_Site__c`) for site-level reporting
- [ ] `Is_Overdue__c` formula on ticket
- [ ] LWCs: asset health dashboard, ticket list + quick-create, PM schedule manager, overdue alert bar
- [ ] Permission sets: Admin / Technician / ReadOnly

### Phase 3.5 — Approved enhancements (build only after Phase 3)
- [ ] Flexible PM rule types (`Rule_Type__c`: Time-based / Usage-based first; Strategy pattern)
- [ ] Failure tracking: `Failure_Reason__c` + `Failure_Category__c` on ticket + failure report

### Phase 4 — Security scan + polish
- [ ] `sf scanner run` — fix all HIGH findings; final `System.debug` sweep; CSP audit on LWCs

### Phase 5 — README + demo + portfolio
- [ ] Full README (ERD, architecture, setup, roadmap) · demo data script · 3-min Loom demo · LinkedIn post · resume entry

---

## 10. Definition of "Done" (every task)

1. ✅ Follows Sections 4–6. 2. ✅ Deploys clean. 3. ✅ Meaningful tests, suite green. 4. ✅ No debug/hardcoding/dead code. 5. ✅ Headers + comments in place. 6. ✅ Org retrieved, committed with proper message. 7. ✅ Roadmap checkbox ticked + Progress Log updated. 8. ✅ Any decision recorded in Decisions Log.

---

## 11. When blocked (protocol)

1. Read the actual error message fully — first, always.
2. Reproduce minimally; check the Decisions Log and this file.
3. Timebox 30 minutes of investigation. Write down what was tried.
4. If still stuck: stop, note state in Progress Log, bring the exact error + attempts to the next Claude session. No thrash-coding.

---

## 12. Progress log (newest first)

- **[Session 4 — Foundation close-out]** Security runAs test added and passing; empirically confirmed `SecurityException` fires for user-mode object-CRUD violations (DmlException catch left deliberately uncovered — D7). Suite green, ~94% coverage. CLAUDE.md rewritten to v2 (this file). **Next:** Phase 2 — PM Scheduler.
- **[Session 3 — Test debugging]** AssetQueryServiceTest 8/8 failures root-caused: @TestSetup violated Service_Ticket validation rules (High-priority Description, Closed Resolution Notes); fixed. Corrected Test 2 count (2 open tickets) and Test 3 warranty data-math. Suite green.
- **[Session 2 — Foundation hardening]** Fixed formula blank-handling bugs; added `Open` status; in-batch duplicate detection; serial validation on update with self-exclusion; moved side-effect DML to after contexts; user-mode DML + double catch; casing cleanup; Flow owns ticket naming.
- **[Session 1 — Strategy]** Decided: evolve FieldOps 360 in place (no rename), rebrand to AssetCare Lite (folder, repo, app label only). Full project audit produced the bug list that became Phase 1.

---

## 13. Decisions log (why we did what we did)

- **D1 — Branding vs API names.** "AssetCare Lite" is branding (repo, folder, app label). API names stay `Customer_Site__c` / `Machine_Asset__c` / `Service_Ticket__c` because Salesforce cannot cleanly rename API names and recruiters don't care. The old `ACL_`-prefixed starter code is **obsolete as written** — reference only.
- **D2 — No namespace / no prefix.** Portfolio-first. If AppExchange packaging ever happens, namespace gets decided then; new components must NOT carry a manual prefix (avoids double-prefix trap).
- **D3 — Two date fields, two roles.** `Last_Maintenance_Date__c` = planned PM only (drives next-due). `Last_Service_Date__c` = any completed work. PM Scheduler will wire the updates.
- **D4 — Flow owns ticket naming.** `Auto_Set_Service_Ticket_Name` Flow sets Name; Apex must never set `ticket.Name`.
- **D5 — Side-effect DML in after context.** Validation in before; creation of other records in after (validated, committed, has Id). `addError` in after context intentionally rolls back the save.
- **D6 — Empirical: user-mode DML throws `System.SecurityException`** for missing object-level create permission (proven via restricted-user runAs test, Minimum Access profile). Catch order: SecurityException, then DmlException.
- **D7 — `DmlException` catch deliberately uncovered.** It guards validation-rule failures that cannot fire with hardcoded Medium/Open values; forcing coverage would pollute production code. Documented trade-off, defensible in review.
- **D8 — Ticket survives asset deletion.** Lookup with SetNull is intentional: service history is preserved.

---

## 14. Quick command reference

```bash
# Retrieve org changes into repo (BEFORE committing)
sf project retrieve start --source-dir force-app

# Deploy repo to org
sf project deploy start --source-dir force-app

# Run one test class / full suite with coverage
sf apex run test --class-names MachineAssetServiceTest --result-format human --code-coverage
sf apex run test --result-format human --code-coverage

# Static security analysis
sf scanner run --target force-app --category Security --format table
```

---

## 15. Final reminder

**This file is the law of this project.** Read it first, follow it always, update the logs as we go.
We are proving senior-level judgment on a zero budget: clean architecture, proven security, honest tests, documented decisions. Stay disciplined. Stick to the plan.
