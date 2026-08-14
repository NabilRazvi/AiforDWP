# Floor 6 Legal Performance Remediation (L2 Technical Knowledge Article)

Title; Version 1.0; Date 14 August 2026; Status Draft; Source Runbook 1.0

## Background and scope
This article defines targeted performance containment for Floor 6 Legal by removing or disabling suspected Friday app-assignment pressure for impacted scope only. Current evidence position in the runbook: two hypotheses are supported (deployment-linked app impact and high background processing), and no single exclusive root cause is selected yet. Scope includes login delay, endpoint slowness, and related startup impact on Floor 6 Legal devices/users. Copilot security investigation is out of scope and remains separate.

## Symptoms
- Slow login/sign-in on Floor 6 Legal devices
- Endpoint slowness after login
- Related startup impact
- Missing shortcuts (tracked as related incident signal)

## Preconditions and access
Access prerequisites:
- Incident commander approval is recorded.
- Change window and named approver are recorded.
- Active incident bridge and communication owner are confirmed.
- Elevated admin access to the tenant assignment tool is verified. [ELEVATED PERMISSIONS REQUIRED]

Tool and system prerequisites:
- Verified tenant assignment tool is identified: NEED TO VERIFY
- Verified tool/module version is recorded: NEED TO VERIFY
- Service health is stable enough to apply assignment changes.

Verified identifiers required before execution:
- App identifier for the Friday document-management deployment: NEED TO VERIFY
- Target group identifier for impacted Floor 6 scope: NEED TO VERIFY
- Deployment type/state to change (required/available/uninstall or platform equivalent): NEED TO VERIFY
- Change record ID: NEED TO VERIFY
- Incident ID: NEED TO VERIFY
- Service Desk contact channel for floor message: NEED TO VERIFY

## Detection and evidence
Collect and retain the runbook evidence set before and during change:
- Exact current app-assignment target population and whether scope is Floor 6-only or broader
- Affected vs unaffected cohort comparison set
- Current assignment configuration (deployment intent, included/excluded groups)
- Current app install status for affected/unaffected samples
- Timestamped impacted user/device list with symptom class
- Per-device joined timeline (deployment/install time, first slow login, process spike window, crash/shortcut timestamps)

Interpretation rule from runbook:
- If performance improves after containment, treat as support for deployment-linked mitigation effectiveness.
- Do not declare final root cause unless one hypothesis remains after timeline and cohort checks.

## Resolution steps with expected result after each
1. Confirm incident commander approval and record approver name/time.
Expected result: Approval to proceed is explicit, timestamped, and attributable.

2. Confirm change window and named approver; record both.
Expected result: Change-governance prerequisites are fully documented.

3. Confirm elevated admin access to verified tenant assignment tool. [ELEVATED PERMISSIONS REQUIRED]
Expected result: Admin execution path is available for assignment operations.

4. Verify current app-assignment target population and scope (Floor 6-only or broader).
Expected result: Current blast radius is known and documented.

5. Compare affected and unaffected users/devices in same migration cohort.
Expected result: Cohort evidence set is available to validate impact concentration.

6. Capture current assignment configuration including deployment intent and include/exclude groups.
Expected result: Pre-change assignment baseline is preserved for rollback.

7. Capture current app install status for affected and unaffected samples.
Expected result: Pre-change install-state baseline is preserved for rollback and verification.

8. Capture timestamped impacted user/device list with symptom class.
Expected result: Impact inventory is preserved with timestamped symptom classes.

9. Validate and record exact execution values: tenant tool, app ID, group ID, deployment type, command syntax. [ELEVATED PERMISSIONS REQUIRED]
Expected result: All execution-critical identifiers and syntax are confirmed in-record.

10. Execute assignment change to remove/disable problematic app assignment for impacted Floor 6 scope only as mitigation, not root-cause closure. [ELEVATED PERMISSIONS REQUIRED]
Expected result: Problematic assignment is removed or disabled for impacted Floor 6 scope only as an immediate containment measure.

11. Trigger or wait for normal policy/application interval on pilot affected devices.
Expected result: Pilot devices move toward updated policy/application state.

12. Collect pilot login/performance outcomes from two to three affected devices.
Expected result: Pilot users show improved login/performance versus pre-change baseline (threshold: NEED TO VERIFY).

13. Review helpdesk intake trend for 30 to 60 minutes after change.
Expected result: New-case volume for same symptom pattern decreases in the 30 to 60 minute window.

14. Check unaffected floors/departments for unintended impact.
Expected result: No material unintended impact is observed outside impacted scope (materiality threshold: NEED TO VERIFY).

15. Capture per-device joined timeline for pilot and sample affected devices.
Expected result: Joined timeline evidence set is captured to isolate one surviving hypothesis.

16. Publish incident update on schedule (next at 30 minutes, then every 60 minutes).
Expected result: Stakeholders receive timely, plain-language status updates at committed cadence.

Commands/placeholders note:
- The source runbook does not provide a concrete command string.
- Preserve and use the exact placeholders already defined as NEED TO VERIFY values.

## Verification
All criteria must be true:
1. Assignment state matches intended removed/disabled scope for Floor 6 impacted group only.
2. Two to three pilot affected devices/users show successful policy/application update state.
3. Pilot login/performance is improved versus pre-change baseline by agreed threshold: NEED TO VERIFY.
4. Helpdesk shows lower new-case intake for same Floor 6 symptom pattern within 30 to 60 minutes.
5. No validated unintended impact exists in unaffected floors/departments after change.
6. Evidence pack contains before/after assignment state, install-state samples, impacted list, and timestamps.
7. Evidence pack includes per-device joined timelines sufficient to isolate one surviving hypothesis.

## Rollback
Rollback steps:
1. Stop further scope changes and notify incident commander that rollback trigger is met.
2. Confirm rollback approval and record approver name/time. [ELEVATED PERMISSIONS REQUIRED]
3. Open captured pre-change baseline (assignment config, deployment intent, include/exclude groups).
4. Restore prior assignment state exactly from captured baseline for affected scope. [ELEVATED PERMISSIONS REQUIRED]
5. Validate restored assignment state matches baseline values.
6. Trigger or wait for normal policy/application interval on pilot devices.
7. Re-check pilot login/performance and side effects after restoration.
8. Publish rollback status update to Floor 6 and incident stakeholders.
9. Re-enter analysis mode with performance and cohort evidence updates.

Rollback triggers:
- No improvement after policy/application interval.
- Impact expands beyond Floor 6 after assignment change.
- Critical legal workflow dependency breaks after assignment removal/disablement.

## Escalation and NEED TO VERIFY items
Escalate to incident commander / technical lead when:
- Service health is unstable (pause assignment changes and reassess timing).
- Pilot results are mixed (keep scope limited and collect additional cohort evidence before expansion).
- No material improvement occurs after policy/application interval (treat as evidence against deployment-only explanation and escalate alternate-path verification).
- Scope appears broader than Floor 6 (isolate impacted group first before broader action).

NEED TO VERIFY items:
- Tenant assignment tool name
- Tool/module version
- App ID for Friday document-management deployment
- Group ID for impacted Floor 6 assignment target
- Deployment type/state label for this platform
- Exact command syntax for confirmed tool and module version
- Agreed pilot improvement threshold for login/performance
- Material unintended-impact threshold for unaffected groups
- Change record ID
- Incident ID
- Service Desk contact channel for user communications
- Multi-device joined timeline evidence needed to isolate one surviving hypothesis
