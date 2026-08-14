# Copilot Security Escalation: Unauthorized Document Access in Search Results
**Date:** 2026-08-14 (Monday, 09:14 report received)  
**Severity:** HIGH — Unconfirmed data exposure signal requiring immediate verification  
**Reported By:** Floor 6 user (Legal department)  
**Issue Category:** Potential permissions bypass, indexing misconfiguration, or account compromise

---

## What This Report Actually Represents

A user reported viewing confidential client matter details in Microsoft 365 Copilot search results. The user states she has no documented business need to access this matter, yet Copilot surfaced it in response to a natural language query. This represents one of three risk categories:

1. **Real unauthorized access:** User permissions system (SharePoint ACL, security group, or app-level access control) has failed or been misconfigured, allowing inappropriate data surface
2. **Indexing/search tier vulnerability:** The new document management app deployed Friday afternoon (or Copilot indexing service) is crawling documents without respecting user permission boundaries
3. **Account compromise or token hijacking:** User's account may be compromised, or app may be indexing via elevated service account (e.g., admin context that sees all documents regardless of user permissions)

**Reported facts only:**
- User saw client matter in Copilot results
- User believes she should not have access
- Timing coincides with: Win11 migration (completed for Floor 6), Intune enrollment (recent), Document Management App deployment (Friday afternoon)
- No confirmation yet that user actually opened/downloaded the document vs. seeing it in search results only

---

## Why This Cannot Be Closed as "AI Weirdness" or Normal Support Bug

### Copilot Search Does Not Hallucinate Document Access
- Copilot search results are built from indexed documents in the organization's tenant
- Documents appear in Copilot results **only if the indexing layer has indexed them**
- Indexing respects user permissions: The indexing process should filter documents to show only those the user has read access to
- **If a document appears in a user's Copilot results, one of these is true:**
  - The user actually has read permissions (documented or misconfigured)
  - The indexing layer has a permissions bypass
  - The search results are being populated via compromised/elevated credentials
  - The document management app deployed Friday has introduced a new indexing vulnerability

### This Is Not a UX Bug or Misunderstanding
- User is reporting content *appearing in search*, not confusion about navigation
- User has sufficient domain knowledge (paralegal) to recognize confidential content and unauthorized access
- This is not a "where do I find X" question; it's "I saw restricted content I shouldn't have seen"

### Security Data Exposure Cannot Be Risk-Accepted as "Normal"
- If legitimate, this is a mis-provisioned permission (needs corrective action)
- If actual breach, every hour of delay allows continued unauthorized access and reduces forensic evidence window
- If it's an app vulnerability, it may affect other users on Floor 6 or beyond who haven't reported yet
- The floor is undergoing major infrastructure changes (Win11 migration, app deployment) — this is the highest-risk window for introduced vulnerabilities

---

## What Must NOT Be Done

| Action | Why Not |
|--------|---------|
| **Close ticket as "user confusion" without verification** | Closes investigation before evidence window; assumes user is wrong without proof |
| **Wait for additional reports before investigating** | Each hour of delay means more potential unauthorized access; other users may not report it |
| **Ask user to "just reset password" or restart machine** | Doesn't address the root cause; may destroy forensic evidence in app logs if user logs out |
| **Assume the document management app is the cause** | Premature conclusion without evidence; could be permission misconfiguration, compromised account, or SharePoint indexing issue |
| **Notify end user "this is a security incident"** before verification | Creates panic, potential data spillage via gossip, may cause user to delete evidence from local machines/cache |
| **Request user to screenshot the Copilot results** | User may be unable to reproduce, or may reveal sensitive content in screenshot; use system logs instead |
| **Ignore the Friday deployment as coincidental** | Document Management App deployment timing is directly relevant; must check its indexing service account permissions and indexing scope |
| **Conduct investigation in ticket comments** | Investigation details should stay in secure channels (InfoSec system), not in Help Desk ticketing system |

---

## Evidence That Must Be Preserved Immediately

