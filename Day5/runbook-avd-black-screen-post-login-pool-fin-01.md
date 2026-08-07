# Runbook: AVD Black Screen Post-Login — POOL-FIN-01

## Version Header

- Title: Runbook: AVD Black Screen Post-Login — POOL-FIN-01
- Version: 1.0
- Date: 07/08/2026
- Author: NabilRazvi
- Reviewed: self
- Status: draft
- Change: initial version from RCA

## 1. Prerequisites

Complete every prerequisite before starting the procedure.

1. Confirm you are handling incident type: users can authenticate to AVD but see a black screen after login or enter disconnect/reconnect loop.
Expected result: Incident pattern matches this runbook scope.

2. Obtain Azure RBAC on subscription/resource group containing host pools `POOL-FIN-01` and `POOL-FIN-02` (minimum: Virtual Desktop Contributor).
Expected result: You can open both host pools and change session host drain mode.
Permission: Elevated required.

3. Obtain permission to update host pool image references and reimage session hosts (via Azure portal or approved automation account).
Expected result: You can change image version used by `POOL-FIN-01` and trigger reimage.
Permission: Elevated required.

4. Obtain read access to Log Analytics workspace or Event Viewer on at least one `POOL-FIN-01` session host and one `POOL-FIN-02` session host.
Expected result: You can query event IDs 1000, 9009, 9011, 21, and 40.
Permission: Elevated required.

5. Confirm your incident bridge has one business approver from Finance for user-impact decisions (drain and redirect).
Expected result: Named approver is present in ticket notes.

6. Open tools: Azure Portal, AVD blade, Log Analytics (or Event Viewer), and incident ticket system.
Expected result: All consoles are open and authenticated.

7. Record rollback target image version from last known good build (example from incident: `build-20240313`).
Expected result: Exact previous image version ID is documented in ticket before any change.

---

## 2. Procedure

Follow steps in order. Each step is one concrete action.

1. In Azure Portal, go to `Azure Virtual Desktop` -> `Host pools` -> `POOL-FIN-01` -> `Session hosts`.
Expected result: `Session hosts` grid loads and lists all `POOL-FIN-01` hosts.

2. For each host listed in `POOL-FIN-01` -> `Session hosts`, select the host and set `Allow new sessions` to `No`.
Expected result: `Allow new sessions` column shows `No` for every `POOL-FIN-01` host.
Permission: Elevated required.

3. In Azure Portal, go to `Azure Virtual Desktop` -> `Application groups` -> finance desktop app group mapped to `POOL-FIN-02` -> `Assignments`, then confirm impacted user groups are assigned.
Expected result: Impacted Finance user groups appear in `Assignments` for the `POOL-FIN-02` desktop app group.
Permission: Elevated required.

4. In Azure Portal, go to `Monitor` -> `Logs` (Log Analytics workspace for AVD), run the query below, and set the time range to the incident window.
Expected result: Query returns one or more rows from `POOL-FIN-01` hosts where `dwm.exe` faulted in `igdumd64.dll` with Event ID `1000`.
```kusto
Event
| where Source == "Application Error"
| where EventID == 1000
| where RenderedDescription has "dwm.exe" and RenderedDescription has "igdumd64.dll"
| where Computer startswith "SHFIN-01"
| project TimeGenerated, Computer, RenderedDescription
```

5. In the same `Monitor` -> `Logs` page, run the query below for the same time range.
Expected result: Query returns Event ID `9009` on the same `POOL-FIN-01` hosts within one minute after the Event ID `1000` times.
```kusto
Event
| where Source has "Desktop Window Manager"
| where EventID == 9009
| where Computer startswith "SHFIN-01"
| project TimeGenerated, Computer, RenderedDescription
```

