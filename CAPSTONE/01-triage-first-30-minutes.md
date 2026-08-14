# First 30-Minute Triage: FinBridge Floor 6 Incident
**Date:** 2026-08-14 (Monday, 09:14 report received)  
**Location:** Floor 6 (Legal department, ~45 people)  
**Context:** Win11 migration + Intune enrollment (recent); Document Management App deployed Friday afternoon  
**Incident Severity:** **HIGH** — Security signal + operational impact

---

## Issue Breakdown & Priority Ranking

### 🔴 PRIORITY 1: Copilot Surfaced Unauthorized Client Matter (SECURITY INCIDENT)

**Why this is Rank 1:**
- Potential data classification breach / unauthorized access to confidential client data
- Suggests either: (a) user permissions misconfigured, (b) search indexes poisoned, (c) document management app has permission bypass, (d) account compromise
- Legal/compliance/liability implications are catastrophic if true
- *Cannot assume this is a false report or user confusion — must treat as real security signal*

**What to check first:**
1. **Verify the Copilot incident itself** — Did this actually happen or is user confused?
   - Get paralegal's name and specific client matter that appeared
   - Get exact timestamp and whether she *interacted* with the document or just saw it in results
   - Screenshot/recording if still visible in Copilot history
   
2. **Check user's actual permissions** — Is she supposed to have access to that matter?
   - Query permission logs for that user account on that document repository
   - Check if user is in any "Legal All" distribution groups or overly broad security groups
   - Verify OneDrive/SharePoint ACLs for the matter folder
   
3. **Check if document management app is the vector**
   - Was this document indexed by the new app deployed Friday?
   - Does the new app have admin/service account that might be running indexing with excessive permissions?
   - Was there a permission import/sync during deployment?

**Why this check is first:**
- Must establish *if the breach actually occurred* before escalating as security incident
- If real, we need evidence immediately before user navigates away or clears history
- If app is the vector, we need to contain it (potentially suspend access) within minutes
- Compliance/legal notification clock starts ticking immediately upon confirmation

**Immediate safe actions/containment:**
- **DO NOT wait** — escalate to InfoSec/Compliance lead immediately with "unconfirmed security signal, investigating"
- Document the paralegal's report exactly as stated (name, time, client matter name, what she did)
- Preserve: Copilot query history, Copilot results, user's OneDrive activity logs, document repository access logs
- If confirmed: Prepare to restrict new document management app's indexing scope pending audit
- If app is the vector: Prepare to revoke its read permissions temporarily while investigating
- **Do NOT notify the paralegal yet** that this is a potential breach until verified — avoid panic/gossip

**Evidence required to confirm:**
- Copilot query/response log showing the document appearing
- User's actual permission entry (or lack thereof) in the document's ACL
- New document management app's service account permissions at Friday 4pm deploy time
- Indexing logs from the app showing which documents were crawled and when
- User's access logs to the legal repository for that client matter (should show today's date only in Copilot, not in actual access)

**NEED TO VERIFY:**
- [ ] Did paralegal actually open/interact with the document or just see it in Copilot search results?
- [ ] Does the document exist in a shared repository or in another user's OneDrive?
- [ ] What exact text triggered Copilot to surface it? (Natural language search vs. indexed keywords)
- [ ] Is the new document management app indexing *entire* repository regardless of user permissions, or was it misconfigured?
- [ ] Are other Floor 6 users reporting similar unauthorized content surface?
- [ ] Has there been any recent account compromise indicators (unusual login times, IP locations, login failures)?

---

### 🟠 PRIORITY 2: Login Failures/Inability to Log In (OPERATIONAL + SECURITY)

**Why this is Rank 2:**
- 12+ users unable to work = business-blocking for entire floor
- Could indicate: (a) Intune MFA/enrollment issue, (b) Active Directory policy applied wrongly, (c) account lockouts, (d) cached credential expiration, (e) device compromise, (f) new document app broke login process
- Security angle: Mass login failures can mask account compromise or indicate policy injection attack
- But *less immediately catastrophic than active data breach*

**What to check first:**
1. **Separate the populations** — Are these all Win11 machines on the recent migration, or mixed?
   - Pull list of affected users' machines
   - Are they Intune-enrolled? What device compliance state?
   - Are affected machines all on Floor 6 or elsewhere too?
   
2. **Check Intune/Azure AD event logs for the population**
   - Sign-in failures: Filter for Floor 6 users in past 2 hours
   - Device compliance state: Are machines showing as non-compliant (would trigger MFA/login blocks)?
   - Conditional access policies: Did a new policy deploy Friday/Monday morning targeting Win11 or document management app?
   
3. **Check if local device policy is blocking**
   - Check event logs on one affected machine for logon errors (Event ID 4625, 4771, 4776)
   - Check if Group Policy applied new restrictions over the weekend
   - Check if new document management app deployed group policies that broke auth flows

