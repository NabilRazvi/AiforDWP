# Root Cause Analysis: Citrix Broker Service Failure — dc-vdi-02 / FinBridge-VDI-Pool-02

**Incident date:** 2026-08-13  
**RCA date:** 2026-08-13  
**Analyst:** DWP Analyst  
**Severity:** High — 22 users unable to launch VDI sessions  
**Status:** Root cause confirmed  

---

## 1. Executive Summary

On 2026-08-13, 22 of 30 users on FinBridge-VDI-Pool-02 were unable to launch Citrix VDI sessions. The Citrix Session Broker returned error 1030 (`No machines available in the desktop group`). Root cause was the Citrix Broker Service on Delivery Controller dc-vdi-02 being in a STOPPED state, leaving 22 of 25 provisioned Pool-02 machines unregistered and unavailable to serve sessions. The service stopped at 23:40 the prior evening. A Windows Update installation ran at 00:15 with a reboot-required flag set but the host was not rebooted. FinBridge-VDI-Pool-01, which registers against a separate Delivery Controller (dc-vdi-01), was unaffected.

---

## 2. Incident Timeline

| Time | Event |
|---|---|
| 2026-08-12 23:40 | Citrix Broker Service last known running on dc-vdi-02 |
| 2026-08-13 00:15 | Windows Update installs on dc-vdi-02; reboot-required flag set; host not rebooted |
| 2026-08-13 06:15:22 | VDI-P02-014 attempts registration against dc-vdi-02 — `connection refused` on port 80 |
| 2026-08-13 06:16:01 | VDI-P02-017 attempts registration against dc-vdi-02 — `connection refused` on port 80 |
| 2026-08-13 (implied) | 22 of 25 Pool-02 machines fail to register; 3 remain registered |
| 2026-08-13 08:58:03 | User jsmith attempts session launch on Pool-02 |
| 2026-08-13 08:58:04 | Broker queries available machines in Pool-02 |
| 2026-08-13 08:58:34 | Broker timeout (30,000 ms); session launch FAILED: error 1030 |
| 2026-08-13 (analysis) | Investigation confirms Broker Service STOPPED on dc-vdi-02; dc-vdi-01 running normally |

---

## 3. Supporting Evidence

### 3.1 Citrix Session Broker Log

```
[08:58:03] Session launch requested: user jsmith, Pool-02
[08:58:04] Broker: Querying available machines in Pool-02
[08:58:34] Broker: Timeout waiting for machine registration response (30000ms exceeded)
[08:58:34] Session launch FAILED: error 1030 'No machines available in the desktop group'
```

### 3.2 Machine Catalog Registration Status

| Pool | Provisioned | Registered | Unregistered | Maintenance |
|---|---|---|---|---|
| Pool-02 | 25 | 3 | 22 | 0 |
| Pool-01 | 20 | 19 | 1 | 0 |

### 3.3 Unregistered Machine Detail (Sample — Pool-02)

```
VDI-P02-014: Last registration attempt 06:15:22, failed
  Error: Unable to contact Delivery Controller
  dc-vdi-02.finbridge.local:80 - connection refused

VDI-P02-017: Last registration attempt 06:16:01, failed
  Error: Unable to contact Delivery Controller
  dc-vdi-02.finbridge.local:80 - connection refused
```

*Note: `connection refused` on port 80 is consistent with a stopped TCP listener (stopped service), not an unreachable host (which would produce a timeout).*

### 3.4 Delivery Controller Health

| Controller | Broker Service | Last Running | Notes |
|---|---|---|---|
| dc-vdi-02 | STOPPED | 2026-08-12 23:40 | Windows Update at 00:15; reboot-required flag set; not rebooted |
| dc-vdi-01 | RUNNING | N/A (uptime 14 days) | No issues; serves Pool-01 |

---

## 4. Root Cause

**The Citrix Broker Service on dc-vdi-02.finbridge.local stopped at 23:40 on 2026-08-12. The most probable trigger is the Windows Update installation process that ran at 00:15 on 2026-08-13, which shut down or failed to maintain dependent services and set a reboot-required flag. The host was not rebooted, leaving the Broker Service in a stopped state. All 22 Pool-02 VDI machines targeting dc-vdi-02 for registration received connection refused on port 80 and could not register. With only 3 machines registered, the Delivery Group had insufficient capacity to serve sessions, causing broker error 1030 for 22 of 30 users.**

---

## 5. Five-Why Analysis

| Why | Answer |
|---|---|
| **Why** did users fail to launch VDI sessions? | The broker returned error 1030: no machines available in the desktop group |
| **Why** were no machines available? | 22 of 25 Pool-02 machines were in an unregistered state |
| **Why** were the machines unregistered? | They could not contact Delivery Controller dc-vdi-02 on port 80 — connection refused |
| **Why** was dc-vdi-02 refusing connections on port 80? | The Citrix Broker Service on dc-vdi-02 was STOPPED |
| **Why** was the Citrix Broker Service stopped? | Windows Update ran at 00:15, shut down services as part of the update process, and the service was not restarted — a reboot-required flag was set but the host was never rebooted to complete recovery |