6. In the same `Monitor` -> `Logs` page, run the query below for `POOL-FIN-02` hosts.
Expected result: Query returns Event ID `9011` rows and returns zero rows for Event ID `1000` with `dwm.exe` and `igdumd64.dll` on `POOL-FIN-02` hosts.
```kusto
let fin02dwmStart = Event
| where Source has "Desktop Window Manager"
| where EventID == 9011
| where Computer startswith "SHFIN-02";
let fin02dwmCrash = Event
| where Source == "Application Error"
| where EventID == 1000
| where RenderedDescription has "dwm.exe" and RenderedDescription has "igdumd64.dll"
| where Computer startswith "SHFIN-02";
fin02dwmStart
| project Signal="DWM_START", TimeGenerated, Computer, RenderedDescription
| union (fin02dwmCrash | project Signal="DWM_CRASH", TimeGenerated, Computer, RenderedDescription)
| order by TimeGenerated asc
```

7. In Azure Portal, go to `Azure Virtual Desktop` -> `Host pools` -> `POOL-FIN-01` -> `Properties` and set `Image` to the recorded last known good image version.
Expected result: `Properties` page displays the selected previous stable image version after saving.
Permission: Elevated required.

8. In Azure Portal, go to `POOL-FIN-01` -> `Session hosts`, select all hosts, and run `Recreate` (or `Reimage`) from the toolbar.
Expected result: Each selected host shows a provisioning/update operation started in `Session hosts` and Azure `Notifications`.
Permission: Elevated required.

9. In Azure Portal, stay on `POOL-FIN-01` -> `Session hosts` and refresh until each host reports `Status = Available` and `Allow new sessions = No`.
Expected result: Zero hosts show `Unavailable`, `Updating`, or `Failed`.

10. Launch the Finance AVD desktop feed as a test account and start one new session that lands on a `POOL-FIN-01` host.
Expected result: Full desktop appears within 30 seconds with no black screen and no immediate disconnect.

11. In `Monitor` -> `Logs`, run the query below for the tested `POOL-FIN-01` host and test-login time.
Expected result: At least one Event ID `9011` row exists after the test login timestamp.
```kusto
Event
| where Source has "Desktop Window Manager"
| where EventID == 9011
| where Computer == "<tested-host-name>"
| where TimeGenerated >= ago(30m)
| project TimeGenerated, Computer, RenderedDescription
```

12. In `Monitor` -> `Logs`, run the query below for the same tested host and 10-minute post-login window.
Expected result: Query returns zero rows.
```kusto
Event
| where Source == "Application Error"
| where EventID == 1000
| where RenderedDescription has "dwm.exe" and RenderedDescription has "igdumd64.dll"
| where Computer == "<tested-host-name>"
| where TimeGenerated >= ago(10m)
| project TimeGenerated, Computer, RenderedDescription
```

13. In Azure Portal, go to `POOL-FIN-01` -> `Session hosts`, select all hosts, and set `Allow new sessions` to `Yes`.
Expected result: `Allow new sessions` column shows `Yes` for every `POOL-FIN-01` host.
Permission: Elevated required.

14. In Azure Portal, go to the finance desktop app group on `POOL-FIN-01` -> `Assignments`, then restore standard assignment groups if they were temporarily removed.
Expected result: Assignment membership matches pre-incident baseline documented in the ticket.
Permission: Elevated required.

15. In the incident ticket, paste the executed log queries, include screenshots of `Session hosts` status, and record image version before/after with UTC timestamps.
Expected result: Ticket contains reproducible evidence for each remediation action.

---

## 3. Verification

Complete all checks before closure.

1. In Azure Portal, go to `Azure Virtual Desktop` -> `Host pools` -> `POOL-FIN-01` -> `User sessions` and refresh after three controlled test logins.
Expected result: `User sessions` shows three active sessions started within the validation window and none in rapid reconnect state.

2. In `Monitor` -> `Logs`, run the query below with time range `Last 30 minutes`.
Expected result: Query returns `0` as `CrashCount`.
```kusto
Event
| where Source == "Application Error"
| where EventID == 1000
| where RenderedDescription has "dwm.exe" and RenderedDescription has "igdumd64.dll"
| where Computer startswith "SHFIN-01"
| summarize CrashCount = count()
```

