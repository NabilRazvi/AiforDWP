# Closure Note — INC-2026-08-06-FINANCE-DRIVE
**Date Closed:** 2026-08-06 10:10  
**Incident:** Finance Shared Drive Access Failure — 45 users, OU=Finance

---

Resolved. Cause: `Map-FinBridgeDrives.ps1` executed via Intune as SYSTEM at 08:00:01 before the Workstation service (LanmanWorkstation) entered running state at 08:00:05, preventing UNC path resolution to `\\finbridge-fs01\Finance` — a latent defect introduced by the 2024-03-14 migration from GPO logon script (user context) to Intune (SYSTEM context) without updating or testing the script for the new execution environment. Action: Intune script assignment for `Map-FinBridgeDrives.ps1` changed from SYSTEM context to logged-on user context (Run this script using the logged on credentials → Yes), restoring post-session-init execution equivalent to the original GPO behaviour; policy pushed to all Finance devices. Preventive: Audit all Intune scripts deployed as SYSTEM for UNC path dependencies; add retry logic with Event Log alerting to `Map-FinBridgeDrives.ps1`; update deployment standards to require logged-on user context or an explicit Workstation service readiness check for any Intune script referencing network resources. User confirmed working.