**Why this check is first:**
- Need to know if this is device-wide, user-wide, or app-wide before proceeding
- Intune/AD are centralized logs (fast to check); device-level logs require remote access/device cooperation
- If it's policy-related, we can potentially roll back immediately
- If it's enrollment/compliance, we can troubleshoot systematically

**Immediate safe actions/containment:**
- **Verify this is actually 12+ distinct users, not the same person reporting multiple times**
- Check if the document management app deployment included a Group Policy Object (GPO) or Intune policy that might have broken auth
- If app deployed policies: **Prepare to remove/disable those policies from the impacted floor's device group**
- Advise affected users: "We're investigating; try restarting machine and signing in again" (gives app time to stabilize if it's a temporary lock)
- If restart doesn't work within 5 minutes: Walk user through "sign out of all apps and clear cached credentials" on device
- **DO NOT force password resets yet** — that will make things worse if it's a device policy/enrollment issue

**Evidence required:**
- Screenshot/list of affected user accounts with timestamps of first failure attempt
- Affected device names/serials — are they a cohort from Friday deployment?
- Azure AD sign-in failure logs (showing exact error: MFA failure, device compliance, policy, credential, etc.)
- Intune device compliance state for affected machines at time of failure
- Group Policy application logs on affected devices (gpresult or Event Viewer)
- New document management app deployment logs/error telemetry

**NEED TO VERIFY:**
- [ ] Are all affected users on Floor 6, or broader?
- [ ] Do all affected machines have the new document management app installed?
- [ ] What is the exact error message users are seeing? (User-reported vs. system error code)
- [ ] Did affected machines successfully log in on Friday and then fail on Monday, or did they never sync since deployment?
- [ ] Did any Group Policy or Intune policy deploy over the weekend?
- [ ] Is this affecting *first login of the day* only, or persistent logoff/relogon failures?
- [ ] Can affected users log in via alternate device (phone, personal laptop) to access email/resources?

---

### 🟡 PRIORITY 3: Slow Login/Device Performance (OPERATIONAL)

**Why this is Rank 3:**
- Impacts usability but doesn't block work completely (users *can* eventually log in)
- Common symptoms during OS migration (startup scripts, policy reprocessing, Windows Update, indexing, credential provider delays)
- May be related to new document management app (indexing, startup hooks, real-time scanning)
- If performance is *extremely* slow (10+ minutes), could indicate resource exhaustion or malware, elevating priority
- *Likely to resolve with troubleshooting app or policy adjustment*

**What to check first:**
1. **Establish baseline** — How slow is "slow"?
   - Request screenshot of login screen state + timestamp from one affected user
   - Get estimate: 2 minutes vs. 10+ minutes vs. frozen?
   - Is it slow at login prompt, or slow loading desktop after credentials accepted?
   
2. **Check device resource usage during login**
   - On one affected machine: Run Task Manager during login attempt (sign out, restart, watch Task Manager)
   - Look for: CPU-heavy processes (Windows Update, indexing, malware scanning), disk I/O at 100%, memory pressure
   - Check if indexing service (Windows Search) is reindexing — if so, that's easily the culprit
   
3. **Check startup scripts and policies**
   - gpresult /h to see what policies applied at startup
   - Event Viewer > Windows Logs > System: Any errors during Winlogon, boot, policy application?
   - Check if new document management app has startup tasks (Task Scheduler)

**Why this check is first:**
- Fast elimination of common causes: Windows Update, indexing, heavy startup scripts
- If it's indexing, we can pause/disable temporarily and regain performance immediately
- If it's policy, we can identify which policy and roll back
- If it's resource exhaustion, we need to identify the process (could be malware)

**Immediate safe actions/containment:**
- **Do NOT reimage machines yet** — that's last resort
- Check Windows Update status; if updating, tell users it's normal and will resolve in 1-2 hours
- If indexing service is the culprit: Temporarily pause Windows Search indexing on affected machines (can resume after hours)
- If startup scripts are slow: Identify and test whether they're related to new document management app or Intune enrollment
- Advise users: "Login is slow this morning; we're identifying the cause and will accelerate it. Please let us know if it's over 5 minutes."

**Evidence required:**
- Screenshot + timestamp of login status (at login prompt vs. loading desktop vs. desktop reached)
- Task Manager: CPU, disk, memory during login attempt (screenshot or performance trace)
- Event Viewer: System and Application logs during login window, especially errors
- Group Policy applied (gpresult), focusing on policies deployed in last 48 hours
- Windows Search indexing status (Services.msc or Get-Service WSearch)
- New document management app startup entries (Task Scheduler, registry Run keys, startup folder)

**NEED TO VERIFY:**
- [ ] Is the slowness consistent across all affected machines, or variable?
- [ ] Did affected machines perform normal login speed on Friday, or was it slow immediately after deployment?
- [ ] Is this only affecting first login of the day, or persistent across logoff/relogon?
- [ ] What is the exact number of affected users (is it really 12+ or a smaller cohort)?
- [ ] Is performance slow at login specifically, or slow throughout the day?
- [ ] Did any Windows Updates deploy over the weekend that might be installing?

---

### 🟡 PRIORITY 4: Missing Desktop Shortcuts (OPERATIONAL/MINOR)

**Why this is Rank 4:**
- Annoying but not business-blocking; users can access apps via Start menu or previous shortcuts
- Could indicate: (a) Intune device management reset user settings, (b) new document management app removed shortcuts during deployment, (c) roaming profile issue, (d) user confusion (not actually missing)
- Lowest security risk and lowest impact to immediate work
- **However: If combined with other issues, may indicate broader profile/provisioning problem**

**What to check first:**
1. **Verify shortcuts are actually missing**
   - Ask reporting user: Are you looking at Desktop? Have you restarted since Friday? Are shortcuts in Start menu?
   - Screenshot of current desktop state
   - Check user's roaming profile on file share: Are .lnk files present in `\user\Desktop` folder?
   
2. **Check if new document management app removed them**
   - App deployment logs: Did the installer include a step to "clean" desktop or modify user settings?
   - Registry: Check `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders` — is Desktop path pointing to correct location?
   - Check if app has "first run" logic that resets user environment
   
3. **Check Intune provisioning**
   - Did Intune push a device configuration removing shortcuts or resetting Start menu?
   - Check if "Cloud PC" or "Reset this PC" was invoked (would wipe desktop)

**Why this check is first:**
- Fastest to verify (just ask user for screenshot)
- If it's app-related, we can advise user to re-create shortcuts (quick workaround)
- If it's Intune policy, we can identify and adjust it
- Unlikely to be blocker for Priority 1/2/3 investigation, but worth capturing for root cause analysis

**Immediate safe actions/containment:**
- Tell affected users: "Recreate shortcuts from Start menu or file shortcuts we'll provide. We're investigating."
- If app is confirmed culprit: Document this as a known issue with the app pending UAT review
- No containment needed at this stage; this is low-risk

**Evidence required:**
- Screenshot of user's current desktop
- Roaming profile path check: `\\fileserver\users$\username\Desktop` — list of .lnk files present/absent
- New document management app deployment package and installer script (to check if it touches desktop)
- Intune device configuration policies applied to Floor 6 machines over past 48 hours
- User's Start menu configuration (to verify it's intact elsewhere)

