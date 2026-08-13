# JAMF macOS Security Baseline Translation (DWP)

Date: 2026-08-13  
Scope: Translate baseline security requirements into JAMF Pro configuration profile and compliance workflow settings for a 25-device Design team fleet.

## Confirmed UI context (best known)
- Navigation baseline in most current tenants:
	- Computers > Configuration Profiles
	- Computers > Smart Computer Groups
	- Computers > Policies
	- Computers > Inventory
- Create flow (best known):
	- New profile > Platform macOS > Payloads
	- Configure and scope profile to Design fleet group

## UI/payload naming verification discipline (explicit)
JAMF Pro payload labels and menu placement can change between versions, release rings, and UI generations.

For every control below, treat payload and field labels as implementation guidance only, then verify exact naming in your tenant before production rollout. This is the same discipline used in the Day 6 Intune labs: validate in-tenant labels and paths rather than trusting static documentation text.

## Profile basics page values (recommended)
- Name: DWP-MAC-COMP-BASELINE-N1-2026-08
- Description: DWP macOS baseline for Design fleet. Requires FileVault, Gatekeeper (identified developers), Application Firewall, password after sleep/screensaver, automatic security updates, and minimum OS version of current stable minus one point release.
- Category: Security Baselines (or your tenant equivalent)

## Policy target
- Platform: macOS
- Fleet: Design team devices (25)
- Assignment strategy:
	- Pilot group first (3-5 devices)
	- Then full Design production group

## Baseline-to-JAMF mapping

### Requirement 1: FileVault disk encryption must be enabled
- Payload type: Security & Privacy payload (FileVault section). In some JAMF versions this appears as Disk Encryption or FileVault2 phrasing.
- Value:
	- Enable FileVault
	- Escrow personal recovery key to JAMF
	- Enforce at login/logout prompt
	- Allow only limited deferment if approved (for example 1-3 deferrals)
- Effect: Full-disk encryption is enforced so data at rest is protected; recovery key escrow supports approved recovery operations.
- False-positive risk:
	- Encryption is in progress and not yet at 100%
	- Recovery key escrow upload delay due to check-in/network timing
	- Recent OS upgrade with temporary inventory lag
- Recommendation:
	- Keep this as required with no permanent exception for standard users.
	- Validate escrow records exist in inventory before declaring compliant.
	- Use a remediation policy for devices that remain unencrypted beyond grace thresholds.
- Latest UI path (best known): Computers > Configuration Profiles > [Your baseline profile] > Security & Privacy > FileVault
- UI path stability flag: High likelihood of naming variation; verify exact FileVault and escrow field names in your tenant.

### Requirement 2: Gatekeeper must be enabled (identified developers only)
- Payload type: Security & Privacy payload (Gatekeeper/General section; labels vary by JAMF/macOS generation).
- Value:
	- Allow apps from App Store and identified developers only
	- Keep assessment/check enabled
- Effect: Prevents launch of unsigned/untrusted software while allowing signed software from known developer identities.
- False-positive risk:
	- Newly approved apps pending notarization propagation
	- Offline validation/transient trust lookup failure
	- Assessment status checked before profile has converged post-enrollment
- Recommendation:
	- Keep enforcement at identified developers only.
	- Handle required exceptions with controlled approvals rather than broadening policy globally.
	- Validate critical design-tool install and launch behavior in pilot before full scope.
- Latest UI path (best known): Computers > Configuration Profiles > [Your baseline profile] > Security & Privacy > Gatekeeper
- UI path stability flag: Moderate-to-high label drift risk; verify exact Gatekeeper wording in your tenant.

### Requirement 3: Minimum macOS version = current stable minus one point release
- Payload type: Not reliably enforced by a single configuration profile payload alone. Implement with Smart Computer Group criteria + remediation policy + reporting.
- Value:
	- Smart group criterion: Operating System Version is greater than or equal to [stable minus one point release]
	- Scope remediation policy to non-compliant group
	- Optional supporting profile: Software Update payload configured for automatic security updates
- Effect: Devices remain on a supportable security baseline and avoid extended drift to vulnerable builds.
- False-positive risk:
	- Inventory/check-in delay immediately after successful update/restart
	- Baseline target not updated when Apple stable version increments
	- Model-specific rollout holdbacks causing healthy but temporarily behind status
- Recommendation:
	- Operate with a monthly version review cadence.
	- Maintain a dated baseline source-of-truth note that records target version and effective date.
	- Use time-bound exceptions for validated app compatibility blockers only.
- Latest UI path (best known):
	- Computers > Smart Computer Groups > [Create N-1 compliance group]
	- Computers > Policies > [Remediation policy for out-of-date devices]
- UI path stability flag: High feature-placement variability across tenants; verify exact smart group criteria labels and policy scoping UI.

### Requirement 4: Firewall must be enabled
- Payload type: Security & Privacy payload (Firewall section).
- Value:
	- Enable Application Firewall
	- Enable stealth mode unless a documented business need requires discoverability
- Effect: Reduces inbound attack surface by filtering unsolicited inbound connections.
- False-positive risk:
	- Status checks during reboot/profile convergence windows
	- Conflicting third-party endpoint tooling visibility
	- Scanner checks local state before MDM policy override is fully applied
- Recommendation:
	- Keep firewall required across all Design devices.
	- Document any app-level inbound allow-list exceptions through change control.
	- Validate no design workflow breakage in pilot (for example local render nodes or peer workflows).
