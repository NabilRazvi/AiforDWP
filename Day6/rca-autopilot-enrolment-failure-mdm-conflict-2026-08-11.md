# Root Cause Analysis: Autopilot Enrolment Failure — Stale MDM Enrolment Conflict

## Incident Metadata

| Field | Detail |
|---|---|
| Analyst | DWP Engineer |
| Date of Analysis | 2026-08-11 |
| Incident Type | Autopilot enrolment failure on Windows 11 endpoint |
| Device | [Device name/serial — to-verify from asset register] |
| Affected User | [Assigned user — to-verify] |
| Incident Window | Enrolment attempt 2026-08-11; legacy enrolment record dated 2023-11-04 |
| Status | Root Cause Confirmed — Remediation Defined |

---

## Incident Summary

An Autopilot enrolment attempt on a Windows 11 endpoint failed with error `0x80180014` ("Device is already enrolled in MDM"). The device had a surviving legacy manual MDM enrolment from November 2023 that was never retired. Autopilot cannot complete provisioning over a conflicting active enrolment. Zero of four compliance/configuration profiles were applied as a direct consequence. Licensing, Azure AD join state, and network connectivity were all healthy and are not contributing factors.

---

## Supporting Evidence

### MDM Diagnostic Export — Full Extract

| Field | Value |
|---|---|
| EnrollmentState | Failed |
| ErrorCode | `0x80180014` |
| ErrorDescription | The device is already enrolled in MDM |
| MDMEnrolled | Yes — legacy manual enrolment from 2023-11-04 |
| EnrolmentSource | Legacy manual MDM enrolment |
| ProfilesApplied | 0 of 4 |
| LastError | `0x80070005` — Access Denied |
| AzureADJoined | Yes |
| IntuneP1Licence | Yes |
| AutopilotLicence | Yes |
| Network | All endpoints reachable, no proxy |

### Error Code Definitions (Microsoft-confirmed)

| Code | Definition | Source |
|---|---|---|
| `0x80180014` | Device is already enrolled in MDM — Autopilot halts when an active enrolment record is detected | Microsoft-documented Autopilot error |
| `0x80070005` | Access Denied — policy push blocked; direct secondary consequence of blocked enrolment | Standard Win32 error surfaced through Intune |

### Evidence Assessment

| Evidence Item | Supports Root Cause? | Notes |
|---|---|---|
| `0x80180014` error | Yes — direct | Unambiguous: this error has one meaning |
| MDMEnrolled = Yes (2023-11-04) | Yes — direct | Confirms the conflicting record exists on the device |
| EnrolmentSource = Legacy manual | Yes — supporting | Confirms the record was not created by Autopilot or Hybrid Join; it is a pre-existing manual record |
| ProfilesApplied = 0 of 4 | Yes — consequence | Profiles cannot be pushed if enrolment is blocked at the first gate |
| `0x80070005` on profile push | Yes — consequence | Access Denied is the result of the enrolment conflict, not an independent permissions failure |
| AzureADJoined = Yes | No — eliminates a hypothesis | AAD join is healthy; this is not an identity or join state issue |
| Licences = Yes (both) | No — eliminates a hypothesis | Licensing is not a factor |
| Network = All endpoints reachable | No — eliminates a hypothesis | Network is not a factor |

---

## Timeline of Events

| Date / Time | Event | Source |
|---|---|---|
| 2023-11-04 | Device manually enrolled into MDM via legacy enrolment method | MDM diagnostic export — `MDMEnrolled` field |
| 2023-11-04 to 2026-08-10 | Device in service under legacy MDM enrolment; no retirement or offboarding action recorded | Inferred from enrolment date and export |
| 2026-08-11 (time to-verify) | Technician initiates Autopilot enrolment on the device | Incident trigger |
| 2026-08-11 | Autopilot contacts Intune; detects existing MDM enrolment; returns `0x80180014` | MDM diagnostic export — `ErrorCode` |
| 2026-08-11 | Autopilot halts; zero profiles applied; `0x80070005` logged on profile push attempt | MDM diagnostic export — `ProfilesApplied`, `LastError` |
| 2026-08-11 | Incident raised; MDM diagnostic export captured and analysed | This RCA |

