# Startup Program Auditor (PowerShell 5.1)

Script:
- `startup-program-auditor.ps1`

## What this script does

This script audits startup programs on a Windows endpoint.

Default behavior is read-only audit mode. It lists startup items from:
- Current User Run registry key
- Local Machine Run registry key
- Current User Startup folder
- All Users Startup folder

Optional behavior:
- Disable matching startup items by name using `-Disable`.
- Preview actions without changes using `-DryRun`.

The script is designed for safe production use. It does not permanently delete startup entries.

## Parameters

`-Disable <string>`
- Disables startup items that exactly match the provided name (case-insensitive).
- Only matching items are processed.

`-DryRun`
- Shows what would happen.
- Makes no changes.

`-WorkingRoot <string>`
- Optional path for backups and state files.
- Default: `Day3\startup-auditor-work`

## Startup locations checked

Registry:
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`
- `HKLM:\Software\Microsoft\Windows\CurrentVersion\Run`

Startup folders:
- Current user startup folder (`[Environment]::GetFolderPath('Startup')`)
- All users startup folder (`[Environment]::GetFolderPath('CommonStartup')`)

## Output fields

For each startup item, the script prints:
- Startup program name
- Source location
- Command/executable path
- Status (where available)

## Logging and backup locations

By default under `Day3`:
- Logs: `logs\startup-auditor-YYYYMMDD-HHMMSS.log`
- Registry backups: `startup-auditor-work\backups\registry\`
- Startup file backups: `startup-auditor-work\backups\startup-files\`
- State files: `startup-auditor-work\state\`

## Safe disable behavior

Registry startup items:
- Exports a registry backup first (`.reg`).
- Moves the value from `Run` to `Run-Disabled-DWP` key.

Startup folder items:
- Moves startup file into a backup folder.

This preserves rollback-friendly data and avoids permanent deletion.

## Idempotence behavior

Running the script repeatedly with the same disable target should not create unexpected duplicate actions:
- Already disabled registry items are skipped.
- Already moved startup files are skipped.
- Actions and skips are logged.

## Summary output

At the end of each run, the script reports:
- Total startup items found
- Disabled items
- Skipped items
- Errors
- Log file path

## Verify-before-run notes

The script intentionally flags these checks at runtime:
- Run elevated if disabling Local Machine startup entries.
- Confirm exact value passed to `-Disable`.
- Review `-DryRun` output before non-dry-run execution.

## Example commands

Audit only (default read-only mode):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\startup-program-auditor.ps1"
```

Audit with dry run (still no changes):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\startup-program-auditor.ps1" -DryRun
```

Disable a startup item by name:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\startup-program-auditor.ps1" -Disable "OneDrive"
```

Disable preview only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\startup-program-auditor.ps1" -Disable "OneDrive" -DryRun
```

Use custom working root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\startup-program-auditor.ps1" -Disable "OneDrive" -WorkingRoot "C:\Temp\StartupAuditor"
```

## Safety notes and limitations

- The script continues on per-item errors and logs them.
- Access-denied errors are expected on some paths without elevation.
- `-Disable` matches by item name, not by executable hash or signer.
- Registry backup uses `reg.exe export` for compatibility with PowerShell 5.1 endpoints.
