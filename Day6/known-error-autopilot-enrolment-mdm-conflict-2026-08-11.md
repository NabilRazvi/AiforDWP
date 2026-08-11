# Known Error: Autopilot Enrolment Failure — Stale MDM Enrolment Conflict

**Date Created:** 2026-08-11  
**Status:** Active  
**Severity:** High (blocks device provisioning)  
**KB ID:** DWP-KE-AP-MDM-001

---

## Symptom

User or technician attempts Autopilot enrolment on a Windows 11 device. The provisioning fails immediately and returns error code `0x80180014` ("The device is already enrolled in MDM"). Zero of four configuration profiles are applied to the device.

---

## Cause

The device has a surviving legacy manual MDM enrolment record from an earlier enrolment (typically pre-dating 2024) that was never retired from Intune before the Autopilot enrolment attempt. Autopilot cannot provision over a conflicting active enrolment and halts at the enrolment gate.

---

## Scope

Windows 11 devices with legacy manual MDM enrolments enrolled before the Autopilot transition programme. Affected devices are blocked from Autopilot provisioning until the legacy record is retired. Devices with Azure AD join, current licensing, and healthy network connectivity are not exempt from this failure.

---

## Workaround

Immediate actions to restore service:
1. In Intune admin center: **Devices > All devices** — locate the device by serial number and select **Retire** (not Wipe).
2. Wait up to 15 minutes for the retire action to complete and the record to be removed.
3. On the device: `Settings > Accounts > Access work or school` — disconnect the legacy work account and restart.
4. Confirm `dsregcmd /status` shows `WorkplaceJoined: NO` and no `MDMUrl` present.
5. Trigger Autopilot reset: `Settings > System > Recovery > Reset this PC` (remove everything) to return to OOBE.

> **Critical:** Do not trigger the Autopilot reset until the Intune Retire action (step 1) has fully completed, otherwise the conflict will persist.

---

## Permanent Fix

1. **Proactive:** Run a bulk query in Intune (`Devices > All devices`, filter `enrolledDateTime` before 2024-01-01) to identify all surviving legacy MDM records. Retire all records for devices scheduled in the Autopilot refresh programme before they reach provisioning.
2. **Process:** Add a mandatory pre-flight gate to the device refresh SOP: confirm no active Intune device record exists (or the record has been retired and cleared) before Autopilot provisioning is initiated.
3. **Monitoring:** Configure an Intune alert on `0x80180014` enrolment failures to surface any recurrence without requiring manual log review.

---

## How to Spot It

**Primary signal:** MDM diagnostic export (or `Get-MsolDevice` in hybrid scenarios) shows:
- `ErrorCode: 0x80180014`
- `ErrorDescription: The device is already enrolled in MDM`
- `MDMEnrolled: Yes` with an enrolment date pre-dating 2024 (for example, 2023-11-04)
- `ProfilesApplied: 0 of 4` (no profiles applied)
- `LastError: 0x80070005` on the profile push attempt

**Secondary signals:**
- Device user reports Autopilot provisioning halts during the enrolment stage.
- Intune audit logs show an enrolment attempt that returns error `80180014` (hex notation may vary by log source).
- Device is listed in `Settings > Accounts > Access work or school` with two enrolment entries: one legacy (from 2023) and one attempted (from 2026).
