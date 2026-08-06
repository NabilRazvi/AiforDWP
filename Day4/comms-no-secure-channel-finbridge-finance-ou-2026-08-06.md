# Communications: Finance OU Login Failure — 2024-03-15
**Incident:** RCA-2026-08-06-FINBRIDGE-DNS  
**Audiences:** Executive / End-user team / Engineer internal note

---

## Audience 1 — Non-Technical Executive

**Subject: Finance login issue on 15 March — resolved, no data impact**

Your team's access and data were not compromised at any point.

On the morning of 15 March, three Finance computers were temporarily unable to log in for approximately 15 minutes due to a configuration step missed during overnight IT infrastructure work. The issue was identified and fixed the same morning. All systems are confirmed working normally.

No action is required from you.

---

## Audience 2 — Affected End-User Team

**Subject: Login issue on 15 March — fixed and what to do if it happens again**

On the morning of 15 March, three Finance computers temporarily could not log in because a routine overnight IT change accidentally pointed them at a server that had been switched off. The issue was fixed the same morning and your access is fully restored.

**If you see a similar login error again**, do not restart your machine repeatedly — contact the IT helpdesk straight away so we can resolve it faster.

**Contact:** IT Helpdesk — [your helpdesk number / email]

---

## Audience 3 — Engineer Internal Note

**Subject: P1 resolved — Finance OU login failure, stale DHCP DNS option post-migration**

---

### Root Cause

DNS migration executed overnight 2024-03-14/15. Old DNS servers decommissioned:
- `10.10.3.250` (Finance subnet DNS)
- `172.16.5.5` (Floor 3 local DNS)

New central DNS: `10.10.0.10`

**DHCP scope `10.10.3.0` (Floor 3 subnet) was not updated.** Option 6 still referenced `10.10.3.250`. On boot at ~07:40, FB031/FB055/FB056/FB057 received the decommissioned DNS via DHCP. All four DNS queries for `FINBRIDGE-DC01.finbridge.local` timed out → Netlogon DC locator failed → Event 5719 → secure channel not established → GP failed (Events 1058, 1030, 1129).

FB029 unaffected: manually pre-configured DNS `10.10.0.10` before migration wave — Event 1500 at 07:40:11 confirms clean GP apply throughout.

---

### Evidence

| Event ID | Machine | Time | Significance |
|---|---|---|---|
| 5719 | FB031 | 07:40:08 | DNS query for DC returned no response |
| 1058 | FB031 | 07:40:09 | SYSVOL inaccessible (0x3) |
| 1030 | FB031 | 07:40:10 | GPO list query failed (0x546) |
| 1129 | FB031 | 07:40:12 | GP acknowledged no DC connectivity |
| 1014 | FB031 | 07:41:05 | None of the configured DNS servers responded |
| 50036 | FB031 | 07:42:18 | DHCP confirmed DNS `10.10.3.250` assigned |
| 50036 | FB029 | 07:40:05 | DHCP confirmed DNS `10.10.0.10` assigned (correct) |
| 1500 | FB029 | 07:40:11 | GP processed successfully — DC healthy throughout |

DHCP server logs confirm FB055–057 received `172.16.5.5` (also decommissioned).

---

### Action Taken

```powershell
# Corrected DHCP scope DNS option
Set-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -OptionId 6 -Value "10.10.0.10"

# Forced lease renewal on affected machines
Invoke-Command -ComputerName FB031, FB055, FB056, FB057 -ScriptBlock {
    ipconfig /release; ipconfig /renew; ipconfig /flushdns
}
```

---

### Verification

```powershell
# DNS resolution confirmed on all affected machines
Resolve-DnsName -Name _ldap._tcp.FINBRIDGE -Type SRV      # returned DC records
Resolve-DnsName -Name FINBRIDGE-DC01.finbridge.local       # resolved correctly

# Secure channel confirmed
Test-ComputerSecureChannel -Verbose                        # returned True

# GP confirmed clean
gpupdate /force
# Event 1500 present in Microsoft-Windows-GroupPolicy/Operational
# Events 1058 / 1030 / 1129 absent
```

User login verified on all four hosts. No further reports.

---

### Preventive Action Required (owner actions outstanding)

1. **Immediate — DHCP / Network team:** Audit every DHCP scope via `Get-DhcpServerv4OptionValue -OptionId 6` across all scopes. Cross-reference against the current authoritative DNS list. Any scope still referencing `10.10.3.250` or `172.16.5.5` must be corrected now — other subnets may have the same exposure.

2. **Change management:** Add mandatory pre-cutover step to DNS migration runbook: enumerate all DHCP scopes referencing the DNS server being decommissioned and update Option 6 before cutover.

3. **Change management:** Add post-migration client validation step to runbook: run `Resolve-DnsName _ldap._tcp.<domain> -Type SRV` from a DHCP-reliant client in each affected subnet before declaring migration complete.

4. **Infrastructure:** Hard-decommission `10.10.3.250` and `172.16.5.5` at the network layer (firewall block or VM removal). Silent DNS timeout (30 s) masks root cause; a hard unreachable fails fast and is immediately diagnosable.

5. **Change management / Architecture:** Mandate dependency mapping for all DNS/DHCP/network changes — all downstream consumers (DHCP scopes, hardcoded client configs) must be listed in the change record before approval.

---

### If This Recurs

Check in this order:
1. `Get-DhcpServerv4OptionValue -ScopeId <subnet> -OptionId 6` — confirm DNS option on the client's subnet
2. `ipconfig /all` on an affected machine — confirm DNS server address received
3. `Resolve-DnsName _ldap._tcp.<domain> -Type SRV` — confirm SRV records resolve
4. Compare an unaffected machine on the same OU — DNS difference will isolate the cause within 2 minutes

*RCA document:* `Day4/rca-no-secure-channel-finbridge-finance-ou-2026-08-06.md`

---

*Communications issued 2026-08-06 — RCA-2026-08-06-FINBRIDGE-DNS*
