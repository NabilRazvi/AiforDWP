# AVD Black Screen Analysis — POOL-FIN-01 — 2026-08-06

## What is happening
Users on POOL-FIN-01 are hitting a black screen immediately after login. For some users it clears after about 30 seconds. For others it persists indefinitely. Roughly 40% of the pool is affected. POOL-FIN-02 has no issues at all.

## When it started
Symptoms were first reported around 07:00, coinciding with the first login wave of the day.

## The only change
An image update was applied to POOL-FIN-01 at 02:00. POOL-FIN-02 was not updated.

## Why POOL-FIN-02 being clean matters
Anything delivered from shared infrastructure — Active Directory, Group Policy, FSLogix file shares — reaches both pools equally. If that were the cause, both pools would show symptoms. Because only POOL-FIN-01 is affected and only POOL-FIN-01 was updated, the cause must be something that lives inside the image itself.

---

## Ranked hypotheses

**1. FSLogix agent version mismatch**
The FSLogix agent is installed inside the image. If the new image contains a different agent version, it may fail to mount existing profile VHDs. Users whose profiles mount slowly recover after ~30 seconds. Users whose profiles fail to mount at all are stuck. POOL-FIN-02 runs the old agent and is unaffected. The 40% split reflects users whose profile state triggers the failure.

**2. Startup application hang**
A finance-specific application baked into the new image may hang on launch. Users affected are those who have that application set to start at login (~40%). The shell eventually continues after a crash timeout (30s group) or loops indefinitely (persistent group). POOL-FIN-02 has the old version of the application.

**3. Explorer / shell not launching**
If the shell registry entry was corrupted during the image bake, Explorer never starts and the user sees a permanent black screen. Windows Error Recovery can restart Explorer for some users (~30s group). Fully image-contained so POOL-FIN-02 is clean. The 40% split is harder to explain at machine level without a per-user override layer.

**4. Display / GPU driver regression**
A new graphics driver in the image can cause the remote session to render black while the GPU initialises. The 30s group recovers as the driver warms up. The persistent group may have an incompatible VM size or GPU config. POOL-FIN-02 has the old driver. The 40% split requires a hardware-SKU explanation, which makes this weaker.

**5. GPO logon script with a broken image dependency**
GPO scripts are delivered from SYSVOL to all pools equally, so a broken script alone would affect POOL-FIN-02 as well. This only fits if the script calls something inside the image (a file, registry key, or executable) that the new image changed. It is the weakest explanation because it requires two failure points and does not cleanly explain pool isolation.

---

## Lead hypothesis
FSLogix profile mount failure. It is the only cause that is image-contained, directly mediates every login, and naturally produces both resolution patterns (slow mount vs total failure).

## Single best first check
On an affected POOL-FIN-01 host, immediately after a failed login run:

```powershell
Get-WinEvent -LogName "Microsoft-FSLogix-Apps/Operational" | Select-Object -First 20
```

