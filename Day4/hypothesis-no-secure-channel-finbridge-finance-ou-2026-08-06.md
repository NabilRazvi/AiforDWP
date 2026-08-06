# Hypothesis: No Secure Channel to Domain FINBRIDGE — Finance OU Login Failure

**Date:** 2026-08-06  
**Analyst:** DWP Engineer  
**Status:** Open — cause not yet confirmed

---

## Scope Facts

| Field | Detail |
|---|---|
| Symptom | "This computer was unable to set up a secure channel to domain FINBRIDGE — no domain controller available" |
| Who | 3 of 4 machines on OU=Finance affected |
| Since | 2024-03-15 07:40–07:55 |
| Change | Nil |

---

## Key Observations Before Ranking

- The 15-minute window (07:40–07:55) and apparent self-resolution suggests a transient condition, not a persistent break.
- 3 of 4 machines affected simultaneously points to a shared dependency (network path, DNS, or DC), not per-machine faults.
- The 1 unaffected machine is a pivot point — what is different about it (IP, VLAN port, DNS cache, DC affinity)?
- "No domain controller available" is the Netlogon/Kerberos layer failing to locate a DC via DNS SRV records; the root cause sits in DNS, network reachability, or DC health.
- No change recorded eliminates scheduled maintenance as an obvious trigger — but does not eliminate an unlogged change or a transient infrastructure event.

---

## Ranked Hypotheses — Most Probable First

---

### 1. Domain Controller Netlogon / NTDS Service Disruption (Transient DC Fault)

**Why this fits:**
The 15-minute bounded window maps precisely to a service blip on the DC that serves the Finance subnet — Netlogon stopped and restarted (e.g., after a patch, memory pressure, or crash). All machines attempting to authenticate during that window would receive "no DC available". The 1 unaffected machine may have already held an active Kerberos TGT and did not need to re-negotiate during the outage window.

**Fastest single check:**
On the DC, run:
```
Get-EventLog -LogName System -Source NETLOGON -After "2024-03-15 07:35" -Before "2024-03-15 08:00"
```
Look for Event ID **5719** (no DC available) on clients, and **3210 / 3228** (Netlogon stopped/started) on the DC itself. A start/stop pair within the window confirms this cause.

---

### 2. DNS SRV Record Resolution Failure (Finance Subnet DNS Fault)

**Why this fits:**
Secure channel setup requires DNS SRV lookups (`_ldap._tcp.FINBRIDGE`, `_kerberos._tcp.FINBRIDGE`). If the DNS server serving the Finance VLAN was unreachable or returned no results during 07:40–07:55, all machines needing a fresh DC lookup would fail. The 1 unaffected machine likely had a valid cached DNS response and did not query DNS during the window.

**Fastest single check:**
On an affected machine (or via historical DNS server logs), confirm whether `_ldap._tcp.FINBRIDGE` SRV records resolved at 07:40–07:55:
```
Resolve-DnsName -Name _ldap._tcp.FINBRIDGE -Type SRV
```
Also check DNS server event logs for restart/timeout in that window. Absent SRV responses during the window confirms this cause.

---

### 3. Network Path Blocked to Domain Controllers (VLAN / Switch / Firewall)

**Why this fits:**
A switch port flap, ACL change, or firewall rule applied to the Finance VLAN between 07:40–07:55 could block Kerberos (TCP/UDP 88), LDAP (389), and SMB (445) — all required for secure channel establishment. 3 of 4 machines affected fits a subnet-level event. The 4th machine surviving could indicate it was on a different switch port or had a cached ticket.

**Fastest single check:**
On an affected machine during or after the window:
```
Test-NetConnection -ComputerName <DC-FQDN> -Port 389
```
Cross-reference switch/firewall logs for the Finance VLAN between 07:38–07:58 for port flap events or ACL hits. Confirmed port blocking in the window eliminates other causes.

---

### 4. Kerberos Clock Skew Exceeding 5-Minute Tolerance

**Why this fits:**
Kerberos rejects tickets when the client clock differs from the DC by more than 5 minutes. If the Finance machines' NTP source became unreachable and clocks drifted, or a manual time change occurred, authentication fails with messages consistent with "no domain controller available" (the error surface can be misleading). 3 of 4 sharing an NTP misconfiguration is plausible; the 4th machine may have been powered off or had a different NTP source. The bounded window fits an NTP server recovering or clocks self-correcting.

**Fastest single check:**
Check the time offset between the affected machines and the DC at the time of failure (use event timestamps as a proxy) or run:
```
w32tm /stripchart /computer:<DC-FQDN> /dataonly /samples:5
```
If offset exceeds 5 minutes (300 seconds), this is the cause. Also check System Event Log for **W32TM Event ID 29** (time source unavailable).

---

