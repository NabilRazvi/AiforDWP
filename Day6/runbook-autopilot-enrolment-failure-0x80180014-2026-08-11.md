# Runbook: Resolve Autopilot Enrolment Failure (Error 0x80180014)

**Incident:** Device fails Autopilot enrolment with error code `0x80180014` ("Device is already enrolled in MDM")  
**Root Cause:** Stale legacy MDM enrolment record from prior to 2024 was never retired before Autopilot attempt  
**Estimated Time to Resolution:** 25–30 minutes (includes 15-minute Intune retire processing time)  
**Last Updated:** 2026-08-11

---

## 1. Prerequisites

Before starting this runbook, verify you have:

### Access & Permissions
- [ ] **Intune admin center access** — must have role: `Intune Administrator` or `Global Administrator` to retire device records
- [ ] **Physical or remote access to the affected device** — Windows 11 endpoint with local admin or built-in admin account
- [ ] **Device serial number or hostname** — required to locate the device in Intune (check IT asset register or device itself: `Settings > System > About > Device name`)

### Tools & Systems
- [ ] **Intune admin center** — https://intune.microsoft.com (fully loaded in browser)
- [ ] **Device:** Windows 11; able to access Settings app; able to open PowerShell or Command Prompt (elevated)
- [ ] **Network connectivity:** Device must reach Microsoft endpoints (Intune, Azure AD); no proxy or firewall blocking the device from Intune endpoints
- [ ] **Device-side verification tool:** `dsregcmd` (built into Windows; no install needed)

### Pre-Checks (Run These Before Proceeding)
1. **On the device:** Open `Settings > Accounts > Access work or school` — confirm you see *two* entries: one from ~2023 (legacy) and possibly one from 2026 attempt
2. **In Intune:** `Devices > All devices` — search by device serial or hostname; confirm you see the device record with enrolment date showing 2023-11-04 or earlier
3. **Have the device serial number and current assigned user on hand** — you will need both during the procedure

---

## 2. Procedure

### Phase A: Intune Admin Center (Retire Legacy Record)

**Step 1: Sign in to Intune admin center**
- **Action:** Open https://intune.microsoft.com in a browser; sign in with your admin account (role: Intune Administrator or Global Administrator)
- **Expected result:** You land on the Intune home page; no authentication errors

**Step 2: Navigate to All Devices view**
- **Action:** Click **Devices** (left sidebar) > **All devices**
- **Expected result:** A list of enrolled devices loads; you see a search box at the top

**Step 3: Search for the affected device**
- **Action:** In the search box, type the device serial number (from IT asset register or `Settings > System > About > Device name`); press Enter
- **Expected result:** One or more device records appear; identify the record with `Enrolled date` showing **2023-11-04 or earlier** (the legacy record)
- **Caution:** Do not select a record showing `Enrolled date` of 2026-08-11 or today's date — that may be a second/failed Autopilot attempt record; focus on the 2023 record

**Step 4: Open the legacy device record**
- **Action:** Click on the device record with the 2023 enrolment date to open the detail pane
- **Expected result:** Device detail panel opens on the right side, showing device name, serial, owner, enrolment date, and a row of action buttons at the top

**Step 5: Retire the device record (NOT Wipe)**
- **Action:** At the top of the detail pane, click the **Retire** button (do not click "Wipe" — Retire removes MDM management only; Wipe erases all user data)
- **⚠️ CRITICAL:** If you do not see a **Retire** button, check the top menu bar for a three-dot "..." menu and select Retire from there
- **Expected result:** A confirmation dialog appears asking "Are you sure you want to retire this device?" Click **Yes** to confirm
- **Expected result after confirm:** Status changes to *Retire pending* or *Retire in progress*; button may gray out

**Step 6: Wait for retire action to complete**
- **Action:** Wait **15 minutes** — Intune processes the retire command in the background. Do not close the browser or proceed to step 7 before 15 minutes have elapsed. (Check the device detail pane every 2–3 minutes; refresh the page if needed.)
- **Expected result:** After ~15 minutes, refresh the device record page (F5). The device record should disappear from the list, or show a status of `Retire completed` or `Retire succeeded`
- **If status shows "Retire failed":** Note the error code and stop. Contact the Intune admin / MEM team before proceeding. Do not proceed to the device-side steps.

---

### Phase B: Device-Side (Disconnect Legacy Account & Verify Clean State)

**Step 7: Sign in to the affected device**
- **Action:** On the affected Windows 11 device, sign in with a local admin account or the user's account (if they can log in, use their account; otherwise use a local admin account you have access to)
- **Expected result:** You are at the Windows desktop

