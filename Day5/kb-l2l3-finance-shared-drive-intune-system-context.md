| Field | Detail |
|---|---|
| **Version** | 1.0 |
| **Date** | 07/08/2026 |
| **Status** | Draft |

---

# KB Article — Finance Shared Drive Access Failure (Intune SYSTEM Context Race Condition)

**KB ID:** KB-L2L3-2026-08-06-FINANCE-DRIVE  
**Applies To:** Finance devices (`DESKTOP-FB*`), `OU=Finance`, drive letter `S:`, UNC path `\\finbridge-fs01\Finance`  
**Incident Reference:** INC-2026-08-06-FINANCE-DRIVE  
**RCA Reference:** RCA-2026-08-06-FINANCE-DRIVE  
**Runbook Reference:** RB-2026-08-06-FINANCE-DRIVE

---

## 1. Background

Finance team devices use a PowerShell script — `Map-FinBridgeDrives.ps1` — to map the shared Finance drive (`S:`) to `\\finbridge-fs01\Finance` at logon. This drive is the primary shared working location for all 45 Finance team members. Without it, users cannot access shared spreadsheets, reports, or finance data stored centrally.

The script is deployed via **Microsoft Intune** as a Platform Script. Intune Platform Scripts run under the **SYSTEM account** by default, early in the boot sequence — before the Windows session is fully established for the logged-on user.

UNC path resolution from the SYSTEM account requires the **Windows Workstation service** (`LanmanWorkstation`) to be in a running state. This service starts during the boot sequence but is not guaranteed to be running at the exact moment Intune executes the script.

This script was originally a **GPO logon script** that ran in the **user context** — after the full user session was established, when LanmanWorkstation was already running. It was migrated to Intune on **2024-03-14** without being updated to handle the SYSTEM execution environment, introducing a latent defect that was not detected until it manifested in production on 2026-08-06.

---

## 2. Symptoms

### What users report
- S: drive is missing after signing in
- Attempts to open Finance shared folders fail with no drive letter visible in File Explorer
- No error message shown to the user — the drive simply does not appear

### What the engineer observes
- Affects **all** Finance devices simultaneously, not individual users
- Failure occurs at a consistent time tied to the logon/boot sequence (08:00 in the original incident)
- No recent change visible in the change log — this is a latent defect, not a triggered change
- Tickets raised in volume from a single team within minutes of each other
- Manually mapping the drive (`net use S: \\finbridge-fs01\Finance`) works when run in the **user's own PowerShell session**, confirming the file server and permissions are healthy

---

## 3. Root Cause

**Root cause statement:** `Map-FinBridgeDrives.ps1` is deployed via Intune as a SYSTEM-context script. When Intune executes it at boot, the Windows Workstation service (`LanmanWorkstation`) has not yet entered a running state. SYSTEM cannot resolve UNC paths without LanmanWorkstation. The script has no retry logic and no failure handling, so the failure is permanent for that logon session.

### Race condition detail

| Event | Timestamp | Source |
|---|---|---|
| Intune executes `Map-FinBridgeDrives.ps1` as SYSTEM | 08:00:01 | IME log |
| Script confirms SYSTEM context | 08:00:02 | IME log |
| Script fails — `\\finbridge-fs01\Finance` not accessible | 08:00:03 | IME log |
| No retry configured — recovery abandoned | 08:00:04 | IME log |
| Workstation service (`LanmanWorkstation`) enters running state | 08:00:05 | Event 7036 |
| Group Policy processes successfully | 08:00:06 | Event 1500 |
| NTFS confirms S: not assigned | 08:00:07 | Event 98 |

The Workstation service was running **2 seconds after** the script already failed. Any device where this 2-second window occurs will silently lose the S: drive for the entire logon session.

### Why the error message is misleading
The error `"Network name cannot be found"` is ambiguous — it is the same error produced by DNS failure or server unavailability. In this case it is caused specifically by the absence of the Workstation service at execution time. Context (SYSTEM account, boot timing) is required to distinguish between these causes — see Section 4.