> **Note:** Exact timestamps for the 2026-08-11 enrolment attempt are to-verify from Intune audit logs (`Devices > Monitor > Audit logs`, filter by device name and action = Enrol).

---

## 5 Whys Analysis

**Problem statement:** Autopilot enrolment failed and the device could not be provisioned.

---

**Why 1 — Why did Autopilot enrolment fail?**

Because the Autopilot provisioning service detected an active MDM enrolment on the device and returned error `0x80180014`, halting the process.

*Evidence:* `EnrollmentState: Failed`, `ErrorCode: 0x80180014`, `ErrorDescription: The device is already enrolled in MDM`.

---

**Why 2 — Why was there an active MDM enrolment on the device?**

Because the device was enrolled via legacy manual MDM in November 2023 and that enrolment record was never retired from Intune or removed from the device before the Autopilot attempt.

*Evidence:* `MDMEnrolled: Yes (2023-11-04)`, `EnrolmentSource: Legacy manual MDM enrolment`.

---

**Why 3 — Why was the legacy enrolment never retired?**

Because no retirement or offboarding process was applied to this device when it transitioned from legacy MDM management to the Autopilot refresh programme. The device was scheduled for Autopilot re-enrolment without a pre-flight check confirming a clean MDM state.

*Evidence:* Enrolment record survived from 2023 to 2026-08-11 with no retirement action recorded. to-verify: Check Intune audit logs for any prior retire/wipe actions against this device record.

---

**Why 4 — Why was there no pre-flight check for a clean MDM state?**

Because the device refresh SOP did not include a mandatory gate requiring confirmation that any existing Intune/MDM device record had been retired before Autopilot provisioning was initiated. Legacy devices were processed directly into the Autopilot queue without a retirement step.

*Evidence:* Inferred from the surviving 2023 record reaching the Autopilot attempt unchanged. to-verify: Review the current device refresh SOP to confirm whether a clean-MDM gate exists.

---

**Why 5 — Why did the SOP not include this gate?**

Because the transition from legacy manual MDM enrolment to Autopilot-based provisioning was not accompanied by a documented process to identify and retire pre-existing enrolment records on devices being refreshed. The assumption was that devices entering the Autopilot queue were already in a clean state.

*Evidence:* Systemic — the same failure pattern is likely reproducible on any other device with a legacy enrolment from the 2023 manual-enrolment cohort.

---

## Root Cause Statement

The Autopilot enrolment failure was caused by a stale legacy MDM enrolment record from November 2023 that was never retired before the device entered the Autopilot provisioning workflow. The device refresh process lacked a mandatory pre-flight gate to verify and clear existing MDM enrolments, allowing the device to reach Autopilot with a conflicting active enrolment, which the Autopilot service correctly rejected with `0x80180014`.

---

## Corrective and Preventive Actions (CAPA)

### Immediate Corrective Actions (This Device)

| Step | Action | Access |
|---|---|---|
| 1 | In Intune admin center: **Devices > All devices** — locate the 2023-11-04 record, select **Retire** (not Wipe) | Admin center only |
| 2 | Wait up to 15 minutes for retire to complete and the record to clear | Admin center only |
| 3 | On device: `Settings > Accounts > Access work or school` — disconnect the legacy MDM work account | Device (physical or remote) |
| 4 | Restart the device | Device |
| 5 | Run `dsregcmd /status` — confirm `WorkplaceJoined: NO` and no `MDMUrl` present | Device |
| 6 | Confirm device serial is listed in **Devices > Enrollment > Windows > Autopilot devices** and a profile is assigned | Admin center only |
| 7 | Trigger Autopilot reset: `Settings > System > Recovery > Reset this PC` (remove everything) to return to OOBE | Device |

> **Critical ordering constraint:** Step 1 (Retire) must complete before Step 7 (reset/OOBE). Initiating Autopilot while the Intune record is still active will reproduce `0x80180014`.

---

### Preventive Actions (Systemic)

