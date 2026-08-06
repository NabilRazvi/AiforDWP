# Root Cause Analysis: AVD Black Screen Post-Login — POOL-FIN-01

## Incident Overview
- **Incident ID:** INC-AVD-20260806-001
- **Date of incident:** 2026-08-06
- **Date of resolution:** 2026-08-06 at 10:00
- **Analyst:** DWP Analyst
- **Severity:** High — finance pool unavailable at start of business day
- **Status:** Resolved

---

## Incident Summary
Users on Azure Virtual Desktop host pool POOL-FIN-01 experienced a black screen immediately after login from approximately 07:00. Affected users either recovered after ~30 seconds or remained in a persistent disconnect/reconnect loop with no desktop rendered. Approximately 40% of POOL-FIN-01 users were affected. POOL-FIN-02 was completely unaffected throughout. Root cause was a faulty Intel GPU driver (`igdumd64.dll`) introduced by an overnight image update to POOL-FIN-01 at 02:00, which caused Desktop Window Manager (`dwm.exe`) to crash on every login. Resolution was confirmed at 10:00 following image rollback.

---

## Timeline

| Time | Event |
|---|---|
| 2026-08-06 02:00 | Image update applied to POOL-FIN-01. Session hosts restarted (boot time confirmed by Kernel-General Event 1 at 07:02:14). POOL-FIN-02 was not updated. |
| 2026-08-06 07:00 | First user login wave begins on POOL-FIN-01. Black screen reports begin. |
| 2026-08-06 07:02:10 | FINBRIDGE\mlopez logs in to SHFIN-01-A (TerminalServices Event 21, Session 3). |
| 2026-08-06 07:02:16 | `dwm.exe` crashes with faulting module `igdumd64.dll` v31.0.101.4146 (Application Error Event 1000, exception 0xc0000005). |
| 2026-08-06 07:02:17 | RDS session disconnected (TerminalServices Event 40, Reason 0). User sees black screen. |
| 2026-08-06 07:02:18 | Desktop Window Manager exits (DWM Event 9009, code 0x40010004). |
| 2026-08-06 07:02:44 | mlopez auto-reconnects (TerminalServices Event 21). |
| 2026-08-06 07:02:46 | `dwm.exe` crashes again — `igdumd64.dll` (Event 1000). Persistent loop confirmed. |
| 2026-08-06 07:02:47 | Session disconnected again (TerminalServices Event 40). |
| 2026-08-06 07:08:22 | FINBRIDGE\akapoor logs in to SHFIN-01-A (TerminalServices Event 21, Session 5). |
| 2026-08-06 07:08:24 | `dwm.exe` crashes with same module `igdumd64.dll` (Event 1000). Pattern confirmed as pool-wide. |
| 2026-08-06 07:01:44 | (Reference) FINBRIDGE\bwalker logs in to SHFIN-02-A (POOL-FIN-02). |
| 2026-08-06 07:01:46 | (Reference) DWM starts successfully on SHFIN-02-A (DWM Event 9011). No crashes in window. |
| 2026-08-06 ~09:00 | Incident escalated. POOL-FIN-01 drained. Affected users redirected to POOL-FIN-02. Image rollback initiated. |
| 2026-08-06 10:00 | Resolution confirmed. Users logging in to POOL-FIN-01 successfully. No further black screen reports. |

---

## Evidence Collected

### Session host: SHFIN-01-A (POOL-FIN-01 — affected)

| Event ID | Source | Time | Detail |
|---|---|---|---|
| 21 | TerminalServices-LocalSessionManager | 07:02:10 | Logon succeeded — mlopez, Session 3 |
| 1 | Kernel-General | 07:02:14 | System boot time 02:03:11 — post-image-update restart confirmed |
| 1000 | Application Error | 07:02:16 | `dwm.exe` v10.0.22621.2861 faulting in `igdumd64.dll` v31.0.101.4146, exception 0xc0000005, offset 0x0000000000047f12 |
| 40 | TerminalServices-LocalSessionManager | 07:02:17 | Session disconnected — mlopez, Reason 0 |
| 9009 | Desktop Window Manager | 07:02:18 | DWM exited, code 0x40010004 |
| 21 | TerminalServices-LocalSessionManager | 07:02:44 | Reconnect — mlopez, Session 3 |
| 1000 | Application Error | 07:02:46 | `dwm.exe` / `igdumd64.dll` crash repeated |
| 40 | TerminalServices-LocalSessionManager | 07:02:47 | Session disconnected again — loop |
| 21 | TerminalServices-LocalSessionManager | 07:03:10 | Second reconnect — mlopez, Session 4 |
| 21 | TerminalServices-LocalSessionManager | 07:08:22 | Logon succeeded — akapoor, Session 5 |
| 1000 | Application Error | 07:08:24 | `dwm.exe` / `igdumd64.dll` crash — second affected user |

### Session host: SHFIN-02-A (POOL-FIN-02 — unaffected, pre-update image)

| Event ID | Source | Time | Detail |
|---|---|---|---|
| 21 | TerminalServices-LocalSessionManager | 07:01:44 | Logon succeeded — bwalker, Session 2 |
| 9011 | Desktop Window Manager | 07:01:46 | DWM started successfully |

No `Event 1000` or `Event 9009` entries recorded on SHFIN-02-A in the entire incident window.

### Hypothesis elimination summary

