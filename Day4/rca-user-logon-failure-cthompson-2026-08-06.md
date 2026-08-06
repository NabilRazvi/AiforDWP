# Root Cause Analysis: User Logon Failure - FINBRIDGE\\cthompson

## Incident Overview
- Incident ID: INC-LOGON-CTHOMPSON-20260806-001
- Date of incident: 2026-08-06
- Affected user: FINBRIDGE\\cthompson
- Affected endpoint(s): DESKTOP-FB022 (confirmed), source IP 10.10.8.112 (confirmed secondary source)
- Severity: Medium (single-user access failure)
- Status: Resolved
- Resolution confirmation time: 09:09 AM

---

## Incident Summary
At approximately 08:40, user FINBRIDGE\\cthompson was unable to log in. Security evidence shows repeated wrong-password attempts leading to account lockout, followed by continued Kerberos pre-authentication failures from a second source. Remediation was applied to stop stale credential retries, account state was corrected, and successful interactive logon was verified at 09:09 with no further user issues reported.

---

## Scope and Constraints Used During Analysis
- Symptom: user cthompson not able to login
- Who: cthompson only one user
- Since: ~08:40 this morning
- Change: Nil reported

---

## Timeline (Evidence-Based)

| Time | Event | Interpretation |
|---|---|---|
| ~08:40 | User reports unable to login | Incident start window based on user report |
| 08:44:01 | Security Event 4776 (Audit Failure), error 0xC000006A wrong password, source DESKTOP-FB022 | Credential validation failed due to wrong password |
| 08:44:03 | Security Event 4625 (Audit Failure), bad password, logon type 2, source DESKTOP-FB022 | Interactive bad-password attempt |
| 08:44:28 | Security Event 4625 (Audit Failure), bad password, logon type 2, source DESKTOP-FB022 | Continued bad-password attempts |
| 08:44:55 | Security Event 4625 (Audit Failure), bad password, logon type 2, source DESKTOP-FB022 | Additional bad-password attempt |
| 08:44:56 | Security Event 4740 (Audit Failure), account locked out, caller DESKTOP-FB022 | Account lockout threshold reached |
| 08:45:10 | Security Event 4625 (Audit Failure), failure reason account locked out, logon type 7, source DESKTOP-FB022 | Unlock/login attempt blocked due to lockout state |
| 08:45:44 | Security Event 4771 (Audit Failure), failure code 0x18 wrong password, source IP 10.10.8.112 | Secondary source continues wrong-password retries |
| 08:46:01 | Security Event 4771 (Audit Failure), failure code 0x18 wrong password, source IP 10.10.8.112 | Repeated wrong-password retry from secondary source |
| 08:46:33 | Security Event 4771 (Audit Failure), failure code 0x18 wrong password, source IP 10.10.8.112 | Ongoing replay/stale credential behavior |
| 09:08:14 | Security Event 4722 (Audit Success), account enabled, done by FINBRIDGE\\helpdesk-admin | Administrative recovery action completed |
| 09:09:01 | Security Event 4624 (Audit Success), successful logon type 2, source DESKTOP-FB022 | Interactive sign-in restored |
| 09:09 | User verification | User confirmed login works and no issues reported |

---

## Supporting Evidence (Raw Signals Mapped to Conclusion)

### A. Wrong password sequence from primary workstation
- Event 4776 at 08:44:01 with error 0xC000006A (wrong password).
- Event 4625 at 08:44:03, 08:44:28, 08:44:55 with bad password (logon type 2 interactive).

### B. Lockout confirmed
- Event 4740 at 08:44:56 confirms account lockout.
- Event 4625 at 08:45:10 confirms lockout blocked a subsequent unlock attempt (logon type 7).

### C. Secondary retry source indicates stale credential replay path
- Event 4771 at 08:45:44, 08:46:01, 08:46:33 with failure code 0x18 (wrong password) from 10.10.8.112.
- Source mismatch (DESKTOP-FB022 vs 10.10.8.112) indicates more than one credential submission path.

