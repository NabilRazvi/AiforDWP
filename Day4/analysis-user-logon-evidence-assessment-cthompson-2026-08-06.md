# User Logon Incident - Evidence Assessment Against Hypotheses (cthompson)

## Scope
- Symptom: user cthompson not able to login
- Who: cthompson only one user
- Since: ~08:40 this morning
- Change: Nil

## Evidence Window
- Security log window reviewed: 08:44 to 08:46 (DESKTOP-FB022 + Kerberos failures from 10.10.8.112)

## Hypothesis-by-Hypothesis Judgement

### 1) Account lockout from bad-password attempts
- Judgement: Support
- Why:
  - Repeated wrong-password failures precede lockout.
  - Explicit lockout event is present.
  - Subsequent attempt shows locked-out state.
- Determining events:
  - Event 4776 at 08:44:01: error 0xC000006A (wrong password).
  - Event 4625 at 08:44:03, 08:44:28, 08:44:55: bad password (interactive logon type 2).
  - Event 4740 at 08:44:56: account locked out.
  - Event 4625 at 08:45:10: failure reason account locked out (logon type 7 unlock attempt).

### 2) Password expired or password state issue
- Judgement: Contradicts (weak-to-moderate)
- Why:
  - Observed failures are wrong-password and lockout patterns, not explicit password-expired indicators.
  - No event in this window explicitly states expiry.
- Determining events:
  - Event 4776 at 08:44:01: wrong password (0xC000006A), not expiry.
  - Event 4771 at 08:45:44, 08:46:01, 08:46:33: Kerberos pre-auth failure code 0x18 (wrong password).
  - Event 4625 at 08:44:03/08:44:28/08:44:55: bad password.

### 3) MFA challenge failure for this user
- Judgement: Contradicts
- Why:
  - Failures shown are credential-validation and Kerberos pre-auth failures before any MFA stage.
  - No MFA-related failure artifact appears in this evidence set.
- Determining events:
  - Event 4776 at 08:44:01: domain credential validation failed (wrong password).
  - Event 4625 at 08:44:03/08:44:28/08:44:55: bad password (interactive).
  - Event 4740 at 08:44:56: account lockout occurred.

### 4) Conditional Access or identity policy block scoped to user conditions
- Judgement: Contradicts (for this incident window)
- Why:
  - Recorded failures are on-password validation and lockout signals in security logs, not policy-deny decisions.
  - Evidence indicates authentication failed before policy-evaluation outcomes would be the primary blocker.
- Determining events:
  - Event 4776 at 08:44:01: wrong password.
  - Event 4625 at 08:44:03/08:44:28/08:44:55: bad password.
  - Event 4740 at 08:44:56: lockout.

### 5) Endpoint-specific credential/profile issue (cached credentials or local profile)
- Judgement: Support
- Why:
  - Interactive failures and lockout caller are tied to DESKTOP-FB022, indicating endpoint-local involvement.
  - Additional wrong-password Kerberos attempts originate from different IP 10.10.8.112, consistent with another device/service using stale credentials and potentially re-locking.
- Determining events:
  - Event 4625 at 08:44:03/08:44:28/08:44:55: interactive failures from DESKTOP-FB022.
  - Event 4740 at 08:44:56: caller computer DESKTOP-FB022.
  - Event 4771 at 08:45:44/08:46:01/08:46:33: wrong-password pre-auth from 10.10.8.112 (different source).

## Interim Position
- No single winner selected yet.
- This step only scores each original hypothesis against the supplied event evidence.

## Appended Update - Event Details, Surviving Hypothesis, and Resolution

### Detailed Event Notes (Incident Window)
- 08:44:01 - Event 4776 (Audit Failure): domain credential validation failed for FINBRIDGE\cthompson, error 0xC000006A (wrong password), source workstation DESKTOP-FB022.
- 08:44:03 - Event 4625 (Audit Failure): bad password for FINBRIDGE\cthompson, logon type 2 (interactive), source DESKTOP-FB022.
- 08:44:28 - Event 4625 (Audit Failure): bad password for FINBRIDGE\cthompson, logon type 2 (interactive), source DESKTOP-FB022.
- 08:44:55 - Event 4625 (Audit Failure): bad password for FINBRIDGE\cthompson, logon type 2 (interactive), source DESKTOP-FB022.
- 08:44:56 - Event 4740 (Audit Failure): account FINBRIDGE\cthompson locked out, caller computer DESKTOP-FB022.
- 08:45:10 - Event 4625 (Audit Failure): account locked out during unlock attempt (logon type 7), source DESKTOP-FB022.
- 08:45:44 - Event 4771 (Audit Failure): Kerberos pre-auth failed (0x18 wrong password) for FINBRIDGE\cthompson from source IP 10.10.8.112.
- 08:46:01 - Event 4771 (Audit Failure): Kerberos pre-auth failed (0x18 wrong password) for FINBRIDGE\cthompson from source IP 10.10.8.112.
- 08:46:33 - Event 4771 (Audit Failure): Kerberos pre-auth failed (0x18 wrong password) for FINBRIDGE\cthompson from source IP 10.10.8.112.

### Surviving Hypothesis
- Account lockout caused by repeated bad-password attempts, with likely stale credentials replaying from one or more sources.
- Primary observed source: DESKTOP-FB022.
- Additional observed source: 10.10.8.112 (different host/IP), indicating potential secondary credential replay path.

### Detailed Resolution Steps
1. Contain retry sources before unlock/reset
- Identify all active sign-in sources for cthompson, prioritizing DESKTOP-FB022 and the host mapped to 10.10.8.112.
- Temporarily isolate suspect sources from network if automated retries continue.
- Confirm containment by checking no new 4771/4776 failures for 5-10 minutes.

2. Validate account state and perform controlled reset
- Verify lockout state and bad password counters on the account.
- Reset password to a temporary strong value.
- Keep account locked until stale-credential sources are remediated to avoid immediate re-lock.

3. Clean stale credentials on DESKTOP-FB022
- Sign out of identity-backed apps (Outlook/Teams/OneDrive), then close them.
- Remove cached credentials from Credential Manager for domain/SSO resources.
- Review and correct saved credentials in mapped drives, printer mappings, scheduled tasks, and user-context services.
- Purge Kerberos tickets in user context and reboot endpoint.

4. Investigate and remediate source 10.10.8.112
- Map 10.10.8.112 to a concrete asset/user/service via DHCP/DNS/CMDB/EDR.
- Check that source for stale credentials in services, scripts, mail clients, VPN, RDP, or other persisted auth paths.
- Disable/update the process using old credentials.

5. Controlled unlock and validation test
- Unlock account once both known sources are remediated.
- Test interactive sign-in on DESKTOP-FB022.
- Test core apps sequentially (Outlook, Teams, OneDrive, VPN where in scope).
- If lockout recurs, correlate exact timestamp with source and remediate that source before retry.

6. Stability verification
- Monitor for 30-60 minutes after restoration.
- Success criteria: no new 4740 events and no new 4771/4776 wrong-password failures for cthompson.

7. Closure and prevention notes
- Document root trigger source(s), stale credential location(s), and final fix.
- Add monitoring/alerting for repeated 4771/4776 patterns on the account to detect early recurrence.
- Advise removal of obsolete saved credentials on secondary devices.