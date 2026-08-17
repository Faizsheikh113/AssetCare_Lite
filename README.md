<h1 align="center">🛠️ AssetCare Lite</h1>

<p align="center">
  <b>Lightweight Preventive Maintenance & Asset Tracking for Salesforce SMBs</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white"/>
  <img src="https://img.shields.io/badge/Apex-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white"/>
  <img src="https://img.shields.io/badge/Status-Phase_2_In_Progress-orange?style=for-the-badge"/>
</p>

---

## 📌 Overview

**AssetCare Lite** is a personal Salesforce portfolio project built to demonstrate
real-world Apex development skill — no Field Service license required.

It tracks customer sites, the machines installed at them, the service tickets
raised against those machines, and a recurring preventive-maintenance (PM)
schedule that automatically opens maintenance tickets before things break.

> Built by a **Salesforce Certified Platform Developer I & Administrator**
> to prove senior-level judgment on a zero-budget portfolio project: clean
> architecture, proven security, honest tests, documented decisions.

*(Note: this project was originally built and committed under the name
"FieldOps 360." The rebrand to AssetCare Lite is branding only — no API
names changed. See `CLAUDE.md` Decision D1.)*

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Backend Logic** | Apex Triggers, Apex Classes, Trigger Handler pattern |
| **Testing** | Apex test classes, 90%+ coverage target |
| **Database** | SOQL, bulk-safe DML, user-mode DML (`AccessLevel.USER_MODE`) |
| **Deployment** | Salesforce DX (SFDX / `sf` CLI) |
| **Version control** | Git + GitHub (public) |

---

## 📦 Modules

### ✅ Asset & Site Management (Phase 1 — Complete)
- `Customer_Site__c` — physical locations, with a rollup of installed assets
- `Machine_Asset__c` — machines, master-detail to a site, unique serial numbers
- `MachineAssetTrigger` → `MachineAssetTriggerHandler` → `MachineAssetService`
  (clean 3-layer trigger architecture)
- User-mode DML proven secure with a restricted-profile `runAs()` test

### ✅ Service Ticket Tracking (Phase 1 — Complete)
- `Service_Ticket__c` — maintenance/repair tasks, linked to a machine
  (lookup is now **required**, delete constraint `Restrict`)
- Validation rules: High-priority tickets need a description; closed tickets
  need resolution notes
- Ticket naming owned entirely by Flow (`Auto_Set_Service_Ticket_Name`) —
  Apex never sets `ticket.Name`

### 🔄 PM Scheduler (Phase 2 — In Progress, ~85%)
- `PM_Schedule__c` — a recurring maintenance rule per machine, with a
  blank-safe `Next_Run__c` formula (new schedules run on their first night)
- `PMSchedulerService.processDueSchedules()` — queries due schedules, builds
  Maintenance tickets, does a **partial-success insert** so one bad record
  never blocks the other 199, and stamps `Last_Run__c` only on success
  (failed schedules retry automatically the next night)
- `PMSchedulerBatch` (`Schedulable`) — the nightly trigger; emails the admin
  only when something fails (silence = success)
- `PMSchedulerServiceTest` — 6 tests covering due/not-due/inactive/bulk/
  partial-failure/empty-queue paths
- **Still open:** register the nightly cron job, write `PMSchedulerBatch`
  tests, wire ticket-close → `Last_Maintenance_Date__c`, optional
  `PM_Alert__e` platform event

### ⬜ LWC Dashboard + SLA Automation (Phase 3 — Planned)
- Asset health dashboard, ticket list + quick-create, PM schedule manager
- SLA tiers via Custom Metadata, `Is_Overdue__c` formula

---

## 🗂️ Project Structure

```
AssetCare_Lite/
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/
│           │   ├── MachineAssetService.cls
│           │   ├── MachineAssetTriggerHandler.cls
│           │   ├── AssetQueryService.cls
│           │   ├── PMSchedulerService.cls
│           │   ├── PMSchedulerBatch.cls
│           │   └── *Test.cls
│           ├── triggers/
│           │   └── MachineAssetTrigger.trigger
│           ├── objects/
│           │   ├── Customer_Site__c/
│           │   ├── Machine_Asset__c/
│           │   ├── Service_Ticket__c/
│           │   └── PM_Schedule__c/
│           └── flows/
│               └── Auto_Set_Service_Ticket_Name.flow-meta.xml
├── config/
│   └── project-scratch-def.json
└── sfdx-project.json
```

---

## 🚀 Deployment Guide

### Prerequisites
- Salesforce CLI (`sf`) installed
- Developer org or Sandbox access

### Steps

```bash
# Step 1 — Authenticate to your org
sf org login web --alias AssetCareLiteOrg

# Step 2 — Deploy source to the org
sf project deploy start --source-dir force-app

# Step 3 — Run all test classes with coverage
sf apex run test --result-format human --code-coverage

# Step 4 — Open the org
sf org open
```

---

## 📊 Development Status

| Phase | Status | Notes |
|---|---|---|
| Phase 1 — Foundation hardening | ✅ Complete | ~94% coverage, security proven via `runAs` |
| Phase 2 — PM Scheduler | 🔄 In Progress (~85%) | Service + batch + service tests done; cron, batch tests, D3 wiring pending |
| Phase 3 — LWC Dashboard + SLA | ⬜ Planned | — |
| Phase 3.6 — Approval Process, Email Alerts, Named Credential + API callout | ⬜ Planned (later) | Not started — queued after Phase 3 |
| Phase 4 — Security scan + polish | ⬜ Planned | — |
| Phase 5 — Demo + portfolio polish | ⬜ Planned | — |

> 🚧 **This project is a work in progress, built in public.** Every commit is real, day-to-day
> progress — nothing here is staged or faked. Follow along in the
> [commit history](https://github.com/Faizsheikh113/AssetCare_Lite/commits/main) to see it
> grow phase by phase.

---

## 🏆 Key Salesforce Concepts Demonstrated

- ✅ Trigger → Handler → Service architecture (no logic in triggers)
- ✅ User-mode DML with proven `System.SecurityException` handling
- ✅ Partial-success DML pattern (`Database.insert(..., false, AccessLevel.USER_MODE)`)
- ✅ Bulk-safe Apex (no SOQL/DML in loops), proven with a 5-record bulk test
- ✅ Meaningful test classes — positive, negative, and bulk cases
- ✅ Every design decision documented and justified (see `CLAUDE.md`)

---

## 👨‍💻 Author

**Faiz Sheikh**
Salesforce Certified Platform Developer I & Administrator

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat&logo=linkedin&logoColor=white)](https://linkedin.com/in/faizsheikh113)
[![Trailhead](https://img.shields.io/badge/Trailhead-00A1E0?style=flat&logo=salesforce&logoColor=white)](https://salesforce.com/trailblazer/uyxif8ind5vuhely5f)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat&logo=github&logoColor=white)](https://github.com/Faizsheikh113)

📧 faizsheikh113@gmail.com
