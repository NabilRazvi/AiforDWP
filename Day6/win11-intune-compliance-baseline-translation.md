# Windows 11 Intune Compliance Policy Translation (DWP)

Date: 2026-08-11  
Scope: Translate baseline security requirements into Microsoft Intune Windows compliance policy settings.

## Confirmed UI context (from tenant screenshots)
- Navigation: Intune admin center > Devices > Manage devices > Compliance
- Create flow:
  - Platform: Windows 10 and later
  - Profile type: Windows 10/11 compliance policy
- Wizard steps: Basics > Compliance settings > Actions for noncompliance > Assignments > Review + create

## Basics page values (Name and Description)
- Name: DWP-WIN11-COMP-BASELINE-N1-22621.2861
- Description: DWP Windows 11 compliance baseline. Requires BitLocker, Secure Boot, OS build 11.0.22621.2861 or higher, Defender real-time protection, Firewall, local unlock secret, and MDE risk score at or below Low. Noncompliance grace period: 7 days.

## Policy target
- Platform: Windows 10 and later (covers Windows 11)
- Policy type: Compliance policy

## Baseline-to-Intune mapping

### Requirement 1: BitLocker must be enabled on the OS drive
- Settings name: Require BitLocker
- Value: Require
- Effect: Device is noncompliant if BitLocker encryption is not enabled.
- False-positive risk: 
  - BitLocker was just enabled and encryption status has not yet reported back to Intune.
  - TPM/firmware transitions after BIOS updates can delay posture reporting.
  - Devices in Autopilot provisioning state may report before encryption completes.
- Recommendation:
  - Keep compliance requirement as Require.
  - Use the 7-day noncompliance grace action to absorb provisioning/reporting delay.
  - Pair with an Endpoint Security Disk Encryption policy so devices remediate automatically.
- Latest UI path (best known): Intune admin center > Devices > Manage devices > Compliance > Policies > Create policy > Windows 10 and later > Windows 10/11 compliance policy > Compliance settings > Device Health > Require BitLocker
- UI path stability flag: UI path may have changed labels/placement since older tenants.

### Requirement 2: Secure Boot must be enabled
- Settings name: Require Secure Boot to be enabled on the device
- Value: Require
- Effect: Device is noncompliant if Secure Boot is disabled or unavailable.
- False-positive risk:
  - Legacy BIOS devices (no UEFI Secure Boot capability) will fail by design.
  - Some firmware updates temporarily reset Secure Boot state.
  - VM/device model limitations in lab environments.
- Recommendation:
  - Keep as Require for managed corporate Windows 11 endpoints.
  - Exclude known legacy/non-capable hardware groups from this policy scope.
  - Validate hardware readiness before assignment broadening.
- Latest UI path (best known): Intune admin center > Devices > Manage devices > Compliance > Policies > Create policy > Windows 10 and later > Windows 10/11 compliance policy > Compliance settings > Device Health > Require Secure Boot to be enabled on the device
- UI path stability flag: UI path may have changed labels/placement since older tenants.

### Requirement 3: Minimum OS build N-1 (22621.2861)
- Settings name: Minimum OS version
- Value: 11.0.22621.2861
- Effect: Device is noncompliant if Windows version/build is below 22621.2861.
- False-positive risk:
  - Version inventory lag immediately after successful update/restart.
  - Devices on approved but differently versioned channels may temporarily drift.
  - Data entry format mistakes (wrong major version prefix) can over-block.
- Recommendation:
  - Use exact value 11.0.22621.2861.
  - Review monthly and move forward in a controlled cadence after pilot validation.
  - Keep the grace action at 7 days to avoid penalizing update propagation windows.
  - Validate in pilot that your tenant accepts and evaluates the selected prefix format consistently.
- Latest UI path (best known): Intune admin center > Devices > Manage devices > Compliance > Policies > Create policy > Windows 10 and later > Windows 10/11 compliance policy > Compliance settings > Device Properties > Minimum OS version
- UI path stability flag: UI path may have changed labels/placement since older tenants.

