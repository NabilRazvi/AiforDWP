# Root Cause Analysis: No Secure Channel to Domain FINBRIDGE — Finance OU Login Failure

**Reference:** RCA-2026-08-06-FINBRIDGE-DNS  
**Date of Incident:** 2024-03-15  
**Date of RCA:** 2026-08-06  
**Analyst:** DWP Engineer  
**Status:** Closed — resolved and verified  
**Severity:** High — 3 of 4 Finance machines unable to authenticate; users blocked from login at start of business

---

## 1. Executive Summary

On 2024-03-15 between 07:40 and 07:55, three of four machines in OU=Finance were unable to establish a secure channel to domain FINBRIDGE, causing login failures and Group Policy processing errors at the start of the business day. The root cause was a DHCP scope misconfiguration: the Floor 3 subnet scope was not updated as part of an overnight DNS server migration, causing affected machines to be assigned decommissioned DNS servers on boot. Without working DNS, machines could not resolve domain controller SRV records, Netlogon could not locate a DC, and the secure channel could not be established. The fourth machine was unaffected because it had been manually pre-configured with the correct DNS server before the migration. Resolution was achieved by correcting the DHCP scope DNS option and forcing a lease renewal on affected machines. User login was verified as fully restored following the fix.

---

## 2. Incident Timeline

| Time (2024-03-15) | Event |
|---|---|
| **~02:00** | DNS migration wave executes overnight. DNS servers `10.10.3.250` (Finance subnet) and `172.16.5.5` (Floor 3 local) are decommissioned. New central DNS server `10.10.0.10` brought online. **DHCP scope for Floor 3 subnet (`10.10.3.0`) is not updated — still references `10.10.3.250`.** |
| **Pre-incident** | DESKTOP-FB029 manually pre-configured with DNS `10.10.0.10` before migration wave. FB055–058 rely on DHCP for DNS assignment. |
| **07:40:02** | DESKTOP-FB031 boots. Network Location Awareness service starts (Event 7036). |
| **07:40:05** | DESKTOP-FB029 obtains DHCP lease. DNS assigned: `10.10.0.10` (correct). GP processes successfully at 07:40:11 — Event 1500. |
| **07:40:08** | DESKTOP-FB031 obtains DHCP lease. DNS assigned: `10.10.3.250` (decommissioned). Netlogon attempts DC location — DNS query for `FINBRIDGE-DC01.finbridge.local` returns no response. **Event 5719** raised. |
| **07:40:09** | Group Policy cannot access SYSVOL share on DC. **Event 1058** raised (Error 0x3). |
| **07:40:10** | Group Policy cannot query GPO list. **Event 1030** raised (Error 0x546). |
| **07:40:11** | Second Event 1058 raised — GP processing failed again. |
| **07:40:12** | Group Policy acknowledges no DC connectivity — will retry when connectivity restored. **Event 1129** raised. |
| **07:41:05** | DNS Client confirms none of the configured DNS servers responded to name resolution for `FINBRIDGE-DC01.finbridge.local`. **Event 1014** raised. |
| **07:42:18** | DHCP lease confirmation logged — DNS `10.10.3.250` confirmed as assigned to FB031. **Event 50036**. |
| **07:44:01** | Group Policy retry fails again — still no DC connectivity. **Event 1129** raised. |
| **07:40–07:55** | FB055, FB056, FB057 experience identical failure pattern. All received DNS `172.16.5.5` (Floor 3 local DNS, also decommissioned). |
| **[Resolution]** | DWP Engineer corrects DHCP scope DNS option for Floor 3 subnet to `10.10.0.10`. Forces lease renewal on FB031, FB055–057. DNS resolution restored. Secure channel re-established. GP applies successfully. |
| **[Verified]** | User login confirmed working on all affected hosts. No further issues reported. |

---

## 3. Supporting Evidence

### 3.1 Event Log — DESKTOP-FB031 (representative affected machine)

