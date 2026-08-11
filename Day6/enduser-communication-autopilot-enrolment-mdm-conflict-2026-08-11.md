# End-User Communications: Autopilot Enrolment Failure Incident

**Date:** 2026-08-11  
**Incident:** Autopilot device provisioning conflict resolved

---

## Audience 1 — Non-Technical Executive

**Subject:** Device Setup Issue Resolved

Your device provisioning encountered a conflict with an outdated system record from 2023. Your data and access remained secure throughout. We retired the old record, reset your device, and confirmed all your security and compliance settings now apply correctly. If you're issued a new device in the future, contact IT to ensure old records are cleared first — this prevents the same delay. No action required on your part at this time.

---

## Audience 2 — Affected End-User Team

**Subject:** Device Setup Issue — Resolved

A few devices hit a snag during setup: the system found an old enrollment from 2023 that wasn't removed before we tried to set up a new one, so setup stopped. Your IT team fixed it by cleaning up the old record and resetting the device — everything is working now. If you see a message like "Device already enrolled in MDM" during setup, let IT know right away — this is a quick fix. **Contact:** IT Service Desk or [email/phone]. Thanks for your patience!

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Root Cause:** Legacy manual MDM enrollment (2023-11-04) survived unretired into Autopilot provisioning phase. Autopilot service correctly rejected with `0x80180014` ("Device is already enrolled in MDM") at enrolment gate.

**Exact Action Taken:**
1. Intune admin center: **Devices > All devices** → located device by serial → **Retire** (not Wipe) → confirmed record removal after ~15 min.
2. Device-side: `Settings > Accounts > Access work or school` → disconnected legacy work account → restart.
3. Verification: `dsregcmd /status` showed `WorkplaceJoined: NO`, no `MDMUrl` present, `AzureAdJoined: YES` (join persisted).
4. Pre-flight check: Confirmed device serial in Autopilot device list with profile assignment active.
5. Reset: `Settings > System > Recovery > Reset this PC` (full wipe) → OOBE → Autopilot auto-detected → all 4 profiles applied successfully.

**Configuration Detail:** Device enrolled fresh under same Autopilot profile assignment. Licensing (Intune P1 + Autopilot) confirmed present. Network connectivity (all Intune endpoints reachable, no proxy) confirmed healthy pre- and post-remediation.

**Verification Step:** Post-enrolment `dsregcmd /status` confirmed:
- `AzureAdJoined: YES`
- `MDMEnrolled: YES` (enrolment date 2026-08-11, new record only)
- `WorkplaceJoined: NO` (no conflicting legacy entry)
- Intune device detail: `Profiles Applied: 4 of 4`, `LastError: [none]`
- Autopilot deployment profile: `Assigned` state

**Preventive Action Required:**
1. **SOP update:** Add mandatory pre-flight gate — confirm no active Intune device record exists for target serial before Autopilot provisioning initiates. If record exists, retire and verify cleared before device reaches technician.
2. **Bulk cleanup:** Query Intune for all devices with `enrolledDateTime < 2024-01-01 AND managementAgent eq 'mdm'` (Graph API or admin center filter). Cross-reference against Autopilot refresh schedule and retire eligible records now, before they cause `0x80180014` at scale.
3. **Monitoring:** Configure Intune alert on enrolment failures filtering for error code `80180014` (hex) — surfaces recurrence without manual log review.
4. **Checklist:** Add device prep validation step: "[ ] No active Intune record exists (or record retired and cleared) before reset."

**Graph API query for bulk discovery:**
```
GET /deviceManagement/managedDevices?$filter=enrolledDateTime lt 2024-01-01T00:00:00Z and managementAgent eq 'mdm'
```

**Known Error Record:** DWP-KE-AP-MDM-001 published to KB; can be referenced for future cases.

---

**Status:** Device operational. Incident closed. Preventive actions assigned to Device Engineering and MDM admin team.