| Hypothesis | Verdict | Reason |
|---|---|---|
| FSLogix agent version mismatch | Eliminated | `Event 21` confirms logon succeeded before disconnect; no FSLogix events present; DWM crash is the direct disconnect cause |
| Startup application hang | Eliminated | Only `dwm.exe` crashes in `Event 1000`; no finance application crash or hang events |
| Explorer / shell not launching | Eliminated | `Event 9009` shows DWM exited before shell could render; no Explorer crash events |
| **GPU driver regression** | **Confirmed** | `igdumd64.dll` cited in every `Event 1000`; POOL-FIN-02 shows `Event 9011` with zero crashes |
| GPO logon script dependency | Eliminated | No GroupPolicy events; full failure chain accounted for by `Event 1000` alone |

---

## Root Cause

The overnight image update applied to POOL-FIN-01 at 02:00 introduced Intel GPU user-mode driver `igdumd64.dll` version `31.0.101.4146`. This driver version contains a defect that causes `dwm.exe` (Desktop Window Manager) to crash with a memory access violation (exception `0xc0000005`) within seconds of every user login. When DWM crashes, the RDS subsystem tears down the session (`Event 40`), which the user experiences as a black screen followed by disconnection. Auto-reconnect re-triggers the same crash, producing a persistent loop for most affected users.

POOL-FIN-02 was not updated, continued running the previous driver version, and showed clean DWM starts (`Event 9011`) with no crashes throughout the incident window.

The 40% affected-user rate reflects the proportion of users whose sessions were brokered to session hosts in POOL-FIN-01 that had the Intel vGPU profile active. Hosts without vGPU acceleration did not invoke `igdumd64.dll` and their users were unaffected.

---

## 5 Why Analysis

**Problem statement:** Finance AVD users hit a black screen and could not access their desktop after a routine overnight image update.

| Why | Answer |
|---|---|
| **Why 1:** Why did users see a black screen? | `dwm.exe` crashed within seconds of login, tearing down the RDS session before the desktop could render. |
| **Why 2:** Why did `dwm.exe` crash? | It loaded `igdumd64.dll` v31.0.101.4146, which contains a defect causing a memory access violation (0xc0000005) during DWM initialisation on this VM SKU. |
| **Why 3:** Why was this driver version present on POOL-FIN-01? | The overnight image update at 02:00 included this driver version. It was not present in the previous image used by POOL-FIN-02. |
| **Why 4:** Why was a defective driver included in the image? | The image build process had no post-bake validation step to confirm DWM started cleanly on a canary session host before the image was promoted to production. |
| **Why 5:** Why was there no validation step? | The image pipeline had no defined smoke-test gate. Image updates were applied directly to a live production pool without a staged rollout or observability check. |

---

## Preventive Actions

### PA-1 — Add DWM smoke test to the image bake pipeline (Priority: High)
After every image build, automatically launch a canary session host from the new image and validate that `Event 9011` (DWM started successfully) is present and that no `Event 1000` for `dwm.exe` is recorded within 60 seconds of first login. Block promotion of the image to any production pool if this check fails.

### PA-2 — Enforce staged pool rollout for image updates (Priority: High)
Image updates must be applied to one pool at a time. A minimum observation window of two hours (covering a login wave) must pass with no session stability incidents before the update is applied to the next pool. This ensures a clean comparison pool is always available for rapid diagnosis.

### PA-3 — Pin and test GPU driver versions independently before image inclusion (Priority: Medium)
Establish a driver validation process separate from the image build. Any new Intel, NVIDIA GRID, or AMD GPU driver must be tested against all deployed VM SKUs in a non-production AVD environment before being approved for inclusion in an image build. Approved driver versions are pinned in the image build specification.

### PA-4 — Set pool-level drain automation on DWM crash threshold (Priority: Medium)
Configure an Azure Monitor alert that triggers automatic drain mode on a host pool when `Event 9009` (DWM exit) is recorded on more than one session host within a five-minute window. This limits user impact to the first login wave rather than the full business day.

### PA-5 — Document rollback runbook and test it quarterly (Priority: Low)
Create a runbook covering the full steps to roll back a host pool image to the previous gallery version, including drain, reimage, validation, and re-enable. Test the runbook in a non-production environment quarterly to ensure the steps remain accurate as infrastructure evolves.

---

## Resolution Applied

1. POOL-FIN-01 session hosts set to drain mode to prevent new user routing.
2. Affected users redirected to POOL-FIN-02 while remediation was performed.
3. POOL-FIN-01 host pool updated to point to the pre-update image (`build-20240313`).
4. All POOL-FIN-01 session hosts reimaged from the previous gallery version.
5. Validation performed on one session host — `Event 9011` confirmed, no `Event 1000` for `dwm.exe`.
6. Drain mode removed from all POOL-FIN-01 session hosts.
7. Resolution confirmed at 10:00 — users logging in to POOL-FIN-01 with no issues reported.

---

## Lessons Learned

- The clean state of POOL-FIN-02 was the single most valuable diagnostic signal. Deliberate staged rollout is both a safety control and a diagnostic tool — it must be policy, not coincidence.
- The failure mode (DWM crash on login) was detectable within seconds of first login. An automated smoke test would have contained this to zero production users.
- Event 9009 and Event 1000 together form a reliable, fast signal for this failure class. These should be baselined as alerting criteria in Azure Monitor for all AVD host pools.