**Step 8: Open Settings > Accounts > Access work or school**
- **Action:** Click **Start** > type `Settings` > open Settings app. Navigate to **Accounts** > **Access work or school** (or `Settings > Accounts > Work or school account`)
- **Expected result:** A list of work/school accounts appears. You should see at least one entry (the legacy 2023 enrolment)

**Step 9: Disconnect the legacy work account**
- **Action:** Click on the legacy work account entry (the one showing a date from 2023, or labeled as "work account" / "Intune" from an old enrolment). Click the **Disconnect** button.
- **Expected result:** A prompt appears asking "Disconnect this account?" Confirm by clicking **Disconnect** or **Yes**
- **Expected result after confirm:** The account disappears from the list. The Settings window may show a message like "You've disconnected your work account" or similar.
- **Note:** If you see *two* work account entries, disconnect both (first the 2023 entry, then any 2026 entry)

**Step 10: Restart the device**
- **Action:** Press **Windows key + I** to open Settings (if not already open), then click the **Power** button (bottom left) > **Restart** (or use `Restart-Computer` in PowerShell). Allow the restart to complete (2–5 minutes).
- **Expected result:** Device restarts and returns to the sign-in screen or user desktop

**Step 11: Verify clean state with dsregcmd**
- **Action:** After restart completes, open PowerShell or Command Prompt (as administrator). Type:
  ```
  dsregcmd /status
  ```
  and press Enter. Read the output.
- **Expected result — look for these specific lines:**
  - `WorkplaceJoined : NO` (critical — this must be NO, not YES)
  - `MDMUrl` should **not appear** in the output, or should be empty/blank
  - `AzureAdJoined : YES` (this should remain YES; Azure AD join is independent and unaffected)
  - If you see these exact values, proceed to step 12
  - If `WorkplaceJoined : YES` or `MDMUrl` is still present, the disconnect did not complete; wait 2 more minutes and run `dsregcmd /status` again. If it persists after 5 minutes, stop and escalate (see Rollback section)

---

### Phase C: Intune Admin Center (Verify Autopilot Readiness & Trigger Reset)

**Step 12: Confirm device is in Autopilot device list**
- **Action:** Return to Intune admin center. Navigate to **Devices > Enrollment > Windows > Autopilot devices**
- **Action:** Search for the device by serial number. Confirm you see it listed with a status of **Registered** (or **Pending** if it has not been assigned yet)
- **Action:** Verify the device has an **Autopilot Deployment Profile** assigned (you should see a profile name listed in the profile column)
- **Expected result:** Device is listed with an active Autopilot profile assigned
- **If device is NOT in Autopilot list:** Speak with Device Engineering to confirm the serial was added to Autopilot before re-triggering provisioning. Do not proceed to step 13 until this is confirmed.

---

### Phase D: Device-Side (Trigger Autopilot Reset)

**Step 13: Trigger Autopilot reset from device**
- **Action:** On the device, open **Settings > System > Recovery** (or `Settings > System > Recovery > Reset this PC`)
- **Action:** Click the **Reset this PC** button
- **Expected result:** A window appears with two options: "Keep my files" and "Remove everything". Click **Remove everything** (this is the factory reset option)
- **⚠️ WARNING:** This step will erase all local user data, apps, and files on the device. Ensure no critical unsaved work is on this device before proceeding.

**Step 14: Confirm the reset and allow OOBE to start**
- **Action:** The system will ask "Remove everything?" Click **Next** or **Yes**. The device will begin restarting and will show a spinner / progress bar for several minutes.
- **Expected result:** After 5–10 minutes, the device boots to Windows OOBE (Out of Box Experience) — you will see a blue screen with "Let's get started" or similar text
- **Expected result:** Autopilot will auto-detect and the device will show "Microsoft Autopilot configuration in progress" or similar. Let this run without interruption. Do not close dialogs or restart the device.
- **Expected result:** After 10–20 minutes, Autopilot provisioning will complete, policies/profiles will be applied, and the device will present a sign-in screen. **Do not sign in yet.**

---

## 3. Verification

After Autopilot provisioning completes and before handing the device back to the user, perform these checks:

### Check 1: Device Registry / DSRegCmd (On Device)
- **Action:** Open PowerShell as administrator and run:
  ```
  dsregcmd /status
  ```
