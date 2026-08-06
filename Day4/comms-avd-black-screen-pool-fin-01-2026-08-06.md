# AVD Incident Communications — POOL-FIN-01 Black Screen — 2026-08-06

---

## Audience 1 — Non-Technical Executive

**Subject: This morning's virtual desktop issue — resolved**

Your access and data are completely safe. This morning, approximately 40% of our finance virtual desktop users experienced a black screen when logging in, caused by a faulty software component introduced during a routine overnight update to one desktop environment. The team identified the cause, rolled back the update, and confirmed full resolution at 10:00. The other desktop environment was unaffected throughout. No action is required from you.

---

## Audience 2 — Affected End-User Team

**Subject: This morning's login issue — fixed**

Hi team, apologies for the disruption this morning. A routine overnight update to your virtual desktop environment included a faulty software component that caused a black screen on login for around 40% of the team. The issue was identified and fully resolved by 10:00 — you should be able to log in normally now. No action is needed from your side. If you experience a black screen when logging in at any point, please disconnect, wait 30 seconds, and try again. If the issue persists, contact the service desk or raise a ticket.

---

## Audience 3 — Internal Engineer Note

**Subject: P1 resolved — POOL-FIN-01 AVD black screen — DWM crash on igdumd64.dll — 2026-08-06**

### Root cause

`dwm.exe` crashed immediately post-login on all vGPU-enabled session hosts in POOL-FIN-01. Faulting module: `igdumd64.dll` v31.0.101.4146 (Intel GPU user-mode driver). Exception: `0xc0000005` (access violation), offset `0x0000000000047f12`. DWM crash triggers `Event 9009` (exit code `0x40010004`) which causes the RDS broker to tear down the session (`Event 40`, Reason 0) — user sees black screen and is auto-reconnected into the same crash loop.

Driver version was introduced by the overnight image update applied to POOL-FIN-01 at 02:00. POOL-FIN-02 was not updated and ran cleanly throughout — `Event 9011` (DWM started successfully) on every login, zero `Event 1000` for `dwm.exe`.

Symptom onset: 07:00 (first login wave). Affected scope: ~40% of POOL-FIN-01 users — those brokered to hosts with Intel vGPU profile active. Hosts without vGPU config did not invoke `igdumd64.dll` and were clean.

### Evidence

Key events from SHFIN-01-A (Application + System logs, 07:00–07:30):

- `Event 21` 07:02:10 — logon succeeded, mlopez Session 3 (login completes before DWM loads)
- `Event 1` 07:02:14 — Kernel-General boot time 02:03:11 (confirms post-update restart)
- `Event 1000` 07:02:16 — `dwm.exe` v10.0.22621.2861, faulting in `igdumd64.dll` v31.0.101.4146
- `Event 40` 07:02:17 — session disconnect
- `Event 9009` 07:02:18 — DWM exited
- `Event 21` 07:02:44 — reconnect; `Event 1000` 07:02:46 — crash repeats (loop)
- `Event 1000` 07:08:24 — same crash, akapoor Session 5 (multi-user confirmation)

SHFIN-02-A (POOL-FIN-02): `Event 9011` at 07:01:46, no `Event 1000` in window.

### Action taken

1. All POOL-FIN-01 session hosts set to drain mode via `Update-AzWvdSessionHost -AllowNewSession:$false`.
2. Affected users redirected to POOL-FIN-02 (capacity confirmed).
3. POOL-FIN-01 host pool image pointer reverted to `build-20240313` (pre-update image) via Azure Compute Gallery.
4. All POOL-FIN-01 session hosts reimaged from the rolled-back gallery version.
5. Drain mode removed via `Update-AzWvdSessionHost -AllowNewSession:$true`.

### Verification

Post-rollback check on SHFIN-01-A:
```powershell
Get-WinEvent -LogName Application |
    Where-Object { $_.Id -in 1000, 9009, 9011 } |
    Select-Object -First 10
```
`Event 9011` present, no `Event 1000` for `dwm.exe`. User logins confirmed clean from 10:00.

### Preventive actions required

**PA-1 (High) — DWM smoke test in image pipeline**
After every image build, boot a canary session host and assert `Event 9011` is present and no `Event 1000` for `dwm.exe` within 60 seconds of first login. Block image promotion if check fails. Needs to cover all vGPU and non-vGPU host SKUs in the build matrix.

**PA-2 (High) — Staged pool rollout policy**
Image updates applied to one pool only. Minimum two-hour observation window covering a login wave before the update is applied to the next pool. Formalise as a change management gate — POOL-FIN-02 being untouched was the critical diagnostic signal here; that needs to be deliberate.

**PA-3 (Medium) — GPU driver pre-qualification**
Intel/NVIDIA GRID/AMD driver versions must pass a standalone test pass against all deployed VM SKUs in non-prod before being approved for image inclusion. Approved versions pinned in the image build spec.

**PA-4 (Medium) — Azure Monitor alert on DWM crash threshold**
Alert rule: `Event 9009` on more than one session host in the same pool within five minutes triggers automatic drain mode. Limits blast radius to the first login wave.

**PA-5 (Low) — Image rollback runbook**
Document and quarterly-test the full rollback procedure (drain → reimage from gallery → validate → re-enable). Ensure any on-call engineer can execute without escalation.

### If this recurs

Check `igdumd64.dll` version on the affected pool immediately:
```powershell
Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion
```
If a version other than the known-good baseline is present, drain the pool and reimage from the last clean gallery image. Do not attempt in-place driver rollback on live session hosts — the DWM crash loop makes the host unusable and reimage is faster.
