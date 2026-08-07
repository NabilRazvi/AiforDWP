# KB: AVD Black Screen Post-Login Diagnosis and Fix (POOL-FIN-01)

## Version Header
- Version: v 1.0
- Date: 07/08/2026
- Status: Draft

## Author
Nabil Razvi

## Background
Finance users access line-of-business apps through Azure Virtual Desktop (AVD). If desktop rendering fails after sign-in, users cannot reach finance systems at start of day, causing high business impact. This KB explains how to diagnose and resolve the specific incident pattern where only one finance pool fails while a peer pool remains healthy.

## Symptom
Engineer observes:
- Spike in tickets reporting black screen immediately after successful sign-in.
- Some users recover after about 30 seconds; others enter repeated disconnect/reconnect loop.
- Affected users are concentrated on POOL-FIN-01.
- POOL-FIN-02 remains usable.

User reports:
- "I can sign in, but I only see a black screen."
- "It disconnects and reconnects repeatedly."

## Root Cause
Specific technical cause:
- Overnight update at 02:00 on POOL-FIN-01 introduced Intel user-mode graphics component igdumd64.dll version 31.0.101.4146.
- Desktop Window Manager process dwm.exe crashes with Event ID 1000 (Application Error), exception code 0xc0000005.
- Session then disconnects with TerminalServices Event ID 40.

Evidence confirming cause:
- POOL-FIN-01: repeated Event ID 1000 (dwm.exe faulting module igdumd64.dll) plus Event ID 9009 (DWM exited).
- POOL-FIN-02: Event ID 9011 (DWM started successfully) and no matching Event ID 1000/9009 during same window.

## Detection
Run this 3-minute check before any fix. Use one affected host from POOL-FIN-01 (example: SHFIN-01-A) and one unaffected host from POOL-FIN-02 (example: SHFIN-02-A).

1. Open Event Viewer on SHFIN-01-A.
Log location: Event Viewer > Windows Logs > Application.
Event ID to search: 1000.
Fields to confirm in event details: Faulting application name = dwm.exe, Faulting module name = igdumd64.dll, Exception code = 0xc0000005.
Expected result: one or more Event 1000 entries match all fields above.

2. Open Event Viewer on SHFIN-01-A.
Log location: Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational.
Event ID to search: 9009.
Fields to confirm in event details: EventID = 9009, TimeCreated within about 60 seconds of Event 1000 on same host.
Expected result: Event 9009 appears immediately after or near Event 1000 times.

3. Open Event Viewer on SHFIN-02-A (healthy control).
Log location: Event Viewer > Applications and Services Logs > Microsoft > Windows > Desktop Window Manager > Operational.
Event ID to search: 9011.
Fields to confirm in event details: EventID = 9011, recent successful start events in incident window.
Expected result: Event 9011 exists on POOL-FIN-02 and there are no matching Event 1000 (dwm.exe + igdumd64.dll) and no Event 9009 in the same window.

4. Run this PowerShell command on SHFIN-01-A to pull Application log crash evidence quickly.
Log location queried by command: Application log.
```powershell
$start = (Get-Date).AddHours(-4)
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=$start} |
Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' } |
Select-Object TimeCreated, MachineName, Id, LevelDisplayName, Message
```
Expected result: output contains Event ID 1000 rows showing dwm.exe and igdumd64.dll.

5. Run this PowerShell command on SHFIN-01-A to pull DWM exit evidence quickly.
Log location queried by command: Microsoft-Windows-Desktop Window Manager/Operational.
```powershell
$start = (Get-Date).AddHours(-4)
Get-WinEvent -FilterHashtable @{
	LogName='Microsoft-Windows-Desktop Window Manager/Operational';
	Id=9009;
	StartTime=$start
} | Select-Object TimeCreated, MachineName, Id, Message
```
Expected result: output contains Event ID 9009 rows in the same timeframe as Step 4.

6. Run this PowerShell command on SHFIN-02-A to confirm healthy baseline control.
Log locations queried by command: Application log and Microsoft-Windows-Desktop Window Manager/Operational.
```powershell
$start = (Get-Date).AddHours(-4)
$crash1000 = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=$start} |
	Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' }
$dwm9009 = Get-WinEvent -FilterHashtable @{
	LogName='Microsoft-Windows-Desktop Window Manager/Operational';
	Id=9009;
	StartTime=$start
}
$dwm9011 = Get-WinEvent -FilterHashtable @{
	LogName='Microsoft-Windows-Desktop Window Manager/Operational';
	Id=9011;
	StartTime=$start
}
[pscustomobject]@{
	Host = $env:COMPUTERNAME
	Crash1000_Dwm_Igdumd64 = $crash1000.Count
	DwmExit9009 = $dwm9009.Count
	DwmStart9011 = $dwm9011.Count
}
```
Expected result: on POOL-FIN-02 host, Crash1000_Dwm_Igdumd64 = 0, DwmExit9009 = 0, DwmStart9011 is greater than 0.

