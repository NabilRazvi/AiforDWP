# Microsoft 365 Copilot Readiness Checklist — Finance Department
**Organisation:** DWP Financial Services  
**Department:** Finance (~200 users)  
**Prepared by:** DWP Engineer  
**Date:** 2026-08-12  
**Status:** Pre-deployment readiness review

---

> **Risk note:** This department holds payroll, board packs, M&A documents, and client financial data. SharePoint permissions were inherited from a 2019 migration and have never been formally audited. Oversharing and permissions remediation is therefore the **highest-priority workstream** in this checklist and must be completed — with sign-off — before Copilot licences are assigned. Copilot surfaces whatever the user can access; unresolved oversharing becomes an AI-amplified data exposure risk.

---

## SECTION 1 — Permissions & Oversharing Remediation ⚠️ HIGHEST PRIORITY

> Complete this section in full before progressing to any other section. Do not assign Copilot licences until Section 1 is signed off.

### 1.1 SharePoint Permissions Audit

- [ ] **Export a full permissions report** for all Finance SharePoint sites using the SharePoint Admin Centre or Microsoft 365 Assessment Tool (`Microsoft365DSC` or `SharePoint PnP PowerShell`).
- [ ] **Identify sites/libraries with "Everyone", "Everyone except external users", or broad AD group inheritance** — flag all occurrences for immediate remediation.
- [ ] **Review inherited permissions from the 2019 migration**: cross-reference current membership of any migrated AD groups against current Finance org chart. Remove stale accounts (leavers, movers, contractors).
- [ ] **Document unique permissions breaks**: ensure all libraries containing payroll, board packs, M&A materials, and client financial data use unique permissions — not inherited from parent site.
- [ ] **Remove or scope down any site collection administrator accounts** that are not actively required. Log and justify those that remain.
- [ ] **Check for externally shared links** (Anyone links, Specific people links to external domains) on Finance sites via SharePoint Admin → Sharing reports. Revoke any links not explicitly approved.
- [ ] **Validate that OneDrive personal drives** of Finance users do not contain sensitive shared files that should be stored in governed SharePoint libraries — move and re-govern if found.

### 1.2 Oversharing Controls

- [ ] **Enable SharePoint Advanced Management (SAM)** if not already active — use it to run a Data Access Governance (DAG) report scoped to Finance sites.
- [ ] **Run a SharePoint Content Assessment** to identify documents shared with >X users (agree threshold with CISO/Data Owner — suggested: >20 internal users for payroll/M&A content).
- [ ] **Restrict default sharing scope**: set Finance site collection sharing to "Only people in your organisation" as a minimum; apply "Specific people only" for sites holding board packs and M&A data.
- [ ] **Configure site-level sharing expiry**: enable expiry on shared links for Finance sites (recommended: 30 days maximum).
- [ ] **Disable re-sharing by non-owners** on all sensitive Finance libraries (Site Settings → Advanced Permissions Settings → uncheck "Allow members to share").
- [ ] **Review Microsoft 365 Groups and Teams membership** linked to Finance SharePoint sites — confirm all members are current, active Finance staff or explicitly approved.

### 1.3 Sign-off Gate

- [ ] Permissions audit findings documented and shared with Data Owner (Finance Director or CISO delegate).
- [ ] Remediation actions completed or risk-accepted in writing by Data Owner.
- [ ] **Signed-off evidence stored** (audit report + remediation log) before proceeding to Section 2.

---

## SECTION 2 — Licensing Prerequisites

- [ ] Confirm all ~200 Finance users hold a valid **Microsoft 365 E5** licence (or E3 + appropriate add-ons) — verify in M365 Admin Centre → Billing → Licences.
- [ ] Confirm **Microsoft 365 Copilot add-on licence** (or Microsoft Copilot for Microsoft 365) is procured for the Finance rollout cohort. Quantity: ___
- [ ] Create a dedicated **Azure AD / Entra ID security group** (e.g. `SG-Copilot-Finance-Pilot`) for staged licence assignment — do not bulk-assign to all 200 users in a single action.
- [ ] Assign Copilot licences to the pilot group only initially (suggested: 10–20 power users from Finance Ops, agreed with Finance lead).
- [ ] Confirm licence assignment propagation in the M365 Admin Centre before proceeding to enablement steps.

---

## SECTION 3 — Microsoft 365 Apps Client Version Requirements

- [ ] Verify all Finance endpoints are running **Microsoft 365 Apps Version 2302 (Build 16130.xxxxx) or later** — this is the minimum for Copilot in Word, Excel, PowerPoint, Outlook, and Teams.
  - Check via: Intune → Apps → Monitor → App install status, or run `winver`/`Get-AppLockerFileInformation` on sampled endpoints.
- [ ] Confirm update channel: Finance devices should be on **Current Channel** or **Monthly Enterprise Channel (MEC)**. Semi-Annual Channel will not receive Copilot features promptly.
- [ ] Ensure no Finance endpoints are pinned to a specific older build via Group Policy (`HKLM\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate`). Remove any build-pin that falls below the minimum.
- [ ] Confirm **Microsoft Teams desktop client** is on a build from 2023 or later — Teams Copilot features require the new Teams client (Teams 2.x). Verify new Teams has been deployed.
- [ ] Verify **Edge or Chrome** is deployed for Copilot in Microsoft 365 web experiences — check browser version requirements (Edge 109+ / Chrome 109+).

