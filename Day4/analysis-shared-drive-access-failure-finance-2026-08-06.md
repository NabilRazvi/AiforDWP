# Analysis: Finance Shared Drive Access Failure
**Date:** 2026-08-06  
**Analyst:** DWP Engineer  
**Status:** ~~Hypothesis — Cause Not Yet Confirmed~~ **Root Cause Confirmed — 2026-08-06**

---

## Scope Facts

| Field | Detail |
|---|---|
| Symptom | Finance team cannot access shared drives |
| Who | 45 users (whole Finance team) |
| Since | 08:00:03 |
| Recorded Change | None |

---

## Ranked Hypotheses — Most Probable First

### 1. File Server / DFS Service Failure
**Why it fits:** Entire team affected simultaneously at a hard timestamp. A service crash (Lanman Server, DFS Namespace, or Server service) on the backend file server would cut off all 45 users at once regardless of their individual config.  
**Fastest check:** `Get-Service LanmanServer, Dfs* | Select Name,Status` on the file server — or `net use \\<fileserver>\<share>` from an affected client to test connectivity directly.

---

### 2. Kerberos / Netlogon Authentication Failure
**Why it fits:** "Login failure" symptom maps directly to Kerberos ticket issuance failing. Finance may authenticate against a specific DC. 08:00:03 could align with a DC restart or Netlogon service hiccup after overnight patching (unrecorded).  
**Fastest check:** `nltest /sc_verify:<domain>` on an affected machine. Look for `NERR_Success` vs a trust/secure-channel error.

---

### 3. Security Group Membership Removed (Unrecorded Change)
**Why it fits:** Finance-specific scope with no other teams affected strongly suggests a permissions boundary. "No change" may mean no formal ticket — an overnight admin action removing the Finance group from the share ACL would not appear in most change logs.  
**Fastest check:** Check AD security group that governs share access — `Get-ADGroupMember "<ShareAccessGroup>"` — and compare against the 45 affected users.

---

### 4. DNS Resolution Failure for File Server
**Why it fits:** If the file server FQDN is unresolvable, every drive-map attempt silently fails. A DNS service restart at 08:00 (scheduled or automated) would produce the exact timestamp pattern with no change ticket raised.  
**Fastest check:** `nslookup <fileserverhostname>` from an affected machine. A timeout or NXDOMAIN confirms this immediately.

---

### 5. GPO / Logon Script Drive Mapping Broken
**Why it fits:** Finance users typically log on between 08:00–09:00. If the GPO that maps their drives references a UNC path that has changed or the GPO was unlinked, all 45 users arriving at that time would fail simultaneously — producing a sharp 08:00 onset.  
**Fastest check:** `gpresult /r` on an affected machine — confirm the drive-mapping GPO is applied and the UNC path in it still resolves to a live share.

---

## Notes

