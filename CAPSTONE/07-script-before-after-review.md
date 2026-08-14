# Script Before/After Review

This review compares [05-ai-generated-floor6-diagnostic.ps1](c:/Users/labuser/Documents/Training/CAPSTONE%20PROJECT/05-ai-generated-floor6-diagnostic.ps1) and [06-corrected-floor6-diagnostic.ps1](c:/Users/labuser/Documents/Training/CAPSTONE%20PROJECT/06-corrected-floor6-diagnostic.ps1) by logical section. It is a code review comparison, not an execution claim.

## 1. Header and parameter contract

AI version:
```powershell
#requires -Version 5.1
<#!
.SYNOPSIS
AI-generated first version — not yet hand-verified.
...
[int]$LookbackHours = 24,
[int]$TopCount = 10,
[string]$TargetRegistryPath,
[string]$TargetUninstallRegistryPath,
[string]$StartupFolderPath,
```

Corrected version:
```powershell
#requires -Version 5.1
<#
.SYNOPSIS
Hand-corrected version — requires controlled-device validation.
...
[ValidateRange(1, 168)]
[int]$LookbackHours = 24,
[ValidateRange(1, 50)]
[int]$TopCount = 10,
[string[]]$TargetRegistryPath,
[string[]]$TargetUninstallRegistryPath,
[string[]]$StartupFolderPath,
```

Fixed: Tightened the parameter contract and changed path inputs to arrays for validated multi-path collection.
Why: The review needed safer inputs without inventing app-specific paths, and the script must stay useful when multiple startup or uninstall locations are locally validated.

## 2. Run metadata and summary schema

AI version:
```powershell
$script:Summary = [ordered]@{
    Header = 'AI-generated first version — not yet hand-verified'
    Mode = if ($DryRun) { 'DryRun' } else { 'Collect' }
    RunTimestamp = $script:RunTimestamp.ToString('yyyy-MM-dd HH:mm:ss')
    ComputerName = $env:COMPUTERNAME
    UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    IsAdministrator = ...
    LookbackHours = $LookbackHours
}
```

Corrected version:
```powershell
$script:Summary = [ordered]@{
    Header = 'Hand-corrected version — requires controlled-device validation'
    SchemaVersion = '1.0'
    Mode = if ($DryRun) { 'DryRun' } else { 'Collect' }
    RunTimestamp = $script:RunTimestamp.ToString('yyyy-MM-dd HH:mm:ss')
    ComputerName = $env:COMPUTERNAME
    UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    IsAdministrator = ...
    LookbackHours = $LookbackHours
    TopCount = $TopCount
    CpuMetricNote = 'CPUSeconds is cumulative processor time since process start, not instantaneous CPU percent.'
}
```

Fixed: Added an explicit schema version, preserved operator context, and made the CPU interpretation part of the output contract.
Why: Another engineer needs to understand the payload shape and avoid misreading CPU time as current utilization.

## 3. Process safety helpers

AI version:
```powershell
$result.Processes = if ($ProcessName) {
    @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Select-Object ProcessName, Id,
            @{ Name = 'CPUSeconds'; Expression = { $_.CPU } },
            @{ Name = 'WorkingSetMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) } },
            StartTime,
            Path,
            FileVersion)
}
```

Corrected version:
```powershell
function Get-SafeProcessProperty { ... }
function Get-SafeProcessPath { ... }
function Get-SafeProcessFileVersion { ... }

function ConvertTo-ProcessRecord {
    [pscustomobject]@{
        ProcessName = $Process.ProcessName
        Id = $Process.Id
        CPUSeconds = if ($null -ne $Process.CPU) { [math]::Round($Process.CPU, 2) } else { $null }
        CpuMetricNote = 'Cumulative processor seconds since process start; not current CPU percent.'
        WorkingSetMB = [math]::Round($Process.WorkingSet64 / 1MB, 2)
        StartTime = Get-SafeProcessProperty -Process $Process -PropertyName 'StartTime'
        Path = Get-SafeProcessPath -Process $Process
        FileVersion = Get-SafeProcessFileVersion -Process $Process
    }
}
```

Fixed: Replaced direct process property reads with safe helper functions and normalized the process record shape.
Why: Protected processes and access-denied cases should not break collection or produce misleading blanks for path, start time, or version.

## 4. OS disk and pending reboot check

