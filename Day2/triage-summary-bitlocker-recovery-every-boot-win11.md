# Triage Summary: T-1001 BitLocker Recovery Prompt Every Boot (New Win11 Laptop)

## Summary (one line)
New Windows 11 laptop is prompting for the BitLocker recovery key on every boot, indicating persistent startup trust validation failure (to-verify).

## Impact (who/how many/business urgency)
- Who affected: One end user on a newly issued Windows 11 laptop (to-verify user identity/team)
- How many affected: One reported device/user so far (to-verify if wider rollout issue)
- Business urgency: High for the affected user because normal endpoint access is disrupted at each restart and could lead to lockout if recovery key is unavailable (to-verify urgency by role/time-critical workload)

## Known facts
- Ticket ID: T-1001.
- Device is a new Windows 11 laptop.
- User is being asked for BitLocker recovery key every boot.
- Prompt recurrence is at every startup attempt, not a one-off event.

## Missing information to gather
1. Affected user name, team, contact details, and business criticality (to-verify).
2. Device identity details: hostname, asset tag, serial, build version (to-verify).
3. Whether user can successfully enter the recovery key and complete boot each time (to-verify).
4. Whether any recent firmware/BIOS/boot-setting/security-policy changes occurred before issue started (to-verify).
5. Whether any hardware changes (dock, storage, motherboard, TPM-related servicing) occurred (to-verify).
6. Whether issue started immediately after device handover or after a specific reboot/update (to-verify).
7. Whether the same behaviour is occurring on other newly deployed Win11 laptops (to-verify).
8. Confirmation that recovery key is escrowed and retrievable through approved internal process (to-verify).

## Likely catagory
Endpoint security / disk encryption: BitLocker repeated recovery mode trigger on Windows 11 startup (to-verify root cause).

## First diagnostic step
Confirm user can boot successfully with the recovery key, then collect startup/recovery event details from the affected device and verify whether TPM/boot trust state changed since the last known good boot (to-verify).