**NEED TO VERIFY:**
- [ ] Is this happening on multiple machines or isolated to one user?
- [ ] Did shortcuts exist immediately after deployment Friday, or missing on first Monday logon?
- [ ] Is this specific to Floor 6 or broader?
- [ ] Are other user files on Desktop intact, or is entire Desktop missing/inaccessible?
- [ ] Are shortcuts missing only for the new document management app, or all shortcuts?

---

## Immediate Actions (Next 30 Minutes)

### For Incident Commander / Escalation:
1. **Open security incident ticket immediately** for Priority 1 (Copilot data breach signal) — assign to InfoSec
2. **Page on-call** Intune admin (Priority 2 login failures) and Systems admin (Priority 3 performance)
3. **Get IT Ops lead on incident call** — brief on preliminary findings, set check-in at 09:45

### Parallel Investigation Tracks:
| Track | Owner | By Time | Deliverable |
|-------|-------|---------|-------------|
| **Priority 1: Copilot Breach** | InfoSec + Document Owner | 09:35 | Confirm/refute breach; escalation level |
| **Priority 2: Login Failures** | Intune Admin | 09:40 | Root cause (policy/compliance/app); remediation start |
| **Priority 3: Performance** | Systems Admin | 09:40 | Resource hog identified; workaround deployed |
| **Priority 4: Shortcuts** | Help Desk / Document Owner | 09:45 | Scope (1 vs. many); cause identified |

---

## What We're *Not* Assuming Yet
- ❌ The document management app is the cause of *all* issues
- ❌ This is a targeted attack or account compromise (yet)
- ❌ Users are confused or misconfiguring their machines
- ❌ The Win11 migration itself is fundamentally broken
- ❌ Any root cause without evidence

---

## Escalation Criteria: Pause and Escalate If...
- **Priority 1 is confirmed** → Escalate to Chief InfoSec Officer + Legal immediately
- **More than 50% of Floor 6 unable to log in** → Consider suspending further deployments to that floor
- **Performance is worse than 10 minutes login time** → Investigate for potential malware/ransomware
- **Multiple users report unauthorized data access** → Treat as active security incident; consider containment (network isolation)

