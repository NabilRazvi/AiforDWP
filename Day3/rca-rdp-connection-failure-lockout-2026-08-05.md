# Root Cause Analysis: RDP Connection Failure and Account Lockout (Windows 11)

## Incident Overview
An RCA was requested for an RDP connection failure followed by account lockout, using Windows System and Security Event Viewer logs from the incident window. After reviewing the supplied workspace evidence, no raw RDP-related System/Security event entries were available for analysis.

Because Event IDs, provider messages, timestamps, and event payload fields are absent, a definitive technical root cause cannot be established without assumption.

Confidence statement:
- High confidence that the evidence set is incomplete for this incident type.
- Low confidence for any specific technical attribution (credentials, protocol, network, or policy) due to missing logs.

## Evidence Summary
### Sources reviewed
- Day3 log files under Day3/logs (operational script logs, no raw incident events)
- Day3 event archive workspace under Day3/eventlog-work (no exported event files present)
- Existing incident write-ups in Day3 (analysis documents, not authoritative raw logs)

### What is explicitly present
- No raw Security log entries showing authentication events for this incident window.
- No raw System or Terminal Services event entries showing RDP protocol/connectivity states for this incident window.

### Missing data required for conclusive RCA
- Security events for account auth/lockout chain (for example logon failures/successes and lockout events)
- System/Terminal Services events for RDP transport/protocol/session negotiation
- Timestamps and source endpoint/IP correlation fields
- Event message text for each relevant Event ID

## Event ID Analysis
### Event IDs present in supplied logs
- None observable for this specific RDP incident.

### What each Event ID records and why it occurred
- Not determinable from supplied evidence because no event records were provided.

### Requested categorization by event type
- Connection attempts: Not evidenced.
- Authentication failures: Not evidenced.
- Protocol errors: Not evidenced.
- Account lockout events: Not evidenced.
- Successful recovery events: Not evidenced.

## Timeline of Events
Only evidence-backed milestones can be included.

1. 2026-08-05: Request submitted to analyze RDP failure + lockout from "below" System/Security logs.
2. 2026-08-05: Workspace evidence review completed.
3. 2026-08-05: No analyzable raw RDP incident events found in supplied logs.

Result: A full technical chronology of the incident cannot be reconstructed from current evidence.

## Mapping to RDP Authentication Process
A deterministic event-to-stage mapping requires concrete Event IDs and message payloads. With no raw events supplied, mapping is not possible.

Expected process stages (reference framework only, not incident findings):
1. Network reachability and RDP listener contact
2. TLS/CredSSP/NLA negotiation
3. Credential validation (Security log chain)
4. Session creation and desktop logon
5. Post-auth session establishment

Incident mapping status: No stages can be confirmed or rejected from provided evidence.

## Primary Issue Determination
Requested determination options:
- Incorrect credentials
- Account lockout policy enforcement
- RDP protocol issues
- Network interruption
- Combination of factors

Evidence-based outcome:
- Primary issue is indeterminate because no raw incident event records are available.

Confidence:
- High confidence in indeterminate outcome under current evidence constraints.

## Root Cause Assessment (Confidence-Rated)
### Most likely root cause
- Root cause cannot be determined from supplied logs.

### Supporting evidence
- No Security/System RDP event chain supplied for analysis.
- No event IDs, timestamps, protocol errors, or lockout confirmations are present.

### Confidence rating
- Root cause attribution confidence: Very low (insufficient telemetry).
- Evidence-gap finding confidence: High.

## Conflicting Information / Multi-Factor Considerations
No direct conflicting event evidence is available. Therefore:
- Multiple contributing causes cannot be confirmed or excluded.
- Combination-of-factors hypothesis remains untestable until logs are provided.

Confidence: High for limitation statement.

## Ranked Remediation Plan
Ranking below is operationally practical for rapid service restoration, but remains hypothesis-driven until logs are reviewed.

