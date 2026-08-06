# Large File Finder (Read-Only)

This document explains how to use the PowerShell 5.1 script:
- `large-file-finder.ps1`

The script is intended for DWP endpoint engineers to locate large files for investigation.

## Safety and behavior

The script is strictly read-only for endpoint file content and structure. It does **not**:
- Delete files
- Move files
- Rename files
- Compress files
- Modify file data

It only generates:
- A timestamped log file
- A timestamped CSV report file

## Script location

- `Day3\large-file-finder.ps1`

## Parameters

### `-ThresholdMB <double>`
- Minimum file size in MB to include in the report.
- Default: `100`
- Example: `-ThresholdMB 250`

### `-ScanPath <string>`
- Folder to scan recursively.
- If omitted, defaults to current user profile (`$env:USERPROFILE`).
- Example: `-ScanPath "C:\Users\jsmith\Downloads"`

## Output files

The script writes outputs under the Day3 folder:
- Logs: `Day3\logs\large-file-finder-YYYYMMDD-HHMMSS.log`
- Reports: `Day3\reports\large-file-report-YYYYMMDD-HHMMSS.csv`

CSV columns:
- `FileName`
- `FullPath`
- `SizeMB`
- `LastModified`
- `Owner`

## Summary counters at end of run

The script reports:
- Total files scanned
- Large files found
- Skipped items
- Errors

## Access denied handling

If a directory or file cannot be read due to permissions or other access issues, the script:
- Logs the issue
- Increments skipped/error counters
- Continues scanning remaining items

## Verify markers before running

The script contains `VERIFY BEFORE RUNNING` comments to review:
- Whether default threshold (`100 MB`) is right for your case
- Whether default path (`$env:USERPROFILE`) is the right scan scope
- Whether output folder policy allows writing logs/reports under Day3

## Sample commands

Run with defaults (100 MB, user profile path):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\large-file-finder.ps1"
```

Run with a 250 MB threshold on a specific folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\large-file-finder.ps1" -ThresholdMB 250 -ScanPath "C:\Users\jsmith\Downloads"
```

Run from inside Day3 with a 150 MB threshold:

```powershell
.\large-file-finder.ps1 -ThresholdMB 150
```

## Idempotence note

The script is idempotent with respect to endpoint data because each run only reads metadata and writes new timestamped report files.