- Latest UI path (best known): Computers > Configuration Profiles > [Your baseline profile] > Security & Privacy > Firewall
- UI path stability flag: Moderate label drift risk, especially stealth mode label; verify in tenant.

### Requirement 5: Login password required after sleep/screen saver
- Payload type: Security & Privacy payload (password after sleep/screensaver controls; exact naming varies).
- Value:
	- Require password immediately after sleep or screensaver starts
	- Delay value = 0 seconds
- Effect: Prevents unauthorized access to unlocked sessions when devices are unattended.
- False-positive risk:
	- Session transition timing during active unlock/sleep cycles
	- Local preference cached before managed profile refresh
	- User-level setting visibility queried before MDM-enforced value lands
- Recommendation:
	- Keep immediate password requirement for this fleet.
	- Validate behavior with both laptop lid-close and manual lock workflows during pilot.
	- Ensure user communication explains expected lock behavior to reduce support tickets.
- Latest UI path (best known): Computers > Configuration Profiles > [Your baseline profile] > Security & Privacy > General (password after sleep/screensaver)
- UI path stability flag: High naming-change risk; verify exact control label in tenant.

### Requirement 6: Automatic security updates enabled
- Payload type: Software Update payload (or equivalent managed update section in your JAMF version).
- Value:
	- Enable automatic check/download/install for security updates
	- Enable system data file and security response updates
	- Keep restart behavior aligned to business maintenance windows
- Effect: Reduces mean time to patch for macOS security vulnerabilities.
- False-positive risk:
	- Device is healthy but waiting on power/network/maintenance window conditions
	- Restart pending state interpreted as noncompliant
	- Apple phased rollout timing delays update availability
- Recommendation:
	- Keep security update automation enabled baseline-wide.
	- Use update deferrals only where operationally required and documented.
	- Track update latency as a KPI (for example median days from release to install).
- Latest UI path (best known): Computers > Configuration Profiles > [Your baseline profile] > Software Update
- UI path stability flag: High variation risk between major JAMF and macOS update-management models; verify exact toggle names.

## Stable-minus-one version method (operational)
1. Determine Apple current stable macOS version for your approved channel.
2. Set minimum required version to one point release behind that stable version.
3. Update the smart group threshold monthly or after approved change advisory.

Example method only:
- If current approved stable = macOS X.Y.Z, then minimum required baseline = macOS X.(Y-1).latest allowed patch for that line.
- Always validate exact version expression and comparator behavior in your JAMF smart group criteria UI.

## Recommended implementation workflow in JAMF
1. Create configuration profile with Security & Privacy and Software Update payloads.
2. Create Smart Computer Group for minimum-version compliance logic.
3. Create remediation policy scoped to non-compliant version group.
4. Assign profile and policy to pilot Design group (3-5 devices).
5. Validate profile installation, inventory freshness, and control behavior.
6. Expand scope to full 25-device Design group after pilot signoff.

## UI path change watchlist (explicit flags)
The following controls are most likely to differ from this document in your tenant:
1. FileVault payload naming and escrow field labels.
2. Gatekeeper option wording (identified developers labels).
3. Password-after-sleep/screensaver control labels.
4. Software Update payload toggle names.
5. Smart Group OS version comparator wording and placement.

## Recommended validation before production rollout
1. Confirm each payload/control name exactly in your JAMF UI before saving production profile.
2. Validate all six requirements on pilot devices with fresh inventory updates.
3. Confirm FileVault key escrow is present in inventory records for each pilot device.
4. Confirm non-compliant version group membership updates correctly after OS upgrade.
5. Record tenant-specific label differences in your internal SOP/runbook.

## Post-assignment validation (pilot device just checked in)

### 1) Where to verify this device posture
1. Open device record in Computers > Inventory.
2. Confirm profile installation status for baseline profile.
3. Confirm Security & Privacy posture values (FileVault, Firewall, Gatekeeper where surfaced).
4. Confirm Software Update managed state and recent inventory timestamp.
5. Confirm smart group membership for minimum-version compliance.

### 2) How to interpret typical status states
- Installed/Compliant intent observed:
	- Profile is installed and posture reflects required settings.
	- Device should pass internal baseline review.
- Pending:
	- Profile assignment/check-in has not fully converged yet.
	- Recheck after inventory update cycle before escalating.
- Failed/Not meeting baseline intent:
	- One or more controls did not apply or were overridden/conflicted.
	- Trigger remediation workflow and revalidate after next check-in.

### 3) FileVault appears non-compliant even though user enabled it
Three common causes and quickest validation:

1. Cause: Encryption not yet complete.
	 - Fast check: Validate FileVault/encryption progress on endpoint and recheck inventory after completion.

2. Cause: Recovery key escrow not yet uploaded.
	 - Fast check: Verify escrow fields in device inventory after a forced check-in.

3. Cause: Stale inventory snapshot.
	 - Fast check: Trigger policy/inventory update and compare last inventory time before reassessing failure.

Operational note:
- If FileVault remains false-noncompliant after second inventory refresh, keep device in remediation queue and investigate profile conflict/scope before relaxing baseline requirements.

## Exception and change-control notes for Design fleet
1. Permit exceptions only with documented business justification and expiry date.
2. Keep exception scope as narrow as possible (device or small group).
3. Revalidate exceptions monthly and retire when blockers are resolved.

## Implementation reminder
Do not treat exact payload labels in this document as authoritative script strings. Confirm all payload and field names in your own JAMF Pro build before automation or production enforcement.
