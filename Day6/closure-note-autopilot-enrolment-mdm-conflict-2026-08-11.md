# Closure Note: Autopilot Enrolment Failure — Stale MDM Enrolment Conflict

**Date Closed:** 2026-08-11  
**Incident ID:** DWP-AP-ENROL-FAIL-20260811  
**Analyst:** DWP Engineer

---

**Resolved.** 

**Cause:** Device had a surviving legacy manual MDM enrolment record from November 2023 that was never retired before Autopilot provisioning was attempted. Error `0x80180014` ("Device is already enrolled in MDM") halted the Autopilot provisioning service at the enrolment gate, preventing all configuration profiles from being applied.

**Action:** 
1. Retired the legacy device record in Intune admin center (**Devices > All devices > Retire**); confirmed removal after 15 minutes.
2. Disconnected the legacy work account on the device (**Settings > Accounts > Access work or school > Disconnect**) and restarted.
3. Verified clean state: `dsregcmd /status` confirmed `WorkplaceJoined: NO` and no `MDMUrl` present.
4. Confirmed device serial in Autopilot device list with active profile assignment.
5. Triggered Autopilot reset (**Settings > System > Recovery > Reset this PC** — remove everything) to return to OOBE and allow Autopilot to complete.

**Preventive:** 
- Added mandatory pre-flight MDM clean-state gate to device refresh SOP: confirm no active Intune device record exists (or record has been retired and cleared) before Autopilot provisioning is initiated.
- Scheduled bulk query to identify and retire all surviving legacy MDM records from devices enrolled before 2024-01-01 before they reach Autopilot queue.
- Configured Intune alert on error code `0x80180014` to surface any recurrence without requiring manual log review.

**Verification:** Device confirmed with `dsregcmd /status` showing `AzureAdJoined: YES`, `MDMEnrolled: YES` (enrolment date 2026-08-11), `WorkplaceJoined: NO`. Intune device record shows all 4 profiles applied successfully. Autopilot deployment profile assigned and active. User successfully signed in and confirmed access to expected resources.

---

**Status:** CLOSED — No further action required on this device.