Detection decision:
- Confirm this incident only when all are true: POOL-FIN-01 has Event 1000 (dwm.exe + igdumd64.dll) and Event 9009; POOL-FIN-02 shows Event 9011 as healthy control with zero matching Event 1000 and zero Event 9009.

## Resolution
Perform in order. Use Portal path or CLI path.

1. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts.
Action: open the Session hosts grid and confirm host names are visible.
Expected result: all POOL-FIN-01 hosts are listed with current Status and Allow new sessions values.

2. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select all hosts > Set drain mode.
Action: set Allow new sessions = No for every host.
CLI fast path:
```bash
az extension add --name desktopvirtualization
az desktopvirtualization session-host list --resource-group <rg> --host-pool-name POOL-FIN-01 --query "[].name" -o tsv
for h in $(az desktopvirtualization session-host list --resource-group <rg> --host-pool-name POOL-FIN-01 --query "[].name" -o tsv); do
	az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name "$h" --allow-new-session false
done
```
Expected result: Allow new sessions shows No for every host in POOL-FIN-01.
Permission: Elevated required.

3. Azure Portal path: Azure Portal > Azure Virtual Desktop > Application groups > <finance-desktop-appgroup-POOL-FIN-02> > Assignments > Add.
Action: add impacted finance user groups to the POOL-FIN-02 desktop application group.
CLI fast path:
```bash
APP_GROUP_ID=$(az desktopvirtualization application-group show --resource-group <rg> --name <finance-desktop-appgroup-POOL-FIN-02> --query id -o tsv)
az role assignment create --assignee-object-id <finance-group-object-id> --assignee-principal-type Group --role "Desktop Virtualization User" --scope "$APP_GROUP_ID"
```
Expected result: impacted groups appear in Assignments for the POOL-FIN-02 app group.
Permission: Elevated required.

4. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Properties > Session host configuration > Image.
Action: select known-good image version (example: build-20240313) and click Save.
CLI fast path:
```bash
az desktopvirtualization hostpool update \
	--resource-group <rg> \
	--name POOL-FIN-01 \
	--vm-template @known-good-vmtemplate.json
```
Expected result: host pool Properties shows the selected known-good image configuration.
Permission: Elevated required.

5. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select all hosts > Recreate.
Action: trigger recreate/reimage for all selected hosts.
CLI fast path:
```bash
for vm in <fin01-vm-name-1> <fin01-vm-name-2> <fin01-vm-name-3>; do
  az vm reimage --resource-group <sessionhost-vm-rg> --name "$vm" --no-wait
done
```
Expected result: each host enters update/recreate workflow and later returns to Available.
Permission: Elevated required.

6. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts.
Action: refresh until every host shows Status = Available and Allow new sessions = No.
CLI fast path:
```bash
az desktopvirtualization session-host list --resource-group <rg> --host-pool-name POOL-FIN-01 --query "[].{Host:name,Status:status,AllowNew:allowNewSession}" -o table
```
Expected result: no host is in Unavailable, NeedsAssistance, or Failed state.

7. Azure client path: Remote Desktop client > Workspace feed > Finance desktop.
Action: perform one test sign-in to POOL-FIN-01.
Expected result: desktop loads in under 30 seconds with no reconnect loop.

8. Azure Portal path: Azure Portal > Monitor > Logs > <AVD-Log-Analytics-Workspace>.
Action: run post-fix query for test host and last 10 minutes.
CLI fast path:
```bash
az monitor log-analytics query -w <workspace-id> --analytics-query "Event | where TimeGenerated >= ago(10m) | where Computer == '<tested-host>' | where Source == 'Application Error' and EventID == 1000 and RenderedDescription has 'dwm.exe' and RenderedDescription has 'igdumd64.dll' | summarize CrashCount=count()"
```
Expected result: CrashCount = 0 for tested host.

9. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select all hosts > Set drain mode.
Action: set Allow new sessions = Yes for every host.
CLI fast path:
```bash
for h in $(az desktopvirtualization session-host list --resource-group <rg> --host-pool-name POOL-FIN-01 --query "[].name" -o tsv); do
	az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name "$h" --allow-new-session true
done
```
Expected result: Allow new sessions shows Yes for every POOL-FIN-01 host.
Permission: Elevated required.

## Verification
1. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions.
Action: filter Start time to the last 30 minutes and count active sessions.
Expected result: at least 3 active sessions started after fix, with no rapid disconnect/reconnect pattern.