### Origin of the defect
The 2024-03-14 migration from GPO logon script (user context) to Intune Platform Script (SYSTEM context) did not include a test plan for SYSTEM-context execution, no acceptance criteria covered UNC path resolution under SYSTEM, and no retry or fallback logic was added. The defect remained dormant until execution timing on affected devices created the gap.

---

## 4. Detection

Work through each check in order. All three must be confirmed before applying the fix.

---

### Check 1 — Intune Management Extension log (confirms SYSTEM context and script failure)

**Log location:** `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`  
**Access:** Requires local admin on the affected device, or Intune remote shell session  
**Tool:** Notepad, VS Code, or PowerShell: `Select-String -Path "<path>" -Pattern "Map-FinBridgeDrives"`

**What to look for — all four lines must be present:**

```
ScriptRunner  Info     Executing: Map-FinBridgeDrives.ps1
ScriptRunner  Info     Script context: SYSTEM account        ← confirms SYSTEM, not user
ScriptRunner  Warning  Network path \\finbridge-fs01\Finance
                       not accessible from SYSTEM context at execution time
ScriptRunner  Error    Script Map-FinBridgeDrives.ps1 failed.
                       Exit code: 1. Error: Network name cannot be found.
ScriptRunner  Info     No retry configured.
```

**Critical field:** `Script context: SYSTEM account` — if this line reads anything other than SYSTEM, this KB does not apply.  
**Note the exact timestamp** on the `ScriptRunner Error` line. You will compare this against Check 2.

---

### Check 2 — Windows System Event Log (confirms Workstation service start timing)

**Log location:** Windows Event Viewer → **Windows Logs → System**  
**Access:** Requires local admin or Event Log Readers group membership  
**Tool:** `eventvwr.msc` → Filter Current Log → Event ID: `7036`, Source: `Service Control Manager`

**What to look for:**

```
Event ID:   7036
Source:     Service Control Manager
Level:      Information
Message:    The Workstation service entered the running state.
```

**Critical comparison:** The timestamp of Event 7036 must be **later** than the `ScriptRunner Error` timestamp from Check 1. Even a 1-second gap is sufficient to cause the failure. If Event 7036 is *earlier* than the script error, this is not the race condition — re-triage.

---

### Check 3 — Windows System Event Log (confirms drive letter never assigned)

**Log location:** Windows Event Viewer → **Windows Logs → System**  
**Tool:** `eventvwr.msc` → Filter Current Log → Event ID: `98`, Source: `Ntfs`

**What to look for:**

```
Event ID:   98
Source:     Ntfs
Level:      Warning
Message:    File system could not map drive letter S:
            Drive letter has not been assigned.
```

**This confirms** the drive was never mapped — the script failure is the cause, not a mid-session disconnection.

---

### Comparison matrix — confirming vs. ruling out similar causes

| Candidate cause | Expected evidence if true | Evidence in this incident | Verdict |
|---|---|---|---|
| File server / DFS failure | IME log error scoped to server unreachable; Event 7036 would not resolve it | IME log explicitly scopes to SYSTEM context; Event 7036 shows Workstation recovered normally | Contradicts |
| Kerberos / Netlogon failure | Event 1500 absent or error; `net use` would also fail for the user | Event 1500 present (GP applied successfully); `net use` works in user session | Contradicts |
| Security group membership removed | Error would be `Access Denied` or `5: Access is denied` | Error is `"Network name cannot be found"` — permissions never tested | Contradicts |
| DNS resolution failure | DNS event errors in System log; `nslookup finbridge-fs01` fails | No DNS events; `nslookup` resolves correctly; root cause is beneath the DNS layer | Ruled out by Check 1 context field |
| GPO / logon script broken | Event 1500 absent or error | Event 1500 present; drive mapping no longer GPO-owned since 2024-03-14 | Contradicts |

