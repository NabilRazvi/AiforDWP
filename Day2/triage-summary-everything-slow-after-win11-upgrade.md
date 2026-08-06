# Triage Summary: T-1006 Everything Is Slow After Win11 Upgrade

## Summary (one line)
User reports broad system slowness starting two days after a Windows 11 upgrade, suggesting post-upgrade performance degradation affecting general endpoint usability (to-verify root cause).

## Impact (who/how many/business urgency)
- Who affected: One upgraded user is confirmed.
- How many affected: One confirmed so far (to-verify if additional upgraded users are impacted).
- Business urgency: Medium to high depending on role and whether slow performance blocks key daily tasks (to-verify).

## Known facts
- Ticket ID: T-1006.
- Reported issue: "Everything is slow."
- Timing context: User upgraded to Windows 11 two days ago.
- Scope context: Symptom appears device-wide rather than tied to a single app (to-verify).

## Missing information to gather
1. Device name/model, hardware profile, and storage free space (to-verify).
2. Specific slow tasks/apps and whether slowness is constant or intermittent (to-verify).
3. Baseline behavior before upgrade and exact date/time upgrade completed (to-verify).
4. Current CPU, memory, disk, and network utilization during slow periods (to-verify).
5. Pending Windows updates, optional driver updates, or restart requirements (to-verify).
6. Startup/load items and whether slowness begins immediately at logon (to-verify).
7. Whether issue persists in safe baseline conditions (for example after clean reboot with minimal startup load) (to-verify).
8. Whether slowness is local only or linked to network/resource access latency (to-verify).
9. Any endpoint protection scans or management jobs running during impact windows (to-verify).
10. Whether similarly upgraded devices in the same team show the same behavior (to-verify).

## Likely catagory
Endpoint performance / post-Windows-upgrade degradation (to-verify).

## First diagnostic step
Capture a short performance snapshot during active slowness (CPU, memory, disk, and top processes), then correlate with recent post-upgrade updates/tasks to determine whether the bottleneck is resource saturation, storage pressure, or background processing (to-verify).
