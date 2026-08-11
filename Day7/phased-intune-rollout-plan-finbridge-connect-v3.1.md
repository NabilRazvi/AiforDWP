# Phased Intune Deployment Plan: FinBridge Connect v3.1 (10,000 Win11 Endpoints, 3-Week Deadline)

Date baseline: 2026-08-11
Deployment deadline: within 3 weeks (by 2026-09-01)

Assumptions for this plan:
- FinBridge Connect v3.1 Win32 app object is already created in Intune and detection is based on registry version string.
- FinBridge Connect v3.0 remains available in catalog and can be reassigned for rollback.
- Device check-in cadence is sufficient for at least two evaluation windows per ring.

## 1. RING STRUCTURE

Ring design targets controlled risk while still meeting the deadline. Group names below are examples; verify naming standards in your tenant.

1. Ring 1 (Pilot)
- Size: 300 endpoints (3 percent of fleet).
- Duration: 4 calendar days total.
  - Day 1 deployment.
  - Days 2-4 monitoring and remediation.
- Include:
  - 220 standard Win11 devices from mixed business units (non-Finance).
  - 50 IT-managed power users and support engineers.
  - 30 devices from the 4GB RAM at-risk population.
- Purpose:
  - Validate install/uninstall commands, detection reliability, and baseline stability on representative hardware.
  - Validate early behavior on constrained hardware before scale.
- Intune assignment group type:
  - Microsoft Entra assigned security group, device-based, static membership for strict control.
  - Assignment intent in Intune: Required.

2. Ring 2 (Early)
- Size: 2,200 endpoints (22 percent of fleet), excluding any users already handled in Finance Ring 0.
- Duration: 6 calendar days total.
  - Day 1-2 deployment waves.
  - Day 3-6 monitoring.
- Include:
  - Business-critical but non-peak-risk departments.
  - Full regional and network diversity.
  - Additional 170 devices from 4GB RAM group (bringing low-RAM sample to 200 total across Ring 1 + Ring 2).
- Purpose:
  - Confirm behavior at medium scale and identify operational bottlenecks (content delivery, reboot handling, helpdesk load).
- Intune assignment group type:
  - Microsoft Entra assigned security group, device-based.
  - Assignment intent in Intune: Required.

3. Ring 3 (Broad)
- Size: remaining endpoints to reach 10,000 total after Rings 0-2 complete (expected about 7,000-7,500 depending pilot scope and exceptions).
- Duration: 8 calendar days total with staged sub-waves.
  - Wave A: 40 percent of remaining.
  - Wave B: 35 percent of remaining.
  - Wave C: 25 percent of remaining.
- Include:
  - All remaining in-scope Win11 endpoints not already deployed or deferred.
- Purpose:
  - Complete fleet rollout within deadline while preserving rollback control through sub-wave pacing.
- Intune assignment group type:
  - Microsoft Entra dynamic device group for scale, with exclusion group for active incidents/deferred devices.
  - Assignment intent in Intune: Required.

4. Hardware-risk isolation group (applies across all rings)
- Create a dedicated device group for 4GB RAM endpoints (expected 500 devices, 5 percent of fleet).
- Keep this group reportable in Intune and separately visible in monitoring so failure rates are not hidden inside fleet averages.

UI-variance check:
- Group and assignment labels can vary between tenant UX versions.
- Verify in live tenant whether membership is configured in Microsoft Entra groups, Intune filters, or both, and ensure assignment intent is Required for each rollout ring.

## 2. ADVANCE CRITERIA

Criteria are mandatory gates. If any gate is missed, do not advance until corrected and re-observed.

1. Ring 1 to Ring 2 advance gate
- Install success rate: at least 97.0 percent Installed status in Intune device install status.
- Error rate threshold: no more than 3.0 percent Failed status.
- User-reported issue rate: no more than 1.5 tickets per 100 deployed users in a 24-hour window, with no Sev1.
- Monitoring period: minimum 72 hours from first device install completion in Ring 1.
- Time-bound decision point: CAB/go-no-go decision within 4 business hours after 72-hour metrics snapshot.

2. Ring 2 to Ring 3 advance gate
- Install success rate: at least 98.0 percent Installed status.
- Error rate threshold: no more than 2.0 percent Failed status.
- User-reported issue rate: no more than 1.0 ticket per 100 deployed users in a 24-hour window, and Sev1 count must be zero.
- Monitoring period: minimum 96 hours from first Ring 2 install completion.
- Time-bound decision point: CAB/go-no-go decision within 4 business hours after 96-hour metrics snapshot.

3. Required observability sources
- Intune app monitoring:
  - Device install status (Installed, Failed, Not applicable, Pending).
  - User install status where user-targeted populations are used.
- ITSM/helpdesk:
  - Ticket volume tagged FinBridge v3.1.
  - Severity tagging (Sev1/Sev2/etc.).

4. Hold condition (pause without full rollback)
- Trigger:
  - Not applicable exceeds 8.0 percent in any ring for 24 consecutive hours.
- Why hold (not rollback):
  - Usually indicates targeting or requirements mismatch (for example architecture/OS filter issue), not app binary failure.
- Action:
  - Pause next wave only.
  - Keep currently installed devices as-is.
  - Correct requirements/targeting and re-evaluate for 24 hours before resuming.
- Specific example:
  - Ring 2 shows 10.4 percent Not applicable because a minimum OS value was set above actual Win11 baseline for part of the estate.

UI-variance check:
- Status bucket names and monitor tab names can differ by tenant version.
- Verify where Installed, Failed, and Not applicable are surfaced in your tenant before gate reviews begin.

## 3. ROLLBACK TRIGGERS

