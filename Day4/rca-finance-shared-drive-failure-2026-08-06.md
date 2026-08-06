# Root Cause Analysis — Finance Shared Drive Access Failure
**Reference:** RCA-2026-08-06-FINANCE-DRIVE  
**Date of Incident:** 2026-08-06  
**Date of RCA:** 2026-08-06  
**Author:** DWP Engineer  
**Status:** Closed — Resolved 10:10

---

## Executive Summary

All 45 Finance team users lost access to shared drives from 08:00:03 on 2026-08-06. The failure was caused by an Intune-deployed PowerShell drive-mapping script (`Map-FinBridgeDrives.ps1`) executing under the SYSTEM account before the Windows Workstation service (LanmanWorkstation) had entered a running state. Without that service, SYSTEM context cannot resolve UNC network paths. The script had no retry logic and no failure handling, so all 45 users were left without mapped drives for the duration of the morning. The fault originated from a 2024-03-14 migration of the script from a GPO logon script (user context) to Intune (SYSTEM context) that was never tested in the new execution environment. Resolution was applied and verified by 10:10.

---

## Incident Details

| Field | Detail |
|---|---|
| Incident ID | INC-2026-08-06-FINANCE-DRIVE |
| Severity | High — 45 users impacted, business operations affected |
| Service Affected | Shared drive access (S:) — `\\finbridge-fs01\Finance` |
| Users Affected | All 45 Finance team users, devices `DESKTOP-FB*`, `OU=Finance` |
| Incident Start | 2026-08-06 08:00:03 |
| Incident End | 2026-08-06 10:10:00 |
| Total Duration | ~2 hours 10 minutes |
| Recorded Change | None |

---

## Timeline

| Time | Event |
|---|---|
| 2024-03-14 23:30 | Drive mapping script migrated from GPO logon script (USER context) to Intune PowerShell script (SYSTEM context). Script not updated to handle SYSTEM execution environment. **Latent defect introduced.** |
| 2026-08-06 08:00:01 | Intune ScriptRunner executes `Map-FinBridgeDrives.ps1` as SYSTEM on Finance devices |
| 08:00:02 | Script confirms execution context: SYSTEM account |
| 08:00:03 | ScriptRunner Warning — `\\finbridge-fs01\Finance` not accessible from SYSTEM context. Error: *"Network name cannot be found."* Script fails. Exit code: 1 |
| 08:00:04 | ScriptRunner confirms no retry configured — no recovery attempted |
| 08:00:05 | Workstation service (LanmanWorkstation) enters running state — **2 seconds after script already failed** (Event 7036) |
| 08:00:06 | Group Policy processes successfully — confirms AD/Kerberos healthy (Event 1500) |
| 08:00:07 | NTFS Event 98 — drive letter S: not assigned |
| 08:00 onwards | 45 Finance users log on and find S: drive unavailable. Tickets raised. |
| ~08:15 | Incident declared. Triage begins. |
| ~08:30 | Event log evidence collected from DESKTOP-FB041 and Intune Management Extension logs |
| ~09:00 | Five hypotheses assessed against evidence. H1–H3, H5 contradicted. H4 neutral. |
| ~09:30 | Root cause confirmed: SYSTEM context race condition with LanmanWorkstation service. 2024-03-14 migration identified as origin. |
| ~09:45 | Resolution applied — Intune script assignment changed to run as logged-on user context. Policy pushed to all Finance devices. |
| 10:10 | Resolution verified — affected user successfully connected to `\\finbridge-fs01\Finance`. S: drive mapped. No further reports. |
| 10:10 | Incident closed. |

---

## Supporting Evidence

### Intune Management Extension Log — DESKTOP-FB041

```
[08:00:01]  ScriptRunner  Info     Executing: Map-FinBridgeDrives.ps1
[08:00:02]  ScriptRunner  Info     Script context: SYSTEM account
[08:00:03]  ScriptRunner  Warning  Network path \\finbridge-fs01\Finance
                                   not accessible from SYSTEM context at execution time
[08:00:03]  ScriptRunner  Error    Script Map-FinBridgeDrives.ps1 failed.
                                   Exit code: 1. Error: Network name cannot be found.
[08:00:04]  ScriptRunner  Info     No retry configured.
```

### System Event Log — DESKTOP-FB041

```
08:00:05  Service Control Manager  Event 7036  — Workstation service entered running state.
08:00:06  GroupPolicy              Event 1500  — Group Policy settings processed successfully.
08:00:07  Ntfs                     Event 98    — File system could not map drive letter S:
                                                 Drive letter has not been assigned.
```

### Key Observation
The Workstation service (Event 7036, `08:00:05`) entered running state **2 seconds after** the script had already failed (`08:00:03`). UNC path resolution from SYSTEM context requires LanmanWorkstation to be active. The 2-second gap was sufficient to cause the failure on every Finance device simultaneously.

### Prior Change Record
> **2024-03-14 23:30** — Drive mapping script migrated from GPO logon script (runs as USER) to Intune PowerShell script (runs as SYSTEM). Script not updated to handle SYSTEM context — network paths via UNC require the Workstation service and mapped credentials which are not available to SYSTEM at login time.

