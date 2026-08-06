# Event Log Archive and Cleanup Safe Script

This folder contains a PowerShell 5.1 script for safe Windows Event Log archive and cleanup.

Script:
- event-log-archive-cleanup-safe.ps1

## Behavior

In cleanup mode, the script:
- Targets only selected logs (default: Application and System).
- Checks if the oldest event in each target log is older than OlderThanDays.
- Archives matching logs to a date-based archive folder.
- Clears a log only after archive succeeds.
- Skips a log if today's archive already exists (idempotent behavior).

In dry run mode, the script:
- Does not archive or clear anything.
- Prints and logs the total record count it would delete.

In rollback mode, the script:
- Reads a manifest from a previous cleanup run.
- Restores archive copies into a timestamped restore folder.

## Parameters

Cleanup mode:
- DryRun
  - Simulates cleanup only.
  - Prints and logs count of records that would be deleted.
- OlderThanDays <int>
  - Default: 3
  - Range: 1..3650
- LogNames <string[]>
  - Default: Application, System
  - You can pass a comma-delimited value like "Application,System".
- WorkingRoot <string>
  - Optional root for work folders.
  - Default: Day3\eventlog-work

Rollback mode:
- Rollback
  - Switches script to rollback mode.
- RollbackManifestPath <string>
  - Path to a manifest CSV created by a previous cleanup run.
- DryRun
  - Shows what rollback would restore.
  - Does not copy files.

## Output locations

By default, script creates:
- Day3\logs
- Day3\eventlog-work\archives\<yyyyMMdd>
- Day3\eventlog-work\manifests
- Day3\eventlog-work\rollback-restored\restore-<yyyyMMdd-HHmmss>

## Summary counters

- LogsEvaluated
- LogsTargeted
- LogsArchived
- LogsCleared
- LogsSkippedNoEvents
- LogsSkippedNotOldEnough
- LogsSkippedArchiveExists
- LogsSkippedInaccessible
- LogsFailed
- RecordsPlannedDelete
- RecordsDeleted
- RollbackFilesPlanned
- RollbackFilesRestored
- RollbackFilesMissing

## Examples

Dry run with defaults:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\event-log-archive-cleanup-safe.ps1" -DryRun
```

Dry run older than 7 days:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\event-log-archive-cleanup-safe.ps1" -DryRun -OlderThanDays 7
```

Cleanup with default logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\event-log-archive-cleanup-safe.ps1" -OlderThanDays 3
```

Cleanup with explicit logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\event-log-archive-cleanup-safe.ps1" -OlderThanDays 3 -LogNames "Application,System"
```

Rollback dry run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\event-log-archive-cleanup-safe.ps1" -Rollback -RollbackManifestPath "C:\Users\labuser\Documents\Training\Day3\eventlog-work\manifests\manifest-YYYYMMDD-HHMMSS.csv" -DryRun
```

Rollback restore:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\event-log-archive-cleanup-safe.ps1" -Rollback -RollbackManifestPath "C:\Users\labuser\Documents\Training\Day3\eventlog-work\manifests\manifest-YYYYMMDD-HHMMSS.csv"
```

## Safety notes

- Run in elevated PowerShell for full event log access.
- Always start with DryRun in production endpoints.
- Rollback restores archived files into a restore folder for safe review.
