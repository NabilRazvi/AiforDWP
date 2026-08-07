| Field | Detail |
|---|---|
| **Title** | Runbook — Finance Shared Drive Access Failure (Intune SYSTEM Context Race Condition) |
| **Version** | 1.0 |
| **Date** | 07/08/2026 |
| **Author** | Nabil Razvi |
| **Reviewed By** | Self |
| **Status** | Draft |
| **Change** | Initial version from RCA |

---

# Runbook — Finance Shared Drive Access Failure (Intune SYSTEM Context Race Condition)
**Runbook ID:** RB-2026-08-06-FINANCE-DRIVE  
**Derived From:** RCA-2026-08-06-FINANCE-DRIVE  
**Applies To:** Finance devices (`DESKTOP-FB*`, `OU=Finance`), drive letter S:, `\\finbridge-fs01\Finance`  
**Last Updated:** 2026-08-07  
**Author:** DWP Engineer

---

## Symptom

All or most Finance users report S: drive is missing at logon. No recent change is visible in the change log. The failure affects every Finance device simultaneously rather than individual users.

---

## 1. Prerequisites

| Requirement | Detail |
|---|---|
| **Intune access** | Entra ID role: **Intune Administrator** or **Endpoint Manager Administrator** — required to view and modify script assignments. Request via Service Desk if not held. ⚠️ *Elevated permission required* |
| **Intune Management Extension log access** | Local admin on at least one affected device, or remote access via Intune remote shell, to read `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` |
| **Event Viewer access** | Local admin or equivalent on the affected device to read System event log |
| **Affected device name** | Obtain at least one confirmed affected device name (e.g. `DESKTOP-FB041`) from the incident ticket |
| **Script name** | `Map-FinBridgeDrives.ps1` — the Intune-deployed drive mapping script |
| **UNC path** | `\\finbridge-fs01\Finance` |

---

## 2. Procedure

### Phase A — Confirm the Failure Pattern

**Step 1.** On the affected device, open **Event Viewer** (`eventvwr.msc`) and navigate to **Windows Logs → System**.

> Expected: Event Viewer opens and displays the System log.

---

**Step 2.** Filter the System log for **Event ID 7036** (Service Control Manager). Look for an entry showing *"Workstation service entered running state"* with a timestamp at or after `08:00:03` on the date of the incident.

> Expected: You find Event 7036 — Workstation service, with a timestamp **2 or more seconds after** the script failure time you will confirm in Step 4.

---

**Step 3.** Still in the System log, filter for **Event ID 98** (source: Ntfs). Confirm an entry reads *"File system could not map drive letter S: — Drive letter has not been assigned."*

> Expected: Event 98 is present, confirming S: was never mapped at logon.

---

**Step 4.** On the affected device, open the Intune Management Extension log:  
`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`  
Search for `Map-FinBridgeDrives.ps1`.

> Expected: You find entries matching this pattern:
> ```
> ScriptRunner  Info     Executing: Map-FinBridgeDrives.ps1
> ScriptRunner  Info     Script context: SYSTEM account
> ScriptRunner  Warning  Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time
> ScriptRunner  Error    Script Map-FinBridgeDrives.ps1 failed. Exit code: 1. Error: Network name cannot be found.
> ScriptRunner  Info     No retry configured.
> ```

---

**Step 5.** Confirm the timestamp on the `ScriptRunner Error` line (Step 4) is **earlier** than the Workstation service Event 7036 timestamp (Step 2).

> Expected: Script failure timestamp precedes Event 7036 by at least 1–2 seconds, confirming the race condition.

---

> ⚠️ **If Steps 1–5 do not confirm this pattern**, stop here. Do not apply the fix below. Re-triage: check file server availability, DNS resolution, and Kerberos health before proceeding. Escalate if root cause is unclear.

---

### Phase B — Apply the Fix in Intune

> ⚠️ **Steps 6–10 require Intune Administrator role.**

**Step 6.** Sign in to the **Microsoft Intune admin centre**: `https://intune.microsoft.com`

> Expected: Admin centre dashboard loads. Your account shows Intune Administrator role.

---

**Step 7.** Navigate to **Devices → Scripts and remediations → Platform scripts**.

> Expected: A list of deployed PowerShell scripts is displayed.

---

**Step 8.** Locate and click **`Map-FinBridgeDrives.ps1`**.

> Expected: The script properties page opens, showing current assignment and configuration.

---

**Step 9.** Click **Properties → Edit** (next to Script settings). Locate the setting labelled **"Run this script using the logged on credentials"**. Change the value from **No** to **Yes**. Click **Review + save**, then **Save**.

> Expected: The setting is saved. The script properties page now shows *"Run this script using the logged on credentials: Yes"*.

---

**Step 10.** Navigate to **Assignments** for the script. Confirm the assignment group still includes the Finance devices group (e.g. `SG-Finance-Devices` or `OU=Finance` equivalent). Click **Save** if any change was made; otherwise leave assignments unchanged.

> Expected: Finance devices remain in scope. The updated script will execute under the logged-on user context at next policy refresh.

---

### Phase C — Force Policy Refresh on Affected Devices

**Step 11.** On a representative affected device, open **PowerShell** and run:

