# HANDOFF — Current state of AssetCare Lite

> 60-second bridge for any fresh session (new chat or Claude Code). After this, read `CLAUDE.md` in full — it is the law.
> This file changes only at milestones. Day-to-day state lives in CLAUDE.md Sections 12–13.

---

## What this project is

**AssetCare Lite** — preventive maintenance + asset tracking on Salesforce. Zero-budget portfolio project to land a Salesforce Developer job. It is the **same codebase as FieldOps 360, rebranded** — folder, repo, and app label renamed; **API names unchanged** (`Customer_Site__c`, `Machine_Asset__c`, `Service_Ticket__c`, `PM_Schedule__c`).

⚠️ **Obsolete artifact warning:** an old starter bundle contained `ACL_`-prefixed code (`ACL_PMSchedulerService`, `ACL_Asset__c`, etc.) from a cancelled rename plan (Decisions D1/D2). Never deploy it. Reference only.

---

## Where we are

**Phase 1 (Foundation hardening) — ✅ COMPLETE.** All bugs fixed. Security proven with a restricted-user `runAs` test (user-mode DML throws `SecurityException` — D6). Suite green, ~94% coverage.

**Phase 2 (PM Scheduler) — IN PROGRESS, ~70% done.**

Built (Faiz wrote the code himself, guided step by step):
1. **`PM_Schedule__c` object** — Interval_Days drives the math; `Next_Run__c` formula: blank Last_Run = due TODAY (new schedules run on first night).
2. **`PMSchedulerService.processDueSchedules()`** — the "brain". Queries due schedules (Active, Next_Run <= TODAY, LIMIT 200) → builds Maintenance tickets (Type='Maintenance', Status='Open', Priority='Medium' — Medium avoids the High-priority validation rule) → **partial-success insert** `Database.insert(tickets, false, AccessLevel.USER_MODE)` → SaveResult loop by index → **stamps `Last_Run__c` ONLY on winners** (D9 — losers stay due and retry automatically tomorrow) → losers reported into returned `List<String>` errors.
3. **`PMSchedulerBatch` (implements `Schedulable`)** — the "alarm clock". Calls the brain; if errors exist, emails the admin (queried by profile, never hardcoded). Silence = success (D11).

## Immediate next steps (in order)

1. **Verify the last fix is deployed + committed.** Last known issue: a duplicated `List<PM_Schedule__c> schedulesToStamp` declaration in the service (compile error). Fix was instructed. Also optional renames: `activeschedules` → `activeSchedules`, `serviceTicket` → `serviceTickets`.
2. **Register the nightly job** (Anonymous Apex, run once):
   `System.schedule('PM Scheduler - Nightly', '0 0 2 * * ?', new PMSchedulerBatch());`
   ⚠️ **Owed to Faiz:** a simple explanation of the cron expression `'0 0 2 * * ?'` — promised, not yet given.
3. **Write tests** for service + batch: due → ticket + stamp; not-due → nothing; inactive → nothing; bulk (50); Schedulable execute path; email path.
4. Wire D3: Maintenance ticket close → update asset `Last_Maintenance_Date__c` (decide Flow vs trigger, record decision).
5. Optional stretch: `PM_Alert__e` platform event.

**Open thread:** Faiz said he "has a plan in mind" and never told us what it is. **Ask him!** 😄

---

## How to work with Faiz (important — read this)

- **Faiz writes ALL the code himself. This is a learning project.** Explain WHAT to build and WHY, give patterns/skeletons, then review his code. Do not write full solutions for him unless he is stuck after trying.
- **Reviews = numbered checklists.** He sometimes fixes "most" points, not all — push for ALL, checklist style (read → fix → tick).
- **Ask design questions BEFORE giving code, and WAIT for his answer.** (Example: the Option A/B stamp question — took 4 asks, but his answer was right and it stuck.) His own reasoning is the goal.
- **Simple English only. Short sentences. No idioms, no hard words.** He finds complex English difficult.
- **English check:** at the end of every reply where his message has mistakes, add a short "✍️ English check" — corrected sentence + 1–3 simple notes. Friendly, never a lecture.
- Common recurring fixes: capital "I", two thoughts = two sentences, no space before "?".

## Key gotchas (learned the hard way)

- Validation rules fire in tests: High ticket → needs `Description__c`; Closed ticket → needs `Resolution_Notes__c`.
- If a field is used in code, it MUST be in the SOQL SELECT list.
- Retrieve org changes BEFORE every commit — org and repo must never drift.
- `addError()` only in trigger context; background jobs return `List<String>` errors instead.
- Apex memory dies when a run ends — anything that must survive lives in the database (that's why unstamped schedules ARE the retry queue).