### Immediate Recovery Actions
1. Validate account state and unlock/reset as required
- Reason for action: Fastest path if lockout is blocking access.
- Verification method: Confirm account is unlocked; attempt sign-in; check for new auth failures.
- Success criteria: User authenticates successfully and no immediate repeat failures occur.
- Confidence: Low to Medium without incident events.

2. Test RDP with known-good credentials from known-good source
- Reason for action: Separates credential/account issues from host/network/protocol issues.
- Verification method: Controlled login test; capture exact event outputs during attempt.
- Success criteria: Successful RDP session establishment or reproducible failure with correlated events.
- Confidence: Medium as a diagnostic step.

3. Collect and preserve Security/System/TerminalServices events for the window
- Reason for action: Required to move from assumption to evidence-based RCA.
- Verification method: Export logs with full event payloads and timestamps.
- Success criteria: Complete event chain available for causality analysis.
- Confidence: High.

### Long-Term Preventive Actions
4. Standardize RDP incident intake checklist
- Reason for action: Prevents future RCAs with missing telemetry.
- Verification method: Ticket template includes mandatory fields (Event ID, provider, timestamp, source IP, username, logon type).
- Success criteria: Every RDP incident has minimum evidence pack attached.
- Confidence: High.

5. Add proactive alerting for repeated auth failures and lockout patterns
- Reason for action: Early detection before user-facing lockout outages.
- Verification method: Alerts trigger on failure thresholds and lockout events.
- Success criteria: Detection occurs before or at first lockout with actionable context.
- Confidence: Medium to High.

6. Validate RDP configuration baseline and access policy hygiene
- Reason for action: Reduces misconfiguration-driven access issues.
- Verification method: Periodic review of NLA/CredSSP policy, account lockout policy, and allowed groups.
- Success criteria: Baseline drift is detected and corrected before incident impact.
- Confidence: Medium.

## Corrective Actions
- Document evidence gap and prevent unsupported technical attribution.
- Request and capture authoritative event logs from incident window.
- Re-run RCA immediately after evidence capture and publish a definitive update.

## Preventive Actions
- Enforce mandatory evidence fields in incident workflow.
- Require event export attachment before final RCA approval for authentication/network incidents.
- Maintain an RDP-specific runbook linking event IDs to process stages.

## Business Impact
- User unable to access remote desktop service during incident period (reported scenario).
- Increased resolution time due to missing primary diagnostics.
- Risk of repeat disruption remains unquantified until event chain is analyzed.

Confidence: Medium for process impact, low for technical impact scope.

## 5-Why Analysis
Problem statement: Definitive RCA for RDP failure and lockout could not be completed.

1. Why could the RCA not be completed definitively?
- Required System/Security incident events were not supplied.

2. Why are those events required?
- They identify where the failure occurred in the auth/protocol sequence.

3. Why can the sequence not be inferred safely?
- Different causes can produce similar user symptoms (credentials, lockout policy, protocol, or network).

4. Why is this operationally risky?
- Assumption-based fixes can restore temporarily but miss true root cause.

5. Why did this become a process issue?
- Evidence collection for the incident did not include minimum telemetry needed for RCA.

## Findings to Cross-Check with Microsoft Documentation
The following should be validated against Microsoft documentation once raw events are supplied:
- Exact interpretation of each observed Event ID in Security/System/Terminal Services logs.
- Canonical mapping of those Event IDs to RDP authentication and session establishment stages.
- Official guidance for distinguishing NLA/CredSSP failures from credential and lockout conditions.
- Supported remediation precedence for mixed authentication and transport error patterns.

## Additional Data Needed to Increase Confidence
To produce a conclusive, high-confidence RCA, provide:
- Full text of all relevant Security events in incident window
- Full text of relevant System and Terminal Services events in same window
- Ordered timestamps and correlation fields (user, source address, target host)
- One known successful post-incident connection event set for comparison

## Final Root Cause Statement
Using only supplied logs, root cause is indeterminate because the required RDP-related System and Security Event Viewer records are not present in analyzable form.