---

### ⚠️ Stop gate

If Checks 1, 2, and 3 are **not all confirmed**, do not proceed with the resolution below. Re-triage using the comparison matrix above. Escalate to Endpoint Engineering Lead if the cause remains unclear.

---

## 5. Resolution

⚠️ **Steps R6–R10 require Entra ID role: Intune Administrator or Endpoint Manager Administrator.**

---

**R1.** Sign in to the Microsoft Intune admin centre at `https://intune.microsoft.com` using your admin credentials.

> Expected: Admin centre dashboard loads. Confirm your account shows the Intune Administrator role under your profile.

---

**R2.** In the left navigation pane, click **Devices**. Under the **Manage devices** section, click **Scripts and remediations**, then click **Platform scripts**.

> Expected: A table of all deployed PowerShell Platform Scripts is displayed.

---

**R3.** Locate and click **`Map-FinBridgeDrives.ps1`** in the script list.

> Expected: The script overview page opens showing Name, Description, Script settings, and Assignments tabs.

---

**R4.** Click the **Properties** tab, then click **Edit** in the **Script settings** section. Locate the field labelled **"Run this script using the logged on credentials"**. Confirm the current value is **No**. Change it to **Yes**.

> Expected: The field now shows **Yes**. Do not change any other field.

---

**R5.** Click **Review + save**, review that only the execution context field has changed, then click **Save**.

> Expected: The Properties page reloads and shows **"Run this script using the logged on credentials: Yes"**. A confirmation banner is displayed.

---

**R6.** Click the **Assignments** tab. Confirm the Finance devices group (e.g. `SG-Finance-Devices`) is still listed under **Included groups**. Do not modify the assignment scope.

> Expected: Assignment scope is unchanged. Finance devices remain targeted.

---

**R7.** To force immediate re-execution without waiting for the next Intune check-in cycle, on an affected device open an elevated PowerShell session and run:

```powershell
Start-Process "C:\Program Files (x86)\Microsoft Intune Management Extension\AgentExecutor.exe"
```

Alternatively, ask the affected user to sign out and sign back in. The Intune agent will re-execute the script on the next logon.

> Expected: The Intune Management Extension log shows a new execution of `Map-FinBridgeDrives.ps1` with `Script context: logged-on user` and exit code 0 within 1–2 minutes of logon.

---

## 6. Verification

All four checks must pass before marking the incident resolved.

**V1.** Ask the reporting user (or use a test Finance account on a Finance device) to sign out and sign back in.  
> Expected: S: drive appears in File Explorer mapped to `\\finbridge-fs01\Finance`. User can browse and open files.

**V2.** Open `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` on the same device. Find the most recent `Map-FinBridgeDrives.ps1` entry.  
> Expected: Log shows `Script context: logged-on user` (not SYSTEM), exit code 0, no Warning or Error lines.

**V3.** Open Event Viewer → **Windows Logs → System**. Filter for **Event ID 98**, source **Ntfs**, within the post-fix window.  
> Expected: No new Event 98 for drive letter S: after the fix was applied.

**V4.** Confirm with at least two additional Finance users on different `DESKTOP-FB*` devices that S: is accessible.  
> Expected: Both users confirm access. No new tickets raised from the Finance team.

---

## 7. Rollback

Use immediately if: the fix is applied and S: drive is still not mapping, or a new failure pattern appears.

**Rollback R1.** Sign in to `https://intune.microsoft.com` with Intune Administrator credentials.  
⚠️ Requires Intune Administrator role.

**Rollback R2.** Navigate to **Devices → Scripts and remediations → Platform scripts → `Map-FinBridgeDrives.ps1` → Properties → Edit → Script settings**.  
Change **"Run this script using the logged on credentials"** from **Yes** back to **No**. Click **Review + save → Save**.  
> Expected: Properties page confirms the field is back to **No**. This exactly restores the pre-fix state.

