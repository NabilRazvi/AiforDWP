# Communications — Finance Shared Drive Access Failure
**Incident:** INC-2026-08-06-FINANCE-DRIVE  
**Date:** 2026-08-06  
**Resolved:** 10:10

---

## Audience 1 — Non-Technical Executive

**Subject: Finance Shared Drive — Service Restored**

Your team's access to shared drives was briefly unavailable this morning due to a software configuration issue on our systems. Your data was never at risk, and no information was lost or compromised. The issue was identified and resolved by 10:10. Access is fully restored and working normally. No action is required from you.

---

## Audience 2 — Affected End-User Team (Finance)

**Subject: Shared Drive Access This Morning — Resolved**

Hi team,

This morning from around 8:00 AM, the S: drive was unavailable because a background automated script that maps your drives ran too early before the system was fully ready. The issue has been fixed and your drives should be working normally now.

If you still cannot see your S: drive, please log off and log back on. If the problem continues, contact the IT Service Desk and quote **INC-2026-08-06-FINANCE-DRIVE**.

Thanks,  
IT Support

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Subject: RCA Summary — Finance Drive Mapping Failure, 2026-08-06**

**Root cause:**  
`Map-FinBridgeDrives.ps1` deployed via Intune executed as SYSTEM at `08:00:01`. LanmanWorkstation did not enter running state until `08:00:05` (Event 7036). SYSTEM context cannot resolve UNC paths (`\\finbridge-fs01\Finance`) before LanmanWorkstation is active — script failed at `08:00:03` with *"Network name cannot be found"* (Exit code 1). No retry configured; all 45 Finance devices (`DESKTOP-FB*`, `OU=Finance`) left without S: mapped for the session.

Latent defect origin: **2024-03-14 23:30** — script migrated from GPO logon script (user context, post-session-init) to Intune PowerShell (SYSTEM context, early boot). Script was not updated or tested for the new execution environment.

**Key event IDs:**
- `08:00:03` ScriptRunner Error — Exit code 1, *"Network name cannot be found"*
- `08:00:05` Event 7036 (SCM) — Workstation service running *(2 seconds too late)*
- `08:00:06` Event 1500 (GroupPolicy) — GP healthy; confirmed Kerberos/Netlogon not implicated
- `08:00:07` Event 98 (NTFS) — S: drive letter not assigned

**Action taken:**  
Intune > Devices > Scripts > `Map-FinBridgeDrives.ps1` — changed **"Run this script using the logged on credentials"** from **No → Yes**. Policy pushed to all Finance devices. Running as logged-on user ensures execution occurs post-session-init when LanmanWorkstation is already active and user credentials are available — equivalent to the original GPO logon script behaviour.

**Verification:**  
Forced Intune sync on test device via `intunemanagementextension://syncapp`. Confirmed script exit code 0 in `%ProgramData%\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`. Event 98 absent on subsequent logon. Affected user manually verified connection to `\\finbridge-fs01\Finance` at 10:10 — S: drive mapped, no errors.

**If this recurs:**  
Check ScriptRunner entries in Intune Management Extension log first. If you see *"not accessible from SYSTEM context"* the script assignment has reverted or a new SYSTEM-context script has been deployed with the same pattern. Verify `Run this script using the logged on credentials = Yes` in Intune. If SYSTEM context is genuinely required, add a LanmanWorkstation readiness loop before any UNC call:
```powershell
$svc = Get-Service LanmanWorkstation
$timeout = 30; $elapsed = 0
while ($svc.Status -ne 'Running' -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 2; $svc.Refresh(); $elapsed += 2
}
if ($svc.Status -ne 'Running') { Write-Error "Workstation service not ready."; exit 1 }
```

**Preventive action outstanding:**  
1. Add retry logic (min 2 retries, 15s delay) with Event Log write on final failure to `Map-FinBridgeDrives.ps1` — currently zero retry configured.  
2. Audit all Intune scripts deployed as SYSTEM for UNC path usage — any without a Workstation service check are at risk of the same race condition.  
3. Add to deployment standards: Intune scripts using network resources must either run as logged-on user or include an explicit service dependency check.  
4. Raise known-error record: *Intune SYSTEM-context scripts referencing UNC paths will fail if LanmanWorkstation has not entered running state at execution time.*

**Full RCA:** `Day4/rca-finance-shared-drive-failure-2026-08-06.md`
