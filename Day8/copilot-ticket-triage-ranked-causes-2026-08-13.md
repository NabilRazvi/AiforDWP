# Copilot Ticket Triage - Ranked Causes (2026-08-13)

Scope: Ranked likely causes are restricted to this list only:
- permissions/access boundary
- data indexing lag
- sensitivity label restriction
- license/client prerequisite issue
- guest/external sharing limitation
- genuine Copilot fault (last resort)

## 1) Paralegal: Copilot cannot summarise client NDA in SharePoint ("I don't have access to that content")

Triage Summary: Paralegal NDA access-denied response in Copilot

Summary: Copilot returned an access denial for a SharePoint file in a folder the user has not opened before.

Impact: Single-user productivity impact; summary workflow blocked for NDA review.

Known facts:
- User is a paralegal.
- Prompt target is a client NDA in SharePoint.
- Copilot response: "I don't have access to that content."
- User states the file is in a folder she has never opened before and only heard about.

Missing information to gather:
- to-verify whether the user can open the exact NDA directly in SharePoint with current account.
- to-verify if the file/folder has unique permissions.
- to-verify if any sensitivity label on the NDA restricts Copilot processing.

Likely cause (ranked):
1. permissions/access boundary
2. sensitivity label restriction
3. data indexing lag
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Open the exact NDA link as the user and confirm whether direct file access succeeds.

Is this actually a Copilot bug?
- No. The error text and context strongly match access boundary behavior.

## 2) New associate: Copilot in Outlook cannot find case emails

Triage Summary: New-starter Outlook grounding gap

Summary: Newly onboarded user reports Copilot in Outlook is not finding needed case emails.

Impact: Onboarding slowdown; reduced ability to get case context quickly.

Known facts:
- User started this week.
- Scenario is Outlook Copilot.
- Copilot cannot find case emails the user expects.

Missing information to gather:
- to-verify mailbox indexing freshness for the new account.
- to-verify Copilot license/service plan assignment for the user.
- to-verify Outlook client sign-in context and update channel.

Likely cause (ranked):
1. data indexing lag
2. license/client prerequisite issue
3. permissions/access boundary
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Check mailbox indexing status and recency for this new user account.

Is this actually a Copilot bug?
- No (most likely). New account grounding delays are common and fit the symptom.

## 3) Partner: Copilot summarised draft settlement from matter not assigned to them

Triage Summary: Unexpected matter visibility surfaced by Copilot

Summary: Partner received a Copilot summary of a draft from a matter they are not assigned to.

Impact: Potential confidentiality concern and trust impact; requires permission review.

Known facts:
- Partner did not expect visibility to that matter.
- Copilot surfaced and summarised a draft settlement.
- Partner did not realize they could see that folder.

Missing information to gather:
- to-verify effective permissions (direct, inherited, and group-based) on that folder/file.
- to-verify whether access was recently granted via group membership changes.
- to-verify document label policy behavior for assigned/non-assigned matter patterns.

Likely cause (ranked):
1. permissions/access boundary
2. sensitivity label restriction
3. data indexing lag
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Run an effective-access check for the partner on the exact settlement file.

Is this actually a Copilot bug?
- No. Copilot using content the user can access is expected; likely over-permissioning, not product fault.

## 4) Legal ops manager: Entire Legal team (40 users) lost Copilot access this morning

Triage Summary: Team-wide Copilot outage in Legal cohort

Summary: A whole department lost Copilot access simultaneously after prior normal operation.

Impact: High business impact across 40 users; immediate productivity degradation.

Known facts:
- All 40 Legal users affected.
- Started this morning.
- Service worked last week.

Missing information to gather:
- to-verify whether Copilot licenses/service plans changed for the Legal group.
- to-verify if any conditional access or client prerequisite policy changed overnight.
- to-verify whether any users remain unaffected in the same org/unit.

Likely cause (ranked):
1. license/client prerequisite issue
2. permissions/access boundary
3. data indexing lag
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Compare Copilot license/service plan assignment for 2 affected Legal users against last known-good state.

Is this actually a Copilot bug?
- Unclear. Blast radius suggests entitlement/policy drift first; core product defect is not first inference.

## 5) Contract specialist: Copilot gives generic answers on contract template clauses

Triage Summary: Weak grounding to contract templates library

Summary: Copilot responses are generic and appear not to ground on the contract templates library.

Impact: Lower quality legal drafting support; repeated manual lookup of clauses.

Known facts:
- User is querying clauses in a contract templates library.
- Responses are vague/generic.
- User perception: Copilot is not reading documents.

Missing information to gather:
- to-verify whether user has read access to representative templates in that library.
- to-verify indexing status/freshness for that SharePoint library.
- to-verify account license/client readiness and correct tenant sign-in.

Likely cause (ranked):
1. data indexing lag
2. permissions/access boundary
3. license/client prerequisite issue
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Test one known template file for semantic indexing/grounding readiness status.

Is this actually a Copilot bug?
- Unclear. Generic output more often indicates grounding or readiness issues than a Copilot defect.