| Timestamp | Source | Event ID | Level | Detail |
|---|---|---|---|---|
| 07:40:02 | Service Control Manager | 7036 | Info | Network Location Awareness entered running state |
| 07:40:08 | Netlogon | **5719** | Error | Secure channel to FINBRIDGE failed — DNS query for `FINBRIDGE-DC01.finbridge.local` returned no response |
| 07:40:09 | GroupPolicy | **1058** | Error | Cannot access `\\FINBRIDGE-DC01\sysvol\...\gpt.ini` — Error 0x3 |
| 07:40:10 | GroupPolicy | **1030** | Warning | Cannot query GPO list — Error 0x546 |
| 07:40:11 | GroupPolicy | **1058** | Error | GP processing failed (repeat) |
| 07:40:12 | GroupPolicy | **1129** | Error | GP failed — no network connectivity to DC |
| 07:41:05 | DNS Client Events | **1014** | Warning | Name resolution for `FINBRIDGE-DC01.finbridge.local` timed out — none of the configured DNS servers responded |
| 07:42:18 | DHCP Client | **50036** | Info | IP `10.10.3.144` leased — DNS assigned: `10.10.3.250` (decommissioned) |
| 07:44:01 | GroupPolicy | **1129** | Error | GP processing failed again — no DC connectivity |

### 3.2 Comparison Machine — DESKTOP-FB029 (unaffected)

| Timestamp | Source | Event ID | Level | Detail |
|---|---|---|---|---|
| 07:40:05 | DHCP Client | 50036 | Info | IP `10.10.3.141` leased — DNS assigned: `10.10.0.10` (correct central DNS) |
| 07:40:11 | GroupPolicy | **1500** | Info | Group Policy settings processed successfully |

FB029 was manually pre-configured with DNS `10.10.0.10` before the migration wave and was therefore unaffected throughout.

### 3.3 DHCP Server Logs — DNS Assignment Comparison

| Machine | DNS Assigned by DHCP | Server Status |
|---|---|---|
| FB055 | `172.16.5.5` | Floor 3 local DNS — **decommissioned 2024-03-14 overnight** |
| FB056 | `172.16.5.5` | Floor 3 local DNS — **decommissioned 2024-03-14 overnight** |
| FB057 | `172.16.5.5` | Floor 3 local DNS — **decommissioned 2024-03-14 overnight** |
| FB058 (FB029) | `10.10.0.10` | Central DNS — **correct, manually set pre-migration** |

DHCP server log note: *"Root cause: DHCP scope for Floor 3 subnet still references the old DNS server. FB058 was manually pre-configured and therefore unaffected."*

---

## 4. Five Why Analysis

**Problem statement:** Three Finance machines were unable to log in on 2024-03-15 at 07:40 because they could not establish a secure channel to domain FINBRIDGE.

---

**Why 1 — Why could the machines not establish a secure channel?**

Netlogon's DC locator could not find a domain controller. Event 5719 explicitly states the DNS query for `FINBRIDGE-DC01.finbridge.local` returned no response — without a DC address, no secure channel can be attempted.

---

**Why 2 — Why did the DNS query return no response?**

The DNS servers assigned to the affected machines were decommissioned and no longer running. Event 1014 confirms *"none of the configured DNS servers responded"*. The servers referenced (`10.10.3.250`, `172.16.5.5`) had been taken offline hours earlier as part of a DNS migration.

---

**Why 3 — Why were the machines using decommissioned DNS servers?**

The machines obtained their DNS server addresses from DHCP. The DHCP scope for the Floor 3 subnet still referenced the old, decommissioned DNS servers — it was not updated as part of the DNS migration. Event 50036 records the moment FB031 received `10.10.3.250` from DHCP at 07:42:18.

---

**Why 4 — Why was the DHCP scope not updated during the DNS migration?**

The DNS migration runbook did not include a step to update DHCP scope DNS options. The decommissioning of the old DNS servers and the onboarding of the new central DNS server were treated as server-side tasks. The downstream dependency — client machines receiving DNS addresses from DHCP — was not identified as a required change in the migration plan.

---

**Why 5 — Why was the DHCP dependency not included in the migration runbook?**

The DNS migration was planned and executed without a full dependency mapping of all systems and configurations that reference the old DNS server addresses. There was no pre-migration audit of DHCP scopes to identify stale DNS options, and no post-migration validation check to confirm client DNS resolution before declaring the migration complete.

