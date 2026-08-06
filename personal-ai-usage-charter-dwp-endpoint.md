# Personal AI Usage Charter (DWP Endpoint Engineer, Public AI Assistants)

## 1. Purpose and scope
I use public AI assistants to improve speed and quality in desktop and endpoint engineering work, without exposing DWP-sensitive information or reducing engineering assurance. This charter applies to all prompts, outputs, and actions I take when using public AI tools.

## 2. Appropriate use: what I may use public AI for
I may use public AI for low-risk, generic, non-sensitive engineering support, including:

1. Drafting PowerShell, batch, or command-line snippets for common endpoint tasks where all details are anonymised.
2. Troubleshooting ideas for generic Windows desktop issues (for example service startup order, event log interpretation patterns, policy refresh behaviour).
3. Converting rough logic into cleaner script structure, functions, comments, and error handling patterns.
4. Explaining technical concepts (certificate chains, BitLocker flow, Intune policy order, SCCM client behaviours) at a general level.
5. Creating checklists, rollback plans, test plans, and runbooks for endpoint changes.
6. Drafting user communications for planned desktop changes or known-issue notices, with no internal or personal data.
7. Producing regex, parsing logic, and reporting templates using synthetic or redacted sample data.
8. Comparing tooling options using public documentation only.

Rule of thumb: if a skilled external engineer could safely answer using only public facts and synthetic examples, it is usually suitable for public AI.

## 3. Not appropriate use: what I must not use public AI for
I must not use public AI for any task that exposes protected content or delegates sensitive judgement, including:

1. Any prompt containing real claimant, customer, colleague, or supplier personal data.
2. Any prompt containing credentials, secrets, tokens, private keys, connection strings, or internal URLs that reveal environment design.
3. Uploading logs, screenshots, config exports, memory dumps, or ticket extracts that include hostnames, usernames, device IDs, case references, or other identifying markers.
4. Asking AI to make final security decisions, risk acceptance decisions, or policy interpretations on my behalf.
5. Producing or validating changes to production controls without internal review and local testing.
6. Feeding unpublished incident details, vulnerabilities, or internal architecture into public tools.
7. Using AI outputs directly in live endpoint environments without verification and rollback readiness.

## 4. Data-handling non-negotiable rule (PII and credentials)
I never enter end-user PII or credentials into public AI. Ever.

Before sending any prompt, I apply this check:

1. Remove or replace all names, usernames, emails, phone numbers, NI numbers, addresses, case IDs, ticket IDs, hostnames, IPs, and serial numbers.
2. Replace secrets with placeholders such as SECRET_TOKEN or REDACTED_PASSWORD.
3. Use synthetic examples where possible.
4. If meaningful redaction is not possible, I do not use public AI for that task.

If I accidentally submit sensitive data, I treat it as a security incident and follow DWP reporting procedures immediately.

## 5. Personal generate-then-verify rule for scripts and system changes
AI can generate; I must verify.

For every script or endpoint/system change suggested by AI, I will:

1. Read the full output and confirm I understand each command and side effect.
2. Validate against DWP standards, hardening baselines, and change controls.
3. Test in a safe environment first (lab or non-production pilot endpoint).
4. Check idempotency, error handling, logging, and rollback steps.
5. Scan for destructive actions, privilege escalation, and dependency assumptions.
6. Peer review high-impact changes before broad deployment.
7. Deploy in stages, monitor outcomes, and keep a rollback path ready.

No verification, no execution.

## 6. Accountability statement
I remain fully accountable for all prompts I send and all actions taken from AI output. Public AI is an assistant, not an authority.