Each trigger includes threshold, timeframe, decision owner, decision window, and exact Intune action.

1. Trigger A: install failure rate automatic halt and rollback
- Threshold and timeframe:
  - Failed status reaches 8.0 percent or higher in any active ring within a rolling 6-hour window.
- Decision authority:
  - Primary: DWP Endpoint Lead.
  - Backup: Intune Service Owner.
- Decision window:
  - 60 minutes from threshold breach confirmation.
- Exact Intune action:
  1. Remove affected ring group(s) from FinBridge Connect v3.1 Required assignment.
  2. Add same ring group(s) to FinBridge Connect v3.0 Required assignment.
  3. Add affected ring group(s) to FinBridge Connect v3.1 Uninstall assignment if side-by-side versioning is not supported.
  4. Force device sync action for a sampled subset, then monitor status for 2 hours.

2. Trigger B: application crash rate rollback consideration
- Threshold and timeframe:
  - 2.0 percent or more of deployed devices show two or more FinBridge process crashes within 24 hours (from endpoint telemetry/crash reporting).
- Decision authority:
  - DWP Endpoint Lead plus Application Owner joint sign-off.
- Decision window:
  - 4 business hours from confirmed metric.
- Exact Intune action if rollback approved:
  1. Freeze new v3.1 assignments (remove pending ring Required assignments).
  2. Reassign active impacted groups from v3.1 Required to v3.0 Required.
  3. Keep unaffected completed groups on v3.1 only if crash metric is below threshold in those groups; otherwise include them in rollback scope.

3. Trigger C: business-critical failure immediate rollback
- Scenario:
  - Finance users cannot complete payment-run connectivity through FinBridge Connect after upgrade (Sev1), confirmed on at least 2 distinct Finance devices within 30 minutes.
- Percentage requirement:
  - None. Immediate rollback regardless of deployment percentage.
- Decision authority:
  - Incident Commander (Major Incident) with DWP Endpoint Lead.
- Decision window:
  - Immediate execution; start rollback within 15 minutes of Sev1 confirmation.
- Exact Intune action:
  1. Remove Finance target groups from v3.1 Required assignment immediately.
  2. Assign Finance target groups to v3.0 Required.
  3. Add Finance group to v3.1 Uninstall assignment if required by app compatibility.
  4. Keep enterprise-wide rollout paused until RCA and fix validation complete.

4. Trigger D: 4GB RAM at-risk group ring isolation
- Threshold and timeframe:
  - Failure rate on dedicated 4GB RAM group reaches 15.0 percent or higher over 24 hours.
- Decision authority:
  - DWP Endpoint Lead.
- Decision window:
  - 2 business hours from metric confirmation.
- Exact Intune action:
  1. Exclude 4GB RAM group from current and future v3.1 Required assignments.
  2. Assign excluded 4GB RAM group to v3.0 Required.
  3. Continue rollout for non-4GB groups only if global thresholds remain within gates.

Operational note:
- Before first production wave, verify v3.0 detection and install/uninstall logic are still valid so rollback assignments are executable without package changes.

UI-variance check:
- Assignment edit views may differ between tenant versions.
- Verify you are changing assignment intent on the correct app object version (v3.1 vs v3.0) before saving.

## 4. FINANCE DEADLINE RESOLUTION

Finance (500 users) must be completed by end of week 1. Two options are evaluated below, followed by one recommendation.

1. Option A - compress pilot timeline and place Finance in Ring 2 by end of week 1
- Minimum safe pilot duration:
  - 72 hours minimum for Ring 1 with at least one full business-day usage cycle.
- Risk introduced:
  - Shortened observation window can miss delayed failures (reboot-dependent issues, day-2 login/profile conflicts).
- Compensating control:
  - Increase pilot observability intensity: 4-hourly metric review, dedicated service desk queue, and pre-approved rollback change ready before Finance expansion.
- Feasibility against deadline:
  - Possible, but only with tight execution and reduced margin for troubleshooting.

2. Option B - create Finance Ring 0 before main pilot
- Ring 0 structure:
  1. Day 1: 100 Finance users (mix of devices, include at least 20 low-RAM if present in Finance).
  2. Day 2-3: monitor with stricter gate.
  3. Day 4: expand to remaining 400 Finance users if gate passes.
  4. Day 5: confirm Finance completion by end of week 1.
- Ring 0 advance conditions (stricter than Ring 1):
  - Installed at least 98.0 percent.
  - Failed no more than 1.5 percent.
  - Sev1 tickets equals 0 over 48-hour monitoring window.
- Ring 0 rollback plan:
  - If Failed reaches 5.0 percent within any 12-hour window or any Finance Sev1 connectivity incident occurs, revert Finance group to v3.0 immediately using the rollback actions in Section 3.

3. Recommendation (single clear choice)
- Recommend Option B (Finance Ring 0 before main pilot).
- Justification:
  1. Meets non-negotiable Finance end-of-week-1 deadline without forcing unsafe compression of the enterprise pilot gate.
  2. Isolates business-critical users for tighter monitoring and faster incident response.
  3. Preserves overall rollout quality by keeping Ring 1 evidence-based rather than rushed.
  4. Provides a clean operational pattern: priority cohort first, then standard rings with unchanged governance criteria.

Execution order with recommendation:
1. Launch Finance Ring 0 on Day 1.
2. Run Ring 1 in parallel for non-Finance endpoints.
3. If both pass gates, move to Ring 2 then Ring 3 and complete by week 3 deadline.

UI-variance check:
- Some tenants may show assignment controls differently for user-based Finance groups versus device-based enterprise rings.
- Verify each Finance action is applied to the correct group object type and app version before confirming changes.
