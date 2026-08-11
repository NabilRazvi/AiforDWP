# Root Cause Analysis: Enterprise Software Installation Failure on One Managed Windows Device

## Incident Summary
- Analyst: DWP Engineer
- Date of analysis: 2026-08-11
- Incident date (from evidence): 2024-03-15
- Incident type: Intune-managed Win32 app deployment failure
- Affected scope: One managed Windows device
- Application: Adobe Acrobat Pro v23.6
- Package artifact: AdobeAcrobatPro.intunewin
- Installer command: msiexec /i AcrobatPro.msi /quiet

## Problem Statement
A managed Windows endpoint failed to install enterprise software. The deployment platform automatically retried, and retry also failed during the incident window.

## Supporting Evidence
### Primary event evidence (incident window)
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

### Resolution and validation evidence
- The recommended prerequisite-focused remediation was applied on the affected endpoint.
- Installation subsequently completed successfully.
- Post-install verification reported no remaining issues.
- Resolution timestamp: to-verify (not provided in evidence set).

## Timeline (Chronological)
1. 2024-03-15 10:01:00: Install workflow starts for Adobe Acrobat Pro v23.6.
2. 2024-03-15 10:01:01 to 10:01:03: SYSTEM-context install command is prepared and invoked.
3. 2024-03-15 10:01:44: First install attempt fails with return code 1603.
4. 2024-03-15 10:01:45 to 10:01:46: Detection runs and returns Not detected.
5. 2024-03-15 10:01:47: Install marked failed; retry scheduled in 60 minutes.
6. 2024-03-15 11:01:47 to 11:01:48: Retry attempt 1 starts and reruns same install command.
7. 2024-03-15 11:02:31 to 11:02:32: Retry 1 fails with return code 1603; another retry is scheduled.
8. 2026-08-11 (analysis update): Prerequisite/state remediation confirmed applied; installation verified successful with no issues reported.

## Hypothesis Elimination Outcome
### Surviving root-cause hypothesis
Local installer prerequisites or local device state requirements were not satisfied on the affected endpoint, causing repeated MSI 1603 failure under SYSTEM context.

### Why this survived
- Agent execution path was healthy (start, command launch, retry scheduler, and retry execution were all present).
- Failure signature repeated without change across attempts (1603 at 10:01:44 and 11:02:31).
- Detection not found occurred after install failure, consistent with failed installation state rather than proof of a detection-only defect.
- The issue resolved after applying prerequisite-focused remediation and re-validation.

## Root Cause Statement
The installation failure was caused by unmet local prerequisite or endpoint state conditions required by the MSI package on the affected managed Windows device. This resulted in repeated MSI 1603 failures during Intune-driven installation attempts until prerequisite/state remediation was applied.

## Corrective Actions Performed
1. Stopped repeated failure cycle while triage and remediation were executed.
2. Assessed local prerequisite and endpoint state gates on the affected device.
3. Applied prerequisite/state remediation on the endpoint.
4. Reattempted deployment and confirmed successful installation.
5. Verified post-install state with no further issues reported.

## Detailed Resolution Procedure (Reusable Runbook)
1. Pause active retries for the impacted device during investigation.
2. Validate prerequisite baseline for the target app on the endpoint.
3. Validate endpoint state gates: pending reboot, Windows Installer service, and available disk space.
4. If needed, execute MSI in SYSTEM context with verbose logging and identify first fatal action.
5. Remediate the specific blocker found (missing dependency, conflict, permission/state lock, or reboot requirement).
6. Re-trigger app sync and install.
7. Validate success code, detection success, and no subsequent retry scheduling.

## 5-Why Analysis
### Problem
Enterprise software installation repeatedly failed on one managed Windows endpoint.

1. Why did the installation fail?
- MSI execution returned error 1603 on both initial and retry attempts.

2. Why did MSI return 1603 repeatedly?
- A required local prerequisite or endpoint state condition remained unresolved between attempts.

3. Why was the condition unresolved between attempts?
- Automatic retry re-ran the same installer path without changing prerequisite/state conditions.

4. Why was this not prevented before install execution?
- Pre-flight prerequisite/state gating did not stop or redirect this endpoint before MSI execution.

5. Why did this become an incident instead of a pre-check failure?
- Deployment workflow lacked sufficiently strict fast-fail validation for endpoint-specific prerequisite/state readiness.

## Preventive Actions
1. Add mandatory pre-flight prerequisite checks in packaging/deployment workflow before MSI execution.
2. Add endpoint readiness gates for pending reboot, installer service health, and minimum disk threshold.
3. Add explicit failure categorization for 1603 incidents with a required local prerequisite/state checklist.
4. Add a conditional retry policy to reduce repeated blind retries when the same non-transient code repeats.
5. Update DWP support runbook with a standard evidence bundle requirement:
- Install command and context
- Return codes per attempt
- Detection output immediately after failure
- Retry schedule and retry result
- Resolution verification evidence

## Validation and Closure
- Remediation outcome: Successful installation confirmed.
- Service status after fix: No issues reported.
- Incident classification: Resolved.
- Follow-up task: Record exact remediation timestamp and attached MSI verbose log path as to-verify evidence for audit completeness.
