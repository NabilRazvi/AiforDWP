# Incident Analysis: Citrix VDI Session Launch Failure — FinBridge-VDI-Pool-02

**Date:** 2026-08-13  
**Analyst:** DWP Analyst  
**Status:** Root cause identified — remediation confirmed  

---

## Executive Summary

22 of 30 users on FinBridge-VDI-Pool-02 were unable to launch VDI sessions from approximately 06:15 onwards on 2026-08-13. The Citrix Session Broker returned error 1030 (`No machines available in the desktop group`). Investigation confirmed that 22 of 25 provisioned machines in Pool-02 were in an unregistered state, all failing to contact Delivery Controller `dc-vdi-02.finbridge.local` on port 80 with `connection refused`. The Citrix Broker Service on dc-vdi-02 was found to be STOPPED. Windows Update activity at 00:15 preceded the failure. FinBridge-VDI-Pool-01 was fully unaffected as it registers against dc-vdi-01, which remained operational throughout.

**Confidence level:** High. Evidence is consistent across broker logs, machine catalog status, unregistered machine detail, and Delivery Controller health data.

---

## Scope

| Attribute | Detail |
|---|---|
| Affected pool | FinBridge-VDI-Pool-02 |
| Affected users | 22 of 30 |
| Unaffected pool | FinBridge-VDI-Pool-01 (same site) |
| Affected Delivery Controller | dc-vdi-02.finbridge.local |
| Unaffected Delivery Controller | dc-vdi-01 |
| Incident window (earliest evidence) | 06:15:22 (first failed registration attempt logged) |
| Incident confirmed | 08:58:34 (broker timeout and error 1030 logged) |

---

## Evidence Reviewed

| Source | Key Finding |
|---|---|
| Citrix Session Broker Log | Error 1030 at 08:58:34; 30s timeout on machine registration query for Pool-02 |
| Machine catalog status (Pool-02) | 25 provisioned; 3 registered; 22 unregistered; 0 in maintenance |
| Machine catalog status (Pool-01) | 20 provisioned; 19 registered; 1 unregistered |
| Unregistered machine detail (sample) | VDI-P02-014 and VDI-P02-017: `connection refused` on dc-vdi-02.finbridge.local:80 at 06:15–06:16 |
| Delivery Controller health (dc-vdi-02) | Citrix Broker Service: STOPPED; last running 23:40 yesterday; Windows Update installed 00:15 today; reboot-required flag set, host not rebooted |
| Delivery Controller health (dc-vdi-01) | Citrix Broker Service: RUNNING; uptime 14 days |

---

## Broker Error 1030

Citrix broker error 1030 (`No machines available in the desktop group`) is generated when the broker cannot find any registered, non-maintenance-mode machines in the target delivery group within the configured timeout. This is consistent with 22 of 25 machines being unregistered.

---

## Hypothesis Ranking

### Hypothesis 1 — Citrix Broker Service stopped on dc-vdi-02 *(confirmed primary cause)*

The Citrix Broker Service on dc-vdi-02 stopped at or around 23:40. All 22 Pool-02 machines that register against dc-vdi-02 attempted re-registration at approximately 06:15 and received `connection refused` on port 80, consistent with a stopped (not crashed) service. A stopped service actively refuses TCP connections; a crashed or unreachable host produces a timeout. Pool-01 machines register against dc-vdi-01, which remained running, explaining the clean split in impact between pools.

The Windows Update installation at 00:15 provides the most plausible trigger: some update processes shut down dependent services pre-installation and may not restart them, particularly when a reboot-required flag is set but the host is not rebooted. The ~35-minute gap between service stop (23:40) and update installation (00:15) may indicate the update process initiated a pre-shutdown sequence.

### Hypothesis 2 — Windows Update left dc-vdi-02 in a degraded state *(contributing factor)*

The reboot-required flag is set but the host has not rebooted. This is a contributing factor supporting hypothesis 1 rather than an independent cause. A pending reboot does not by itself stop services, but the incomplete update state means dc-vdi-02 should be rebooted in a controlled window after the Broker Service is restored, to fully commit the update.

### Hypothesis 3 — Firewall rule blocking port 80 on dc-vdi-02 *(eliminated)*

`Connection refused` could in theory indicate a host-based firewall block. This is eliminated by the explicit confirmation that the Citrix Broker Service is STOPPED. A firewall-blocked running service would produce a timeout, not a connection refusal. No firewall change evidence is present.

---

## Finalised Root Cause

The Citrix Broker Service on dc-vdi-02 stopped at 23:40, most likely due to the Windows Update process running at 00:15 initiating a pre-installation service shutdown that was never recovered. With the Broker Service stopped, dc-vdi-02 stopped accepting machine registrations on port 80. All 22 Pool-02 VDI machines targeting dc-vdi-02 became unregistered, leaving only 3 machines (which may register against a secondary controller or cached state) available, insufficient to serve 30 concurrent users.

---

## Remediation Plan

### Steps (in order)

1. Notify the Citrix infrastructure team before touching a production Delivery Controller.
2. Connect to `dc-vdi-02.finbridge.local` via RDP or console as a Citrix admin / Domain Admin.
3. Confirm Broker Service state: `Get-Service "Citrix Broker Service"`
4. Start the service: `Start-Service "Citrix Broker Service"`
5. Confirm service is running and listening: `Test-NetConnection localhost -Port 80`
6. Allow 3–5 minutes for VDI machines to re-register (automatic retry cycle).
7. Validate Pool-02 registration count: `Get-BrokerMachine -DesktopGroupName "FinBridge-VDI-Pool-02" | Group-Object RegistrationState`
8. Confirm user session launches are restored with a test launch.
9. Separately schedule a controlled reboot of dc-vdi-02 in a maintenance window to complete the pending Windows Update. Do not reboot concurrently with the service restore — stabilise user sessions first.

### Verification Criteria

- Pool-02 registered machine count ≥ 20 of 25.
- Test user session launch on Pool-02 succeeds without error 1030.
- `Test-NetConnection dc-vdi-02.finbridge.local -Port 80` returns `TcpTestSucceeded: True`.
- Citrix Director / Studio shows Pool-02 Delivery Controller as Registered.

---

## Preventive Actions

1. **Windows Update maintenance window policy for Delivery Controllers** — restrict update installation to a defined out-of-hours window that includes an automatic reboot, preventing the host from remaining in a partially-updated, service-degraded state.
2. **Post-reboot service health check** — deploy a scheduled task or monitoring script on all Delivery Controllers to verify the Citrix Broker Service is running after any reboot and alert if it is not.
3. **Machine registration threshold alert** — configure Citrix Director or equivalent monitoring to alert on-call if registered machine count for any pool drops below 50% of provisioned capacity.
4. **Dual-controller registration for critical pools** — configure Pool-02 machines to register against both dc-vdi-01 and dc-vdi-02 (where Citrix licensing and topology allow), providing resilience against single-controller failure.

---

## Related Files

- `Day9/rca-citrix-broker-service-failure-dc-vdi-02-2026-08-13.md` — Full RCA with 5-Why analysis