---

## SECTION 4 — Identity & MFA Readiness

- [ ] Confirm all 200 Finance users have **Azure AD / Entra ID accounts** (no on-prem-only accounts in scope).
- [ ] Verify **Azure AD Connect / Entra Connect sync** is healthy and Finance user accounts are synchronised and not stale.
- [ ] Confirm **Multi-Factor Authentication (MFA) is enforced** for all Finance users:
  - Preferred: Conditional Access policy targeting Finance group, requiring MFA for all cloud apps.
  - Verify no users are excluded from MFA via legacy per-user MFA exceptions or named location bypasses.
- [ ] Check for and remediate any Finance accounts still using **Basic Authentication** or legacy authentication protocols — block via Conditional Access if not already done.
- [ ] Confirm **no shared/generic accounts** are in scope for Copilot assignment (Copilot is a per-user licence; shared accounts present audit and data leakage risk).
- [ ] Verify **Privileged Identity Management (PIM)** or equivalent is in place for Finance users with elevated SharePoint or Exchange admin rights — these users must not use admin accounts for day-to-day Copilot activity.
- [ ] Confirm **Sign-in risk and user risk policies** (Entra ID Protection) are active and Finance is covered.

---

## SECTION 5 — Sensitivity Labelling

- [ ] Confirm **Microsoft Purview sensitivity labels** are configured in the tenant (Information Protection → Labels).
- [ ] Verify a label taxonomy appropriate for Finance data is in place — at minimum:
  - `Public`
  - `Internal`
  - `Confidential` (covers client financial data, general Finance documents)
  - `Highly Confidential` (covers payroll, board packs, M&A — should enforce encryption + restrict to named groups)
- [ ] Confirm **auto-labelling policies** are configured (or in simulation mode pending review) for Finance-relevant content types: payroll keywords, IBAN/sort code patterns, M&A project names.
- [ ] Verify **default labels** are applied to Finance SharePoint sites — site-level default labels ensure new content is labelled at creation.
- [ ] Confirm **label-based encryption** is enforced on `Highly Confidential` content — test that encrypted documents cannot be opened by users outside the defined Finance group.
- [ ] Validate that **Copilot will respect sensitivity labels**: Microsoft 365 Copilot honours sensitivity label permissions at query time — confirm this is understood by the Finance Data Owner and that label coverage is sufficient before go-live.
- [ ] Run a **Content Explorer** scan (Purview → Data Classification → Content Explorer) scoped to Finance sites to identify unlabelled or mislabelled sensitive content — remediate before Copilot is enabled.

---

## SECTION 6 — End-User Communications & Enablement

- [ ] Agree a **Copilot go-live date** with Finance lead and comms team — do not soft-launch without advance notice.
- [ ] Issue a **pre-launch communication** to Finance users (1–2 weeks before go-live) covering:
  - What Copilot is and what it can do in their M365 apps.
  - What Copilot **cannot** do (it will not access data they cannot already see — but they should treat AI-generated output as a draft requiring review).
  - Data handling expectations: remind users not to paste sensitive third-party data into Copilot prompts.
  - Signposting to the [DWP personal AI usage charter](../personal-ai-usage-charter-dwp-endpoint.md) — Finance users must read and acknowledge this.
- [ ] Deliver a **30-minute enablement session** for Finance users before or at go-live — cover practical use cases relevant to Finance: summarising long reports, drafting board pack narratives, generating Excel formula suggestions.
- [ ] Create a **Finance-specific Copilot prompt guide** (top 10 use cases: budget report summarisation, meeting recap, policy document Q&A, etc.) and distribute via Teams/SharePoint.
- [ ] Nominate **2–3 Finance Copilot Champions** who will act as first-line peer support and feedback collectors during the pilot period.
- [ ] Set up a **feedback channel** (Teams channel or Forms survey) to capture Finance user experience for the first 4 weeks post-launch.
- [ ] Schedule a **4-week post-launch review** with Finance lead, CISO rep, and DWP engineer to assess usage, data concerns raised, and readiness for full 200-user rollout.

---

## Sign-off Summary

| Section | Owner | Target Date | Signed Off |
|---|---|---|---|
| 1 — Permissions & Oversharing Remediation | DWP Engineer + Finance Data Owner | | ☐ |
| 2 — Licensing Prerequisites | M365 Admin / Procurement | | ☐ |
| 3 — M365 Apps Client Version | Endpoint / Intune Team | | ☐ |
| 4 — Identity & MFA | Identity / Security Team | | ☐ |
| 5 — Sensitivity Labelling | Information Governance / Purview Team | | ☐ |
| 6 — End-User Comms & Enablement | Finance Lead + Comms | | ☐ |

> **Go/No-Go decision:** Section 1 sign-off is a hard gate. All other sections should be complete or have documented risk acceptance before Copilot licences are assigned to production users.

---

*Document owner: DWP Engineer | Review cycle: Before each deployment phase | Classification: Internal*
