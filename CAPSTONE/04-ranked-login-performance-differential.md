# Ranked Differential: Floor 6 Legal Login and Performance Problem
**Date:** 2026-08-14 (Monday)  
**Scope analyzed:** Floor 6 Legal login failures, slow logins/performance, missing desktop shortcuts, and one Copilot report involving an unfamiliar client matter  
**Method:** Ranked differential only. Confirmed facts are weighted heavily, but correlation is not treated as proof.

---

## Confirmed Facts Weighted Heavily

- Affected area is Floor 6 Legal.
- Devices were recently migrated to Windows 11.
- Devices were recently enrolled in Intune.
- A new document-management app was deployed Friday afternoon.
- Problems were reported Monday morning.

---

## Ranked Differential

### 1. Friday document-management app introduced login/startup overhead and may also have changed document visibility or indexing behavior

**Rank:** 1. **Why it fits:** Best timing match: Friday deployment, Monday symptoms, and Floor 6 Legal scope; one app change could plausibly affect login time, shortcuts, and repository/search visibility.  
**Fastest safe check:** Compare Friday deployment scope and install status against affected users/devices. **Support:** strong cohort alignment, startup/indexing/repository behavior, app service account or connector scope. **Contradict:** many affected devices lack the app, or package review shows no plausible mechanism. **Status:** NEED TO VERIFY

---

### 2. Post-migration Windows 11 plus Intune policy/compliance processing is causing authentication delays, slow first logon, and profile-side effects

**Rank:** 2. **Why it fits:** Recent Win11 migration and Intune enrollment are a strong fit for Monday login delay, sign-in failures, and profile or shortcut side effects across one cohort.  
**Fastest safe check:** Review sign-in outcomes and Intune compliance state for affected Floor 6 users/devices. **Support:** conditional-access or compliance failures, repeated policy processing, profile reset indicators. **Contradict:** healthy compliant devices with no shared policy pattern, or evidence points specifically to the Friday app. **Status:** NEED TO VERIFY

---

### 3. Access or group-membership misprovisioning during migration or app rollout changed who can see legal content and may also be interfering with sign-in

**Rank:** 3. **Why it fits:** Migration or rollout could have changed group membership, ACL inheritance, or connector scope for Floor 6 Legal, which fits the Copilot access concern and may also affect sign-in access paths.  
**Fastest safe check:** Compare pre-Friday and current group memberships plus repository permissions for the reporting paralegal and a sample of affected users. **Support:** new broad group/ACL changes or connector scope expansion. **Contradict:** no identity/access changes, or user has no actual access despite the Copilot result. **Status:** NEED TO VERIFY

---

### 4. Heavy background processing on recently migrated endpoints is causing Monday slowness, while the Copilot allegation is a separate issue

**Rank:** 4. **Why it fits:** Recently migrated endpoints often spend Monday morning finishing updates, indexing, sync, or scan work, which fits slow logons and poor performance across a cohort.  
**Fastest safe check:** Capture one live performance snapshot during or just after a slow login. **Support:** CPU/disk pressure from updates, indexing, sync, or scans with eventual successful login. **Contradict:** no resource contention, or failures are clearly authentication-related rather than performance-related. **Status:** NEED TO VERIFY

---

### 5. User-profile or desktop redirection issue on Floor 6 Legal devices is creating missing shortcuts and slower logons, but does not explain the full incident alone

**Rank:** 5. **Why it fits:** Missing shortcuts point to profile, shell-folder, or desktop redirection issues, and the same faults can slow logon after migration or Intune enrollment.  
**Fastest safe check:** Verify one affected user's desktop path, active profile state, and Start menu entries. **Support:** wrong or reset desktop/profile path and shell-load delay. **Contradict:** shortcut loss is clearly caused by the Friday app package, or login failure occurs before profile load. **Status:** NEED TO VERIFY

---

## Evidence required to confirm or rule out the Friday deployment as the cause

Do not treat timing alone as proof. The Friday deployment should only move from suspicion to supported if evidence shows both technical capability and cohort alignment.

### Required evidence

1. **Deployment scope and targeting**
- Exact package name, version, and release notes.
- Assignment target: whether the rollout was limited to Floor 6 Legal or a broader cohort.
- Device/user list showing who was targeted.

