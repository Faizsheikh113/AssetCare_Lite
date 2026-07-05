# HANDOFF — Current state of AssetCare Lite

> 60-second bridge for any fresh session. After this, read `CLAUDE.md` in full — it is the law.
> This file changes only at major milestones. Day-to-day state lives in CLAUDE.md Sections 12–13.

---

## What this project is

**AssetCare Lite** — preventive maintenance + asset tracking on Salesforce. Zero-budget portfolio project to land a Salesforce Developer job. It is the **same codebase as FieldOps 360, rebranded** — folder, repo, and app label renamed; **API names unchanged** (`Customer_Site__c`, `Machine_Asset__c`, `Service_Ticket__c`).

⚠️ **Obsolete artifact warning:** an earlier starter bundle contained `ACL_`-prefixed code (`ACL_PMSchedulerService`, `ACL_Asset__c`, etc.) built for a rename plan that was **cancelled** (CLAUDE.md Decision D1/D2). That code references objects that will never exist. Treat it as design reference only — do NOT deploy it. The PM Scheduler will be built fresh against real object names.

---

## Where we are

**Phase 1 (Foundation hardening) — COMPLETE.** Highlights:
- All known bugs fixed (formula blank-handling, status mismatch, in-batch duplicate serials, naming conflict).
- Security: `insert as user` on ticket auto-creation, SecurityException-first double catch, friendly addError messages — **proven** with a restricted-user `runAs` test.
- Trigger architecture corrected: validation in before insert+update; side-effect DML in after insert+update.
- Both test classes green; ~94% overall coverage; trigger/handler at 100%.

**Phase 2 (PM Scheduler) — CURRENT.** Design is locked in CLAUDE.md Sections 7 & 9:
- New `PM_Schedule__c` object (Lookup → `Machine_Asset__c`) with blank-safe `Next_Run__c` formula.
- `PMSchedulerService` + `PMSchedulerBatch` (Batchable + Schedulable, nightly, dedupe guard, admin error email).
- PM tickets = `Service_Ticket__c`, Type 'Maintenance', Status 'Open', Priority 'Medium'.
- On PM ticket close → update asset `Last_Maintenance_Date__c` (D3: the two-dates rule).
- `PM_Alert__e` platform event on creation.

---

## How to work here (short version)

- `CLAUDE.md` first, always. Naming matches existing style — **no prefixes**.
- Faiz writes the code for learning; guidance explains *what and why*, then reviews.
- Test data must satisfy the org's validation rules (High ticket → Description; Closed ticket → Resolution Notes).
- Retrieve org changes before every commit. Update Progress Log every session; Decisions Log on every decision.
