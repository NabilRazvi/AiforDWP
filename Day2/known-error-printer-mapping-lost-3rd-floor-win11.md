Symptom: Printer mapping is missing for users on the 3rd floor after Windows 11 upgrade.
Cause: Logon script was not re-applied because it referenced the old OS drive path.
Scope: Whole 3rd floor user group post-Win11 upgrade.
Workaround: Manually remap required printers for affected users until script correction is deployed.
Permanent fix: Update the logon script to use the correct Windows 11 OS drive path, re-apply via standard policy/logon process, and validate mapping on 3rd floor devices.