- **Verify these fields:**
  - `AzureAdJoined : YES` ✓
  - `MDMEnrolled : YES` ✓ (new enrolment date must be today's date, e.g., 2026-08-11, not 2023-11-04)
  - `WorkplaceJoined : NO` ✓ (must be NO; confirms no legacy entry)
  - Look for `MDMUrl` — should be present and contain an Intune endpoint ✓

### Check 2: Intune Device Record (In Intune Admin Center)
- **Action:** Go to **Devices > All devices**, search by device serial
- **Verify:**
  - Only **one** device record for this serial exists (dated 2026-08-11)
  - The **old 2023 record is gone** (not in the list)
  - Device shows `Enrolled date: 2026-08-11` (or today's date)
  - Scroll down in device detail > **Compliance** or **Device compliance** section — should show **4 of 4 profiles applied** (or similar, all profiles green/compliant)
  - No error codes shown in the device detail view

### Check 3: Autopilot Profile Assignment (In Intune Admin Center)
- **Action:** In Intune, navigate to **Devices > Enrollment > Windows > Autopilot devices**
- **Action:** Locate the device by serial
- **Verify:** The device shows a **Deployment profile** assigned and status is **Assigned** or **Active**

### Check 4: User Sign-In & Resource Access (On Device)
- **Action:** Sign in to the device using the assigned user's credentials
- **Verify:**
  - User signs in without repeated credential prompts
  - User can access expected resources: file shares, Microsoft 365 apps, email (if applicable)
  - No error dialogs during or after sign-in

### Check 5: Windows Event Logs (On Device) — Optional but Recommended
- **Action:** Open Event Viewer (`eventvwr.msc`). Navigate to **Windows Logs > System**
- **Look for:** Any **error** or **warning** events from the last 30 minutes mentioning "MDM", "Intune", or "Enrolment". Blue warnings or info events are normal.
- **Verify:** No critical errors related to MDM/Intune in the recent log

---

**All five checks passed?** → Incident resolved. Proceed to documentation (closure note, etc.).

---

## 4. Rollback

If at any point during the procedure the device state gets worse (for example, device becomes unusable, cannot sign in, or error persists), perform the following rollback:

### Rollback Scenario 1: Device stuck after reset, Autopilot profile not applying

**Symptoms:** Device is at OOBE for >30 minutes; Autopilot configuration message stuck or looping

**Immediate action:**
1. **Force device restart:** Power off the device (hold power button 10 seconds) or restart from OOBE menu
2. **Check Intune connectivity:** Unplug network cable, wait 30 seconds, reconnect. If on Wi-Fi, forget and rejoin network.
3. **Retry Autopilot detection:** Restart device again. Wait a full 25 minutes for Autopilot to detect and apply profiles before concluding this failed.

**If still stuck after 25 minutes:**
1. **In Intune admin center:** Go to **Devices > All devices**. Search for the device. Select it and click **Sync** (in the top menu). Wait 5 minutes.
2. Return to device, restart again, and wait another 10 minutes.

**If Autopilot still not applying after second sync:**
1. **Escalate:** Contact the Device Engineering team and provide the device serial, Intune audit log entries (navigate to **Devices > Monitor > Audit logs**, filter by device serial), and the exact error message from the device if visible.

---

### Rollback Scenario 2: Device no longer connects to Azure AD or Intune after disconnecting work account

**Symptoms:** After step 10, device cannot reach Azure AD, Intune, or internal resources

**Immediate action:**
1. **Verify network connectivity:** Ping a public site (`ping google.com`) to confirm internet access. If internet works but Intune endpoints do not, contact network/firewall team.
2. **Check Intune endpoint access:** Open PowerShell and run:
   ```
   Test-NetConnection enterpriseregistration.windows.net -Port 443
   ```
   Confirm connection succeeds. If it fails, firewall may be blocking.
3. **If network is fine:** The Azure AD join may have been accidentally removed. Proceed to step 13 (full reset) — this will re-establish Autopilot and Azure AD join.

---

### Rollback Scenario 3: "Retire failed" message in Intune (Step 6)

**Symptoms:** After 15 minutes, Intune shows "Retire failed" or "Retire error [code]"

**Immediate action:**
1. **Note the error code** displayed in Intune device record
2. **Do NOT proceed to device-side steps yet.** Stop and escalate to Intune administrator
3. **Common fixes (if you have access):**
   - Try **Retire** again (sometimes transient); wait 5 minutes and retry
   - Try **Wipe** instead of Retire (Wipe is more forceful, but it will erase data; only do this if you have user permission and data is backed up)
   - Check if device is currently connected to Intune: In device detail, look for `Last check-in` timestamp; if older than 1 hour, device may not be reachable. Power on the device and wait 10 minutes for it to check in again, then retry Retire.
4. **If error persists,** escalate with the error code to your Intune admin / Microsoft support

---

### Rollback Scenario 4: After Autopilot completes, device shows "Not compliant" or no profiles appear in Intune

**Symptoms:** dsregcmd looks good, but Intune shows 0 profiles applied or device status is non-compliant

**Immediate action:**
1. **On the device:** Wait 10 minutes after first sign-in (policies take time to sync)
2. **In Intune:** Go to **Devices > All devices > [device] > Device compliance**. Click **Refresh** or wait 5 minutes and reload the page. Profiles may update.
3. **If still 0 profiles after 15 minutes:**
   - On device: Open PowerShell as admin and run `gpupdate /force` (forces Group Policy refresh)
   - In Intune: Go to **Devices > All devices > [device] > Sync** (top menu). Wait 10 minutes.
4. **If profiles still not applied:**
   - Confirm device is in the correct Azure AD group for Autopilot profile targeting (check with Device Engineering)
   - Device may not have permissions to download profiles due to licensing or group membership. Escalate to Device Engineering.

---

### Rollback Scenario 5: `0x80180014` error recurs after remediation

**Symptoms:** After completing entire runbook, a second Autopilot attempt shows `0x80180014` again

**Immediate action:**
1. **Do NOT retry the full procedure yet.** The legacy record may not have fully cleared.
2. **In Intune admin center:** Go to **Devices > All devices**. Search by device serial. If you see **two** records (one from 2023, one from 2026), the retire of the 2023 record did not complete fully.
3. **Retry step 6:** Select the 2023 record again and click **Retire**. Wait a full 20 minutes this time (not 15).
4. **Verify in Intune audit logs:** Navigate to **Devices > Monitor > Audit logs**. Filter by device serial. Look for `Retire` action showing `Success` or `Failed`. If you see `Failed`, note the error code and escalate.
5. **If retire succeeds on second attempt,** return to the device and re-trigger Autopilot reset (step 13).

---

### Escalation Contact (If Rollback Actions Do Not Resolve)
- **Intune / MDM Team:** Contact your Intune administrator or Device Management team with:
  - Device serial number
  - Error code(s) encountered
  - Screenshot of error or Intune audit log entry
  - Which step of this runbook failed and at what time
  
---

## 5. Notes

### Related Incidents
- This error also occurs if a device was re-imaged but the old Intune record was not retired before re-provisioning.
- Legacy devices from the 2023 manual-MDM cohort are at higher risk. Check your asset register for devices enrolled prior to 2024-01-01 and ensure their records are retired before Autopilot refresh.

### Edge Cases & Warnings

**Edge Case 1: Device shows Autopilot profile but still not applying policies after provisioning**
- **Why:** AAD group membership may not have synced to the device yet. Policies are assigned to AAD groups; if the device is not yet a member, it won't receive them.
- **Workaround:** Wait 30 minutes and check again. If still not applied, confirm device membership in the target AAD group using Azure AD admin center (**Azure AD > Devices > [device name]**). If device is not in the group, add it manually.

**Edge Case 2: User signs in but receives "You can't access this right now" or permission errors**
- **Why:** Profile application may still be in progress, or user's license has not propagated to the device yet.
- **Workaround:** Have the user sign out and sign back in after 5 minutes. If errors persist, it may be a separate user access/license issue, not related to this enrolment fix.

**Edge Case 3: Device has multiple legacy work accounts (2+ entries in Access work or school)**
- **Why:** Device may have been enrolled multiple times or never fully deprovisioned between cycles.
- **Action:** Disconnect **all** legacy entries. After each disconnect, wait 1 minute and refresh Settings to ensure it's gone. Then proceed with dsregcmd verification and Autopilot reset.

**Edge Case 4: Autopilot profile is not assigned or device is not in Autopilot device list**
- **Why:** Device serial may not have been registered with Autopilot, or it was added but the profile assignment has not propagated.
- **Action (before triggering reset):** Contact Device Engineering. Confirm the serial is registered and a profile is assigned. Wait 5–10 minutes for assignment to propagate in Intune, then retry.

### Performance Notes
- The retire action in Intune typically takes **10–15 minutes**. Do not click retry or re-run Retire during this window; it may queue duplicate actions.
- dsregcmd output may take **1–2 minutes** to update after disconnect. If you see old values immediately after disconnect, wait 2 minutes and run the command again.
- Autopilot OOBE provisioning typically takes **15–25 minutes** depending on profile complexity and network speed. Do not interrupt or restart during this phase.

### Preventive Actions (Not Part of This Runbook)
- After resolving this incident, the team should implement the preventive actions outlined in the RCA:
  1. Mandate a pre-flight MDM clean-state gate in device refresh SOP
  2. Run a bulk query to identify and retire all legacy records pre-dating 2024-01-01
  3. Configure Intune alerting on error code `0x80180014`
  4. Add device prep validation checklist

See the RCA document for full details: [rca-autopilot-enrolment-failure-mdm-conflict-2026-08-11.md](rca-autopilot-enrolment-failure-mdm-conflict-2026-08-11.md)

---

**Runbook Version:** 1.0  
**Last Tested:** 2026-08-11  
**Owner:** DWP Device Engineering / Endpoint Operations  
**Questions?** Contact the Intune / MDM admin team or escalate via your IT ticketing system.