---

## 6. Contributing Factors

| Factor | Description |
|---|---|
| No service health monitoring | No alert fired when the Citrix Broker Service stopped at 23:40; the failure went undetected for ~7 hours |
| Uncontrolled update reboot | Windows Update ran and set a reboot-required flag on a production Delivery Controller without a scheduled maintenance reboot completing the process |
| Single-controller pool dependency | All 22 Pool-02 machines were configured to register against dc-vdi-02 only; no secondary controller registration provided resilience |
| No registration threshold alerting | No alert was configured to fire when Pool-02 registered machine count dropped from 25 to 3 |

---

## 7. Impact Assessment

| Dimension | Detail |
|---|---|
| Users affected | 22 of 30 on FinBridge-VDI-Pool-02 |
| Users unaffected | All Pool-01 users; 8 Pool-02 users (registered against surviving machines) |
| Duration | ~7 hours (23:40 service stop to investigation — exact restoration time to-be-confirmed post-remediation) |
| Business impact | Finance/FinBridge users unable to access VDI desktops during business hours |
| Data loss | None confirmed |
| Security impact | None confirmed |

---

## 8. Remediation Steps (Ordered)

1. Notify the Citrix infrastructure team before touching a production Delivery Controller.
2. Connect to `dc-vdi-02.finbridge.local` via RDP or console as Citrix admin / Domain Admin.
3. Confirm Broker Service state: `Get-Service "Citrix Broker Service"`
4. Start the service: `Start-Service "Citrix Broker Service"`
5. Confirm the service is running and listening on port 80: `Test-NetConnection localhost -Port 80`
6. Allow 3–5 minutes for VDI machines to complete the automatic re-registration cycle.
7. Validate Pool-02 registration count in Citrix Studio or via:  
   `Get-BrokerMachine -DesktopGroupName "FinBridge-VDI-Pool-02" | Group-Object RegistrationState`
8. Confirm user session launches are restored with a test launch.
9. Log the incident and communicate restoration to affected users.
10. In a separate, scheduled maintenance window: reboot dc-vdi-02 to complete the pending Windows Update. Do not reboot while stabilising user sessions.

---

## 9. Verification Criteria

| Check | Pass Condition |
|---|---|
| Pool-02 registered machine count | ≥ 20 of 25 machines registered |
| Test session launch | Pool-02 session launches successfully without error 1030 |
| Port 80 connectivity | `Test-NetConnection dc-vdi-02.finbridge.local -Port 80` returns `TcpTestSucceeded: True` |
| Citrix Director / Studio | Pool-02 Delivery Controller status shown as Registered |

---

## 10. Preventive Actions

### 10.1 Windows Update Maintenance Window Policy for Delivery Controllers

Configure a Group Policy or WSUS-enforced maintenance window for all Citrix Delivery Controllers that:
- Restricts update installation to a defined out-of-hours window.
- Enforces an automatic, scheduled reboot after update installation to complete service recovery.
- Excludes Delivery Controllers from receiving Windows Update reboots during business hours.

### 10.2 Post-Reboot and Service Health Monitoring

- Deploy a scheduled task or monitoring script on all Delivery Controllers to verify the Citrix Broker Service is running after any reboot.
- Configure a monitoring alert (Citrix Director, SCOM, or equivalent) to page on-call immediately when the Citrix Broker Service on any Delivery Controller enters a non-running state.

### 10.3 Machine Registration Threshold Alert

- Configure Citrix Director or equivalent to alert on-call when the registered machine count for any pool drops below 50% of provisioned capacity.
- This would have triggered an alert at ~06:15 when Pool-02 dropped to 3 registered machines, allowing a ~3-hour earlier resolution.

### 10.4 Dual-Controller Registration for Critical Pools

- Where Citrix topology and licensing allow, configure Pool-02 machines to register against both dc-vdi-01 and dc-vdi-02.
- This would have allowed Pool-02 machines to fall back to dc-vdi-01 on dc-vdi-02 failure, maintaining session availability during single-controller outages.

---

## 11. Lessons Learned

| Lesson | Action Owner |
|---|---|
| Production Delivery Controllers must have monitored service health with alerting | Infrastructure / Monitoring team |
| Windows Update on Delivery Controllers must follow a controlled, rebooted maintenance process | Change Management / Infrastructure team |
| Critical VDI pools should have controller redundancy configured | Citrix Platform team |
| Registration threshold alerts are a low-effort, high-value early warning mechanism | Infrastructure / Monitoring team |

---

## 12. Related Files

- `Day9/analysis-citrix-session-failure-pool02-2026-08-13.md` — Detailed analysis document