```powershell
Start-Process "C:\Program Files (x86)\Microsoft Intune Management Extension\AgentExecutor.exe"
```

Alternatively, instruct the affected user to **sign out and sign back in** to trigger a fresh logon script execution.

> Expected: The Intune agent re-executes the script under the logged-on user context. The S: drive appears in File Explorer within 1–2 minutes of logon.

---

## 3. Verification

**Step V1.** Ask the reporting user (or use a test Finance account on a Finance device) to **sign out and sign back in**.

> Expected: S: drive appears in File Explorer mapped to `\\finbridge-fs01\Finance` with no error.

---

**Step V2.** On the same device, open the Intune Management Extension log again and search for the most recent `Map-FinBridgeDrives.ps1` entry.

> Expected: Log shows script executed as **logged-on user context** (not SYSTEM), exit code 0, no errors.

---

**Step V3.** On the same device, open **Event Viewer → Windows Logs → System** and confirm there is **no new Event ID 98** (Ntfs, drive letter not assigned) for S: after the fix was applied.

> Expected: No Event 98 for S: in the post-fix window.

---

**Step V4.** Confirm with at least **two additional Finance users** on different devices that S: is accessible and they can browse to `\\finbridge-fs01\Finance`.

> Expected: Both users confirm access. No new tickets raised from Finance team.

---

**Step V5.** Update the incident ticket to **Resolved** only after Steps V1–V4 are all confirmed.

---

## 4. Rollback

Use this section immediately if the procedure makes things worse or S: drive is still not mapped after the fix.

---

**Rollback Step R1.** Sign back in to the Intune admin centre: `https://intune.microsoft.com`  
⚠️ *Requires Intune Administrator role.*

> Expected: Admin centre loads.

---

**Rollback Step R2.** Navigate to **Devices → Scripts and remediations → Platform scripts → `Map-FinBridgeDrives.ps1` → Properties → Edit**.  
Change **"Run this script using the logged on credentials"** back to **No**. Click **Review + save → Save**.

> Expected: Script reverts to SYSTEM context assignment — restores the previous state exactly.

---

**Rollback Step R3.** Navigate to **Assignments** and confirm Finance devices group is still assigned. Save if needed.

> Expected: Assignment scope is unchanged from before you began.

---

**Rollback Step R4.** Ask an affected user to **sign out and sign back in** to confirm whether S: maps under the reverted configuration.

> Expected: If S: still does not map under SYSTEM context (as expected — this is the known failure mode), the user will still lack the drive. This confirms rollback has restored the prior state and has not introduced a new failure. Escalate to Endpoint Engineering Lead.

---

**Rollback Step R5.** If users need immediate access to Finance data while the root cause is under investigation, raise an emergency request with the File Server team to **provide a temporary web or VPN-based access method** to `\\finbridge-fs01\Finance`, or instruct users to map the drive manually:

```powershell
# Run as the affected user in their own PowerShell session
net use S: \\finbridge-fs01\Finance /persistent:no
```

> Expected: S: maps for that session. This is a temporary workaround — it does not survive reboot and must not be treated as a resolution.

---

## 5. Notes

### Edge Cases

- **"No recent change" does not rule this out.** The latent defect was introduced by a migration on 2024-03-14 — over two years before it manifested. If the symptom matches, follow this runbook regardless of change log status.
- **Individual user failure vs. mass failure.** This failure pattern affects all Finance devices simultaneously at logon. If only one or two users are affected, investigate user-specific group membership or profile corruption before applying this fix.
- **"Network name cannot be found" is ambiguous.** This error can also indicate DNS failure or file server unavailability. Do not skip Phase A — confirm SYSTEM context and the Workstation service race condition before applying the Intune fix.
- **Devices not yet refreshed.** After saving the Intune change, devices that are offline or not checking in will not receive the update until they next connect. Users on those devices should be asked to connect to VPN or the office network and sign out/in.

### Warnings

- ⚠️ Do not change the script assignment group while applying the fix — only change the execution context setting. Removing or widening the assignment group could affect non-Finance devices.
- ⚠️ The manual workaround (`net use`) in R5 does not persist across reboots. Communicate this clearly to users and managers.

### Related Incidents and Records

| Reference | Detail |
|---|---|
| INC-2026-08-06-FINANCE-DRIVE | Original incident — 45 Finance users, 2026-08-06 |
| RCA-2026-08-06-FINANCE-DRIVE | Full root cause analysis |
| Known Error (to be created) | *"Intune SYSTEM-context scripts referencing UNC paths will fail if the Workstation service (LanmanWorkstation) has not entered running state at execution time"* — see Preventive Action 5 in the RCA |
| Change 2024-03-14 | Migration of `Map-FinBridgeDrives.ps1` from GPO user context to Intune SYSTEM context — origin of latent defect |

### Pending Improvements (from RCA Preventive Actions)

The following actions are tracked in the RCA and are not yet complete. This runbook will be updated once they are implemented:

- Retry logic and alerting to be added to `Map-FinBridgeDrives.ps1` (2 retries, 15-second delay, custom Event Log source)
- Audit of all remaining Intune SYSTEM-context scripts that reference UNC paths
- Test checklist for future GPO-to-Intune script migrations
