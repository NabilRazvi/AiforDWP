# Triage Summary: T-1004 Company App Fails to Install from Company Portal

## Summary (one line)
User cannot install a company app from Company Portal, with install failure code 0x87D1041C, indicating an endpoint app deployment issue (to-verify root cause).

## Impact (who/how many/business urgency)
- Who affected: One user is confirmed; additional users targeting the same app deployment may also be affected (to-verify).
- How many affected: One confirmed so far (to-verify broader scope).
- Business urgency: Medium to high depending on whether the app is required for core duties or time-critical work (to-verify).

## Known facts
- Ticket ID: T-1004.
- Reported issue: Company app fails to install from Company Portal.
- Observed code: 0x87D1041C.
- Entry point: Company Portal client flow.
- Platform context: Windows endpoint environment in service desk scope (to-verify exact OS build and device type).

## Missing information to gather
1. Affected user identity, device name, and business function criticality (to-verify).
2. Exact app name/version and whether it is required or optional for the user (to-verify).
3. Full on-screen failure message text and timestamp of the latest failed attempt (to-verify).
4. Whether other users assigned the same app can install successfully (to-verify).
5. Whether this user/device has successfully installed other Company Portal apps recently (to-verify).
6. Current network context during install attempts (office, VPN, home, restricted network) (to-verify).
7. Device management state in endpoint management portal: enrolled, compliant, and recently synced (to-verify).
8. Assignment targeting details for this app: user/device group membership and install intent (to-verify).
9. Available disk space and any pending reboot on the endpoint (to-verify).
10. Local install log excerpts from Company Portal/agent around the failure time (to-verify).

## Likely catagory
Endpoint management / Intune app deployment: Company Portal app installation failure (to-verify).

## First diagnostic step
Confirm the app assignment and device compliance/sync status for the affected user-device pair in endpoint management, then trigger a fresh Company Portal sync and retry install while capturing the exact failure message and timestamp for correlation (to-verify).
