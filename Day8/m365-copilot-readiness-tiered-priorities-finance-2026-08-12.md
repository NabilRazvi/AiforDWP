# Microsoft 365 Copilot Readiness — Tiered Priority Ranking
**Organisation:** DWP Financial Services  
**Department:** Finance (~200 users)  
**Prepared by:** DWP Engineer  
**Date:** 2026-08-12  
**Source document:** [m365-copilot-readiness-checklist-finance-2026-08-12.md](m365-copilot-readiness-checklist-finance-2026-08-12.md)

---

> **Purpose of this document:** This tiering assessment takes every item from the Finance Copilot Readiness Checklist and ranks it into one of three deployment gates. It also provides a Finance-specific justification for why the permissions and oversharing audit is a hard blocker — ahead of items that are technically simpler to complete.

---

## Tier 1 — MUST Complete Before Rollout (Blocking)

> These items are hard gates. Copilot licences **must not** be assigned to Finance users until every item in this tier carries a documented sign-off. Proceeding without them creates legal, regulatory, or immediate data exposure risk.

### From Section 1 — Permissions & Oversharing Remediation

| # | Item | Blocking Reason |
|---|---|---|
| 1.1a | Export full permissions report for all Finance SharePoint sites | Cannot assess exposure without baseline inventory |
| 1.1b | Identify and remediate "Everyone" / broad AD group inheritance | Directly enables Copilot-amplified oversharing on day one |
| 1.1c | Review and remove stale accounts from 2019 migration groups | Departed users' data accessible via Copilot if not removed |
| 1.1d | Break inheritance on payroll, board packs, M&A, and client financial libraries | These document classes require unique permissions; Copilot will surface them to anyone with inherited access |
| 1.1e | Remove or scope down unnecessary site collection admins | Admin scope = unlimited Copilot data surface |
| 1.1f | Revoke unapproved external sharing links | External sharing + Copilot = potential exfiltration path |
| 1.2a | Enable SharePoint Advanced Management (SAM) and run DAG report | Required to quantify oversharing scope before go-live |
| 1.2c | Restrict default sharing scope to "Only people in your organisation" minimum | Prevents new Copilot-generated content being shared too broadly by default |
| 1.2e | Disable re-sharing by non-owners on sensitive Finance libraries | Prevents users forwarding Copilot outputs to unintended recipients |
| 1.3 | Permissions sign-off gate (Data Owner + CISO delegate sign-off, evidence stored) | Hard gate — no licence assignment without written sign-off |

### From Section 4 — Identity & MFA

| # | Item | Blocking Reason |
|---|---|---|
| 4.3 | MFA enforced for all Finance users via Conditional Access (no legacy exceptions) | Copilot access without MFA is an unauthenticated data exposure risk under NCSC and DWP policy |
| 4.4 | Block legacy authentication / Basic Auth for Finance accounts | Legacy auth bypasses Conditional Access; Copilot sessions must be fully governed |
| 4.5 | Confirm no shared or generic accounts are in scope | Copilot is per-user; shared accounts break audit trails and create uncontrolled data access |

### From Section 5 — Sensitivity Labelling

| # | Item | Blocking Reason |
|---|---|---|
| 5.2 | Label taxonomy in place including `Highly Confidential` for payroll, board packs, M&A | Copilot cannot respect protections that do not exist at query time |
| 5.5 | Label-based encryption enforced and tested for `Highly Confidential` content | Encryption is the last line of defence if Copilot surfaces a mislabelled document |
| 5.6 | Finance Data Owner briefed that Copilot honours sensitivity labels — and label coverage is confirmed sufficient | Misunderstanding of Copilot's label behaviour at go-live = unplanned data disclosure |

---

## Tier 2 — SHOULD Complete Before Rollout (High Risk if Skipped)

> These items do not constitute absolute blockers in every scenario, but skipping them creates a significant and foreseeable risk. Any item left incomplete at go-live must have a written risk acceptance from the appropriate owner before the rollout proceeds.

### From Section 1 — Permissions & Oversharing Remediation

