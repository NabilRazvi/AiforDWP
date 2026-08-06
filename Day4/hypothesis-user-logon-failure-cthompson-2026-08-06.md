# User Logon Incident Hypothesis - cthompson (2026-08-06)

## Scope Facts
- Symptom: user cthompson not able to login
- Who: cthompson only one user
- Since: ~08:40 this morning
- Change: Nil

## Ranked Most Likely Causes (Most probable first)

1. Account lockout from bad-password attempts
- Why this fits the scope facts:
  - Sudden onset at a specific time is typical of lockout threshold hit.
  - Single-user impact strongly matches user-level lockout.
  - Can occur with no declared change (for example stale saved credentials repeatedly retrying).
- Single fastest check:
  - Check identity logs for cthompson lockout/bad password events and current lockout state; if locked, unlock once and retest sign-in.

2. Password expired or password state issue
- Why this fits the scope facts:
  - Policy-driven expiry can begin at start of day and affect only one user.
  - Users often report no change when expiry is the trigger.
- Single fastest check:
  - Verify password expiry/status on the account and perform a reset, then test immediate sign-in.

3. MFA challenge failure for this user
- Why this fits the scope facts:
  - MFA failures are commonly user-specific and can start abruptly.
  - No visible environment change is needed for MFA failure to occur.
- Single fastest check:
  - Review latest sign-in failure reason for cthompson for MFA deny/timeout/unavailable challenge.

4. Conditional Access or identity policy block scoped to user conditions
- Why this fits the scope facts:
  - Policy decisions can change based on risk, location, device compliance, or session context.
  - This can affect one user while others remain unaffected.
- Single fastest check:
  - Inspect the most recent failed sign-in decision details to identify any blocking policy and its reason.

5. Endpoint-specific credential/profile issue (cached credentials or local profile)
- Why this fits the scope facts:
  - Local endpoint issues can isolate failure to one user.
  - Fits a sudden issue with no tenant-wide change.
- Single fastest check:
  - Attempt cthompson sign-in via a different known-good path (web sign-in or another workstation) to separate account vs endpoint cause.

## Note
- No single cause has been selected yet.
- This is a ranked hypothesis list based only on scope facts.
