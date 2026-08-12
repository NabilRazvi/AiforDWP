# Copilot Ticket Triage - Ranked Causes (2026-08-12)

Scope: Ranked likely causes are restricted to this list only:
- permissions/access boundary
- data indexing lag
- sensitivity label restriction
- license/client prerequisite issue
- guest/external sharing limitation
- genuine Copilot fault (last resort)

## 1) Finance lead: Copilot won't summarise the Q3 board pack in SharePoint. "It's right there, I can see it myself."
Likely cause (ranked):
1. sensitivity label restriction
2. data indexing lag
3. permissions/access boundary
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Open the board-pack file details and confirm whether its sensitivity label/policy blocks Copilot or semantic indexing.

Is this actually a Copilot bug?
- Unclear. Most evidence points to policy or indexing conditions rather than a product defect.

## 2) New hire (started yesterday): Copilot in Outlook seems to know nothing about my recent emails.
Likely cause (ranked):
1. data indexing lag
2. license/client prerequisite issue
3. permissions/access boundary
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Verify mailbox and M365 graph indexing freshness for this new account (recent-mail ingestion status).

Is this actually a Copilot bug?
- No (most likely). New accounts commonly show grounding delay before recent content is fully searchable to Copilot.

## 3) HR manager: Asked Copilot in Word to pull data from a sensitive salary review spreadsheet, got "I don't have access to that content."
Likely cause (ranked):
1. sensitivity label restriction
2. permissions/access boundary
3. data indexing lag
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Check the spreadsheet sensitivity label and rights configuration for AI/Copilot and delegated access restrictions.

Is this actually a Copilot bug?
- No (most likely). The returned message aligns with enforced access or label policy.

## 4) Sales rep: Copilot in Teams can't find a client contract that was shared with her via a guest link from another org.
Likely cause (ranked):
1. guest/external sharing limitation
2. permissions/access boundary
3. data indexing lag
4. license/client prerequisite issue
5. sensitivity label restriction
6. genuine Copilot fault

Fastest check:
- Confirm whether the contract is accessed via external guest link rather than org-native permission grant in the user's tenant.

Is this actually a Copilot bug?
- No (most likely). Cross-tenant guest-link content often has grounding limitations by design.

## 5) IT admin: Copilot suddenly stopped working for the whole Finance team this morning, was fine yesterday.
Likely cause (ranked):
1. license/client prerequisite issue
2. permissions/access boundary
3. data indexing lag
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Check whether Copilot licenses/service plans are still assigned and enabled for affected Finance users.

Is this actually a Copilot bug?
- Unclear. A tenant-wide sudden impact is more often licensing, policy, or client prerequisite drift than a core defect.

## 6) Manager: Copilot found and summarised a file I don't remember ever opening, from a folder I forgot I had access to.
Likely cause (ranked):
1. permissions/access boundary
2. data indexing lag
3. sensitivity label restriction
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Validate current effective permissions on that folder/file for the manager account.

Is this actually a Copilot bug?
- No. This behavior matches design: Copilot can use content the user is permitted to access, even if rarely used.

## 7) Analyst: Copilot gives generic answers, doesn't seem to use any of our internal SharePoint content at all.
Likely cause (ranked):
1. license/client prerequisite issue
2. data indexing lag
3. permissions/access boundary
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Verify analyst account has the required Copilot license/service plan and is signed into the correct tenant/account in client apps.

Is this actually a Copilot bug?
- Unclear. Broadly generic responses usually indicate setup/prerequisite or grounding-scope issues, not immediate proof of a defect.

## 8) Executive assistant: Copilot in Outlook can't see a shared mailbox's calendar that I manage on behalf of my director.
Likely cause (ranked):
1. permissions/access boundary
2. license/client prerequisite issue
3. data indexing lag
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

Fastest check:
- Confirm delegated/shared mailbox calendar permissions and whether Copilot supports that delegated data path in this client scenario.

Is this actually a Copilot bug?
- Unclear. Delegated/shared mailbox access paths are frequently permission/scope-limited rather than product defects.