| # | Item | Risk if Skipped |
|---|---|---|
| 1.1g | Audit OneDrive personal drives of Finance users for mis-stored sensitive files | Ungoverned OneDrive content is in-scope for Copilot; sensitive files outside SharePoint governance are invisible to the permissions audit |
| 1.2b | Run SharePoint Content Assessment to identify documents shared with >threshold users | Quantifies residual oversharing risk; without it, the audit is incomplete |
| 1.2d | Configure sharing link expiry on Finance sites (≤30 days) | Persistent links remain valid after Copilot is enabled; expiry limits the window |

### From Section 2 — Licensing

| # | Item | Risk if Skipped |
|---|---|---|
| 2.1 | Confirm all pilot users hold valid M365 E5 (or E3 + add-on) prerequisite licence | Without the base licence, Copilot will not activate — rollout fails silently or with confusing errors |
| 2.2 | Confirm Copilot add-on licence procured and quantity matches pilot cohort | Cannot assign licences that have not been purchased |
| 2.3 | Create dedicated Entra ID security group for staged licence assignment | Without a group, there is no mechanism for controlled rollout — risk of bulk accidental assignment |
| 2.4 | Assign licences to pilot group only (10–20 users); confirm propagation | Staged rollout is required by DWP policy; bulk assignment to 200 users bypasses change control |

### From Section 3 — M365 Apps Client Version

| # | Item | Risk if Skipped |
|---|---|---|
| 3.1 | Verify Finance endpoints on M365 Apps Version 2302+ | Copilot in-app features will not appear; users receive a degraded experience with no clear error |
| 3.2 | Confirm update channel is Current Channel or MEC (not Semi-Annual) | Semi-Annual Channel delays feature delivery; Finance pilot users will not see Copilot features on schedule |
| 3.3 | Remove Group Policy build pins below minimum version | GPO pins can silently prevent updates — endpoints appear compliant but are not |
| 3.4 | Confirm new Teams client (2.x) is deployed to Finance | Teams Copilot (meeting recap, chat summarisation) will not function on old Teams client |

### From Section 4 — Identity & MFA

| # | Item | Risk if Skipped |
|---|---|---|
| 4.1 | Confirm all Finance users have Entra ID accounts (no on-prem-only) | On-prem-only accounts cannot receive Copilot licences |
| 4.2 | Verify Entra Connect sync health for Finance accounts | Stale or unsynchronised accounts produce unpredictable Copilot behaviour |
| 4.6 | PIM or equivalent in place for Finance users with elevated admin rights | Admin accounts used for daily Copilot activity dramatically expand the data surface |
| 4.7 | Sign-in risk and user risk policies active and covering Finance | Compromised accounts with Copilot access = high-value target for data exfiltration |

### From Section 5 — Sensitivity Labelling

| # | Item | Risk if Skipped |
|---|---|---|
| 5.1 | Confirm Purview sensitivity labels are configured in tenant | If labels do not exist in the tenant, none of Section 5 is achievable |
| 5.3 | Auto-labelling policies configured (or in simulation with review date) | Unlabelled content created after go-live will not receive protection automatically |
| 5.4 | Default labels applied to Finance SharePoint sites | New documents created via Copilot will be unlabelled unless a site default is set |
| 5.7 | Content Explorer scan run; unlabelled/mislabelled sensitive content remediated | Unresolved mislabelling means Copilot can surface `Highly Confidential` content to users without the correct label-based restriction |

### From Section 6 — Comms & Enablement

| # | Item | Risk if Skipped |
|---|---|---|
| 6.1 | Go-live date agreed with Finance lead | Uncoordinated launch creates confusion and undermines trust in the rollout |
| 6.2 | Pre-launch communication issued to Finance users (inc. AI usage charter acknowledgement) | Users without briefing will misuse Copilot — most likely pasting sensitive third-party financial data into prompts |
| 6.3 | 30-minute enablement session delivered | Adoption will be low and user frustration high without basic enablement |

---

## Tier 3 — CAN Complete During or After Rollout (Lower Risk)

> These items are valuable but do not gate deployment. They can be completed in the weeks immediately following go-live, ideally before the 4-week post-launch review.