AI version:
```powershell
$osDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
[pscustomobject]@{
    OSDisk = [pscustomobject]@{
        DeviceID = $osDisk.DeviceID
        FreeGB = [math]::Round($osDisk.FreeSpace / 1GB, 2)
        SizeGB = [math]::Round($osDisk.Size / 1GB, 2)
        FreePercent = [math]::Round(($osDisk.FreeSpace / $osDisk.Size) * 100, 2)
    }
}
```

Corrected version:
```powershell
$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
$systemDrive = $os.SystemDrive
$driveLetter = $systemDrive.TrimEnd('\')
$osDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $driveLetter) -ErrorAction Stop
[pscustomobject]@{
    OSDisk = [pscustomobject]@{
        DeviceID = $osDisk.DeviceID
        FreeGB = [math]::Round($osDisk.FreeSpace / 1GB, 2)
        SizeGB = [math]::Round($osDisk.Size / 1GB, 2)
        FreePercent = if ($osDisk.Size -gt 0) { [math]::Round(($osDisk.FreeSpace / $osDisk.Size) * 100, 2) } else { $null }
    }
    PendingRebootIndicators = @(Get-PendingRebootIndicators)
}
```

Fixed: Removed the hard-coded `C:` assumption and guarded the free-space percentage calculation.
Why: The requirement is free OS disk space, not always `C:`, and the output should not fail on unexpected disk metadata.

## 5. Pending reboot error handling

AI version:
```powershell
foreach ($check in $checks) {
    $isPresent = $false
    if ($check.ValueName) {
        $item = Get-ItemProperty -Path $check.Path -Name $check.ValueName -ErrorAction SilentlyContinue
        $isPresent = $null -ne $item.$($check.ValueName)
    }
    else {
        $isPresent = Test-Path -Path $check.Path
    }
    [pscustomobject]@{ Name = $check.Name; Path = $check.Path; IsPresent = $isPresent }
}
```

Corrected version:
```powershell
foreach ($check in $checks) {
    try {
        ...
        [pscustomobject]@{
            Name = $check.Name
            Path = $check.Path
            IsPresent = $isPresent
            AccessNote = 'Registry read only; local policy may limit visibility.'
        }
    }
    catch {
        [pscustomobject]@{
            Name = $check.Name
            Path = $check.Path
            IsPresent = $null
            AccessNote = 'Registry read only; local policy may limit visibility.'
            Error = $_.Exception.Message
        }
    }
}
```

Fixed: Added per-indicator try/catch and explicit access notes to the reboot checks.
Why: Registry visibility can vary by rights and policy, so another engineer needs to distinguish “not present” from “not readable.”

## 6. Target app and startup evidence collection

AI version:
```powershell
function Get-StartupArtifacts {
    param(
        [string]$ProcessName,
        [string]$ServiceName,
        [string]$RegistryPath,
        [string]$StartupPath
    )
    ...
}

function Get-TargetApplicationPresence {
    param(
        [string]$AppName,
        [string]$ProcessName,
        [string]$ServiceName,
        [string]$UninstallRegistryPath
    )
    ...
}
```

Corrected version:
```powershell
function Get-RegistryPathSnapshot {
    param([string[]]$Paths)
    ...
}

function Get-StartupArtifacts {
    param(
        [string]$ProcessName,
        [string]$ServiceName,
        [string[]]$RegistryPath,
        [string[]]$StartupPath
    )
    ...
    $results.TargetRegistryPath = @(Get-RegistryPathSnapshot -Paths $RegistryPath)
}

function Get-TargetApplicationPresence {
    param(
        [string]$AppName,
        [string]$ProcessName,
        [string]$ServiceName,
        [string[]]$UninstallRegistryPath
    )
    ...
}
```

Fixed: Expanded registry and startup collection to handle multiple locally validated paths without inventing any app-specific locations.
Why: The Friday deployment details are still unknown, so the script has to stay parameter-driven and safe when engineers discover more than one relevant path.

## 7. Check-to-hypothesis mapping

AI version:
```powershell
$checkDefinitions = @(
    @{
        Name = 'TopProcesses'
        CommandCategory = 'ProcessInspection'
        Purpose = 'Capture top processes by CPU and working set to test for app-driven startup or resource overhead'
    },
    ...
)
```

