# Analysis: Autopilot Enrolment Failure — Stale MDM Enrolment Conflict
**Date:** 2026-08-11  
**Analyst:** DWP Engineer  
**Status:** Root Cause Confirmed — Remediation Defined

---

## Scope Facts

| Field | Detail |
|---|---|
| EnrollmentState | Failed |
| Error Code | `0x80180014` — Device is already enrolled in MDM |
| Error Description | The device is already enrolled in MDM |
| Existing MDM Enrolment | Yes — legacy manual enrolment from 2023-11-04 |
| Enrolment Source | Legacy manual MDM enrolment |
| Profiles Applied | 0 of 4 |
| Last Policy Error | `0x80070005` — Access Denied |
| Azure AD Joined | Yes |
| Intune P1 Licence | Yes |
| Autopilot Licence | Yes |
| Network | All endpoints reachable, no proxy |

---

## Root Cause

**Stale legacy MDM enrolment from 2023-11-04 was never retired before Autopilot provisioning was attempted.**

`0x80180014` is the direct, documented result of attempting Autopilot enrolment on a device that already holds an active MDM enrolment record. The legacy record — created via manual enrolment in November 2023 — persisted on both the device and in Intune. Autopilot cannot complete over a conflicting existing enrolment; it halts immediately and no profiles are pushed, explaining the `0x80070005` Access Denied error and the 0 of 4 profiles applied result.

Licensing, Azure AD join state, and network connectivity are all healthy and are not contributing factors.

---

## Ranked Hypotheses Assessed

### 1. Stale legacy MDM enrolment not removed before Autopilot provisioning *(confirmed root cause)*
- **Why it fits:** `0x80180014` is unambiguous — the device reported an existing enrolment to Autopilot and provisioning was blocked. The 2023-11-04 enrolment date confirms this is a legacy record, not a concurrent session. No other scope fact is required to explain the primary failure.
- **Status:** Confirmed. All other hypotheses are secondary or dependent on this.

### 2. Device was not factory-reset / OOBE-triggered before Autopilot was attempted
- **Why it fits:** The legacy enrolment persisting to 2026 indicates the device was never wiped as part of a refresh cycle. Autopilot is designed to run from a clean OOBE state.
- **Status:** Contributing factor. Addressed by remediation step 6.

### 3. Autopilot profile not correctly scoped to device group
- **Why it fits:** `0x80070005` on profile application could also indicate the device is not in the correct AAD group for profile assignment, which would become the next failure point after the enrolment conflict is cleared.
- **Status:** To verify — confirm in Intune that the device serial is assigned to a group in scope for the Autopilot profile before re-triggering. Not the primary cause.

---

## Remediation

### Order of Operations

| Step | Action | Access Required |
|------|--------|----------------|
| 1 | Retire old device record in Intune admin center | Admin center only |
| 2 | Disconnect legacy work account on the device | Device (physical or remote) |
| 3 | Restart the device | Device |
| 4 | Verify clean `dsregcmd /status` output | Device |
| 5 | Confirm device serial is in Autopilot device list | Admin center only |
| 6 | Trigger Autopilot reset / OOBE | Device |

> **Critical:** Do not trigger step 6 until step 1 (Intune Retire) has completed. Initiating reset while the Intune record is still active will reproduce the same `0x80180014` failure.

---

### Phase 1 — Retire the Stale Intune Record (Admin Center Only)

1. Sign in to `https://intune.microsoft.com`
2. Navigate to **Devices > All devices**
3. Search by device name or serial number — locate the record showing enrolment date **2023-11-04**
4. Select the device record
5. Click **Retire** (do not select Wipe — Retire removes MDM management without erasing user data)
6. Confirm the action
7. Wait up to 15 minutes for status to progress to *Retire pending* and the record to be removed

---

### Phase 2 — Remove Stale Work Account from Device (Device Access Required)

1. On the device: `Settings > Accounts > Access work or school`
2. Locate the legacy MDM enrolment entry from 2023
3. Click on it > **Disconnect** > confirm
4. Restart the device

---

### Phase 3 — Verify Clean State (Device Access Required)

Run the following from an elevated command prompt or PowerShell:

```powershell
dsregcmd /status
```

Confirm the following before proceeding:
- `WorkplaceJoined : NO`
- No `MDMUrl` value present in the output
- `AzureAdJoined : YES` (Azure AD join is expected to remain)

---

### Phase 4 — Re-trigger Autopilot (Admin Center + Device)

1. In Intune admin center: **Devices > Enrollment > Windows > Autopilot devices** — confirm the device serial number is listed and has a profile assigned
2. Confirm the device is a member of the AAD group targeted by the Autopilot deployment profile
3. On the device, trigger reset: `Settings > System > Recovery > Reset this PC` — select **Remove everything** to return to OOBE
   - Alternatively, issue **Autopilot Reset** from Intune admin center if the device record is still reachable: **Devices > All devices > [device] > Autopilot Reset**
4. Allow OOBE to complete — Autopilot profile will be detected and applied automatically

---

## Verification Checks (Post-Remediation)

| Check | Expected Result |
|-------|----------------|
| `dsregcmd /status` — `AzureAdJoined` | `YES` |
| `dsregcmd /status` — `MDMEnrolled` | `YES` with today's enrolment date |
| `dsregcmd /status` — `WorkplaceJoined` | `NO` (no conflicting legacy enrolment) |
| Intune > Devices > All devices | New device record present; enrolment date 2026-08-11 |
| Intune device detail — Profiles Applied | 4 of 4 |
| Intune device detail — Autopilot profile | Shows as Assigned |
| User sign-in and resource access | Successful, no credential loops or access errors |

---

## Preventive Action

**Gate:** Before any Autopilot deployment for a device with a legacy enrolment history, a pre-flight check must confirm no active Intune record exists.

**Process:**
1. In Intune admin center: **Devices > All devices** — filter by *Enrolment type: User enrolment* or *Manual* to identify surviving legacy records
2. Retire all legacy records for devices scheduled for Autopilot refresh before the device reaches the technician
3. Add this as a mandatory gate in the device refresh SOP: **Autopilot reset must not be initiated until the Intune record is confirmed clean**
4. For at-scale identification, use an Intune Device Management report or Graph API query filtered on `enrollmentType eq 'userEnrollment'` and `enrolledDateTime lt 2024-01-01` to surface all legacy records proactively

---

## Error Code Reference

| Code | Meaning | Confirmed |
|------|---------|-----------|
| `0x80180014` | Device is already enrolled in MDM — Autopilot cannot enrol over an existing record | Yes — Microsoft documented |
| `0x80070005` | Access Denied — policy push blocked; secondary consequence of the enrolment conflict | Yes — standard Win32 error surfaced through Intune |