2. Azure Portal path: Azure Portal > Monitor > Logs > <AVD-Log-Analytics-Workspace>.
Action: run 30-minute crash-signature query on POOL-FIN-01.
```kusto
Event
| where TimeGenerated >= ago(30m)
| where Source == "Application Error"
| where EventID == 1000
| where RenderedDescription has "dwm.exe" and RenderedDescription has "igdumd64.dll"
| where Computer startswith "SHFIN-01"
| summarize CrashCount=count()
```
CLI fast path:
```bash
az monitor log-analytics query -w <workspace-id> --analytics-query "Event | where TimeGenerated >= ago(30m) | where Source == 'Application Error' and EventID == 1000 and RenderedDescription has 'dwm.exe' and RenderedDescription has 'igdumd64.dll' | where Computer startswith 'SHFIN-01' | summarize CrashCount=count()"
```
Expected result: CrashCount = 0.

3. Azure Portal path: Azure Portal > Monitor > Logs > <AVD-Log-Analytics-Workspace>.
Action: run 30-minute DWM start query on POOL-FIN-01.
```kusto
Event
| where TimeGenerated >= ago(30m)
| where Source has "Desktop Window Manager"
| where EventID == 9011
| where Computer startswith "SHFIN-01"
| summarize DwmStartCount=count() by Computer
```
CLI fast path:
```bash
az monitor log-analytics query -w <workspace-id> --analytics-query "Event | where TimeGenerated >= ago(30m) | where Source has 'Desktop Window Manager' and EventID == 9011 | where Computer startswith 'SHFIN-01' | summarize DwmStartCount=count() by Computer"
```
Expected result: each active POOL-FIN-01 host sampled shows DwmStartCount >= 1.

4. Azure Portal path: Azure Portal > Monitor > Logs > <AVD-Log-Analytics-Workspace>.
Action: run pool comparison control check.
```kusto
let fin01Crash = Event
| where TimeGenerated >= ago(30m)
| where Source == "Application Error" and EventID == 1000
| where RenderedDescription has "dwm.exe" and RenderedDescription has "igdumd64.dll"
| where Computer startswith "SHFIN-01"
| summarize Count=count() by Metric="FIN01_Crash1000";
let fin02Crash = Event
| where TimeGenerated >= ago(30m)
| where Source == "Application Error" and EventID == 1000
| where RenderedDescription has "dwm.exe" and RenderedDescription has "igdumd64.dll"
| where Computer startswith "SHFIN-02"
| summarize Count=count() by Metric="FIN02_Crash1000";
let fin02Start = Event
| where TimeGenerated >= ago(30m)
| where Source has "Desktop Window Manager" and EventID == 9011
| where Computer startswith "SHFIN-02"
| summarize Count=count() by Metric="FIN02_Start9011";
fin01Crash | union fin02Crash | union fin02Start
```
Expected result: FIN01_Crash1000 = 0, FIN02_Crash1000 = 0, FIN02_Start9011 > 0.

5. Ticketing console path: Finance EUC queue > Created time = Last 30 minutes > keyword = black screen.
Action: check for recurrence.
Expected result: zero new incidents matching same symptom.

## Rollback
Use if user impact increases after applying fix.

1. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > select all hosts > Set drain mode.
Action: set Allow new sessions = No immediately.
CLI fast path:
```bash
for h in $(az desktopvirtualization session-host list --resource-group <rg> --host-pool-name POOL-FIN-01 --query "[].name" -o tsv); do
	az desktopvirtualization session-host update --resource-group <rg> --host-pool-name POOL-FIN-01 --name "$h" --allow-new-session false
done
```
Expected result: no new users route to POOL-FIN-01.
Permission: Elevated required.

2. Azure Portal path: Azure Portal > Azure Virtual Desktop > Application groups > <finance-desktop-appgroup-POOL-FIN-01> > Assignments.
Action: remove impacted user groups from FIN-01 app group.
CLI fast path:
```bash
APP_GROUP_ID=$(az desktopvirtualization application-group show --resource-group <rg> --name <finance-desktop-appgroup-POOL-FIN-01> --query id -o tsv)
az role assignment delete --assignee-object-id <finance-group-object-id> --role "Desktop Virtualization User" --scope "$APP_GROUP_ID"
```
Expected result: impacted users are no longer assigned to FIN-01 desktop app group.
Permission: Elevated required.

3. Azure Portal path: Azure Portal > Azure Virtual Desktop > Application groups > <finance-desktop-appgroup-POOL-FIN-02> > Assignments > Add.
Action: add impacted user groups to FIN-02 app group.
CLI fast path:
```bash
APP_GROUP_ID=$(az desktopvirtualization application-group show --resource-group <rg> --name <finance-desktop-appgroup-POOL-FIN-02> --query id -o tsv)
az role assignment create --assignee-object-id <finance-group-object-id> --assignee-principal-type Group --role "Desktop Virtualization User" --scope "$APP_GROUP_ID"
```
Expected result: new user sign-ins route to POOL-FIN-02.
Permission: Elevated required.

4. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Properties > Session host configuration > Image.
Action: if the failure started after changing image settings, switch Image back to the previous known-good version and click Save.
CLI fast path:
```bash
az desktopvirtualization hostpool update \
	--resource-group <rg> \
	--name POOL-FIN-01 \
	--vm-template @previous-known-good-vmtemplate.json
```
Expected result: POOL-FIN-01 shows previous image configuration in Properties.
Permission: Elevated required.

5. Azure Portal path: Azure Portal > Azure Virtual Desktop > Host pools > POOL-FIN-02 > User sessions.
Action: refresh for 2 minutes and confirm at least one impacted user session is Active.
Expected result: at least one impacted user is connected on POOL-FIN-02.

6. Azure Portal path: Azure Portal > Monitor > Activity log > Filter by Resource group <rg> and Last 30 minutes.
Action: export operations and post ROLLBACK ACTIVATED with UTC timestamp in incident ticket.
CLI fast path:
```bash
az monitor activity-log list --resource-group <rg> --offset 30m -o table
```
Expected result: rollback actions are captured in both Activity Log and incident timeline.

## Preventive
Implement all controls below. Do not remove controls from change governance.

1. Mandatory pre-deployment smoke-test gate.
Owner: Release engineer. Timing: Before deployment. Method: Automated [REQUIRES: CI pipeline gate + synthetic AVD login test].
Pass/Fail signal: Event ID 9011 >= 1 within 60 seconds and Event ID 1000 (dwm.exe + igdumd64.dll) = 0 on canary host; fail blocks release promotion.
If fail: change manager sets status to Failed Gate, image owner fixes build, new build required before CAB resubmission.

2. Staged rollout control by pool.
Owner: Change manager. Timing: During deployment. Method: Manual with log query evidence.
Pass/Fail signal: first pool 2-hour window must show Event ID 1000 count = 0 and Service Desk black-screen tickets = 0 before next pool.
If fail: stop rollout immediately, keep remaining pools unchanged, execute rollback section and raise Major Incident bridge.

3. Approved graphics version allow-list enforcement.
Owner: Image owner. Timing: Before deployment. Method: Automated [REQUIRES: image manifest validation in build pipeline].
Pass/Fail signal: build artifact must match approved GPU package list by VM SKU; any mismatch returns pipeline failure.
If fail: build is rejected, no image publication to gallery, release engineer notified in pipeline output.

4. In-flight monitoring alert during rollout window.
Owner: DWP engineer. Timing: During deployment. Method: Automated [REQUIRES: Azure Monitor alert + Action Group + Automation Account].
Pass/Fail signal: alert fires if Event ID 9009 occurs on >1 host in 5 minutes in same pool or Event ID 1000 signature count >= 2 in 5 minutes.
If fail: automation sets Allow new sessions = No on impacted pool, posts on-call alert, and creates incident with alert payload.

5. Quarterly rollback drill with timed objective.
Owner: Service desk lead. Timing: After deployment readiness cycle (quarterly). Method: Manual.
Pass/Fail signal: drill completes drain + redirect + evidence capture in <= 3 minutes; all timestamps recorded in drill ticket.
If fail: runbook update required within 5 business days and retraining session scheduled for on-call rotation.

6. Post-deployment validation gate before change closure.
Owner: DWP engineer. Timing: After deployment. Method: Manual (can be automated via workbook).
Pass/Fail signal: 30-minute check shows POOL-FIN-01 Event ID 1000 count = 0, Event ID 9011 count >= 1 per active host, new black-screen tickets = 0.
If fail: keep change open, revert via rollback, and do not mark CAB implementation successful.

7. Explicit rollback trigger threshold.
Owner: Change manager. Timing: During and after deployment. Method: Manual trigger with optional automation.
Pass/Fail signal: if any of these occur, rollback is mandatory: 2+ users impacted in 10 minutes, Event ID 1000 signature >= 2 in 5 minutes, or repeated reconnect loop on test account.
If fail threshold met: declare ROLLBACK ACTIVATED, apply rollback steps 1-6 immediately, notify bridge within 5 minutes.

8. Knowledge and checklist update control.
Owner: Image owner. Timing: After deployment/incident closure. Method: Manual [REQUIRES: KB governance checklist].
Pass/Fail signal: runbook, L1 KB, and release checklist updated with incident learnings and approved within 3 business days.
If fail: next similar change is blocked in CAB until documentation delta is completed and linked in ticket.

## Related
- Primary RCA: Day4/rca-avd-black-screen-pool-fin-01-2026-08-06.md
- Operational runbook: Day5/runbook-avd-black-screen-post-login-pool-fin-01.md
- End-user article: Day5/kb-l1-black-screen-after-sign-in-self-service.md
- Related pattern reference: Day2/triage-summary-avd-session-disconnects-after-10-min-then-reconnects.md
