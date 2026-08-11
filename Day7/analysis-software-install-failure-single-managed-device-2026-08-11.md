# Analysis: Software Installation Failure on One Managed Device (2026-08-11)

## Scope Facts Used
- Symptom: Enterprise software installation failed
- Who: One managed Windows device
- Result: Installation failed and was automatically retried
- Change: None reported

## Ranked Likely Causes (Most Probable First)

### 1) Device-specific Intune Management Extension (IME) execution issue
Why this fits the scope facts:
- The failure is isolated to one managed device, which strongly points to a local agent/runtime issue rather than a broad platform outage.
- Automatic retry is consistent with management agent behavior after a failed app install attempt.

Single fastest check to confirm or eliminate:
- On the affected device, immediately review recent IME app install entries in the Intune management extension log to verify whether the install command was triggered and failed locally.

### 2) Local installer prerequisites missing or not satisfied on that device
Why this fits the scope facts:
- One-device impact aligns with a prerequisite mismatch (for example runtime/dependency baseline drift) specific to that endpoint.
- Retries can continue failing when prerequisite state does not change between attempts.

Single fastest check to confirm or eliminate:
- Run a prerequisite validation on the affected endpoint against the app’s required runtime/dependency list and confirm pass/fail before reattempting install.

### 3) Detection rule mismatch causing repeated failure/retry cycle
Why this fits the scope facts:
- In managed deployment workflows, an incorrect detection condition can make a successful or partial install appear as failed/not installed, triggering retries.
- Single-device manifestation is possible when local path/version/state differs from expected detection logic.

Single fastest check to confirm or eliminate:
- Execute the exact deployment detection rule locally on the affected device and verify whether it returns the expected installed state.

### 4) Endpoint security control (AV/EDR/App Control) blocking installer actions
Why this fits the scope facts:
- Security enforcement can block process launch, file write, script execution, or elevation on one endpoint while policy appears unchanged globally.
- No reported change does not exclude policy enforcement timing or local reputation/quarantine events.

Single fastest check to confirm or eliminate:
- Check the endpoint’s security event timeline for a block/quarantine event at the same timestamp as the failed installation attempt.

### 5) Device-side resource/state constraint (disk space, pending reboot, or Windows Installer service state)
Why this fits the scope facts:
- Local environmental constraints commonly produce install failure on a single machine.
- Auto-retry behavior is expected when platform keeps attempting and device state remains unresolved.

Single fastest check to confirm or eliminate:
- Perform a one-pass health check on the affected device for free disk space threshold, pending reboot flag, and Windows Installer service status.

## Positioning
- This is a probability-ranked hypothesis list only.
- No single root cause is selected yet; each item requires the noted fast check before commitment.

## Addendum: Incident Evidence Review (2024-03-15)

### Event Details (Incident Window)
- 2024-03-15 10:01:00 AgentExecutor: Starting app install: Adobe Acrobat Pro v23.6
- 2024-03-15 10:01:01 AppInstaller: Install context: SYSTEM
- 2024-03-15 10:01:02 AppInstaller: Package: AdobeAcrobatPro.intunewin
- 2024-03-15 10:01:03 AppInstaller: Install command: msiexec /i AcrobatPro.msi /quiet
- 2024-03-15 10:01:44 AppInstaller: Return code: 1603
- 2024-03-15 10:01:44 AppInstaller: Install failed. Return code 1603.
- 2024-03-15 10:01:45 DetectionRule: Running detection: registry check
- 2024-03-15 10:01:45 DetectionRule: Key: HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0
- 2024-03-15 10:01:45 DetectionRule: Value: not found
- 2024-03-15 10:01:46 DetectionRule: Detection result: Not detected
- 2024-03-15 10:01:47 AgentExecutor: App install result: Failed
- 2024-03-15 10:01:47 AgentExecutor: Retry scheduled: 60 minutes
- 2024-03-15 11:01:47 AgentExecutor: Retry attempt 1: Adobe Acrobat Pro v23.6
- 2024-03-15 11:01:48 AppInstaller: Install command: msiexec /i AcrobatPro.msi /quiet
- 2024-03-15 11:02:31 AppInstaller: Return code: 1603
- 2024-03-15 11:02:32 AgentExecutor: Retry 1 failed. Next retry: 60 minutes

### Survived Hypothesis
- Local installer prerequisites missing or not satisfied on the affected device (resulting in MSI 1603 under SYSTEM context).

Why this survived evidence elimination:
- The deployment agent path executed correctly (start, install invocation, retry scheduling, and retry attempt all occurred).
- The same installer command failed twice with return code 1603, indicating a persistent local unmet condition.
- Detection was run after failed installation and reported not detected, which is consistent with failed install state.

### Detailed Resolution Steps
1. Stabilize retries during triage.
- Temporarily pause assignment retries for this device, or remove the device from active targeting during investigation.
- Confirm no parallel install session for the same app is active.

2. Run a rapid local prerequisite and state baseline.
- Verify pending reboot state.
- Verify free disk space on system and target volumes.
- Verify Windows Installer service health and availability.
- Verify required runtime/dependency prerequisites for the package baseline.

3. Capture the definitive MSI failure reason.
- Re-run the same MSI in SYSTEM context with verbose logging enabled.
- Identify the first fatal action in the MSI log and map it to the blocking condition.

4. Remediate the discovered prerequisite or state blocker.
- Install missing prerequisite if absent.
- Repair or remove conflicting product/version if present.
- Correct local file system or permission issues if found.
- Reboot if pending reboot or lock condition is detected.

5. Re-validate deployment configuration.
- Confirm requirement rules match the affected device state.
- Confirm install command line and package content path are correct.
- Confirm detection rule aligns to intended installed footprint.

6. Re-attempt and validate installation.
- Trigger device sync and app install retry.
- Validate success return code, detection state as detected, and no additional retry scheduling.

7. Add preventive control.
- Add a pre-flight prerequisite gate in packaging/deployment workflow to fail fast with explicit reason before MSI execution.
