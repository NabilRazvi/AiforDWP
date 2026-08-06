# Triage Summary: T-1008 VPN Connects but No Internal Resources Reachable After Win11 Upgrade

## Summary (one line)
VPN session establishes successfully but internal resources are unreachable after a Windows 11 upgrade, indicating a post-upgrade network path or endpoint routing/name-resolution issue (to-verify root cause).

## Impact (who/how many/business urgency)
- Who affected: One remote user is confirmed.
- How many affected: One confirmed so far (to-verify whether other upgraded VPN users are impacted).
- Business urgency: High if user cannot access core internal systems needed for daily operations.

## Known facts
- Ticket ID: T-1008.
- Reported issue: VPN connects, but internal resources are not reachable.
- Timing context: Issue started after Windows 11 upgrade.
- Connectivity context: Tunnel establishment appears successful at user level (to-verify with session details).

## Missing information to gather
1. Affected user/device details and exact VPN client/profile used (to-verify).
2. Which internal resources fail (fileshares, intranet, line-of-business apps, remote desktops) (to-verify).
3. Whether failures are by name, by IP, or both (to-verify).
4. VPN session details at failure time: assigned IP, connection duration, and reconnect behavior (to-verify).
5. Local internet access behavior while VPN is connected (to-verify).
6. Whether issue reproduces across different networks (home Wi-Fi, hotspot, office) (to-verify).
7. Any recent VPN client updates/policy pushes concurrent with Win11 upgrade (to-verify).
8. Endpoint routing and adapter state after VPN connection (to-verify).
9. Firewall/security software behavior post-upgrade that may affect internal traffic (to-verify).
10. Whether other users on same VPN profile after Win11 upgrade experience similar symptoms (to-verify).

## Likely catagory
Remote access / VPN post-Windows-upgrade internal reachability failure (to-verify).

## First diagnostic step
Reproduce on the affected device and test one known internal hostname and one known internal IP while connected to VPN, then capture client network state to determine whether the failure is name resolution, routing, or policy enforcement related (to-verify).