**Root cause:** Absence of a DHCP scope DNS audit in the DNS migration runbook, combined with no post-migration DNS resolution validation step for client machines.

---

## 5. Impact

| Dimension | Detail |
|---|---|
| Users affected | All users assigned to DESKTOP-FB031, FB055, FB056, FB057 on OU=Finance |
| Duration | ~15 minutes at incident onset (07:40–07:55); persistent for any machine that did not self-remediate via DHCP renewal |
| Business impact | Finance staff unable to log in at start of business; Group Policy not applied for the affected session |
| Domain controller | Healthy throughout — no DC-side fault |
| Data loss | None |
| Security impact | None — no unauthorised access; machines simply could not authenticate |

---

## 6. Resolution Applied

1. **DHCP scope corrected** — DNS option for Floor 3 scope (`10.10.3.0`) updated from `10.10.3.250` to `10.10.0.10` using `Set-DhcpServerv4OptionValue`.
2. **Lease renewed on affected machines** — `ipconfig /release`, `/renew`, `/flushdns` run on FB031, FB055, FB056, FB057.
3. **DNS resolution verified** — `Resolve-DnsName -Name _ldap._tcp.FINBRIDGE -Type SRV` returned correct DC records on all machines.
4. **Group Policy refreshed** — `gpupdate /force` run; Event 1500 confirmed on all machines; Events 1058/1030/1129 absent.
5. **Secure channel verified** — `Test-ComputerSecureChannel -Verbose` returned `True` on all machines.
6. **User login verified** — Users confirmed able to log in to all four hosts with no issues reported.

---

## 7. Preventive Actions

| # | Action | Priority | Owner | Detail |
|---|---|---|---|---|
| 1 | Audit all DHCP scopes for stale DNS references | **Immediate** | Network / DHCP team | Run `Get-DhcpServerv4OptionValue -OptionId 6` across all scopes and compare against the current authoritative DNS server list. Correct any scope still referencing decommissioned servers. Other subnets may have the same exposure. |
| 2 | Add DHCP scope DNS audit to DNS migration runbook | **High** | Change management | Before any DNS server decommission, identify every DHCP scope that references the old server and update all scopes as part of the migration task. Include as a mandatory pre-cutover checklist item. |
| 3 | Add post-migration client DNS validation to runbook | **High** | Change management | After DNS migration, run a sample DNS resolution test (`Resolve-DnsName _ldap._tcp.<domain> -Type SRV`) from a DHCP-reliant client in each affected subnet before declaring migration complete. |
| 4 | Decommission old DNS servers at the network layer | **High** | Infrastructure | Block `10.10.3.250` and `172.16.5.5` at the firewall or remove the VM/service entirely. A hard unreachable failure surfaces misconfiguration immediately at connection time, rather than a 30-second silent DNS timeout that is harder to diagnose. |
| 5 | Require pre-migration dependency mapping for infrastructure changes | **Medium** | Change management / Architecture | All DNS, DHCP, and network change requests must include a dependency map identifying all downstream consumers of the resource being changed (DHCP scopes, hardcoded client configs, monitoring agents, etc.) before the change is approved. |
| 6 | Establish a post-change validation window | **Medium** | Service management | For infrastructure migration changes, mandate a 30-minute monitored validation window at the start of the next business day, with a rollback-ready engineer on standby, rather than relying on users to report failures. |

---

## 8. Lessons Learned

- **The "no change" record was misleading.** The DNS migration was an unrecorded dependency of the incident. Future scope analysis must explicitly ask whether any infrastructure change occurred in the preceding 24 hours, not just the preceding shift.
- **The 1-of-4 machine pattern was the fastest diagnostic accelerator.** FB029's clean event log immediately differentiated a per-machine fault from a shared-dependency fault and pointed at the DNS/DHCP layer within the first minute of investigation.
- **Silent DNS timeout hides root cause.** Event 5719 surfaces as "no domain controller" when the true failure is one layer below in DNS. Engineers unfamiliar with the DC locator chain may spend time investigating DC health rather than DNS. Training should cover the DC locator sequence: DNS SRV → DC contact → Kerberos.

---

*RCA completed 2026-08-06. Incident closed.*
