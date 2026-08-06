# Engineer Note — VPN Client Loss After Win11 Upgrade

**Root cause:** Win11 feature upgrade silently removed the legacy VPN client. Intune re-deployment of the replacement client did not trigger because the detection rule was keyed to the old client's registry presence — once removed, the rule returned "compliant" (false positive), so the deployment policy never fired.

## Action taken

1. Manually cleared stale VPN registry entries under `HKLM\SOFTWARE\<vendor>` (keys left orphaned post-uninstall).
2. Force-triggered Intune sync (`IME` restart + **Sync** from Company Portal) to re-evaluate all applicable policies.
3. New VPN client deployed via Intune; split-tunnel config applied as part of the standard profile.

## Verification

Confirmed connectivity to all internal subnets post-deployment; no data loss observed.

## Preventive action required

Detection rule for the VPN client deployment policy must be updated — switch from registry-key presence check to version-based file detection (e.g., `%ProgramFiles%\<vendor>\vpnclient.exe` at expected version). This prevents a false-compliant state if the registry key is absent. Recommend reviewing all Intune app detection rules for any other legacy-client migrations ahead of the wider Win11 rollout.