---

## Hypothesis Assessment Summary

All five initial hypotheses were assessed against the event log evidence before the root cause was confirmed.

| # | Hypothesis | Verdict | Reason |
|---|---|---|---|
| 1 | File Server / DFS Service Failure | Contradicts | ScriptRunner 08:00:03 explicitly scopes failure to SYSTEM context, not server unavailability; Event 7036 shows Workstation service recovered normally |
| 2 | Kerberos / Netlogon Failure | Contradicts | Event 1500 08:00:06 — GP applied successfully; Kerberos must be functional for GP to process |
| 3 | Security Group Membership Removed | Contradicts | Error is *"Network name cannot be found"* — permissions are never tested; Access Denied would indicate a permissions boundary |
| 4 | DNS Resolution Failure | Neutral — root cause beneath | No DNS event present; error resembles DNS failure but is caused by Workstation service not running; H4 was the surviving hypothesis |
| 5 | GPO / Logon Script Broken | Contradicts | Event 1500 08:00:06 — GP healthy; drive mapping no longer GPO-owned since 2024-03-14 migration |

---

## Five Why Analysis

| Step | Why |
|---|---|
| **Why 1** | Why could Finance users not access shared drives? — Because drive letter S: was never mapped at logon (NTFS Event 98, 08:00:07) |
| **Why 2** | Why was S: not mapped? — Because `Map-FinBridgeDrives.ps1` failed with exit code 1 at 08:00:03; no retry ran |
| **Why 3** | Why did the script fail? — Because it ran as SYSTEM at 08:00:01, before the Workstation service was running (08:00:05); SYSTEM cannot resolve UNC paths without LanmanWorkstation |
| **Why 4** | Why was the script running as SYSTEM before the Workstation service was ready? — Because the script was migrated to Intune in March 2024 and Intune runs device-context scripts as SYSTEM early in the boot sequence, before user-session services initialise |
| **Why 5** | Why was the script not updated or tested for the new execution context? — Because the migration change on 2024-03-14 did not include a test plan for SYSTEM-context execution, no acceptance criteria covered UNC path resolution under SYSTEM, and the latent defect was not detected until a triggering condition exposed it in production |

**Root cause statement:** A 2024 script migration introduced a latent defect by deploying a UNC-dependent drive mapping script in SYSTEM context without validating that the required Workstation service would be running at execution time. No retry or failure handling was added to detect or recover from the condition.

---

## Resolution Applied

**Action taken:** Intune script assignment for `Map-FinBridgeDrives.ps1` changed from **SYSTEM context** to **logged-on user context** (Run this script using the logged on credentials → Yes).

**Why this works:** Running as the logged-on user occurs after the full user session is established — the Workstation service is running, user credentials are available, and UNC paths resolve correctly. This restores behaviour equivalent to the original GPO logon script.

**Verified:** 10:10 — affected Finance user confirmed successful connection to `\\finbridge-fs01\Finance`. Drive S: mapped. No further incidents reported.

---

## Preventive Actions

| # | Action | Owner | Priority |
|---|---|---|---|
| 1 | **Add execution context to script deployment standards** — any Intune PowerShell script using UNC paths, mapped drives, or network resources must be assigned logged-on user context, or must include an explicit Workstation service readiness check before attempting network calls | Endpoint Engineering Lead | High |
| 2 | **Add retry and alerting to `Map-FinBridgeDrives.ps1`** — implement minimum 2 retries with a 15-second delay; on final failure write to Windows Event Log with a custom source so monitoring can detect drive mapping failures across the estate | Endpoint Engineer | High |
| 3 | **Create a test checklist for Intune script migrations** — any script migrated from GPO/user context to Intune must be tested under SYSTEM context in a non-production OU, specifically validating network path resolution, credential availability, and service dependencies | Change Management / Endpoint Engineering | Medium |
| 4 | **Audit remaining Intune scripts for SYSTEM context UNC usage** — review all PowerShell scripts currently deployed via Intune as SYSTEM; identify any that reference UNC paths or mapped drives without a Workstation service check | Endpoint Engineer | Medium |
| 5 | **Add a known error record** — document this failure pattern in the known-error database: *"Intune SYSTEM-context scripts that reference UNC paths will fail if the Workstation service (LanmanWorkstation) has not yet entered running state at execution time."* | Service Desk / Problem Management | Low |

---

## Lessons Learned

- A "no change" response during initial scoping does not rule out a latent defect introduced by a previous change. The 2024-03-14 migration was not visible in any recent change log.
- The exact 08:00:03 timestamp was a strong signal pointing to an automated process rather than a user action. Following that signal shortened triage significantly.
- Evidence-based elimination of hypotheses prevented premature commitment to a server-side cause (H1) that would have directed effort to the wrong team.
- The error message *"Network name cannot be found"* is ambiguous — it can indicate DNS failure, server unavailability, or a missing service dependency. Context (SYSTEM account, boot timing) was required to distinguish between them.