**Critical (Preserve Before End of Day):**
- [ ] **Copilot query log** for the user: Exact query text, timestamp, and results returned (from Copilot audit logs / Microsoft 365 admin center > Search & Intelligence > Copilot interactions)
- [ ] **Copilot result metadata:** Which document was surfaced, URL, last indexed date, document path
- [ ] **User's Azure AD account sign-in logs** for past 48 hours: All sign-in events, MFA state, device IDs, IP locations, success/failure
- [ ] **User's OneDrive activity logs** for past 7 days: Access to legal/confidential document repositories (check if user actually *accessed* the document or only saw it in search)
- [ ] **Document Management App deployment logs:**
  - Service account used for indexing (check if it's a high-privilege account)
  - Indexing scope: Which document repositories did the app crawl?
  - Installation timestamp on Floor 6 machines
  - Any permission elevation or admin consent required during deployment
  - App's error logs for the past 48 hours
  
**Important (Preserve Within 2 Hours):**
- [ ] **Document's Access Control List (ACL)** as of Monday 09:00 AM: Exact list of users/groups with read access
- [ ] **User's Active Directory group memberships** as of Friday 4 PM (before app deployment) and Monday 09:00 AM: Check if new groups were added
- [ ] **Intune device configuration** applied to Floor 6 machines: Any policies related to data access, index filtering, or Copilot settings
- [ ] **Windows Search indexing logs** on at least one affected machine: Check if Windows Search indexed the document, and with what permissions context
- [ ] **Group Policy objects (GPOs)** applied to Floor 6 in past 72 hours: Check for any policy changes affecting permissions, indexing, or Copilot search filters
- [ ] **SharePoint site permission audit logs** for the document's parent site: Changes to permissions in past 7 days

**If App Suspected as Vector:**
- [ ] **App installation script/deployment package:** Examine for hardcoded permissions, service account elevation, or permission bypass logic
- [ ] **App's service account permissions:** What roles/groups does the app's indexing service account belong to? (If it's Global Admin or has "read all" permissions, this explains the breach)
- [ ] **App telemetry/diagnostic logs** from the indexing service: What documents were crawled, in what order, at what timestamp?

---

## Security/Privacy/Access Owners Who Must Receive This Escalation

| Role | Purpose | Team Name |
|------|---------|-----------|
| **Chief Information Security Officer (CISO) or InfoSec Lead** | Owns security incident response, account compromise investigation, threat analysis | NEED TO VERIFY: Exact team/title |
| **Chief Privacy Officer (CPO) or Data Protection Officer** | Owns confidentiality breach risk, regulatory notification requirements (especially if confidential client data is involved) | NEED TO VERIFY: Exact team/title |
| **Legal / Compliance / General Counsel** | Owns legal liability, client notification requirements, regulatory reporting obligations, attorney-client privilege risk | NEED TO VERIFY: Exact team/title |
| **Identity & Access Management (IAM) / Azure AD Admin** | Owns permission model verification, account compromise investigation, group membership audit | NEED TO VERIFY: Exact team/title |
| **SharePoint / Content Repository Owner** | Owns document permission ACLs, permission audit logs, permission reset if required | NEED TO VERIFY: Exact team/title |
| **Document Management App Owner / Procurement** | Owns app security posture, indexing configuration audit, vendor notification if vendor-supplied app | NEED TO VERIFY: Exact team/title |
| **Intune / Mobile Device Management Admin** | Owns device security policy audit, policy change investigation for Floor 6 machines | NEED TO VERIFY: Exact team/title |
| **Copilot Search/Index Administrator** | Owns Copilot indexing configuration, query audit logs, search permission filters | NEED TO VERIFY: Exact team/title |
| **Incident Commander (SOC/War Room Lead)** | Owns incident orchestration, communication, timeline, escalation | NEED TO VERIFY: Exact team/title |

---

## Escalation Statement

**Sentence 1 (Reported exposure & potential risk — no confirmed unauthorized access claim):**

A Floor 6 user reported viewing confidential client matter details in Copilot search results without documented authorization to access the matter, indicating a potential permissions bypass, indexing misconfiguration, account compromise, or service account elevation requiring immediate forensic verification.

**Sentence 2 (Immediate actions: access review, evidence preservation, scope, containment):**

Immediate actions required: secure Copilot query/result logs and user access logs for forensic review, verify the user's actual permission state on the document and the document management app's indexing service account privileges, assess scope by surveying other Floor 6 users for similar unauthorized data surface, and prepare containment measures including temporary indexing scope restriction pending permission audit.

---

## Next Steps (Assigned to InfoSec / Incident Commander)

1. **By 09:35 AM:** Retrieve Copilot query logs and confirm/refute whether document actually surfaced in results
2. **By 09:40 AM:** Pull user's permission ACL on document; compare against reported access level
3. **By 09:45 AM:** Begin document management app indexing service account privilege audit
4. **By 10:00 AM:** Escalation decision: Proceed to full incident response or close as misconfiguration/false report
5. **If confirmed:** Activate incident response protocol; notify Chief InfoSec Officer and General Counsel

---

## Incident Tracking
**Ticket ID:** NEED TO VERIFY  
**Assigned to:** NEED TO VERIFY (InfoSec Lead or Incident Commander)  
**Escalation Deadline:** Within 1 hour of report  
**Preserve Evidence Until:** NEED TO VERIFY (typically 90 days minimum for potential litigation)