### Requirement 4: Windows Defender real-time protection must be on
- Settings name: Real-time protection
- Value: Require
- Effect: Device is noncompliant when real-time antimalware scanning is disabled.
- False-positive risk:
  - Third-party AV transitions can temporarily suppress Defender status telemetry.
  - Service startup delays after major updates/reboots.
  - Stale compliance check-in state.
- Recommendation:
  - Keep as Require.
  - If third-party AV is in scope, validate coexistence and reporting integration before broad assignment.
  - Add operational runbook checks for transient status before enforcement actions.
- Latest UI path (best known): Intune admin center > Devices > Manage devices > Compliance > Policies > Create policy > Windows 10 and later > Windows 10/11 compliance policy > Compliance settings > System Security > Defender > Real-time protection
- UI path stability flag: UI path may have changed labels/placement since older tenants.

### Requirement 5: Firewall must be enabled for all profiles
- Settings name: Firewall
- Value: Require
- Effect: Device is noncompliant if Windows Firewall is not enabled.
- False-positive risk:
  - Brief service restarts during updates can produce transient noncompliance.
  - Third-party firewall products that disable Windows Firewall and do not report expected state.
- Recommendation:
  - Keep as Require.
  - Standardize firewall control plane (Defender Firewall preferred) to avoid telemetry ambiguity.
  - Confirm all profile states (Domain/Private/Public) are managed via Endpoint Security Firewall policy.
- Latest UI path (best known): Intune admin center > Devices > Manage devices > Compliance > Policies > Create policy > Windows 10 and later > Windows 10/11 compliance policy > Compliance settings > System Security > Device security > Firewall
- UI path stability flag: UI path may have changed labels/placement since older tenants.

### Requirement 6: A PIN or password must be configured
- Settings name: Require a password to unlock mobile devices
- Value: Require
- Effect: Device is noncompliant if no local unlock secret is configured (PIN/password equivalent through Windows sign-in policy posture).
- False-positive risk:
  - Ambiguity between compliance password controls and Windows Hello for Business controls.
  - Shared/kiosk device scenarios with alternate sign-in models.
  - Inconsistent user-sign-in policy deployment timing.
- Recommendation:
  - Keep compliance as Require.
  - Enforce concrete complexity and credential type with Windows device configuration policy (Account protection / Windows Hello for Business), not compliance alone.
  - Validate kiosk/shared-device exclusions.
- Latest UI path (best known): Intune admin center > Devices > Manage devices > Compliance > Policies > Create policy > Windows 10 and later > Windows 10/11 compliance policy > Compliance settings > System Security > Password > Require a password to unlock mobile devices
- UI path stability flag: This label is known to be legacy/quirky for Windows and may be renamed or relocated in newer UI.

### Requirement 7: Device must not be jailbroken or rooted
- Settings name: Require the device to be at or under the machine risk score
- Value: Low
- Effect: Device is noncompliant when Microsoft Defender for Endpoint reports risk above Low, which is the practical Windows equivalent to blocking tampered/high-risk endpoints.
- False-positive risk:
  - Requires Microsoft Defender for Endpoint integration; missing/partial onboarding can mark devices unexpectedly.
  - Aggressive detections can temporarily raise risk to Medium before triage closes alerts.
  - Sensor/service health issues can stale risk data.
- Recommendation:
  - Keep threshold at Low for strong posture while avoiding excessive noise from transient informational detections.
  - If your environment has frequent transient Medium signals during rollout, temporarily pilot with Medium and move to Low after detection tuning.
  - Document this as the approved Windows substitution for jailbreak/root detection.
- Latest UI path (best known):
  - Intune admin center > Devices > Manage devices > Compliance > Policies > Create policy > Windows 10 and later > Windows 10/11 compliance policy > Compliance settings > Microsoft Defender for Endpoint > Require the device to be at or under the machine risk score
  - Prerequisite integration path: Intune admin center > Endpoint security > Microsoft Defender for Endpoint