| # | Item | Notes |
|---|---|---|
| 3.5 | Verify Edge 109+ / Chrome 109+ on Finance endpoints | Web Copilot experiences degrade gracefully; most Finance users are likely on current builds already |
| 6.4 | Create Finance-specific Copilot prompt guide (top 10 use cases) | Enhances adoption; can be a living document updated based on pilot feedback |
| 6.5 | Nominate 2–3 Finance Copilot Champions | Peer support structure; can be established in week 1 post-launch |
| 6.6 | Set up feedback channel (Teams channel or Forms survey) | Should be ready at go-live but does not block launch |
| 6.7 | Schedule 4-week post-launch review | Schedule before launch; the review itself occurs post-launch by definition |
| 1.2b (residual) | Ongoing sharing threshold monitoring via SAM DAG reports | Initial run is Tier 1; recurring monitoring becomes an operational task post-launch |

---

## Finance-Specific Justification: Why Permissions & Oversharing is Tier 1 — Not Licensing or Client Version

Licensing verification (Section 2) and client version checks (Section 3) are operationally simpler tasks: they involve reading data from the M365 Admin Centre and Intune, confirming numbers match, and correcting them if not. They are also **reversible and fast to fix** — a missing licence can be assigned in minutes; an endpoint can be updated overnight via Intune. If either of these items is wrong, the consequence is that Copilot does not work for some users. That is a functional failure, not a data breach.

**The permissions and oversharing audit is different in kind, not just degree, for the following Finance-specific reasons:**

**1. Copilot is a data amplifier, not a data creator.**
Microsoft 365 Copilot operates entirely within the user's existing Microsoft Graph permissions. It does not add access — but it collapses the friction that normally limits how much of that access a user exercises in practice. A Finance analyst who technically has read access to a board pack folder they never knew existed will, after Copilot is enabled, be one natural-language query away from a summary of every document in it. Oversharing that was dormant becomes active on day one.

**2. The 2019 migration permissions have never been audited.**
This is a documented legacy risk specific to this Finance environment. Seven years of personnel changes — leavers, movers, contractors, team restructures — are almost certainly baked into AD groups whose memberships have never been formally reviewed. Those groups propagate inherited permissions across Finance SharePoint sites. Copilot will query across all of that inherited access simultaneously and without the user having to navigate folder structures. The blast radius of unaudited inherited permissions is not theoretical; it is a near-certainty.

**3. The data classes in Finance are in the highest regulatory and reputational risk category.**
Payroll data, board packs, M&A materials, and client financial data carry obligations under UK GDPR, FCA regulations, and DWP internal data classification policy. A Copilot-surfaced disclosure of payroll data to an unauthorised Finance user is not a minor misconfiguration — it is a reportable data breach. Licensing a Copilot add-on to a user on the wrong update channel is an inconvenience. Copilot surfacing a board pack to a user who should not see it during a live M&A process can constitute a market-sensitive information disclosure.

**4. The risk cannot be fixed retroactively once Copilot is enabled.**
If licensing is incomplete at go-live, the fix is to assign licences — no harm done. If a client version is wrong, the fix is to push an update — no harm done. If oversharing is discovered after Copilot has been live for two weeks, the harm has already occurred: Copilot has already answered queries using data users were not entitled to see, and those interactions are logged in Copilot interaction history. The permissions audit is the only item in the checklist where the **window to prevent harm closes at the moment Copilot is activated.** Every other item can be remediated after the fact with limited or no data risk. This one cannot.

**Conclusion:** Licensing and client version checks gate whether Copilot *works*. The permissions and oversharing audit gates whether Copilot can be *deployed safely*. In a Finance environment handling the data classes described here, safe deployment is the only deployment that is permissible.

---

## Tier Summary — Quick Reference

| Tier | Sections Primarily Drawn From | Gate Condition |
|---|---|---|
| **MUST — Blocking** | Section 1 (all), Section 4 (MFA/shared accounts), Section 5 (encryption + labelling) | Hard gate — no licence assignment without sign-off |
| **SHOULD — High Risk** | Section 2, Section 3, Section 4 (remainder), Section 5 (remainder), Section 6 (comms + enablement) | Risk acceptance required in writing if not completed |
| **CAN — Post-Launch** | Section 3 (browser), Section 6 (champions, feedback, review) | Complete within first 4 weeks; reviewed at post-launch checkpoint |

---

*Document owner: DWP Engineer | Related document: m365-copilot-readiness-checklist-finance-2026-08-12.md | Classification: Internal*
