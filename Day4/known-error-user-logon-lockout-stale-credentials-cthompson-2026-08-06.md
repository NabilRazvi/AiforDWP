Symptom     : User FINBRIDGE\\cthompson cannot log in interactively on DESKTOP-FB022. During the incident, login attempts failed until account recovery was completed.

Cause       : Verified root cause was account lockout triggered by repeated wrong-password attempts. A contributing factor was stale cached credentials being retried from multiple sources, including DESKTOP-FB022 and source IP 10.10.8.112.

Scope       : This incident affected one user only: FINBRIDGE\\cthompson. Observed systems in scope were DESKTOP-FB022 and a secondary credential source at 10.10.8.112.

Workaround  : Restore service by containing/remediating stale credential retry paths, then correcting account state. In this case, account recovery was performed (Event 4722 at 09:08:14) and successful interactive logon was then verified (Event 4624 at 09:09:01).

Permanent fix: Apply the stale credential hygiene runbook and enforce completion during lockout incidents. Implement multi-source lockout detection using correlated Events 4776, 4771, 4625, and 4740 to catch and contain recurrence early.

How to spot it: Look for the sequence of wrong-password failures and lockout: Event 4776 (0xC000006A), repeated Event 4625 bad password (logon type 2), Event 4740 lockout, and Event 4625 account locked out (logon type 7). Also confirm repeated Event 4771 failures with code 0x18 from a second source (10.10.8.112) and recovery with Event 4722 followed by Event 4624 success.