# L2/L3 KB: Autopilot Enrolment Failure (0x80180014) — Stale MDM Record Conflict

**Version:** 1.0  
**Date:** 07-08-2026  
**Status:** Draft  
**Audience:** DWP Engineers, Intune Administrators, Endpoint Operations  
**Severity:** High (blocks device provisioning)

---

## Background

### What the System Does

Windows Autopilot is Microsoft's zero-touch deployment service for Windows devices. It detects a device's hardware identity (serial number) in Azure AD and assigns a deployment profile containing OOBE (Out-of-Box Experience) customizations, compliance policies, and configuration profiles. Autopilot executes these settings automatically during device setup without manual intervention.

**Prerequisites for successful Autopilot enrolment:**
- Device hardware identity registered in Intune (`Devices > Enrollment > Windows > Autopilot devices`)
- Azure AD tenant can reach Intune service endpoints
- No conflicting MDM enrolment record on the device or in Intune for that serial number
- Device is in OOBE state (factory reset or clean Windows installation)

### Why It Matters

Autopilot is the standard device provisioning path for the organization. Blocking this flow delays device deployment, increases IT operational costs (manual setup required), and degrades user experience. When Autopilot fails at scale due to a systemic cause, it can affect hundreds of devices.

---

## Symptom

### What the Engineer Observes

**Primary indicator:** Device provisioning halts during Autopilot OOBE. One or more of:

- Autopilot progress screen shows spinning wheel for >25 minutes without advancing
- Device returns to sign-in screen without applying any profiles
- User reports "device won't set up" or "keeps asking to restart"
- MDM diagnostic export (from device or via `Get-MsolDevice` query) shows:
  - `EnrollmentState: Failed`
  - `ErrorCode: 0x80180014`
  - `ErrorDescription: The device is already enrolled in MDM`
  - `ProfilesApplied: 0 of 4` (or 0 of N, where N is expected profile count)
  - `LastError: 0x80070005` (Access Denied)

**Secondary indicators:**
- Intune audit logs show Autopilot enrolment attempt returning HTTP error with message containing "already enrolled"
- Device `Settings > Accounts > Access work or school` lists two work accounts: one from 2023–2024 (legacy) and one from current date (failed attempt)

### What the User Reports

- "My device won't finish setup" or "setup is stuck"
- "I see a message about being enrolled already"
- "IT tried to set up my device but it failed"
- No user-triggerable action caused this; it occurs immediately upon Autopilot OOBE

---

## Root Cause

### The Technical Failure

**Primary root cause:** A stale legacy manual MDM enrolment record exists on the device and/or in the Intune backend for that device serial number, and this record was never retired before the Autopilot enrolment attempt.

**Mechanism:**
1. Device was enrolled via legacy manual MDM method (pre-Autopilot transition, typically 2023–early 2024)
2. Device remains in service under legacy MDM management
3. Device is later scheduled for Autopilot refresh (re-provisioning programme)
4. At Autopilot OOBE, the Autopilot service calls Microsoft Intune to enrol the device
5. Intune detects an active MDM enrolment record for that serial number
6. Intune returns HTTP 409 Conflict (translated by Autopilot to error `0x80180014`)
7. Autopilot provisioning halts; no profiles are pushed; device loops or returns to sign-in

**Why this happens:**
- Device refresh SOP lacks a pre-flight gate requiring confirmation that any existing Intune device record has been retired before Autopilot provisioning is initiated
- Legacy manual-enrolment devices were not offboarded as part of the transition to Autopilot
- Assumption was made that all devices entering Autopilot queue were in a clean state (no pre-existing records)

### Evidence That Confirms This Root Cause

**Direct evidence:**
1. **Error code `0x80180014` is Microsoft-documented** — means "Device is already enrolled in MDM". No other known cause produces this exact code.
2. **MDM diagnostic export field `MDMEnrolled: Yes` with date prior to 2024** (e.g., 2023-11-04) — confirms an enrolment record exists and predates the Autopilot attempt
3. **MDM diagnostic export field `EnrolmentSource: Legacy manual MDM enrolment`** — confirms the record was not created by Autopilot or Hybrid Join
4. **`ProfilesApplied: 0 of 4`** — direct consequence of enrolment being blocked; profiles cannot be pushed if the device is not enroled in the first place
5. **`LastError: 0x80070005` (Access Denied) on profile push** — secondary error; the device is trying to pull profiles but is denied because enrolment was rejected