### 5. Machine Account Password Desynchronisation (Stale / Mismatched Netlogon Secret)

**Why this fits:**
Each computer maintains a password for its machine account in AD, rotated every 30 days. If the local LSA secret and AD-stored password diverged (e.g., a restore from snapshot, repeated imaging, or Netlogon channel reset without AD replication), the machine cannot build a secure channel. 3 of 4 affected simultaneously is less typical for this cause, but is possible if all three machines were re-imaged from the same base on the same date and their account passwords all expired or conflicted at the same time. The 4th machine having a more recent password rotation would explain it being unaffected.

**Fastest single check:**
On an affected machine (as a local admin):
```
Test-ComputerSecureChannel -Verbose
```
A return of `False` confirms machine account password mismatch. Follow with `Test-ComputerSecureChannel -Repair -Credential (Get-Credential)` to remediate if confirmed.

---

## What Makes These Hypotheses Distinguishable

| # | Cause | Affects 1 machine | Affects 3–4 machines | Time-bounded | 4th machine unaffected |
|---|---|---|---|---|---|
| 1 | DC Netlogon blip | No | Yes | Yes | Cached TGT |
| 2 | DNS SRV failure | No | Yes | Yes | Cached DNS |
| 3 | Network path blocked | No | Yes | Yes | Different switch port |
| 4 | Clock skew | Possible | Yes | Yes | Different NTP source |
| 5 | Machine account password | Yes (normally) | Possible if batch-imaged | Unlikely | Later password rotation |

---

## Recommended Next Action

Before committing to a cause, collect three data points in parallel:

1. **Event ID 5719** on affected machines (confirms they hit the "no DC" error at 07:40–07:55)
2. **DC System log** for Netlogon start/stop events in the same window
3. **`Test-ComputerSecureChannel`** on an affected machine right now

These three checks together will confirm or eliminate hypotheses 1 and 5 within minutes and narrow focus to DNS/network if both are clear.

---

## Evidence Assessment Against Hypotheses

Evidence source: System Event Log — DESKTOP-FB031 and comparison machine DESKTOP-FB029, plus DHCP server logs.  
Window: 2024-03-15 07:40–07:55.

---

### H1 — DC Netlogon / NTDS Service Disruption

**Verdict: CONTRADICTED**

- **Event 1500 @ 07:40:11 (FB029)** — FB029 successfully processed Group Policy at 07:40:11, proving the DC's Netlogon service was healthy and serving requests throughout the window. A DC Netlogon blip would have affected FB029 equally.
- **Event 5719 @ 07:40:08 (FB031)** — The error text itself says *"DNS query for FINBRIDGE-DC01.finbridge.local returned no response"*. The failure is at DNS resolution, before the machine ever attempted to contact the DC. A dead Netlogon service would surface after DNS succeeded.

---

### H2 — DNS SRV Record Resolution Failure (Finance Subnet DNS Fault)

**Verdict: STRONGLY SUPPORTED**

- **Event 5719 @ 07:40:08** — Explicitly states the DNS query for `FINBRIDGE-DC01.finbridge.local` returned no response. The machine cannot locate the DC because DNS is silent.
- **Event 1014 @ 07:41:05** — Confirms *"None of the configured DNS servers responded"* — the DNS servers assigned to this machine are unreachable, not merely missing records.
- **Event 50036 @ 07:42:18** — DHCP assigned DNS server `10.10.3.250`, which was decommissioned at 02:00 during the migration wave. The DHCP scope for the Finance subnet was never updated.
- **DHCP server logs** — FB055–057 received `172.16.5.5` (Floor 3 local DNS, decommissioned 2024-03-14 overnight). All three affected machines were pointing at dead DNS servers from boot.
- **FB029 Event 50036 @ 07:40:05** — FB029 received DNS `10.10.0.10` (correct central DNS) because it was manually reconfigured before the migration wave. This directly explains why it alone was unaffected.

The combination of Event 1014, Event 50036, and the DHCP server logs together give a complete causal chain: stale DHCP scope → decommissioned DNS assigned → SRV lookups fail → Netlogon cannot locate DC → secure channel fails.

---

### H3 — Network Path Blocked to Domain Controllers (VLAN / Switch / Firewall)

**Verdict: CONTRADICTED**

- **Event 1014 @ 07:41:05** — The failure is at DNS resolution stage: *"None of the configured DNS servers responded"*. The machine never reached the point of attempting a TCP/UDP connection to the DC on ports 88, 389, or 445. A firewall or switch block would only matter after DNS succeeded.
- **Event 1500 @ 07:40:11 (FB029)** — FB029, on the same physical subnet and VLAN, reached the DC successfully. A VLAN-level network block would have affected all four machines including FB029.

---

### H4 — Kerberos Clock Skew Exceeding 5-Minute Tolerance

