# Root Cause Analysis: Startup Performance Drop – Finance-Win11
**Signal Date:** 2026-08-12  
**Incident Window:** 2026-08-04 02:00 config deployment  
**Affected:** Finance-Win11 (215 devices) | Unaffected: IT-Win11 (40 devices)

---

## Ranked Likely Causes (Most Probable First)

### 1. **Additional Defender Scan Policy Blocking Startup Path**
**Why it fits the evidence:**
- The new security baseline explicitly added "additional Defender scan policy" deployed only to Finance-Win11 at 2026-08-04 02:00
- Defender scans are I/O intensive and run synchronously during startup by default, directly delaying "login to usable desktop"
- Timing is immediate and precise: Finance group drops from 18.2s to 41.3s overnight; IT group (no policy) stays at 16.8–17.1s
- Clean comparison: IT-Win11 unaffected because policy was not deployed there

**Fastest confirmation check:**
1. Compare Defender policy versions deployed to Finance-Win11 before vs. after 2026-08-04 02:00
2. Extract the policy definition: check scan scope, exclusions, and execution timing (must run at user logon?)
3. On a Finance device, disable the additional scan policy and measure startup time
4. If startup recovers by ~23 seconds, this is the primary cause

---

### 2. **Compliance Logging Startup Script Adds Overhead**
**Why it fits the evidence:**
- Startup script was explicitly added to Finance-Win11 deployment only at 2026-08-04 02:00
- Runs at every login, before desktop is usable, on all 215 affected devices
- Timing and scope match exactly: drop occurs immediately in Finance group, zero impact on IT group (no script)
- Magnitude (23–26 sec increase) is consistent with script execution + logging I/O

**Fastest confirmation check:**
1. Retrieve the compliance logging script from Finance-Win11 devices
2. Time its execution end-to-end on a staging device during startup
3. Profile the script: look for network calls, Registry queries, file system I/O, or loops
4. Disable the script on one Finance device and measure startup recovery
5. If recovered time is 5–15 seconds, this script is a contributing factor (may be combined with cause #1)

---

### 3. **Resource Contention Between New Defender Policy and Logging Script**
**Why it fits the evidence:**
- The 23–26 second drop is larger than typical single-cause overhead; suggests interaction effects
- Both changes deployed together at 2026-08-04 02:00 to Finance-Win11 only; either alone might cause <15s delay
- Combined execution during startup (additional Defender scan + compliance script) may create I/O bottleneck or CPU contention
- IT group unaffected because neither policy nor script was deployed there

**Fastest confirmation check:**
1. On a Finance test device, measure startup time with both policies enabled (current state)
2. Disable Defender policy only; measure startup time
3. Re-enable Defender policy; disable logging script only; measure startup time
4. If neither policy alone accounts for the full 23+ second drop, but both together do, contention is likely
5. Check Event Viewer startup logs for resource warnings or policy application delays during the config window

---

## Next Steps
Recommend starting with checks for causes #1 and #2 in parallel (policy review + script analysis).  
If either single cause accounts for <20 seconds recovery, investigate cause #3 interaction.