**Supporting evidence:**
- Device listed in `Settings > Accounts > Access work or school` shows work account entry from 2023 (confirming legacy record exists locally)
- Intune audit log shows no `Retire` or `Wipe` action against this serial number between 2023-11-04 and 2026-08-11 (confirming the record was never offboarded)

---

## Detection

### How to Confirm This Is the Issue (Step-by-Step)

#### Detection Step 1: Capture MDM Diagnostic Export from the Device

**Location:** Device running Windows 11 in OOBE or signed-in state  
**Action:** Open PowerShell as Administrator and run:
```powershell
Get-MdmDiagnosticData -Out C:\Temp\MDMDiag.xml
```
Or navigate to `Settings > Accounts > Access work or school` > select account > **Info** > **Export diagnostic data**

**What to look for:**
- Field `EnrollmentState` — should show `Failed` (not Succeeded, not Pending)
- Field `ErrorCode` — should show `0x80180014` (in decimal) or `80180014` (in hex, depending on log format)
- Field `MDMEnrolled` — should show `Yes` with a date field showing `MDMEnrollmentDate: 2023-11-04` (or earlier; date before current year)
- Field `EnrolmentSource` — should show `Legacy manual MDM enrolment` or `ManualEnrollment`
- Field `ProfilesApplied` — should show `0 of [N]` (zero profiles applied)
- Field `LastError` — should show `0x80070005` (Access Denied)

