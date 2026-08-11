# Step-by-Step Guide: Add a Windows App to Intune App Catalog (Pre-Rollout)

## Purpose
This guide walks a DWP engineer through adding a Windows app to Microsoft Intune before any phased rollout begins.

Worked example used throughout:
- App name: FinBridge Connect v3.1
- Package type: Windows LOB app packaged as a .intunewin file
- Install command: FinBridgeConnect_Setup.exe /silent
- Uninstall command: FinBridgeConnect_Setup.exe /uninstall /silent
- Detection method: Registry key
- Detection value: HKLM\SOFTWARE\FinBridge\Connect\Version = 3.1

Important UI note:
- Intune UI labels and menu names can vary by tenant version, admin center updates, and role permissions.
- At every navigation step below, verify labels in your live tenant rather than trusting screenshots or older documentation.

## 1. Go to the correct place in Intune and choose the right app type

1. Sign in to the Microsoft Intune admin center.
2. Navigate to: Apps > All apps > Add.
3. In the Add app pane, choose Select app type.
4. Choose the app type based on what you are deploying:
   1. Windows LOB app (.intunewin package): select Windows app (Win32).
   2. Microsoft Store app: select Microsoft Store app (new).
   3. Web link shortcut: select Web link.
5. For this guide, select Windows app (Win32), then click Select.

UI-variance check:
- In some tenants, the path may appear as Apps > Windows apps, or the Add entry point may be inside a platform-specific view.
- If labels differ, confirm you are still creating a Win32 app from a .intunewin package.

## 2. Create the LOB Windows app (FinBridge Connect v3.1)

1. In App package file, upload the .intunewin file for FinBridge Connect v3.1.
2. Continue to App information and populate required fields.

### 2.1 App information (required)

1. Name: FinBridge Connect v3.1
2. Description: FinBridge secure connectivity client for internal finance workloads.
3. Publisher: FinBridge
4. Version: 3.1

UI-variance check:
- Some tenants label Version as App version or Display version.
- Verify your entered value is visible in the app catalog card/details.

### 2.2 Program (required)

1. Install command:
   FinBridgeConnect_Setup.exe /silent
2. Uninstall command:
   FinBridgeConnect_Setup.exe /uninstall /silent
3. Install behavior:
   1. System context: installs for device-wide use (recommended for most managed enterprise apps).
   2. User context: installs in user scope (use only if app vendor requires per-user install).
4. For FinBridge Connect v3.1, choose System unless vendor guidance explicitly says User.

UI-variance check:
- Install behavior may appear as Install as system or Install for system.
- Confirm the selected context aligns with where your detection rule checks (HKLM implies system-wide install).

### 2.3 Requirements (required)

1. Operating system architecture:
   1. Choose supported architecture(s), typically x64 for modern Win11 estates.
2. Minimum operating system:
   1. Select the minimum supported Windows version per your estate standard.
   2. Example: Windows 10 21H2 or later / Windows 11 equivalent baseline.

UI-variance check:
- OS minimum options differ across tenant UI releases.
- Verify selected minimum OS aligns with your policy baseline and pilot device build versions.

### 2.4 Detection rules (required)

Goal:
- Detection rules tell Intune how to confirm install success.

Supported common methods:
1. Registry key/value
2. MSI product code
3. File/folder existence or version

Worked example (use this):
1. Rule type: Registry
2. Key path: HKLM\SOFTWARE\FinBridge\Connect
3. Value name: Version
4. Detection method: String comparison equals
5. Expected value: 3.1

UI-variance check:
- Detection operator labels can vary (for example Equals vs String equals).
- Verify the effective logic is exact-match on Version value 3.1 in HKLM.

### 2.5 Return codes (required and important)

1. Review default return codes presented by Intune.
2. Ensure success and failure semantics are correctly mapped.
3. Typical mappings in enterprise packaging:
   1. 0 = Success
   2. 3010 = Soft reboot required (often treated as success with restart)
   3. 1641 = Hard reboot initiated (often treated as success)
   4. Non-zero unknown codes = Failure (unless packaging standard defines otherwise)
4. Keep or adjust mappings only if they match your packaging standard and vendor installer behavior.

UI-variance check:
- Return code category labels may vary slightly.
- Verify that reboot-related success codes are not accidentally treated as hard failures.

## 3. Complete and save the app

1. Progress through remaining wizard pages (Scope tags, if used in your tenant).
2. Review all values before Create.
3. Click Create.
4. Wait for app object creation to complete.

UI-variance check:
- Scope tags may be optional or enforced depending on RBAC setup.
- Verify app object appears under All apps after creation.

## 4. Assignment basics (pilot-first discipline)

1. Open the created app: FinBridge Connect v3.1.
2. Go to Assignments.
3. Understand assignment types:
   1. Required:
      App installs automatically on targeted devices/users.
   2. Available for enrolled devices:
      App is offered in Company Portal; user installs on demand.
   3. Uninstall:
      App is removed from targeted devices/users.
4. Pilot-first requirement:
   1. Do not assign new apps directly to the full 10,000-device fleet.
   2. Assign first to a small controlled pilot group (for example 10-50 representative devices/users).
   3. Validate install success, performance impact, and rollback confidence before phased expansion.

Why pilot first:
1. Limits blast radius if commands, detection logic, or prerequisites are incorrect.
2. Exposes edge-case failures (architecture mismatch, stale dependencies, conflicting versions).
3. Protects service continuity for critical business populations.

UI-variance check:
- Assignment category labels can appear as Required, Available, Uninstall, or similar wording.
- Verify each group is placed under the intended assignment intent before saving.

## 5. Verification steps after assignment

### 5.1 Verify app appears correctly in catalog

1. In Intune, go to Apps > All apps.
2. Confirm FinBridge Connect v3.1 is listed.
3. Open app details and confirm:
   1. Name/version/publisher are correct.
   2. Install/uninstall commands are correct.
   3. Detection rule is the HKLM registry check for Version = 3.1.

UI-variance check:
- Details tabs may be split into Properties and Monitor views in some tenants.
- Verify values from the summary and per-section edit views.

### 5.2 Check install status on assigned test device

1. Ensure at least one pilot device is targeted by assignment and has checked in.
2. In Intune app Monitor area, open:
   1. Device install status, and/or
   2. User install status (depending on assignment model).
3. Locate pilot device entry and inspect status.
4. If needed, force a sync from Company Portal or Intune device action and re-check status.

UI-variance check:
- Monitor page names can differ (Install status, Device status, User status).
- Verify you are checking the same assignment context (device-targeted vs user-targeted).

### 5.3 Interpret status values

1. Installed:
   Intune reports app installation completed and detection rule passed.
2. Failed:
   Installation attempt returned a failure code, timed out, or detection rule did not validate expected state.
3. Not applicable:
   The target does not meet requirement filters (for example unsupported OS or architecture), or assignment context does not apply.

Follow-up actions by status:
1. Installed:
   Proceed with broader phased rollout only after pilot success criteria are met.
2. Failed:
   Review installer logs, return codes, and detection rule accuracy first.
3. Not applicable:
   Re-check Requirements and assignment targeting logic.

## 6. Pre-rollout readiness checklist (must pass)

1. App object exists and metadata is correct.
2. Program commands are validated and silent install works.
3. Install behavior (System/User) is intentionally chosen.
4. Requirements match intended pilot estate.
5. Detection rule correctly validates FinBridge Connect version 3.1.
6. Return codes are aligned with packaging standards.
7. Assignment is pilot-only (not fleet-wide).
8. Pilot devices report expected statuses with low/no failure rate.

When all checks pass, proceed to phased rollout waves according to DWP change governance.