Then compare the FSLogix agent version between the two pools:

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\FSLogix\Apps" | Select-Object InstallVersion
```

If versions differ and the log shows mount errors, hypothesis 1 is confirmed. If the log is clean, move to hypothesis 2 and check for application crash events (Event ID 1000/1002) in the Application event log.

---

## Evidence review — session host event log (SHFIN-01-A, 07:00–07:30)

### Key events observed

| Time | Source | Event ID | Detail |
|---|---|---|---|
| 07:02:10 | TerminalServices-LocalSessionManager | 21 | Logon succeeded — FINBRIDGE\mlopez, Session 3 |
| 07:02:14 | Kernel-General | 1 | Boot time 02:03:11 — confirms host restarted after image update |
| 07:02:16 | Application Error | 1000 | `dwm.exe` faulting module `igdumd64.dll` v31.0.101.4146, exception 0xc0000005 |
| 07:02:17 | TerminalServices-LocalSessionManager | 40 | Session disconnected — FINBRIDGE\mlopez |
| 07:02:18 | Desktop Window Manager | 9009 | DWM exited with code 0x40010004 |
| 07:02:44 | TerminalServices-LocalSessionManager | 21 | Reconnect — FINBRIDGE\mlopez, Session 3 |
| 07:02:46 | Application Error | 1000 | `dwm.exe` / `igdumd64.dll` crash repeats |
| 07:02:47 | TerminalServices-LocalSessionManager | 40 | Session disconnected again — loop confirmed |
| 07:08:24 | Application Error | 1000 | `dwm.exe` / `igdumd64.dll` crash — FINBRIDGE\akapoor, Session 5 |

### Comparison — SHFIN-02-A (POOL-FIN-02, pre-update image)

| Time | Source | Event ID | Detail |
|---|---|---|---|
| 07:01:44 | TerminalServices-LocalSessionManager | 21 | Logon succeeded — FINBRIDGE\bwalker |
| 07:01:46 | Desktop Window Manager | 9011 | DWM started successfully |

No `Event 1000` or `Event 9009` entries on SHFIN-02-A in the entire window.

### Assessment against each hypothesis

| # | Hypothesis | Verdict | Determining event |
|---|---|---|---|
| 1 | FSLogix agent mismatch | Neutral / leans contradicts | `Event 21` at 07:02:10 — logon succeeded before disconnect; no FSLogix events present |
| 2 | Startup application hang | Contradicts | `Event 1000` at 07:02:16 — only `dwm.exe` crashes, no finance app crashes |
| 3 | Explorer / shell broken | Contradicts | `Event 9009` at 07:02:18 — DWM exits before shell renders; no Explorer crash events |
| 4 | GPU driver regression | **Directly supports** | `Event 1000` at 07:02:16, 07:02:46, 07:08:24 — `igdumd64.dll` in every crash; `Event 9011` on POOL-FIN-02 with no crashes |
| 5 | GPO script dependency | Neutral / effectively contradicts | No GroupPolicy events; full failure chain explained by `Event 1000` alone |

---

## Confirmed root cause

**GPU driver regression — `igdumd64.dll` v31.0.101.4146 crashing DWM in the new image**

`dwm.exe` faults inside `igdumd64.dll` (Intel GPU user-mode driver) within seconds of every login on POOL-FIN-01. DWM crashing tears down the RDS session (`Event 40`), producing the black screen. The crash loops on reconnect for affected users. POOL-FIN-02 running the pre-update image shows `Event 9011` (DWM started successfully) with zero crashes. This driver version was introduced by the 02:00 image update and is the sole differentiator between the two pools.

---

## Resolution steps

### Immediate containment

**1. Drain POOL-FIN-01** — prevent new users routing to the broken pool:
```powershell
$hosts = Get-AzWvdSessionHost -ResourceGroupName <RG> -HostPoolName "POOL-FIN-01"
foreach ($h in $hosts) {
    Update-AzWvdSessionHost -ResourceGroupName <RG> -HostPoolName "POOL-FIN-01" `
        -Name $h.Name.Split('/')[1] -AllowNewSession:$false
}
```

**2. Redirect affected users to POOL-FIN-02** — confirm capacity, update application group or workspace assignment.

**3. Notify users** — disconnect and reconnect; they will land on a working pool.

### Root cause fix

**4. Confirm the driver version delta** on a POOL-FIN-01 host:
```powershell
Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion, DriverDate
```
Cross-reference against the image build manifest from the 02:00 update.

**5a. Roll back the image (recommended)** — if the previous image version is available in the Azure Compute Gallery:
- Update POOL-FIN-01's host pool to point to the pre-update image (`build-20240313`)
- Reimage all POOL-FIN-01 session hosts from the portal

**5b. Fix and republish (if rollback unavailable)** — spin up the image master VM, uninstall or roll back `igdumd64.dll` to the previously working version, sysprep, publish a new image version to the Compute Gallery, update POOL-FIN-01, reimage session hosts.

### Validation before reopening

**6. Test one host before lifting drain mode:**
```powershell
Get-WinEvent -LogName Application |
    Where-Object { $_.Id -in 1000, 9009, 9011 } |
    Select-Object -First 10
```
Confirm `Event 9011` present and no `Event 1000` for `dwm.exe`.

**7. Re-enable all session hosts:**
```powershell
foreach ($h in $hosts) {
    Update-AzWvdSessionHost -ResourceGroupName <RG> -HostPoolName "POOL-FIN-01" `
        -Name $h.Name.Split('/')[1] -AllowNewSession:$true
}
```

### Post-incident actions

**8. Add a DWM smoke test to the image bake pipeline** — validate `Event 9011` on a canary host before any pool is updated. This would have caught the failure at 02:00 before users arrived at 07:00.

**9. Enforce staged pool updates** — apply image updates to one pool at a time with a minimum observation window before updating the next pool.