**Verdict: CONTRADICTED**

- **Event 1014 @ 07:41:05** — The failure occurs at DNS name resolution. Kerberos clock skew only becomes relevant after the DC is located and a TGT is requested. There is no W32TM Event 29 or any time-related event in the log window.
- **Event 5719 @ 07:40:08** — The error message explicitly attributes the failure to the DNS query returning no response, not to a Kerberos authentication rejection. A clock skew failure produces a different error path (KDC_ERR_SKEW), not a "no domain controller available" from Netlogon's DC locator.

---

### H5 — Machine Account Password Desynchronisation

**Verdict: CONTRADICTED**

- **Event 5719 @ 07:40:08** — The secure channel failure is caused by the DNS query failing, not by a rejected credential during the secure channel handshake. Machine account password mismatch would only surface after the DC was successfully located via DNS; the machines here never reached that stage.
- **Event 1014 @ 07:41:05** — Confirms the DNS servers themselves were silent. Password desynchronisation leaves DNS intact; the DC locator would succeed and the failure would appear as a distinct Netlogon error (e.g., Event 3210) rather than a "no DC available" from the locator.

---

## Updated Evidence Summary Table

| # | Cause | Verdict | Key Evidence |
|---|---|---|---|
| 1 | DC Netlogon blip | Contradicted | FB029 Event 1500 @ 07:40:11 — DC healthy; 5719 blames DNS not DC |
| 2 | DNS SRV / DNS server failure | **Strongly Supported** | 5719 @ 07:40:08; 1014 @ 07:41:05; 50036 @ 07:42:18; DHCP server logs |
| 3 | Network path blocked | Contradicted | Failure at DNS layer, not TCP; FB029 unaffected on same VLAN |
| 4 | Clock skew | Contradicted | No W32TM events; failure at DNS stage before Kerberos is reached |
| 5 | Machine account password | Contradicted | Failure at DNS stage before secure channel handshake attempted |

---

*Evidence assessment added 2026-08-06. Cause not yet formally confirmed — winner to be declared in separate analysis document.*

---

## Confirmed Cause

**H2 — Stale DHCP Scope Assigning Decommissioned DNS Servers**

All other hypotheses were eliminated by the evidence. H2 is the sole surviving cause.

Confirmed causal chain:

> DHCP scope for Floor 3 subnet not updated during DNS migration  
> → Affected machines assigned decommissioned DNS server on boot  
> → `_ldap._tcp.FINBRIDGE` SRV lookup times out (Event 1014 @ 07:41:05)  
> → Netlogon DC locator fails (Event 5719 @ 07:40:08)  
> → Secure channel cannot be established  
> → Group Policy fails (Events 1058, 1030, 1129)  
>  
> FB029 unaffected because it was manually pre-configured with DNS `10.10.0.10` before the migration wave (Event 50036 @ 07:40:05).

---

## Resolution Steps

### Immediate — Fix the DHCP scope (root fix)

Update the DNS server option on the Floor 3 DHCP scope to point at the correct central DNS server:

```powershell
# Confirm the scope address first
Get-DhcpServerv4Scope

# Replace the stale DNS option
Set-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -OptionId 6 -Value "10.10.0.10"

# Verify
Get-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -OptionId 6
```

### Force affected machines to renew lease and flush DNS

Run on each affected machine (FB031, FB055–057), or remotely:

```powershell
Invoke-Command -ComputerName FB031, FB055, FB056, FB057 -ScriptBlock {
    ipconfig /release
    ipconfig /renew
    ipconfig /flushdns
}
```

### Confirm DNS resolution is restored

```powershell
Resolve-DnsName -Name _ldap._tcp.FINBRIDGE -Type SRV
Resolve-DnsName -Name FINBRIDGE-DC01.finbridge.local
```

Both must return results before proceeding.

### Force Group Policy refresh to clear the deferred GP backlog

```cmd
gpupdate /force
gpresult /r
```

Expect Event **1500** in `Microsoft-Windows-GroupPolicy/Operational`. Absence of Events 1058 / 1030 / 1129 confirms resolution.

### Verify secure channel is re-established

```powershell
Test-ComputerSecureChannel -Verbose
```

Must return `True`.

---

### Prevent Recurrence

| Action | Owner |
|---|---|
| Audit all DHCP scopes against the DNS migration change record — confirm no other scopes still reference decommissioned DNS servers | Network / DHCP team |
| Add DHCP DNS option values as a mandatory checklist item in the DNS migration runbook | Change management |
| Decommission `10.10.3.250` and `172.16.5.5` at the network layer so future misconfigurations fail immediately rather than timing out silently | Infrastructure |
| Check whether machines on other floors received similar stale DNS assignments | Desktop / DHCP team |

---

*Resolution added 2026-08-06.*