**Comparison check:** On a **working** device that successfully completed Autopilot:
- `EnrollmentState: Succeeded` (not Failed)
- `MDMEnrolled: Yes` with `MDMEnrollmentDate: 2026-08-11` (today's date, not 2023)
- `EnrolmentSource: Autopilot` or `AutopilotProfileDriven` (not Legacy)
- `ProfilesApplied: 4 of 4` (all profiles applied, not zero)
- `LastError: [blank]` or `0` (no error)

If your broken device matches the first pattern and working device matches the second, you have a match.

---

#### Detection Step 2: Verify the Legacy Record Exists in Intune

**Location:** Intune Admin Center > `https://intune.microsoft.com`  
**Path:** **Devices > All devices**

**Action:**
1. In the search box, type the device serial number (from IT asset register or `Settings > System > About > Device name`)
2. Press Enter
3. Look at the results — you should see **at least one** device record for this serial

**What to look for:**
- **Old record (legacy):** Look for a record with `Enrolled date` showing `11/4/2023` or earlier (before 2024-01-01)
  - `Owner` field may show `[Unknown]` or a generic account name (legacy enrolments often had no user assigned)
  - `Enrollment date` column displays the critical field here
- **New record (failed Autopilot):** You may also see a record with `Enrolled date` showing today's date (2026-08-11)
  - This represents the failed Autopilot attempt

**Example comparison:**
```
| Enrolled Date | Device Name | Serial | Enrollment Source | Status |
|---|---|---|---|---|
| 11/4/2023 | DEVICE-XYZ-001 | SN-12345 | Manual | Retire pending |
| 8/11/2026 | DEVICE-XYZ-001 | SN-12345 | Autopilot | Failed |
```

If you see two records for the same serial with different enrollment dates, this is diagnostic.

---

#### Detection Step 3: Check Intune Audit Log for Retire History

**Location:** Intune Admin Center > `https://intune.microsoft.com`  
**Path:** **Devices > Monitor > Audit logs**

**Action:**
1. Click **Audit logs**
2. In the search filters, select **Category** > **Device management**
3. Enter the device serial number in the search box (or device name)
4. Set date range to last 90 days
5. Click **Search**

**What to look for:**
- Look for entries with `Activity` = `Retire device` or `Delete device` or `Wipe device` for this serial number
- Check the `Date` field — if no retire/wipe/delete actions appear, the device was never offboarded
- **Expected for failed case:** No retire/wipe actions, device record shows enrolment date 2023-11-04 with no offboarding
- **Expected for successful case:** At least one `Retire device` action before the Autopilot attempt date

**Comparison check:** Query a device that successfully completed Autopilot refresh:
- Audit log should show a `Retire device` action (dated before current Autopilot enrolment)
- Followed by a new `Enroll device` action (dated after retire)

---

#### Detection Step 4: Verify Device Cannot Access Intune Endpoint After Autopilot Halt

**Location:** Device in OOBE or sign-in state  
**Action (if device can access PowerShell):** Run:
```powershell
Test-NetConnection enterpriseregistration.windows.net -Port 443
```

**What to look for:**
- `TcpTestSucceeded: True` — network connectivity is fine (not the cause)
- If `False`, firewall/proxy is blocking Intune endpoints (separate issue; escalate to network team)

**On a working device (post-Autopilot):** Run:
```powershell
dsregcmd /status
```
Look for:
- `AzureAdJoined: YES`
- `MDMEnrolled: YES`
- `MDMUrl: https://enterpriseregistration.windows.net/EnrollmentServer/device/[GUID]` (non-empty)
- `WorkplaceJoined: NO` (no conflicting legacy entry)

**On a broken device (stuck Autopilot):** Run same command, look for:
- `WorkplaceJoined: YES` OR `MDMEnrolled: Yes` with an old date
- This confirms the legacy record is still present locally on the device

---

#### Detection Step 5: Correlate with Autopilot Deployment Profile Assignment

**Location:** Intune Admin Center > `https://intune.microsoft.com`  
**Path:** **Devices > Enrollment > Windows > Autopilot devices**

**Action:**
1. Search for the device serial number
2. Check the `Deployment profile` column — confirm a profile is assigned

**What to look for:**
- Device should appear in this list with a profile assigned (e.g., "Default Autopilot Profile")
- If device does NOT appear here at all, it was never registered with Autopilot (separate issue; contact Device Engineering)
- If it appears but profile shows blank or `Not assigned`, the profile assignment may not have propagated yet (wait 10 minutes and recheck)

---

## Resolution

### Step-by-Step Fix (With Expected Results)

#### Resolution Step 1: Access Intune Admin Center and Locate the Legacy Device Record

**Location:** `https://intune.microsoft.com`  
**Path:** **Devices > All devices**  
**Required Permission:** `Intune Administrator` or `Global Administrator` role

**Action:**
1. Sign in to Intune admin center
2. Click **Devices** (left sidebar)
3. Click **All devices**
4. In the search box at the top, type the device serial number
5. Press Enter

**Expected result:** One or more device records appear in the list. Identify the record with `Enrolled date: 11/4/2023` or earlier (the legacy record). Select it by clicking on the name.

---

#### Resolution Step 2: Retire the Legacy Device Record (NOT Wipe)

**Location:** Intune Admin Center  
**Path:** **Devices > All devices > [device record] > [top menu bar]**  
**Required Permission:** `Intune Administrator` or `Global Administrator` role

**Action:**
1. With the legacy device record selected (dated 2023-11-04), look at the top menu bar of the device detail pane
2. Click the **Retire** button (do NOT click "Wipe" — Retire removes MDM management only; Wipe erases all data)
3. If you do not see a **Retire** button, click the three-dot menu ("...") and select **Retire** from the dropdown

**Expected result:** A confirmation dialog appears asking "Are you sure you want to retire this device?" Click **Yes** to confirm. The device detail pane should update to show status `Retire pending` or `Retire in progress`.

---

#### Resolution Step 3: Monitor Retire Action and Wait for Completion

**Location:** Intune Admin Center  
**Path:** **Devices > All devices > [device record]**

**Action:**
1. Do NOT proceed to the next step until retire completes
2. Refresh the device record page (F5) every 2–3 minutes
3. Watch the device status field — after ~15 minutes, the status should change to `Retire completed` or the record should disappear from the All devices list

**Expected result after ~15 minutes:** 
- Device record status shows `Retired` or similar
- If you navigate back to **Devices > All devices** and search for the same serial, the 2023-dated record should no longer appear (or show a `Retired` status)
- The device is no longer registered as actively enrolled in MDM

**If status shows "Retire failed":** Stop here. Note the error code and escalate to Intune admin. Do NOT proceed to device-side steps.

---

#### Resolution Step 4: On the Device — Disconnect the Legacy Work Account

**Location:** Device running Windows 11  
**Path:** `Settings > Accounts > Access work or school`  
**Required Permission:** Local admin or user account on device (physical or remote access required)

**Action:**
1. On the device, open Settings (`Start > Settings` or `Windows Key + I`)
2. Click **Accounts** (left sidebar)
3. Click **Access work or school**
4. You should see one or more work/school account entries. Locate the entry from 2023 (it may show a date or company name from the legacy enrolment)
5. Click on that account entry
6. Click **Disconnect**
7. A confirmation dialog appears: "Disconnect this account?" Click **Disconnect** or **Yes**

**Expected result:** 
- The work account entry disappears from the list
- Settings window may show "You've disconnected your work account" or similar message
- If there are multiple work accounts, repeat this step for each one until the list is empty or shows only entries you expect

---

#### Resolution Step 5: Restart the Device

**Location:** Device  
**Action:**
1. On the device, press `Windows Key + I` to open Settings (if not already open)
2. Click **Power** (bottom left) > **Restart**
3. Allow the device to restart completely (2–5 minutes)
4. Device will boot to sign-in screen or desktop, depending on its state

**Expected result:** Device restarts without error. No MDM enrollment notifications appear during startup.

---

#### Resolution Step 6: Verify Clean State with dsregcmd

**Location:** Device  
**Action:**
1. After restart, open PowerShell or Command Prompt as Administrator
2. Run:
   ```
   dsregcmd /status
   ```
3. Read the output carefully

**Expected result — critical fields to verify:**
- `WorkplaceJoined : NO` (must be NO; confirms legacy work account is gone)
- `MDMUrl` field should **not appear** in the output, or should be empty/blank
- `AzureAdJoined : YES` (this should remain YES; Azure AD join is independent)
- `MDMEnrolled` should show `NO` or not appear (the device is no longer enrolled under the old record)

**If you see:**
- `WorkplaceJoined : YES` — stop. The legacy account did not fully disconnect. Wait 2 more minutes and run `dsregcmd /status` again. If it persists after 5 minutes, escalate.
- `MDMUrl` still present with an Intune URL — wait 2 minutes, then retry. If present after 5 minutes, the retire may not have completed on the backend; wait another 5 minutes.

---

#### Resolution Step 7: Confirm Device is Ready in Autopilot List

**Location:** Intune Admin Center  
**Path:** **Devices > Enrollment > Windows > Autopilot devices**

**Action:**
1. Return to Intune admin center
2. Navigate to **Devices > Enrollment > Windows > Autopilot devices**
3. Search for the device serial number
4. Confirm the device appears in the list with `Deployment profile` column showing a profile name (e.g., "Default Autopilot Profile")

**Expected result:** 
- Device is listed and shows a deployment profile assigned
- Status should be `Registered`, `Pending`, or `Active`
- If device does NOT appear in Autopilot list, contact Device Engineering to confirm registration before proceeding

---

#### Resolution Step 8: Trigger Autopilot Reset from Device

**Location:** Device  
**Path:** `Settings > System > Recovery > Reset this PC`  
**Required Permission:** Local admin or user on device

**Action:**
1. On the device, open Settings (`Start > Settings`)
2. Click **System** (left sidebar)
3. Scroll down and click **Recovery**
4. Click the **Reset this PC** button
5. A window appears with two options: **Keep my files** and **Remove everything**
6. Click **Remove everything** (this initiates a full reset back to OOBE)
7. **⚠️ WARNING:** This will erase all local user data, files, and apps on the device. Ensure no critical unsaved work exists before confirming.

**Expected result:** System begins restart sequence. You will see a spinner / progress bar. After 5–10 minutes, device boots into Windows OOBE (Out-of-Box Experience) with blue setup screen.

---

#### Resolution Step 9: Allow Autopilot to Auto-Detect and Provision

**Location:** Device at OOBE  
**Action:**
1. At OOBE, do NOT manually click through setup steps yet
2. Autopilot will auto-detect the device and display a message like "Microsoft Autopilot configuration in progress" or "Setting up your device for your organization"
3. Let this run without interruption (do NOT close dialogs, restart, or force shutdown)
4. Wait 10–20 minutes while Autopilot provisioning completes in the background

**Expected result:**
- After 10–20 minutes, OOBE will complete and device will show sign-in screen
- Device will have applied all four compliance/configuration profiles automatically
- No error messages about "already enrolled" or `0x80180014`
- Device is ready for user sign-in

**If Autopilot stalls or loops after 25 minutes:** See Rollback section (Scenario 1).

---

## Verification

### How to Confirm the Fix Worked

#### Verification Check 1: Device Registry and Join State (On Device)

**Location:** Device  
**Action:** Open PowerShell as Administrator and run:
```powershell
dsregcmd /status
```

**Verify these exact fields:**
- `AzureAdJoined : YES` ✓
- `MDMEnrolled : YES` ✓
- `MDMEnrollmentDate` shows today's date (e.g., `8/11/2026`), NOT 2023 ✓
- `WorkplaceJoined : NO` ✓ (no legacy entry)
- `MDMUrl` field is present and contains `https://enterpriseregistration.windows.net/EnrollmentServer/device/[GUID]` ✓

---

#### Verification Check 2: Intune Device Record (In Intune)

**Location:** Intune Admin Center > **Devices > All devices**  
**Action:**
1. Search for device serial number
2. Open the device record
3. Verify these fields:

**Verify:**
- Only **ONE** device record for this serial exists (the 2023 record is gone) ✓
- `Enrolled date` shows **today's date** (2026-08-11), NOT 2023 ✓
- Device detail pane shows a **Deployment profile** assigned (e.g., "Default Autopilot Profile") ✓
- Scroll down to **Device compliance** or **Compliance** section — should show `4 of 4 profiles applied` (all compliant) or similar ✓
- No error codes or `LastError` field showing in the detail pane ✓

---

#### Verification Check 3: Autopilot Profile Assignment (In Intune)

**Location:** Intune Admin Center > **Devices > Enrollment > Windows > Autopilot devices**  
**Action:**
1. Search for device serial
2. Verify the device appears with status

**Verify:**
- Device is listed in Autopilot devices ✓
- `Deployment profile` column shows a profile name (not blank) ✓
- Status shows `Active` or `Assigned` (not `Failed` or `Error`) ✓

---

#### Verification Check 4: User Sign-In and Resource Access (On Device)

**Location:** Device at sign-in screen  
**Action:**
1. Sign in with the assigned user's credentials (email@company.com or username)
2. Wait 30 seconds for profile policies to apply
3. Test resource access:
   - Open File Explorer and navigate to a mapped network share (e.g., `\\fileserver\sharename`)
   - Open Microsoft Teams or Outlook (if applicable)
   - Verify icons/shortcuts appear on desktop as expected (set by Autopilot profile)

**Verify:**
- User signs in without repeated password prompts ✓
- User can access file shares, Teams, email without "Access denied" errors ✓
- No error dialogs during sign-in or app launch ✓

---

#### Verification Check 5: Windows Event Logs (On Device) — Optional

**Location:** Device  
**Action:** Open Event Viewer (`eventvwr.msc`) > **Windows Logs > System**

**Look for:**
- In the last 30 minutes, any entries with **Source** = "Microsoft-Windows-Workplace-Join" or "DeviceEnrollment"
- Entries should show **Success** (green checkmark) or **Information**, NOT **Error** or **Critical**
- Specifically look for events with message "Workplace join succeeded" or "Device enrolled successfully"

**Verify:**
- No `Error` level events mentioning MDM, Intune, or enrollment ✓
- Recent `Information` or `Success` events show device join/enrolment succeeded ✓

---

**All five verification checks passed?** → **Incident resolved. Safe to close ticket.**

---

## Rollback

### If the Fix Makes Things Worse

#### Rollback Scenario 1: Device Stuck in Autopilot OOBE After Reset (Step 9)

**Symptoms:** After full reset (step 8), device is at OOBE with "Setting up your device" message for >30 minutes; no progress.

**Immediate actions:**
1. **Force device restart:** Power off the device (hold power button 10 seconds), then power back on
2. **Check network connectivity:** Ensure device is connected to wired Ethernet or has Wi-Fi connected
3. **Wait 25 full minutes** after restart for Autopilot to detect and apply profiles (do not interrupt)

**If still stuck after 25 minutes:**
1. **In Intune admin center:** Go to **Devices > All devices**, search for device serial
2. **Verify the device record exists and shows a profile assignment** — if yes, continue to next step
3. **Click **Sync** in the top menu of the device detail pane** — this forces Intune to push the profile again
4. **On device:** Restart again and wait another 10 minutes
5. **If still stuck:** Escalate to Device Engineering with:
   - Device serial number
   - Screenshot of OOBE message
   - Intune audit log entries (see Detection > Step 5 for audit log path)

---

#### Rollback Scenario 2: After Retirement, Device Cannot Reach Azure AD / Intune

**Symptoms:** After step 5 (disconnect), device shows no network connectivity to Intune services, or `dsregcmd /status` shows `AzureAdJoined: NO`.

**Immediate actions:**
1. **Verify network connectivity:** Test `ping google.com` in PowerShell — if this fails, network is down (not this incident)
2. **Test Intune endpoint access:**
   ```
   Test-NetConnection enterpriseregistration.windows.net -Port 443
   ```
   Should show `TcpTestSucceeded: True`
   - If `False`: Network/firewall is blocking Intune. Contact network team.
3. **If network is fine but Azure AD join is lost,** proceed to step 8 (full reset) immediately — this will re-establish both Azure AD join and Autopilot enrolment

---

#### Rollback Scenario 3: Retire Action Failed in Intune (Step 3)

**Symptoms:** After 20 minutes, Intune still shows "Retire pending" or "Retire failed" status.

**Immediate actions:**
1. **Check if device is online in Intune:** Navigate to device record in **Devices > All devices**. Look for `Last check-in` timestamp — if older than 1 hour, device may be offline.
   - **If offline:** Power on the device, connect to network, wait 10 minutes for it to report to Intune, then retry Retire
2. **If device is online,** retry Retire:
   - Click the Retire button again (sometimes transient failure)
   - Wait another 15 minutes
3. **If Retire still fails,** try **Wipe** instead:
   - ⚠️ WARNING: Wipe erases all data on the device. Only use if:
     - Data backup exists or user has no critical local data
     - User permission is obtained
   - Click the **Wipe** button in device detail pane
   - Wait 15 minutes for Wipe to complete (more forceful than Retire; usually succeeds)
4. **If Wipe also fails,** escalate to Intune administrator with:
   - Device serial number and name
   - Screenshot of the error message
   - Error code shown in Intune (if any)

---

#### Rollback Scenario 4: Multiple Work Accounts Remain After Disconnect (Step 4)

**Symptoms:** After step 4, `Settings > Accounts > Access work or school` still shows 1+ work account entries.

**Immediate actions:**
1. **Disconnect all remaining entries:**
   - Click each remaining work account
   - Click **Disconnect**
   - Confirm the disconnect
   - Repeat until the list is empty
2. **Wait 2 minutes**, then reopen Settings > Accounts > Access work or school to confirm all are gone
3. **If entries reappear after disconnect,** the MDM backend may be re-adding them — proceed to full reset (step 8) without waiting further

---

#### Rollback Scenario 5: Error 0x80180014 Recurs After All Steps Completed

**Symptoms:** After completing all resolution steps and Autopilot profile was supposedly applied, a second Autopilot attempt shows `0x80180014` again.

**Immediate actions:**
1. **Check for a second legacy record:**
   - In Intune admin center, navigate to **Devices > All devices**
   - Search for device serial
   - If you see **two** records (one from 2023, one from 2026), the 2023 record retire did not complete fully
2. **Retry retirement of the 2023 record:**
   - Select the 2023-dated record
   - Click **Retire**
   - Wait 20 minutes (not 15 — give it more time)
   - Verify in Intune audit logs that retire succeeded: **Devices > Monitor > Audit logs**, filter by device serial, look for `Activity: Retire device` with `Result: Success`
3. **If retire succeeds on second attempt:**
   - Return to device and reboot
   - Trigger Autopilot reset again (step 8)
4. **If retire still fails,** escalate with full device history: serial number, all audit log entries, and error codes encountered

---

## Preventive

### Specific Process and Tooling Changes to Prevent Recurrence

#### Preventive Action 1: Mandate Pre-Flight MDM Clean-State Gate in Device Refresh SOP

**Current problem:** Devices entering Autopilot provisioning are not verified to have a clean MDM state (no pre-existing Intune records).

**Specific change:**
1. **Update the Device Refresh SOP document** (owned by Device Engineering) to include a new mandatory step:
   - **Title:** "Pre-Autopilot Device Verification"
   - **Timing:** Before device reaches technician for Autopilot provisioning
   - **Action:** Device Engineering engineer runs this query in Intune:
     ```
     GET /deviceManagement/managedDevices?$filter=deviceName eq '[DEVICE_SERIAL]'
     ```
   - **Gate condition:** If any record is returned with `enrolledDateTime` prior to today's date, the record must be retired and confirmed removed before device proceeds to technician
   - **Sign-off:** SOP must require documented sign-off: "Device [SERIAL] verified clean MDM state on [DATE]" before assignment to technician
2. **Add this step to the device handoff checklist** before technician receives the device

**Owner:** Device Engineering lead  
**Target completion:** Before next batch of devices enters Autopilot queue

---

#### Preventive Action 2: Bulk Identification and Retirement of Legacy MDM Records

**Current problem:** ~[N] devices from the 2023 manual-MDM cohort are still in Intune with active legacy records. Each is at risk for this failure.

**Specific change:**
1. **Run this query in Intune to surface all at-risk devices:**
   - **Location:** Intune Admin Center > **Devices > All devices**
   - **Filter:** Add column filter:
     - `Enrollment type: User enrollment` OR `Manual enrollment`
     - `Enrolled date: before 1/1/2024`
   - **Export:** Export the list to CSV
2. **Cross-reference the export against Device Refresh Schedule:**
   - Obtain the Device Refresh Schedule from Device Engineering (contains list of devices scheduled for Autopilot in next 30/60/90 days)
   - Identify devices in the exported list that are also on the refresh schedule (these are the highest-risk devices)
3. **Retire devices in batches:**
   - For each device on the intersection list, navigate to Intune > **Devices > All devices**
   - Select the legacy record (dated pre-2024)
   - Click **Retire**
   - Wait 15 minutes for each retire to complete
   - Document each retirement in a log: "[SERIAL], [DATE], Retire successful" or "Retire failed: [ERROR_CODE]"
4. **Retry any failures:**
   - For any retire that shows "failed", retry after 10 minutes or escalate if error persists

**Owner:** Intune Administrator  
**Target completion:** Retire all at-risk devices **before they are scheduled for Autopilot reset**  
**Estimated effort:** 2–4 hours for [N] devices (assume 1 retire per 3 minutes)

---

#### Preventive Action 3: Configure Automated Alerting on Error 0x80180014

**Current problem:** Autopilot enrolment failures are not surfaced in real-time; incidents are discovered reactively when users report issues.

**Specific change:**
1. **Set up alert in Intune > Monitor > Alerts**
   - **Location:** Intune Admin Center > **Devices > Monitor > Alerts**
   - **Alert type:** Create a new alert on Autopilot enrollment failures
   - **Condition:** Trigger when enrolment failure events contain error code `80180014` (hex notation) or `2146893844` (decimal)
   - **Threshold:** Alert on any single occurrence (not batched)
   - **Recipients:** Route to [Endpoint Operations email / team]
   - **Action:** Alert template should include: Device serial number, error code, timestamp, device name
2. **Alternatively, use Log Analytics:**
   - **Location:** Azure portal > **Log Analytics workspace** > query editor
   - **Query:** 
     ```kusto
     IntuneOperationalLogs
     | where ActivityType contains "Enroll" and ErrorCode contains "80180014"
     | project TimeGenerated, DeviceId, DeviceName, ErrorCode, ActivityType
     ```
   - **Alert rule:** Create alert rule on this query
   - **Frequency:** Run hourly
   - **Action:** Notify [Endpoint Operations email]

**Owner:** Intune Administrator / Endpoint Operations  
**Target completion:** Alert configured and tested within 1 week

---

#### Preventive Action 4: Add Device Prep Validation Checklist

**Current problem:** There is no structured pre-provisioning verification step for technicians to confirm device readiness before Autopilot provisioning is triggered.

**Specific change:**
1. **Create a Device Prep Validation Checklist** (to be completed by Device Engineering before handing off device to provisioning technician):
   ```
   [ ] Device serial confirmed in Autopilot device list with deployment profile assigned
   [ ] No active Intune device record exists for this serial 
        (or if one exists, it has been retired and confirmed removed)
   [ ] Device is a member of correct Azure AD group for Autopilot profile targeting
   [ ] Device is in OOBE state or ready for factory reset
   [ ] dsregcmd /status run on device confirms WorkplaceJoined: NO before reset
   [ ] Device serial documented with sign-off: "Verified clean by [ENGINEER NAME] on [DATE]"
   ```
2. **Make checklist mandatory:**
   - Add to device handoff form or ticketing system
   - Require checklist to be 100% complete before device reaches technician
   - No device proceeds to provisioning without all checks signed off
3. **Store completed checklists:**
   - Retain in ticket or asset management system for audit trail

**Owner:** Device Engineering / Endpoint Operations  
**Target completion:** Checklist implemented in next device batch

---

#### Preventive Action 5: Document and Train on This Incident

**Current problem:** No documented runbook or L2/L3 KB for this specific failure pattern; knowledge is scattered or anecdotal.

**Specific change:**
1. **Publish this KB article** to your internal knowledge base (Confluence, SharePoint, ServiceNow, etc.) with the path:
   - `IT > Endpoint Management > Autopilot > Known Issues > 0x80180014 - Device Already Enrolled`
2. **Add link to runbook:**
   - Publish the L2/L3 runbook (this document) alongside the KB
3. **Train L1 support:**
   - Schedule 15-minute training for L1 support staff on how to identify `0x80180014` and escalate to L2
   - Provide L1 with the L1/self-service KB article (end-user facing) so they can direct users to self-help first
4. **Train L2 / Endpoint Operations:**
   - Schedule 30-minute training for L2 engineers on how to execute the runbook and troubleshoot using the detection steps
   - Emphasize the ordering constraint: **Retire in Intune BEFORE reset on device**

**Owner:** L2 / Endpoint Operations lead  
**Target completion:** Training scheduled and completed within 2 weeks

---

## Related

### Other Incidents and KB Articles

| Related Item | Connection | Location | Action |
|---|---|---|---|
| **KB: Autopilot Enrolment Timeout (No Progress)** | Similar symptom (provisioning halts) but different cause — this is typically network/firewall blocking Intune endpoints, not MDM conflict. If user reports "setup stuck" but error code is NOT `0x80180014`, refer to that KB. | [Internal KB URL] | Cross-reference in Symptom section |
| **KB: Azure AD Join Failed** | If a device loses Azure AD join status (rare), it cannot proceed with Autopilot. This is separate from 0x80180014 but can occur in same refresh batch. | [Internal KB URL] | Related preventive: Same pre-flight gate should catch unhealthy Azure AD state |
| **Incident: Device Refresh Programme Delays (Aug 2026)** | If this incident occurs at scale (>10 devices), may indicate systemic gap in legacy MDM cohort retirement. Correlate with device refresh schedule. | [Incident ticket URL] | Escalate if bulk failures detected |
| **RCA: Autopilot Enrolment Failure — Stale MDM Conflict (2026-08-11)** | Root cause analysis covering this same incident; contains evidence assessment and timeline. | [rca-autopilot-enrolment-failure-mdm-conflict-2026-08-11.md](rca-autopilot-enrolment-failure-mdm-conflict-2026-08-11.md) | Reference for full incident context |
| **Runbook: Autopilot Enrolment Failure 0x80180014** | Operational step-by-step runbook for resolving this issue. | [runbook-autopilot-enrolment-failure-0x80180014-2026-08-11.md](runbook-autopilot-enrolment-failure-0x80180014-2026-08-11.md) | Use for resolution execution |
| **L1 KB: Device Won't Set Up Properly (Self-Service)** | End-user facing KB for this issue. Direct users here for self-help troubleshooting. | [l1-kb-device-setup-failure-self-service-2026-08-11.md](l1-kb-device-setup-failure-self-service-2026-08-11.md) | Share with L1 support for user escalation path |

---

## Document Control

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 07-08-2026 | DWP Analyst | Initial version; incident resolved 2026-08-11 |

**Last Updated:** 07-08-2026  
**Next Review:** 30 days (to verify preventive actions implemented)