3. In `Monitor` -> `Logs`, run the query below with time range `Last 30 minutes`.
Expected result: Query returns at least one Event ID `9011` per sampled `POOL-FIN-01` host that accepted a validation login.
```kusto
Event
| where Source has "Desktop Window Manager"
| where EventID == 9011
| where Computer startswith "SHFIN-01"
| summarize DwmStartCount=count() by Computer
```

4. In the ticketing console, filter for queue `Finance EUC` and keyword `black screen` with created time `Last 30 minutes`.
Expected result: Filter returns zero new incidents linked to `POOL-FIN-01` black-screen symptoms.

5. In the incident ticket activity log, add a closure-approval note and tag the Finance approver for explicit acknowledgement.
Expected result: Approver reply is present in ticket activity and states service is restored.

Closure criterion: Close incident only when all five verification checks pass.

---

## 4. Rollback

Use this section only when the active fix causes worse impact. Complete Steps 1-6 in under 3 minutes to contain user impact.

1. In Azure Portal, go to `Azure Virtual Desktop` -> `Host pools` -> `POOL-FIN-01` -> `Session hosts`.
Expected result: `Session hosts` grid is visible for `POOL-FIN-01`.

2. In `POOL-FIN-01` -> `Session hosts`, select all hosts and set `Allow new sessions` to `No`.
Expected result: `Allow new sessions` column shows `No` for every `POOL-FIN-01` host.
Permission: Elevated required.

3. In Azure Portal, go to `Azure Virtual Desktop` -> `Application groups` -> finance desktop app group on `POOL-FIN-01` -> `Assignments`, then remove the impacted Finance user groups from this app group.
Expected result: No emergency assignment remains that routes new users to `POOL-FIN-01`.
Permission: Elevated required.

4. In Azure Portal, go to `Azure Virtual Desktop` -> `Application groups` -> finance desktop app group on `POOL-FIN-02` -> `Assignments`, then add impacted user groups.
Expected result: Impacted user groups are assigned to `POOL-FIN-02` desktop app group.
Permission: Elevated required.

5. In Azure Portal, go to `Azure Virtual Desktop` -> `Host pools` -> `POOL-FIN-01` -> `User sessions`, then sign out only sessions that are in reconnect loop state.
Expected result: Reconnect-loop sessions disappear from `User sessions` within one refresh cycle.
Permission: Elevated required.

6. In Azure Portal, go to `Azure Virtual Desktop` -> `Host pools` -> `POOL-FIN-02` -> `User sessions`, then confirm at least one new impacted user session appears within 2 minutes.
Expected result: At least one impacted user is actively connected on `POOL-FIN-02`, confirming rollback routing is effective.

7. In the incident ticket, post `ROLLBACK ACTIVATED` with UTC timestamp and attach screenshots of `POOL-FIN-01` drain state and `POOL-FIN-02` active user sessions.
Expected result: Incident timeline contains auditable evidence of rollback activation.

8. In Azure Portal, go to `Monitor` -> `Activity log`, filter `Resource group` for AVD resources and time `Last 30 minutes`, then export entries.
Expected result: Export file contains the exact rollback operations performed.

9. Escalate to platform engineering with the activity-log export and summary: `POOL-FIN-01 drained, user routing forced to POOL-FIN-02`.
Expected result: Ownership of deep remediation is accepted while service remains stable for users.

---

## 5. Notes

- Warning: Do not remove drain mode on `POOL-FIN-01` until Verification Section 3 checks are complete and passed.
- Warning: Do not run parallel image experiments on both finance pools at the same time; keep one clean comparison pool available.
- Edge case: If both pools are already on the same image version, use host-level driver/package inventory to identify drift before changing routing.
- Edge case: If Event 1000 exists but module is not `igdumd64.dll`, stop this runbook and use the generic AVD black-screen triage path.
- Edge case: If users authenticate but are denied profile/container access, validate FSLogix separately; this runbook addresses DWM crash chain only.
- Related incident/RCA: `rca-avd-black-screen-pool-fin-01-2026-08-06.md`.
- Related operational guidance: staged rollout and DWM smoke-test gate should be treated as mandatory controls for all future image promotions.
