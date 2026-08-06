# Known Error Record — AVD Black Screen Post-Login (DWM Crash on igdumd64.dll)

**Record ID:** KE-AVD-20260806-001
**Date raised:** 2026-08-06
**Status:** Resolved — retained for recurrence detection

---

**Symptom**
Users experience a black screen immediately after logging into their Azure Virtual Desktop session. The session disconnects within seconds and auto-reconnects into the same black screen loop. Some users recover after approximately 30 seconds; others remain stuck indefinitely.

**Cause**
A faulty Intel GPU user-mode driver (`igdumd64.dll` v31.0.101.4146) introduced by an image update causes `dwm.exe` (Desktop Window Manager) to crash with a memory access violation (exception `0xc0000005`) during session initialisation. The DWM crash tears down the RDS session before the desktop renders, producing the black screen.

**Scope**
Affects AVD session hosts in the updated host pool that have an Intel vGPU profile active. Only the pool that received the image update is affected; any pool still running the previous image version is unaffected. Approximately 40% of users in the affected pool are impacted — those brokered to vGPU-enabled hosts.

**Workaround**
Set all session hosts in the affected pool to drain mode to stop new users being routed there, then redirect affected users to an unaffected pool. No data loss occurs; users can resume work immediately from the alternative pool.

**Permanent fix**
Roll back the affected host pool image to the last known-good version in the Azure Compute Gallery (pre-update build) and reimage all session hosts in the pool. Confirm resolution by verifying `Event 9011` (DWM started successfully) is present and no `Event 1000` for `dwm.exe` is recorded on a test login before re-enabling the pool.

**How to spot it**
Look for `Application Error Event 1000` with faulting application `dwm.exe` and faulting module `igdumd64.dll` in the Application event log on the session host, followed immediately by `DWM Event 9009` (DWM exited) and `TerminalServices-LocalSessionManager Event 40` (session disconnected). The pattern repeats on every reconnect. A healthy host running the correct image version will show `DWM Event 9011` (DWM started successfully) with no accompanying `Event 1000`.
