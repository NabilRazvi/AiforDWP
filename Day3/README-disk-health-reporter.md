# Disk Health Reporter (Read-Only)

This document explains how to use the PowerShell 5.1 script:
- `disk-health-reporter.ps1`

The script is intended for DWP endpoint engineers to report disk health and optimization status without changing system state.

## Safety and behavior

The script is strictly read-only for disk state. It does **not**:
- Run optimization or defragmentation
- Repair disks or volumes
- Clear or format disks
- Run clean-up or any disk-changing command

Specifically, the script does not call:
- `Optimize-Volume`
- `defrag.exe`
- `Repair-Volume`
- `Clear-Disk`
- `Format-Volume`

It only generates:
- A timestamped log file
- A timestamped CSV report file

## Script location

- `Day3\disk-health-reporter.ps1`

## Parameters

### `-OutputRoot <string>`
- Base folder where `logs` and `reports` folders are written.
- Default: script folder (`Day3`)
- Example: `-OutputRoot "C:\Temp\DiskHealthOutput"`

### `-OptimizationEventLookbackDays <int>`
- Number of days to look back in `Microsoft-Windows-Defrag/Operational` event log for read-only optimization/analysis status.
- Default: `30`
- Example: `-OptimizationEventLookbackDays 90`

### `-SkipOptimizationEventLookup`
- Skips optimization/fragmentation event-log lookup.
- Useful where event-log access is restricted.

## What the report includes

For each local disk (DriveType=3), the CSV includes:
- Drive letter
- Volume label
- File system
- Total size (GB)
- Free space (GB)
- Free space percent
- Volume health status (where available)
- Volume operational status (where available)
- Disk health status (where available)
- Disk operational status (where available)
- Physical media type (SSD/HDD where available)
- Physical disk health and operational status (where available)
- Read-only optimization status from event logs (where available)
- Classification (`Healthy` or `WarningOrUnhealthy`)

## Output files

The script writes outputs under the selected output root:
- Logs: `logs\disk-health-reporter-YYYYMMDD-HHMMSS.log`
- Reports: `reports\disk-health-report-YYYYMMDD-HHMMSS.csv`

## Summary counters at end of run

The script reports:
- Total disks checked
- Healthy disks
- Warning or unhealthy disks
- Skipped checks
- Errors

## Verify markers before running

The script contains `VERIFY BEFORE RUNNING` comments to review:
- Output folder policy compliance
- Optimization event lookback period
- Whether to disable event-log lookup with `-SkipOptimizationEventLookup`

## Sample commands

Run with defaults:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\disk-health-reporter.ps1"
```

Run with custom output root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\disk-health-reporter.ps1" -OutputRoot "C:\Temp\DiskHealthOutput"
```

Run with longer optimization history window:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\disk-health-reporter.ps1" -OptimizationEventLookbackDays 90
```

Run and skip optimization event lookup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Day3\disk-health-reporter.ps1" -SkipOptimizationEventLookup
```

Run from inside Day3:

```powershell
.\disk-health-reporter.ps1
```

## Idempotence note

The script is idempotent with respect to endpoint disk state because each run only reads disk and event data and writes new timestamped output files.