#### 1. Mandate a pre-flight MDM clean-state gate in the device refresh SOP

Before any device is submitted for Autopilot provisioning, the assigning engineer must confirm in Intune admin center (**Devices > All devices**) that no active device record exists for that serial number. If a record exists, it must be retired and confirmed removed before the device reaches the technician.

**Owner:** Device Engineering / Endpoint Operations lead  
**Target:** All devices in the current Autopilot refresh programme  

---

#### 2. Proactively identify and retire all surviving legacy MDM records from the 2023 cohort

Run a bulk query in Intune or via Microsoft Graph API to surface all devices enrolled before a specified cutoff:

```
GET /deviceManagement/managedDevices?$filter=enrolledDateTime lt 2024-01-01T00:00:00Z and managementAgent eq 'mdm'
```

Review the list, cross-reference against the Autopilot refresh schedule, and retire records for devices that are in scope before they reach the provisioning queue.

**Owner:** Intune / MDM administrator  
**Target:** All devices with `enrolledDateTime` before 2024-01-01 and `managementAgent: mdm`  

---

#### 3. Add Autopilot pre-flight validation to device preparation checklist

Add the following as mandatory checklist items in the device preparation form completed before handing off to the provisioning technician:

- [ ] Device serial confirmed in Autopilot device list with profile assigned
- [ ] No active Intune device record exists for this serial (or record has been retired and confirmed cleared)
- [ ] Device is in the correct AAD group for Autopilot profile targeting
- [ ] `dsregcmd /status` run on device confirms `WorkplaceJoined: NO` before reset

---

#### 4. Alert on Autopilot enrolment failures by error code in Intune

Configure a Monitor alert or Log Analytics query against Intune audit logs to trigger on `0x80180014` events. This surfaces any device hitting the same failure without requiring manual review of individual enrolment states.

**Query target:** Intune Audit Logs / Endpoint Analytics — filter on enrollment failure events containing `80180014`.

---

## Verification Checks to Close This Incident

| Check | Expected Result |
|---|---|
| `dsregcmd /status` — `AzureAdJoined` | `YES` |
| `dsregcmd /status` — `MDMEnrolled` | `YES` — enrolment date 2026-08-11 |
| `dsregcmd /status` — `WorkplaceJoined` | `NO` |
| Intune > All devices — device record enrolment date | 2026-08-11 (new record only, old record absent) |
| Intune > Device detail — Profiles Applied | 4 of 4 |
| Intune > Device detail — Autopilot profile | Assigned |
| User sign-in and resource access | Successful — no credential loops or access errors |

---

## Gaps and To-Verify Items

| Item | Action Required |
|---|---|
| Exact timestamp of the 2026-08-11 enrolment attempt | Check Intune audit logs: **Devices > Monitor > Audit logs**, filter by device and action = Enrol |
| Whether any prior retire/wipe actions were attempted against the 2023 record | Check Intune audit logs filtered by device serial across full history |
| Count of other devices in the estate with legacy enrolment records pre-dating 2024 | Run Graph API query (see Preventive Action 2) |
| Whether the current device refresh SOP documents an MDM clean-state gate | Review SOP with Device Engineering lead |
| Device name and assigned user | Confirm from asset register and Intune device record |

---

## Executive Summary

A Windows 11 device failed Autopilot enrolment on 2026-08-11 because a legacy manual MDM enrolment from November 2023 was never retired before the device entered the Autopilot provisioning workflow. Autopilot correctly rejected the enrolment attempt with error `0x80180014` ("Device is already enrolled in MDM"), and no configuration profiles were applied as a result. Licensing, Azure AD join state, and network connectivity were all confirmed healthy and are not contributing factors. Immediate remediation requires retiring the stale Intune record, removing the legacy work account from the device, and re-triggering Autopilot from a clean OOBE state. Systemically, the device refresh SOP must be updated to include a mandatory pre-flight gate confirming no active MDM record exists before Autopilot provisioning is initiated. A proactive bulk-retirement exercise is recommended to clear all surviving legacy records from the 2023 manual-enrolment cohort before they cause the same failure at scale.