Corrected version:
```powershell
$checkDefinitions = @(
    @{
        Name = 'TopProcesses'
        CommandCategory = 'ProcessInspection'
        Purpose = 'Capture top processes by cumulative CPU time and working set to test for startup or runtime overhead'
        HypothesisMap = @('Rank 1 deployment overhead', 'Rank 4 background processing')
    },
    @{
        Name = 'StartupAndLogonIndicators'
        ...
        HypothesisMap = @('Rank 1 deployment overhead', 'Rank 2 post-migration and Intune processing', 'Rank 5 profile or desktop redirection issues')
    }
)
```

Fixed: Added explicit hypothesis mapping to every check definition.
Why: The brief required collection only where justified by the differential, so the review needed a visible audit trail from each check back to a ranked hypothesis.

## 8. Per-check output schema

AI version:
```powershell
$data = & $ScriptBlock
$outputPath = Write-JsonFile -Name $OutputName -Data $data
```

Corrected version:
```powershell
$data = & $ScriptBlock
$payload = [pscustomobject]@{
    SchemaVersion = '1.0'
    CheckName = $Name
    CommandCategory = $CommandCategory
    Purpose = $Purpose
    HypothesisMap = $HypothesisMap
    CollectedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    AccessRequirement = $planRecord.AccessRequirement
    LocalValidation = $planRecord.LocalValidation
    Data = $data
}
$outputPath = Write-JsonFile -Name $OutputName -Data $payload
```

Fixed: Wrapped each collected dataset in a consistent payload with purpose, hypothesis map, and access context.
Why: Raw data alone is not actionable enough for handoff; another engineer needs the collection rationale and schema at the file level.

## 9. DryRun plan detail

AI version:
```powershell
$dryRunLines += ('  Command category: {0}' -f $result.Plan.CommandCategory)
$dryRunLines += ('  Output path: {0}.json' -f $result.Plan.OutputPath)
$dryRunLines += ('  Access requirement: {0}' -f $result.Plan.AccessRequirement)
$dryRunLines += ('  Local validation: {0}' -f $result.Plan.LocalValidation)
$dryRunLines += ('  Purpose: {0}' -f $result.Plan.Purpose)
```

Corrected version:
```powershell
$dryRunLines += ('  Command category: {0}' -f $result.Plan.CommandCategory)
$dryRunLines += ('  Output path: {0}.json' -f $result.Plan.OutputPath)
$dryRunLines += ('  Access requirement: {0}' -f $result.Plan.AccessRequirement)
$dryRunLines += ('  Local validation: {0}' -f $result.Plan.LocalValidation)
$dryRunLines += ('  Hypothesis map: {0}' -f ($result.Plan.HypothesisMap -join '; '))
$dryRunLines += ('  Purpose: {0}' -f $result.Plan.Purpose)
```

Fixed: Added hypothesis mapping and CPU interpretation to DryRun planning output.
Why: DryRun is supposed to tell an engineer exactly what will be gathered and why, without needing to inspect the script body.

## 10. Final run index and operator summary

AI version:
```powershell
$indexData = [pscustomobject]@{
    Summary = [pscustomobject]$script:Summary
    RollbackPlan = 'No rollback actions required; script is designed to be read-only. Only generated output files may be deleted if no longer needed.'
    Results = $results
}
```

Corrected version:
```powershell
$indexData = [pscustomobject]@{
    Summary = [pscustomobject]$script:Summary
    RollbackPlan = 'No system rollback required. Delete the generated output folder if the evidence package is no longer needed.'
    ErrorHandling = 'Per-check try/catch with continue-on-error. Failures are recorded in Results.'
    Results = $results
}
```

Fixed: Added explicit error-handling description and improved the operator-facing summary content.
Why: The handoff requirement was actionable output for another engineer, not just data files without collection context.

## Items Still Marked NEED TO VERIFY

- `TargetAppName`
- `TargetProcessName`
- `TargetServiceName`
- `TargetRegistryPath`
- `TargetUninstallRegistryPath`
- `StartupFolderPath`
- Exact Friday app package identity
- Exact Friday app executable name
- Exact Friday app service name
- Exact Friday app uninstall registry path or paths
- Exact Friday app startup folder path or paths
- Exact Friday app repository connector details
- Any local-only values required to validate whether a discovered path, process, or service is truly part of the Friday deployment