2. **Install status by cohort**
- Per-device or per-user install success, failure, retry, and timestamp data.
- Comparison of affected versus unaffected users to test whether symptoms cluster on installed systems.

3. **Package behavior review**
- Whether the app adds startup tasks, services, shell extensions, repository sync, desktop changes, or indexing components.
- Whether it modifies login flow, profile initialization, or desktop shortcuts.

4. **Repository and search integration details**
- Whether the app connects to document repositories, syncs matter data, or contributes content to search/Copilot-visible systems.
- Any service account, connector, delegated permission, or broad read scope used by the app.

5. **Timing correlation with hard evidence**
- Verified install timestamps on affected devices.
- First known symptom timestamps Monday morning.
- Evidence that the problem began after install, not before.

6. **Comparison group evidence**
- A matched cohort with similar Win11 and Intune state but without the Friday app rollout.
- Confirmation whether that cohort did or did not experience similar Monday symptoms.

7. **Direct technical traces from at least one affected device**
- Startup/service/task evidence showing the app active during slow logon.
- Local logs or telemetry showing the app consuming resources, delaying login, altering the shell, or failing repeatedly.

8. **Access-control evidence for the Copilot allegation**
- Current and recent ACLs for the surfaced legal matter or repository.
- Copilot interaction record showing what was surfaced.
- Proof of whether the reporting user had actual access, inherited access, or no legitimate access at all.

### Evidence that would move the Friday deployment toward supported

- Most affected users/devices received the Friday app, and most unaffected comparators did not.
- The package demonstrably changes startup behavior, shell state, or repository indexing.
- Technical logs show the app active in the incident path on affected systems.
- The Copilot allegation traces to app-driven indexing, connector scope, or permissions introduced by the deployment.

### Evidence that would move the Friday deployment toward ruled out

- No meaningful cohort alignment exists between deployment and affected users.
- The package has no plausible mechanism for login, performance, shortcut, or repository-visibility effects.
- A matched non-deployed cohort has the same symptoms.
- Identity, Win11, or Intune evidence fully explains the issue without needing the Friday app.

---

## Current Position

No single hypothesis is confirmed from the current facts. The list above is limited to the top five most plausible explanations based on the current timing and scope, and each remains **NEED TO VERIFY** until cohort alignment, package behavior, identity evidence, and access-control evidence are collected.

---

## Appended Evidence Evaluation (Based on Supplied Inputs)

**Evaluation timestamp:** 2026-08-14  
**Supplied evidence fields:**
- Controlled device output from corrected script (`Computer Name: LEG-FL6-011`, `Collection Time: 2026-08-10 09:42:15`)
- Intune deployment summary and unaffected-device comparison (deployment/change record timestamp `2026-08-08 16:30`)

### Hypothesis 1
**Statement:** Friday document-management app introduced login/startup overhead and may also have changed document visibility or indexing behavior.  
**Judgement:** **SUPPORTS**  
**Determining supplied field(s) and timestamps:**
- `Deployment Ring: Floor6-Legal`, `Install Success: 45 / 45 devices`, and `No deployments were made to other floors` (`2026-08-08 16:30`).
- Controlled-device login differential: `Average Login Time (Previous Week): 42 seconds` vs `Average Login Time (Today): 312 seconds` (`Collection Time: 2026-08-10 09:42:15`).
- Controlled-device resource load: `Top Processes By CPU: DocManager.exe 38%` and `Top Processes By Memory: DocManager.exe 2.4 GB` (`Collection Time: 2026-08-10 09:42:15`).
- Application faults: `Application: DocManager.exe`, `Event ID: 1000`, `Exception Code: 0xc0000005` at `2026-08-10 08:58:41` and `2026-08-10 09:03:59`.
- Shortcut failure: `Shortcut Creation Script Failed` at `2026-08-10 08:52:11` with `Error: DocManager Shell Extension Timeout`.
- Change record mechanism match: `Introduced: Shell integration, Matter indexing engine, Desktop shortcut management component`; `Known Issue: Initial indexing can increase CPU and memory consumption` (`2026-08-08 16:30`).

