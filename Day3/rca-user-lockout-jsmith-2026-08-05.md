# Root Cause Analysis: User Lockout Incident (jsmith)

## Incident Metadata
- Analyst: DWP Analyst
- Date of analysis: 2026-08-05
- Incident window reviewed: 08:02:14 to 08:23:44 (30-minute window provided)
- User account: jsmith
- Source endpoint observed: DESKTOP-FB001
- Domain actor for unlock action: FINBRIDGE\helpdesk-admin

## Scope and Evidence
The analysis below is based only on the supplied Security event entries:
- 4625 failures at 08:02:14 and 08:04:22 (bad password, logon type 2)
- 4740 lockout at 08:06:01
- 4625 failure at 08:07:45 (account locked out, logon type 7)
- 4722 success at 08:22:10 (account enabled by helpdesk-admin)
- 4624 success at 08:23:44 (interactive logon)

Where certainty is limited by missing policy/context, this document marks points as to-verify.

## Event ID Meaning (What Each Event Records)

### Event ID 4625 (Audit Failure)
- Records a failed logon attempt.
- In this incident, it shows failed authentication for jsmith from DESKTOP-FB001.
- Failure reason variants seen:
  - Unknown username or bad password
  - Account locked out
- Logon types seen:
  - Type 2: Interactive logon attempt at the console.
  - Type 7: Workstation unlock attempt.

### Event ID 4740 (Audit Failure)
- Records that a user account was locked out by lockout policy.
- Includes the caller/source computer where lockout-triggering attempts were associated.
- Here it states jsmith was locked out and called from DESKTOP-FB001.

### Event ID 4722 (Audit Success)
- Records that an account was enabled.
- Includes who performed the action.
- Here jsmith was enabled by FINBRIDGE\helpdesk-admin.
- to-verify: In some environments, lockout remediation may be logged as unlock (for example, different admin workflows or tooling) rather than explicit enable event; local policy/audit configuration should be checked.

### Event ID 4624 (Audit Success)
- Records a successful logon.
- Here jsmith successfully logged on interactively (type 2) after helpdesk action.

## Reconstructed Sequence in Plain English
1. At 08:02:14, jsmith entered invalid credentials at the machine console (DESKTOP-FB001), causing a failed interactive sign-in.
2. At 08:04:22, a second invalid interactive sign-in attempt occurred from the same machine.
3. At 08:06:01, the account hit lockout policy threshold and was locked (event 4740).
4. At 08:07:45, an unlock attempt was made on the locked workstation session (logon type 7) and failed specifically because the account was locked.
5. At 08:22:10, helpdesk admin performed an account administrative action (event 4722: account enabled).
6. At 08:23:44, jsmith successfully signed in interactively, indicating access was restored.

## Most Likely Cause of Lockout
### Primary cause
Repeated bad password entry for jsmith at the local interactive console on DESKTOP-FB001 triggered account lockout policy.

### Evidence supporting this cause
- Two pre-lockout 4625 events with reason Unknown username or bad password from same source DESKTOP-FB001.
- A direct 4740 lockout event immediately after these failures.
- A subsequent 4625 with reason Account locked out during unlock attempt, consistent with a post-threshold state.
- Successful login only after helpdesk administrative intervention.

### Alternative hypotheses and confidence
- Cached credentials mismatch after password change: plausible, but not directly evidenced in supplied events (to-verify).
- Keyboard layout/input issue causing bad password entry: plausible for repeated local failures, not directly evidenced (to-verify).
- Brute-force from remote host: low likelihood in this slice because all listed attempts are tied to DESKTOP-FB001 and local/unlock logon types.

## 5 Whys Analysis

### Problem statement
User jsmith was locked out and could not access their machine during the incident window.

1. Why was jsmith locked out?
- Because account lockout policy was triggered (event 4740 at 08:06:01).

2. Why was account lockout policy triggered?
- Because multiple failed authentication attempts occurred for jsmith (4625 bad password failures at 08:02:14 and 08:04:22, followed by locked state).

3. Why were there multiple failed authentication attempts?
- Most likely incorrect password entry or outdated remembered credentials entered at console/unlock.
- to-verify: whether user had recently changed password, had sticky keys/input locale issue, or credential manager artifacts.

4. Why did the user remain unable to access until helpdesk action?
- Because once lockout threshold was exceeded, further authentication was denied (4625 account locked out at 08:07:45) until administrative action.

5. Why did this become an incident rather than a self-recovering user error?
- Account policy and support flow required admin intervention to restore access (4722 by helpdesk-admin), and user lacked immediate self-service path.

## Root Cause Statement
The lockout was caused by repeated invalid local interactive credential attempts for jsmith on DESKTOP-FB001, which exceeded lockout policy threshold and blocked access until helpdesk intervened.

## Corrective and Preventive Actions (CAPA)

### Immediate corrective actions
- Confirm user can authenticate post-remediation (already evidenced by 4624 success at 08:23:44).
- Confirm no continued 4625 failures after recovery window (to-verify with additional logs).

### Preventive actions
1. User-side controls
- Reinforce password change/rotation communication and expected credential update steps.
- Provide quick guidance for verifying keyboard layout/caps lock before retrying credentials.

2. Support workflow
- Implement or improve self-service unlock path where policy allows.
- Standardize lockout triage checklist: source host, logon types, count of failures, timeline to admin action.

3. Monitoring and alerting
- Alert on repeated 4625 for same account and same endpoint before threshold is reached.
- Correlate 4625 + 4740 + admin remediation events into single incident timeline for faster triage.

4. Policy tuning (if business-approved)
- Review lockout threshold and reset window balance between security and usability.
- to-verify against security baseline owner before any change.

## Validation Checks to Close Incident
- Verify in Security logs that:
  - No additional 4740 events for jsmith occurred after 08:23:44.
  - 4625 frequency normalized for jsmith on DESKTOP-FB001.
  - No suspicious logon types or alternate source hosts appeared in the wider window.
- Confirm user report: access restored and stable.

## Gaps / To-Verify Against Environment and Microsoft Guidance
- Exact domain/local lockout threshold and observation window values.
- Whether event 4722 usage (enable) aligns with your AD unlock process/tooling in this tenant.
- Whether any related identity events (for example, password change/reset) occurred just before 08:02:14.

## Executive Summary (One Paragraph)
During the reviewed 30-minute window, jsmith experienced repeated failed local interactive sign-in attempts from DESKTOP-FB001, which triggered account lockout policy (event 4740). A subsequent unlock attempt failed because the account was already locked. Helpdesk admin then performed account remediation (event 4722), after which jsmith successfully logged in (event 4624). The most likely root cause is repeated incorrect credential entry (or stale local credential usage) at the endpoint, with lockout policy enforcement turning a user-authentication issue into a service interruption requiring admin intervention.