- UI path stability flag: High likelihood of UI variation across tenants and release rings.

## Grace period requirement
- Requirement: 7 days for all settings
- Intune implementation:
  - Area: Actions for noncompliance
  - Action: Mark device noncompliant
  - Schedule (days after noncompliance): 7
- Important note: This action applies at policy level (not per individual setting), effectively providing the 7-day grace period for all checks in this compliance policy.
- Latest UI path (best known): Intune admin center > Devices > Manage devices > Compliance > Policies > [Your Windows policy] > Properties > Actions for noncompliance
- UI path stability flag: Moderate likelihood of placement/name changes (Properties vs Edit workflow changes over time).

## UI path change watchlist (explicit flags)
The following settings are most likely to have changed naming or placement since older documentation/training snapshots:
1. Require a password to unlock mobile devices (Windows label is historically inconsistent).
2. Windows jailbreak/root equivalent is now commonly implemented through Microsoft Defender for Endpoint machine risk score.
3. Defender real-time protection location (can appear under System Security or a Defender-specific subsection depending on tenant UX version).
4. Actions for noncompliance editor path (Properties/Edit navigation often changes).

## Recommended validation before production rollout
1. Create pilot policy assigned to IT pilot device group.
2. Confirm each setting appears exactly as named in your tenant UI.
3. Trigger fresh device sync and record first/second compliance evaluation timestamps.
4. Validate that transient provisioning/update states clear within the 7-day grace window.
5. Document any tenant-specific label differences in your internal SOP.

## Post-assignment validation (test device just synced)

### 1) Where to see this device status for this specific policy
1. Go to Intune admin center > Devices > Manage devices > Compliance > Policies.
2. Select the policy: DWP-WIN11-COMP-BASELINE-N1-22621.2861.
3. Open Monitor tab:
   - Use Device status for overall policy result on that device.
   - Use Per-setting status to confirm which setting passed or failed.
4. For the specific test device, either:
   - Select View report and search by device name, or
   - Go to Devices > All devices > [test device] > Device compliance and open this policy row.

### 2) What each compliance state means for Conditional Access impact
- Compliant:
  - Device meets all evaluated settings for this policy.
  - If Conditional Access requires a compliant device, access is allowed (assuming other CA controls also pass).
- Not compliant:
  - One or more required settings failed and grace has expired, or policy action has marked the device noncompliant.
  - If Conditional Access requires a compliant device, access is blocked.
- In grace period:
  - Device has failed one or more settings but is still within the configured grace window (7 days in this policy).
  - Intended operational impact: temporary access is typically still allowed while user/device remediates, then blocked after grace expires if still failing.
  - Important: If any other assigned compliance policy marks the same device Not compliant, Conditional Access can still block immediately.

### 3) BitLocker shows noncompliant even though BitLocker is enabled
Three most common false-positive causes and the fastest check for each:

1. Cause: Device Health Attestation is only refreshed reliably at boot for BitLocker posture.
   - Fastest check:
     - Confirm recent reboot time on the endpoint.
     - Reboot once, then force sync from Company Portal and recheck policy result.

2. Cause: BitLocker is enabled but encryption is still in progress or not fully protected yet.
   - Fastest check:
     - On endpoint run: manage-bde -status C:
     - Verify Conversion Status = Fully Encrypted and Protection Status = Protection On.

3. Cause: Reporting lag or stale check-in snapshot in Intune after sync.
   - Fastest check:
     - In policy View report, compare Last check-in timestamp vs time of local sync.
     - Trigger another manual sync from Company Portal and confirm timestamp advances before re-evaluating failure.

Operational note for this policy:
- If BitLocker remains false-noncompliant after reboot + second sync, keep device in 7-day grace window and investigate at scale using Per-setting status counts before changing the requirement.
