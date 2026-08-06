# Known Error: No Secure Channel to Domain — Stale DHCP DNS Option After DNS Migration

**Record ID:** KE-2026-08-06-FINBRIDGE-DNS  
**Date confirmed:** 2026-08-06  
**Source RCA:** RCA-2026-08-06-FINBRIDGE-DNS

---

**Symptom:**
Users on affected machines receive the error "This computer was unable to set up a secure channel to domain FINBRIDGE — no domain controller available" at login. Group Policy fails to apply (Events 1058, 1030, 1129) and users are blocked from authenticating to the domain.

**Cause:**
A DHCP scope DNS option (Option 6) was not updated when the DNS servers it referenced were decommissioned during a DNS migration. Machines that obtained a DHCP lease after the old DNS servers were taken offline received a non-responding DNS server address, causing all domain controller SRV lookups to time out and Netlogon to fail with Event 5719.

**Scope:**
All machines in any subnet whose DHCP scope Option 6 still references a decommissioned DNS server. In the confirmed incident, this affected FB031, FB055, FB056, FB057 on OU=Finance (Floor 3 subnet 10.10.3.0). Machines with a manually configured DNS address or a cached DHCP lease from before the migration are not affected.

**Workaround:**
Manually set the DNS server on the affected machine to the correct central DNS server (10.10.0.10), then run `ipconfig /flushdns` and `gpupdate /force`. This restores name resolution and GP immediately without waiting for a DHCP fix.

**Permanent fix:**
Correct the DHCP scope Option 6 on the affected subnet to the authoritative DNS server address (`Set-DhcpServerv4OptionValue -ScopeId <subnet> -OptionId 6 -Value "10.10.0.10"`), then force a lease renewal on all affected machines (`ipconfig /release && ipconfig /renew`). Verify with `Test-ComputerSecureChannel -Verbose` (must return `True`) and confirm Event 1500 in the Group Policy operational log.

**How to spot it:**
Look for Event ID **5719** (Netlogon) with the text *"DNS query for \<DC-FQDN\> returned no response"* — this distinguishes a DNS-layer failure from a DC-side fault. Confirm with Event ID **1014** (DNS Client Events): *"None of the configured DNS servers responded"*. Cross-check `ipconfig /all` on the affected machine — if the DNS server address matches a decommissioned server, this known error is the cause. An unaffected machine on the same OU with a different DNS address in Event 50036 (DHCP Client) is a fast differentiator.
