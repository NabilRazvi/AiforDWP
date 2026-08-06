# Triage Summary: AVD Black Screen Post-Login — POOL-FIN-01

## Summary (one line)
~40% of POOL-FIN-01 users hit a black screen post-login from ~07:00; POOL-FIN-02 is completely unaffected, strongly implicating the overnight image update applied to POOL-FIN-01 at 02:00.

## Impact
- Who affected: ~40% of users on POOL-FIN-01 (finance pool).
- POOL-FIN-02: completely unaffected (no image update applied).
- Two resolution patterns observed: black screen clears after ~30 seconds for some users; persists indefinitely for others.
- Business urgency: High — finance users blocked at start of business day.

## Known facts
- Symptom onset: ~07:00 (first login wave).
- Change event: overnight image update to POOL-FIN-01 completed at 02:00; POOL-FIN-02 was NOT updated.
- Symptom is pool-scoped, not user-roaming — this isolates the cause to POOL-FIN-01's image.
- The image update is the sole confirmed change between the two pools.

## Key discriminating constraint
POOL-FIN-02 is untouched and completely clean. Any cause delivered from shared infrastructure (AD, SYSVOL, GPO servers, FSLogix file share) would reach both pools and produce symptoms on both. The cause must therefore live **inside the image itself**.

---

## Ranked hypotheses (most probable first)

### 1. FSLogix profile container failure — new agent version in image
**Why it fits the scope facts:**
The FSLogix agent is installed inside the image, not pulled from infrastructure at runtime. A version change in the new image creates a mismatch with existing profile VHDs. Only POOL-FIN-01 sessions use the new agent; POOL-FIN-02 runs the old agent and mounts profiles as before. Pool isolation is clean and requires no additional assumptions. The 40% split maps to users whose VHD state (locked, oversized, on a specific share path) triggers the failure. The two resolution patterns match slow-but-successful mount (30s group) versus total mount failure (persistent group).

**Fastest check:** On an affected POOL-FIN-01 host immediately after a failed login:
```powershell
Get-WinEvent -LogName "Microsoft-FSLogix-Apps/Operational" | Select-Object -First 20
```
Look for mount errors or `VHD(X) locked` messages. Compare FSLogix agent version between pools:
```powershell
Get-ItemProperty "HKLM:\SOFTWARE\FSLogix\Apps" | Select-Object InstallVersion
```

---

### 2. Startup application hang — new application version baked into image
**Why it fits the scope facts:**
The application binary is baked into the image. POOL-FIN-02 has the old binary (working); POOL-FIN-01 has the new version (hanging on launch). Pool isolation is clean. The 40% split is explained by only a subset of users having that application configured to start (role-based; plausible for a finance-specific thick client). The 30s recovery group matches a crash-timeout after which the shell proceeds; the persistent group has the application in a retry loop.

**Fastest check:** During a live black-screen session, open Task Manager (`Ctrl+Shift+Esc`) and check for any process in a `Not Responding` state or with sustained high CPU at login. On a recovered session check:
```
Event Viewer > Windows Logs > Application — Event ID 1000 / 1002 (application crash) timed at login
```

---

### 3. Explorer.exe / shell entry broken in the new image
**Why it fits the scope facts:**
Shell configuration (the `Shell` registry value under `Winlogon`) is baked into the image. If the image bake corrupted the entry or a per-user override was introduced, Explorer never launches and the result is a permanent black screen. POOL-FIN-02 is untouched so its shell entry is intact. Fully image-contained. Drops to third because a broken shell entry at machine level would typically affect close to 100% of users on the pool, making the 40% split harder to explain without an additional per-user registry layer.

**Fastest check:** During a live black-screen session, press `Ctrl+Shift+Esc` to open Task Manager, then `File > Run > explorer.exe`. If the desktop appears instantly, Explorer failed to auto-launch. Check:
```
HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\Shell
```
for unexpected per-user overrides.

---

### 4. GPU / display driver regression in the new image
**Why it fits the scope facts:**
The graphics driver is installed in the image. A new NVIDIA GRID or RemoteFX driver introduced in the new image can cause the remote session to render black until the GPU is fully initialised. POOL-FIN-02 has the old driver (working). Pool isolation is clean. Ranked fourth because the 40% split requires a hardware-SKU explanation (only a subset of session hosts in the pool have GPU attached), which adds complexity, and the pattern is the weakest behavioural match for the persistent group.

**Fastest check:** Compare display adapter driver versions between an affected POOL-FIN-01 host and a POOL-FIN-02 host:
```powershell
Get-WmiObject Win32_VideoController | Select-Object Name, DriverVersion
```

---

### 5. Broken logon / GPO script — script dependency removed from new image *(weakest fit)*
**Why it fits the scope facts (partially):**
This is the only candidate that is **not image-contained by default**. GPO scripts are delivered from SYSVOL to every session host in the domain regardless of pool or image version. If the script itself were broken, POOL-FIN-02 would also be broken. This cause only survives the pool-isolation filter if the script calls a dependency *inside the image* (a file path, registry key, or executable) that the new image changed — an indirect, two-step relationship. The 40% split could reflect a security-group-scoped GPO. The 30s recovery maps to a script timeout; persistence maps to a genuine hang.

**Fastest check:**
```
Event Viewer > Applications and Services > Microsoft > Windows > GroupPolicy > Operational
```
Filter for logon script errors at ~07:00. If errors exist on POOL-FIN-01 but not POOL-FIN-02, identify which script is failing and what image-resident dependency it references.

---

## Missing information to gather
1. FSLogix agent version in the new image vs the old image (to-verify).
2. Full changelog / image build manifest for the 02:00 update — what specifically changed (to-verify).
3. Whether the 40% affected users share a common security group, OU, or profile path (to-verify).
4. Whether affected users are consistent across session hosts or vary by host (to-verify — would indicate host-level vs user-level cause).
5. Whether any affected users have successfully logged in from POOL-FIN-02 without symptoms (to-verify profile portability).
6. FSLogix Operational event log content from an affected host at login time (to-verify).
7. Application crash events (Event ID 1000/1002) on affected hosts at login time (to-verify).

## Likely category
AVD image regression — session initialisation failure post image update (to-verify root cause; FSLogix agent version delta is lead hypothesis).

## First diagnostic step
Pull the FSLogix Operational log from an affected POOL-FIN-01 host during or immediately after a failed login and compare the FSLogix agent version between pools. This single check confirms or eliminates the top two hypotheses simultaneously.
