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

**Phase 2 (PM Scheduler) — IN PROGRESS, ~85% done.**

Built (Faiz wrote the code himself, guided step by step):
1. **`PM_Schedule__c` object** — Interval_Days drives the math; `Next_Run__c` formula: blank Last_Run = due TODAY (new schedules run on first night).
2. **`PMSchedulerService.processDueSchedules()`** — the "brain". Queries due schedules (Active, Next_Run <= TODAY, LIMIT 200) → builds Maintenance tickets (Type='Maintenance', Status='Open', Priority='Medium' — Medium avoids the High-priority validation rule) → **partial-success insert** `Database.insert(tickets, false, AccessLevel.USER_MODE)` → SaveResult loop by index → **stamps `Last_Run__c` ONLY on winners** (D9 — losers stay due and retry automatically tomorrow) → losers reported into returned `List<String>` errors. The duplicate-declaration compile bug is **fixed and committed** (`e80ec84`).
3. **`PMSchedulerBatch` (implements `Schedulable`)** — the "alarm clock". Calls the brain; if errors exist, emails the admin (queried by profile, never hardcoded). Silence = success (D11).
4. **`PMSchedulerServiceTest`** — 6 tests, committed: due→ticket+stamp, recently-run→nothing, inactive→nothing, bulk (5 schedules), partial DML failure, empty-queue path.
5. **`Service_Ticket__c.Machine_Asset__c` made required** — ⚠️ side effect: forced the delete constraint from `SetNull` to `Restrict`. Reverses D8 ("ticket survives asset deletion"). Logged as **D12** in CLAUDE.md — needs Faiz's confirmation this was intentional.

## Immediate next steps (in order) — for finishing Phase 2

1. **Register the nightly job** (Anonymous Apex, run once):
   `System.schedule('PM Scheduler - Nightly', '0 0 2 * * ?', new PMSchedulerBatch());`
   ⚠️ **Owed to Faiz:** a simple explanation of the cron expression `'0 0 2 * * ?'` — promised, not yet given.
2. **Write `PMSchedulerBatchTest`** — service has tests, batch doesn't. Need: Schedulable `execute()` path, and the admin-email path when errors exist.
3. **Confirm D12** — was making `Machine_Asset__c` required (and the resulting switch to `Restrict`) intentional? If yes, formally retire D8.
4. Wire D3: Maintenance ticket close → update asset `Last_Maintenance_Date__c` (decide Flow vs trigger, record decision).

**Phase 2 done-when:** all 4 above complete, tests green ≥90%, committed.

## What's queued next (Phase 3, approved but not started)

- **Point 1 — Flow:** SLA-breach escalation, Record-Triggered Flow (this replaces the Process Builder idea — PB is retired, can't create new ones since 2023).
- **Point 2 — Platform Event + LWC + Aura:** `PM_Alert__e` fires after 2+ consecutive failed nights; one LWC subscribes via `empApi`; that same alert gets wrapped in one thin Aura component (`c:overdueAlertAura`) — realistic Aura-calls-LWC pattern, not a second app. Plus one Report + Dashboard on `Service_Ticket__c`.
- Original Phase 3 scope unchanged: SLA Custom Metadata, `Is_Overdue__c` formula, asset health dashboard, ticket list, PM schedule manager, permission sets.

## Queued for later (Phase 3.6 — after Phase 3, not started)

- Approval Process (Admin skill, no code)
- Email Alerts / Templates (ties into the Phase 3 SLA Flow)
- Named Credential + one free external API callout

**Open thread:** Faiz said he "has a plan in mind" and never told us what it is. **Ask him!** 😄 (Possibly the required-field change was it — worth asking directly.)

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