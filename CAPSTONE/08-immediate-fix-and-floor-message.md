# Immediate Recovery Action and Floor 6 Communication
**Date:** 2026-08-14  
**Incident Lead:** DWP Incident Lead (acting)  
**Scope:** Floor 6 Legal login and performance incident  

---

## Part A - Technical Action (Performance Remediation Only)

### 1) Evidence-supported most-likely cause
**Current evidence position (performance/login path):** Two hypotheses are supported and one exclusive root cause is not yet proven.
- **Supported Hypothesis 1:** Friday deployment of Legal Document Manager v5.2 is aligned to impact scope and timing, with app-specific faults and shortcut timeout signals.
- **Supported Hypothesis 4:** Heavy background processing (including indexing workload) is present during slow-login conditions.

**Status:** **NO SINGLE ROOT CAUSE SELECTED**. Remains **NEED TO VERIFY** until one hypothesis is isolated by additional multi-device timeline evidence.

### 2) Keep workstreams separate
- **Performance remediation workstream (this section):** Restore Floor 6 login and endpoint performance.
- **Copilot security workstream (separate):** Potential unauthorized content visibility is handled by InfoSec and compliance workflow. Do not merge security evidence handling into endpoint performance rollback steps.

### 3) Prerequisites (must be true before action)
- Confirm incident commander approval to change production assignment state.
- Confirm change window and named approver for Floor 6 remediation.
- Confirm service health is stable enough to apply assignment changes.
- Confirm verified admin access to the tenant tool used for app assignments.
- Confirm an active incident bridge and communication owner.

### 4) Blast-radius check (before any rollback/removal)
- Verify exact target population currently assigned the app.
- Compare affected vs unaffected users/devices in the same migration cohort.
- Confirm whether assignment is Floor 6-only or broader.
- If broader, isolate rollback/removal scope to Floor 6 impact group first.

### 5) Backup/current-state capture (before change)
Capture and retain:
- Current app assignment configuration (include deployment intent and included/excluded groups).
- Current app install status by device/user for affected and unaffected samples.
- Timestamped list of impacted users/devices and symptom class.
- Change record ID and screenshots/exports of assignment state.

Label all captures with UTC/local timestamp and incident ID.

### 6) Action
Because required execution values are not fully verified in this packet (verified tenant tool, app ID, group ID, deployment type, and exact command syntax), **do not run a concrete command string yet**.

Evidence-informed operational decision:
- Proceed with **targeted containment** for Floor 6 scope only (assignment disable/remove path), because deployment alignment and app/indexing load are both supported.
- Treat this as an incident mitigation action, not root-cause closure.

Use this verified-only template:

```powershell
# NEED TO VERIFY before execution:
# - TenantTool = NEED TO VERIFY
# - AppId = NEED TO VERIFY
# - GroupId = NEED TO VERIFY
# - DeploymentType = NEED TO VERIFY (required/available/uninstall or platform equivalent)
# - CommandSyntax = NEED TO VERIFY for the confirmed tenant tool/module version

<NEED TO VERIFY TenantTool command> `
  -AppId "NEED TO VERIFY" `
  -GroupId "NEED TO VERIFY" `
  -DeploymentType "NEED TO VERIFY" `
  <NEED TO VERIFY action that removes or disables assignment for impacted scope>
```

Operational intent for the action:
- Remove or disable the problematic app assignment for the impacted Floor 6 scope only.
- Avoid tenant-wide removal unless blast-radius evidence supports wider containment.

### 7) Expected result
Within the next login cycle after policy refresh:
- New app rollout pressure is removed for Floor 6 targeted users/devices.
- Login delays and startup slowness trend downward.
- New incident volume from Floor 6 decreases on the same symptom pattern.
- If no material improvement is observed, treat as evidence against deployment-only explanation and escalate alternative path verification.

### 8) Verification
Verify in this order:
1. Assignment state reflects intended removed/disabled scope.
2. Two to three pilot affected devices receive updated policy state.
3. Pilot users complete login with materially improved time.
4. Helpdesk intake trend shows reduced new cases in 30-60 minutes.
5. No unintended impact appears in unaffected floors or departments.
6. Capture per-device joined timeline (install/change time, first slow login, process spikes, crash/shortcut timestamps) to isolate a single surviving hypothesis.

### 9) Rollback trigger
Trigger rollback/reinstatement review if any of the following occur:
- Login/performance does not improve after policy/application interval.
- Impact expands beyond Floor 6 after assignment change.
- A critical legal workflow dependency is broken by assignment removal.

If rollback trigger is met, restore prior assignment state from captured baseline under incident commander approval.

### 10) Rollback or assignment-removal command policy
A **concrete rollback/removal command** will only be issued once all of the following are explicitly verified in-record:
- Verified tenant tool
- Verified app ID
- Verified group ID
- Verified deployment type
- Verified command syntax for the tool/module version in use

Until then, use placeholders marked **NEED TO VERIFY** only.

---

## Part B - Floor 6 User Message (Calm, Plain Language)

**Subject:** Floor 6 login and computer slowness - IT is working on it

Hello Floor 6 team,

This morning, some of you are seeing slow sign-in, slow computer performance after login, and in some cases missing desktop shortcuts.

IT is actively investigating and making changes to reduce impact. We are treating this as a priority and are working through both system performance and access-related checks.

Current technical findings show signs of high background workload on affected devices, and we are applying targeted changes for Floor 6 to reduce that pressure while analysis continues.

What you should do now:
- Keep your device powered on and connected to the network.
- If you can sign in, continue working and report if login takes longer than usual.
- If you cannot sign in, contact the service desk and include your device name, time of failure, and any error message shown.
- Do not attempt repeated self-fixes that change system settings unless IT asks you to.

How to report impact:
- Service Desk: NEED TO VERIFY
- Include: your name, location (Floor 6), device name, first time issue was seen, and whether issue is login failure, slow login, or missing shortcuts.

Update cadence:
- Next update will be provided in **30 minutes**.
- After that, updates will be sent **every 60 minutes** until the incident is stabilized.

Thank you for your patience while we work this.