### D. Recovery evidence
- Event 4722 at 09:08:14 confirms account enabled by helpdesk-admin.
- Event 4624 at 09:09:01 confirms successful interactive logon from DESKTOP-FB022.
- User confirmation at 09:09 indicates service restoration from user perspective.

---

## Root Cause Statement
Primary cause: User account lockout triggered by repeated wrong-password attempts.

Contributing cause: One or more stale cached credential sources continued submitting incorrect credentials, including a secondary source (10.10.8.112), increasing lockout risk and persistence.

Why this is the root cause: The event chain directly shows wrong-password failures, explicit lockout, and post-remediation successful interactive logon. No evidence in the incident window supports MFA failure, conditional access block, or password-expiry as primary blockers.

---

## 5 Why Analysis

Problem statement: FINBRIDGE\\cthompson could not log in.

| Why | Answer |
|---|---|
| Why 1: Why could the user not log in? | The account was in locked-out state (Event 4740, then Event 4625 with account locked out). |
| Why 2: Why did the account become locked out? | Multiple wrong-password attempts were submitted in a short time window (Events 4776 and 4625 sequence). |
| Why 3: Why were repeated wrong passwords submitted? | Stale/incorrect credentials were likely stored and retried automatically from at least one endpoint/app path. |
| Why 4: Why did retries continue even after lockout? | A second source (10.10.8.112) kept performing Kerberos pre-auth attempts with wrong password (Event 4771 series). |
| Why 5: Why was this not prevented earlier? | There was no immediate detection/containment of multi-source stale credential replay for this user before lockout threshold was reached. |

---

## Resolution Actions Applied
1. Identified lockout and repeated wrong-password pattern from Security events.
2. Contained and remediated stale credential retry paths (primary endpoint and secondary source path investigation).
3. Performed account recovery action (account enabled by helpdesk-admin, Event 4722 at 09:08:14).
4. Validated successful interactive sign-in (Event 4624 at 09:09:01 from DESKTOP-FB022).
5. Confirmed user experience recovery (user reported no remaining issue at 09:09).

---

## Preventive Actions

### PA-1: Stale Credential Hygiene Standard (Priority: High)
- Enforce checklist during lockout incidents to clear Credential Manager, stale Outlook/Teams/OneDrive credentials, mapped resource saved credentials, and scheduled tasks using user context.
- Add to service desk runbook and require completion record.

### PA-2: Multi-Source Lockout Detection (Priority: High)
- Alert when same user has wrong-password events from multiple sources within a short window (for example 10 minutes).
- Include Event IDs 4776, 4771, 4625, and 4740 correlation logic.

### PA-3: Early Containment Procedure (Priority: Medium)
- Define a standard action: pause retries/isolate suspect endpoint(s) before unlock/reset to prevent immediate re-lock.
- Include explicit validation window (no new 4771/4776 for at least 5-10 minutes).

### PA-4: Source Attribution Playbook for Unknown IP (Priority: Medium)
- Create fast lookup workflow (DHCP/DNS/CMDB/EDR) to map source IPs like 10.10.8.112 to host/service owner quickly during incidents.

### PA-5: Post-Incident User Guidance (Priority: Low)
- Provide targeted user guidance on removing old saved passwords across secondary devices/clients after password changes.

---

## Validation and Closure
- Technical validation: Event 4624 success at 09:09:01 confirms restored interactive sign-in.
- Admin action validation: Event 4722 at 09:08:14 confirms account state recovery action completed.
- User validation: User confirmed successful login and no further issues at 09:09 AM.
- Closure decision: Incident resolved and closed with preventive actions captured.

---

## Residual Risk
- If any unmanaged secondary device still stores old credentials, lockout can recur.
- Mitigation is covered by PA-1 and PA-2; monitor for repeated 4771/4776 for this user for at least one business day.
