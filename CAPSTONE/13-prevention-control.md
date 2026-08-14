# Conditional Prevention Control for Floor 6 Legal App Releases

- Control name
Pre-Monday Cohort Gate for Legal Document Manager Release (Conditional)

- Risk addressed
A Friday release to a single business cohort may cause Monday morning slow sign-in, post-sign-in slowness, app crashes, and missing shortcuts that are only visible after broad rollout.

- Owner role
Change and Release Analyst (control owner), with Incident Lead approval authority.

- When it runs
For every Friday release affecting Floor 6 Legal, run at two points:
1. Immediately after pilot deployment completion on Friday.
2. Before broad cohort enablement and again before Monday business start.

- Pilot/comparison scope
Pilot scope: small Floor 6 Legal subset on new version.
Comparison scope: matched legal-support cohort not on new version.
Dependency: exact pilot size and cohort definition NEED TO VERIFY.

- Exact evidence collected
1. Average login time: previous-week baseline vs current test window.
2. Top CPU and memory processes during login window.
3. Application error events for released app (event time, app name, event ID, exception code).
4. Shortcut creation outcome and any timeout/error text.
5. Cohort comparison snapshot: login time, crash count, missing shortcut count, login failure count.
6. Deployment targeting and install-success evidence by cohort.

- Measurable pass criteria
1. Pilot login time increase remains within agreed tolerance versus baseline. NEED TO VERIFY tolerance value.
2. No repeated app-crash pattern in pilot during control window.
3. No shortcut-creation failure pattern in pilot.
4. Pilot outcomes are not materially worse than comparison cohort. NEED TO VERIFY materiality threshold.

- Measurable fail/rollback trigger
Fail the gate if any one occurs:
1. Pilot login time exceeds agreed tolerance versus baseline.
2. Repeated app-crash pattern appears in pilot.
3. Shortcut timeout/failure pattern appears in pilot.
4. Pilot materially underperforms comparison cohort.

- Action if it fails
1. Block broad cohort enablement.
2. Keep impact scope limited to pilot only.
3. Raise incident/change hold and execute targeted containment plan.
4. Require corrected build or release-configuration change before re-run.

- Record retained for audit
1. Time-stamped gate decision (pass/fail) and approver.
2. Pilot and comparison evidence pack (metrics, event extracts, shortcut outcomes).
3. Deployment scope and install-status export.
4. Decision rationale and follow-up actions.
5. Re-test results if re-run occurs.

- Dependencies marked NEED TO VERIFY
1. Single exclusive root cause remains unverified; control is conditional on supported deployment-linked and workload findings.
2. Pilot cohort size and composition NEED TO VERIFY.
3. Login-time tolerance threshold NEED TO VERIFY.
4. Materiality threshold for comparison gap NEED TO VERIFY.
5. Approved evidence collection window (Friday and pre-Monday timing) NEED TO VERIFY.
6. Named approver role and sign-off workflow NEED TO VERIFY.