### Hypothesis 2
**Statement:** Post-migration Windows 11 plus Intune policy/compliance processing is causing authentication delays, slow first logon, and profile-side effects.  
**Judgement:** **CONTRADICTS**  
**Determining supplied field(s) and timestamps:**
- Unaffected comparison cohort on v5.1 shows normal outcomes: `Average Login Time: 38 seconds`, `Application Crashes: 0`, `Missing Shortcuts: 0`, `Login Failures: 0` (comparison supplied with deployment context `2026-08-08 16:30`).
- Controlled-device error signatures are app-specific (`DocManager.exe` crashes at `2026-08-10 08:58:41` and `2026-08-10 09:03:59`; `DocManager Shell Extension Timeout` at `2026-08-10 08:52:11`) rather than policy/compliance telemetry.
**Status:** **NEED TO VERIFY**  
**Minimum next evidence required:**
1. Intune compliance timeline and Conditional Access result logs for affected Floor 6 users during Monday symptom window.
2. Per-device policy processing durations/error codes for Floor 6 versus unaffected comparison devices.

### Hypothesis 3
**Statement:** Access or group-membership misprovisioning during migration or app rollout changed who can see legal content and may also be interfering with sign-in.  
**Judgement:** **NEUTRAL**  
**Determining supplied field(s) and timestamps:**
- No supplied field includes group-membership deltas, ACL changes, connector scope changes, or Copilot retrieval audit records.
- Available timestamps (`2026-08-10 08:52:11`, `08:58:41`, `09:03:59`, `09:42:15`) are operational/app events, not identity/authorization evidence.
**Status:** **NEED TO VERIFY**  
**Minimum next evidence required:**
1. Before/after group membership and repository ACL delta for affected users.
2. Copilot retrieval/source trace for the reported unfamiliar matter.
3. Sign-in/access denial logs mapped to impacted users and times.

### Hypothesis 4
**Statement:** Heavy background processing on recently migrated endpoints is causing Monday slowness, while the Copilot allegation is a separate issue.  
**Judgement:** **SUPPORTS**  
**Determining supplied field(s) and timestamps:**
- Elevated workload during incident window: `DocManager.exe 38% CPU`, `SearchIndexer.exe 12% CPU`, `DocManager.exe 2.4 GB memory` (`Collection Time: 2026-08-10 09:42:15`).
- Login slowdown coincides with high workload: `42 seconds` previous week vs `312 seconds` today (`Collection Time: 2026-08-10 09:42:15`).
- Release notes include workload risk: `Known Issue: Initial indexing can increase CPU and memory consumption` (`2026-08-08 16:30`).
**Status:** **NEED TO VERIFY**  
**Minimum next evidence required:**
1. Same-time snapshots from additional affected Floor 6 devices to confirm repeatability.
2. Per-device timeline showing indexer/process spikes immediately preceding slow login completion.

### Hypothesis 5
**Statement:** User-profile or desktop redirection issue on Floor 6 Legal devices is creating missing shortcuts and slower logons, but does not explain the full incident alone.  
**Judgement:** **CONTRADICTS**  
**Determining supplied field(s) and timestamps:**
- Shortcut failure is explicitly app-shell related: `Shortcut Creation Script Failed` at `2026-08-10 08:52:11`; `Error: DocManager Shell Extension Timeout`.
- Change record provides direct alternate mechanism: `Desktop shortcut management component` introduced in v5.2 (`2026-08-08 16:30`).
**Status:** **NEED TO VERIFY**  
**Minimum next evidence required:**
1. Profile path/redirection policy results for affected users.
2. Logon-phase trace distinguishing profile-load delay from post-shell shortcut creation delay.

## Root Cause Selection Gate

No root cause selected. More than one hypothesis survives current evidence (`Hypothesis 1` and `Hypothesis 4` are supported), so the current evidence is not exclusive.

**Status:** **NEED TO VERIFY**  
**Minimum next evidence required to isolate one surviving hypothesis:**
1. Multi-device Floor 6 sample proving whether delay is primarily app startup/indexing path or another shared path.
2. Per-device joined timeline: deployment/install timestamp, first slow login timestamp, process spike window, crash and shortcut error timestamps.
3. One matched Floor 6 device on v5.2 without symptoms (if present) to identify required co-factors.
