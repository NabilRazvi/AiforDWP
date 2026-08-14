# Floor 6 Legal Performance Remediation Runbook (Section 4 Fix)

Title; Version 1.1; Date 14 August 2026; Author Nabil Razvi; Reviewed Self; Status Draft; Change Updated to evidence-based containment posture; no single root cause selected.

## 1. Purpose and scope

This runbook provides the operational procedure to execute targeted performance containment for Floor 6 Legal by removing or disabling the suspected Friday app-assignment pressure for the impacted scope only.

Current evidence position: two hypotheses are supported (deployment-linked app impact and high background processing), and no single exclusive root cause is selected yet.

Scope includes login delay, endpoint slowness, and related startup impact on Floor 6 Legal devices/users.

This runbook is the single source of truth for both knowledge articles.

This runbook does not include Copilot security investigation steps; security remains a separate InfoSec/compliance workstream.

## 2. Prerequisites: access, tools, systems, verified identifiers

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

## 3. Numbered procedure: one concrete action per step

1. Confirm incident commander approval for production assignment change and record approver name/time.
2. Confirm change window and named approver, then record both in the change record.
3. Confirm elevated admin access to the verified tenant assignment tool. [ELEVATED PERMISSIONS REQUIRED]
4. Verify the exact current app-assignment target population and confirm whether scope is Floor 6-only or broader.
5. Compare affected and unaffected users/devices in the same migration cohort and record the comparison set.
6. Capture current assignment configuration including deployment intent and included/excluded groups.
7. Capture current app install status for affected and unaffected sample devices/users.
8. Capture a timestamped impacted-user/device list with symptom class.
9. Validate and record the exact execution values: tenant tool, app ID, group ID, deployment type, and command syntax. [ELEVATED PERMISSIONS REQUIRED]
10. Execute the assignment change that removes or disables the problematic app assignment for impacted Floor 6 scope only as a mitigation action, not root-cause closure. [ELEVATED PERMISSIONS REQUIRED]
11. Trigger or wait for the normal policy/application interval on pilot affected devices.
12. Collect pilot login/performance outcomes from two to three affected devices.
13. Review helpdesk intake trend for 30 to 60 minutes after change.
14. Check unaffected floors/departments for unintended impact after the assignment change.
15. Capture a per-device joined timeline for pilot and sample affected devices (deployment/install time, first slow login, process spike window, crash/shortcut timestamps).
16. Publish incident update on schedule (next at 30 minutes, then every 60 minutes) with current status.

## 4. Expected result after every step

1. Approval to proceed is explicit, timestamped, and attributable.
2. Change-governance prerequisites are fully documented.
3. Admin execution path is available for assignment operations.
4. Current blast radius is known and documented.
5. Cohort evidence set is available to validate impact concentration.
6. Pre-change assignment baseline is preserved for rollback.
7. Pre-change install-state baseline is preserved for rollback and verification.
8. Impact inventory is preserved with timestamped symptom classes.
9. All execution-critical identifiers and syntax are confirmed in-record.
10. Problematic assignment is removed or disabled for impacted Floor 6 scope only as an immediate containment measure.
11. Pilot devices move toward updated policy/application state.
12. Pilot users show improved login/performance versus pre-change baseline (threshold: NEED TO VERIFY).
13. New-case volume for the same symptom pattern decreases in the 30 to 60 minute window.
14. No material unintended impact is observed outside impacted scope (materiality threshold: NEED TO VERIFY).
15. Joined timeline evidence set is captured to isolate one surviving hypothesis.
16. Stakeholders receive timely, plain-language status updates at the committed cadence.

## 5. Verification: exact success criteria

All criteria below must be true:

1. Assignment state now matches intended removed/disabled scope for Floor 6 impacted group only.
2. Two to three pilot affected devices/users show successful policy/application update state.
3. Pilot login/performance is improved versus pre-change baseline by the agreed threshold: NEED TO VERIFY.
4. Helpdesk reports lower new-case intake for the same Floor 6 symptom pattern within 30 to 60 minutes.
5. No validated unintended impact exists in unaffected floors/departments after the change.
6. Evidence pack contains before/after assignment state, install-state samples, impacted list, and timestamps.
7. Evidence pack includes per-device joined timelines (deployment/install, first slow login, process spikes, crash/shortcut events) sufficient to isolate one surviving hypothesis.

Verification interpretation rule:
- If performance improves after containment, treat as support for deployment-linked mitigation effectiveness.
- Do not declare final root cause unless one hypothesis remains after timeline and cohort checks.

## 6. Rollback: immediately actionable steps in correct order

1. Stop further scope changes and notify incident commander that rollback trigger is met.
2. Confirm rollback approval and record approver name/time. [ELEVATED PERMISSIONS REQUIRED]
3. Open captured pre-change baseline (assignment config, deployment intent, include/exclude groups).
4. Restore prior assignment state exactly from captured baseline for the affected scope. [ELEVATED PERMISSIONS REQUIRED]
5. Validate restored assignment state matches baseline values.
6. Trigger or wait for normal policy/application interval on pilot devices.
7. Re-check pilot login/performance and side effects after restoration.
8. Publish rollback status update to Floor 6 and incident stakeholders.
9. Re-enter analysis mode with performance and cohort evidence updates.

Rollback triggers:
- No improvement after policy/application interval.
- Impact expands beyond Floor 6 after assignment change.
- Critical legal workflow dependency breaks after assignment removal/disablement.

## 7. Warnings and edge cases

- Do not issue tenant-wide removal unless blast-radius evidence supports wider containment.
- Do not merge Copilot security evidence handling into this performance rollback path.
- Do not execute any command until tenant tool, app ID, group ID, deployment type, and syntax are verified in-record.
- If assignment scope is broader than Floor 6, isolate impacted group first before broader action.
- If service health is unstable, pause assignment changes and reassess timing.
- If pilot results are mixed, keep scope limited and collect additional cohort evidence before expansion.
- If no material improvement is observed after policy/application interval, treat as evidence against deployment-only explanation and escalate alternate-path verification.

## 8. NEED TO VERIFY items

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