- Causes 1 and 2 can co-exist (a DC restart can take a file server's Kerberos auth with it).
- Run checks for hypotheses 1 and 2 in parallel first — they will eliminate or confirm the most impactful scenarios fastest.
- "No change recorded" does not rule out an unrecorded or automated change. Treat this as unverified until AD audit logs are reviewed.
- Do not commit to a single cause until at least two checks have returned results.

---

## Evidence Review — Event Log Assessment

**Source:** Intune Management Extension Log + System Log  
**Affected:** All Finance users (DESKTOP-FB* devices, OU=Finance)

### Raw Events

```
[08:00:01]  ScriptRunner  Info     Executing: Map-FinBridgeDrives.ps1
[08:00:02]  ScriptRunner  Info     Script context: SYSTEM account
[08:00:03]  ScriptRunner  Warning  Network path \\finbridge-fs01\Finance
                                   not accessible from SYSTEM context at execution time
[08:00:03]  ScriptRunner  Error    Script Map-FinBridgeDrives.ps1 failed.
                                   Exit code: 1. Error: Network name cannot be found.
[08:00:04]  ScriptRunner  Info     No retry configured.

[08:00:05]  Service Control Manager  Event 7036  — Workstation service entered running state.
[08:00:06]  GroupPolicy              Event 1500  — Group Policy settings processed successfully.
[08:00:07]  Ntfs                     Event 98    — File system could not map drive letter S:
                                                   Drive letter has not been assigned.
```

**Prior change note (migration log):**
> 2024-03-14 23:30 — Drive mapping script migrated from GPO logon script (runs as USER) to Intune PowerShell script (runs as SYSTEM). Script not updated to handle SYSTEM context.

---

### Hypothesis Verdict Table

| # | Hypothesis | Verdict | Determining Event |
|---|---|---|---|
| 1 | File Server / DFS Service Failure | **Contradicts** | ScriptRunner Warning 08:00:03 — failure scoped to *"SYSTEM context"*, not global; Event 7036 08:00:05 shows Workstation service came up normally |
| 2 | Kerberos / Netlogon Failure | **Contradicts** | Event 1500 08:00:06 — GP applied successfully; Kerberos must be functioning for GP to process |
| 3 | Security Group Membership Removed | **Contradicts** | ScriptRunner Error 08:00:03 — error is *"Network name cannot be found"*, not *Access Denied*; permissions are never tested |
| 4 | DNS Resolution Failure | **Neutral** | No DNS-specific event present; error resembles DNS failure but is masked by Workstation service timing issue |
| 5 | GPO / Logon Script Broken | **Contradicts** | Event 1500 08:00:06 — GP fine; drive mapping no longer GPO-owned since 2024-03-14 migration |

---

## Confirmed Root Cause

**Surviving hypothesis:** H4 (DNS / Name Resolution) — not contradicted, but the evidence revealed the specific mechanism beneath it.

**Root cause:** `Map-FinBridgeDrives.ps1` executes via Intune as SYSTEM at `08:00:01`. The Workstation service (LanmanWorkstation) does not enter running state until `08:00:05` (Event 7036). SYSTEM context cannot resolve UNC paths (`\\finbridge-fs01\Finance`) without LanmanWorkstation running — producing *"Network name cannot be found"* at `08:00:03`, which is superficially identical to a DNS failure.

The failure was introduced on **2024-03-14** when drive mapping was migrated from a GPO logon script (USER context — full session init, Workstation service already running) to an Intune PowerShell script (SYSTEM context — early boot, no user credentials, Workstation service not yet ready). The script was not updated to handle the new execution context.

---

## Resolution Steps

### Immediate — Restore User Access

1. Confirm scope — pull Intune Management Extension logs from all `DESKTOP-FB*` devices in `OU=Finance`; verify same `Exit code: 1` pattern.
2. Push a one-time remediation script in **logged-on user** context, or advise users to run manually:
   ```powershell
   net use S: \\finbridge-fs01\Finance /persistent:yes
   ```

### Short-Term Fix — Repair the Script

3. In Intune > Devices > Scripts > `Map-FinBridgeDrives.ps1`, set **Run this script using the logged on credentials → Yes**. This restores the original GPO behaviour and eliminates the SYSTEM/Workstation race condition.

4. If SYSTEM context is required, add a Workstation service readiness check to the script:
   ```powershell
   $svc = Get-Service LanmanWorkstation
   $timeout = 30; $elapsed = 0
   while ($svc.Status -ne 'Running' -and $elapsed -lt $timeout) {
       Start-Sleep -Seconds 2; $svc.Refresh(); $elapsed += 2
   }
   if ($svc.Status -ne 'Running') { Write-Error "Workstation service not ready."; exit 1 }
   ```

5. Add at minimum one retry with a 10-second delay — currently no retry is configured (ScriptRunner Info `08:00:04`).

### Verification

6. Force Intune sync on a test Finance device:
   ```powershell
   Start-Process "intunemanagementextension://syncapp"
   ```
   Confirm script exits with code `0` in `IntuneManagementExtension.log` and drive S: is assigned.

7. Confirm Event 98 (NTFS, drive letter not assigned) is absent from the System log on the next logon cycle.

### Close-Out

8. Raise a change record against the 2024-03-14 migration — script was deployed without testing in the new execution context.
9. Add to known-error database: *Intune SYSTEM-context scripts cannot resolve UNC paths before LanmanWorkstation service is running.*