**Rollback R3.** Click **Assignments**. Confirm Finance devices group is still listed under **Included groups**.  
> Expected: Assignment scope is unchanged.

**Rollback R4.** Ask an affected user to sign out and sign back in.  
> Expected: S: drive will still not map — this is expected, as reverting to SYSTEM context restores the failure mode. This confirms rollback has not introduced any new failure. Do not attempt further changes without escalating.

**Rollback R5.** Escalate to Endpoint Engineering Lead. While escalation is in progress, provide a temporary workaround to affected users by running the following in the user's own PowerShell session (not elevated):

```powershell
net use S: \\finbridge-fs01\Finance /persistent:no
```

> Expected: S: maps for the current session only. Warn users this will not survive a reboot. This is a workaround, not a fix.

---

## 8. Preventive Actions

These are specific changes to process and tooling, not general guidance.

| # | Action | Specific change required | Owner | Priority |
|---|---|---|---|---|
| 1 | **Intune script deployment standard** | Add a mandatory field to the Intune script deployment request form: *"Does this script reference UNC paths, mapped drives, or network resources?"* If Yes, the execution context must be set to logged-on user, or the script must include an explicit `Get-Service LanmanWorkstation` readiness check with a retry loop before any `net use` or UNC call | Endpoint Engineering Lead | High |
| 2 | **Add retry logic to `Map-FinBridgeDrives.ps1`** | Implement a `do/while` retry loop: minimum 2 retries, 15-second delay between attempts. On final failure, write a custom Windows Event Log entry using `Write-EventLog` with Source `DWP-DriveMap`, Event ID `9001`, Level Error, so monitoring can detect drive mapping failures across the estate | Endpoint Engineer | High |
| 3 | **GPO-to-Intune migration test checklist** | Create a checklist item in the change template for any script migrated from GPO user context to Intune: *(a)* Deploy to a test OU first; *(b)* Confirm `Script context` field in IME log shows expected value; *(c)* Confirm `net use` or UNC calls succeed with exit code 0; *(d)* Sign-off required before production deployment | Change Management | Medium |
| 4 | **Audit existing SYSTEM-context Intune scripts** | Run the following query in Intune (Devices → Scripts and remediations → Platform scripts) and export to CSV. For each script where *"Run this script using the logged on credentials"* is **No**, check whether the script body contains `\\`, `net use`, `New-PSDrive`, or `Map-Drive`. Flag each match for review | Endpoint Engineer | Medium |
| 5 | **Known error record** | Create a known error record in the KEDB: *Title: Intune SYSTEM-context scripts fail to resolve UNC paths at boot. Pattern: Script error "Network name cannot be found" in IME log, SYSTEM context confirmed, LanmanWorkstation Event 7036 timestamp later than script failure timestamp.* Link to this KB article | Service Desk / Problem Management | Low |

---

## 9. Related Articles and Incidents

| Reference | Type | Detail |
|---|---|---|
| INC-2026-08-06-FINANCE-DRIVE | Incident | Original incident — 45 Finance users, 2026-08-06, ~2h 10m duration |
| RCA-2026-08-06-FINANCE-DRIVE | Root cause analysis | Full five-why analysis, hypothesis assessment, timeline |
| RB-2026-08-06-FINANCE-DRIVE | Runbook | Step-by-step operational procedure for engineers responding under pressure |
| KB-L1-FINANCE-DRIVE (self-service) | L1 KB article | End-user self-service guide: sign out/restart steps, service desk contact |
| Change 2024-03-14 | Change record | Migration of `Map-FinBridgeDrives.ps1` from GPO user context to Intune SYSTEM context — origin of latent defect |
| Microsoft Docs — Intune Management Extension | External reference | `https://learn.microsoft.com/en-us/mem/intune/apps/intune-management-extension` — covers execution context options for Platform Scripts |
