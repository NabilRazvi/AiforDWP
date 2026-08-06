# Known Error Record — DWP Knowledge Base
**Record ID:** KE-2026-08-06-FINANCE-DRIVE  
**Date Raised:** 2026-08-06  
**Status:** Active  
**Source Incident:** INC-2026-08-06-FINANCE-DRIVE  
**Source RCA:** Day4/rca-finance-shared-drive-failure-2026-08-06.md

---

**Symptom:** Users cannot access mapped shared drives at logon; drive letter S: is missing with no error presented to the user. All affected users experience the failure simultaneously at the same point in the boot sequence.

**Cause:** An Intune-deployed PowerShell script (`Map-FinBridgeDrives.ps1`) runs as SYSTEM during early boot before the Workstation service (LanmanWorkstation) has entered a running state. SYSTEM context cannot resolve UNC paths without LanmanWorkstation active, so the mapping attempt fails with *"Network name cannot be found."* The script has no retry logic, so no recovery occurs after the service becomes available.

**Scope:** All devices in `OU=Finance` with hostnames matching `DESKTOP-FB*` where `Map-FinBridgeDrives.ps1` is assigned via Intune with SYSTEM context (Run this script using the logged on credentials = No). Confirmed across 45 users on 2026-08-06; any Intune-managed device running a SYSTEM-context script that references UNC paths before LanmanWorkstation is ready is susceptible to the same pattern.

**Workaround:** Ask the affected user to run `net use S: \\finbridge-fs01\Finance /persistent:yes` from a Command Prompt, or log off and log back on after the Intune script assignment has been corrected. This restores drive access for the current session without requiring a device restart.

**Permanent fix:** In Intune > Devices > Scripts > `Map-FinBridgeDrives.ps1`, set **Run this script using the logged on credentials → Yes**. This moves execution to logged-on user context, which occurs after the full user session is established and LanmanWorkstation is already running, restoring behaviour equivalent to the original GPO logon script. Additionally, add retry logic (minimum 2 retries, 15-second delay) and an Event Log write on final failure to enable proactive detection.

**How to spot it:** ScriptRunner Warning in `%ProgramData%\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` at logon time: *"Network path not accessible from SYSTEM context at execution time"* followed by ScriptRunner Error *"Exit code: 1 — Network name cannot be found."* In the System Event Log, NTFS Event ID 98 (*"File system could not map drive letter S: — Drive letter has not been assigned"*) appears within seconds of logon, and Event ID 7036 (Service Control Manager) confirming LanmanWorkstation entered running state will be timestamped *after* the ScriptRunner failure.
