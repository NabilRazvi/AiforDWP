#requires -Version 5.1
<#!
.SYNOPSIS
AI-generated first version — not yet hand-verified.

.DESCRIPTION
Read-only diagnostic script for one Floor 6 Windows 11 device.
Collects evidence relevant to the current top-ranked hypothesis:
- Friday document-management app deployment introduced login/startup overhead
- Friday deployment may also have changed repository/search visibility behavior

The script does not remediate, uninstall, stop processes, edit registry,
or trigger policy sync. In normal mode it performs read-only checks only.

.ROLLBACK PLAN
No rollback actions are required because the script is designed to avoid
changing system state. If execution is interrupted, no remediation or cleanup
should be necessary beyond deleting the generated output folder if it is no
longer needed.

.NOTES
- Some fields require local validation because the exact document-management
  app name, executable, service, package identity, and repository connector
  details are NEED TO VERIFY.
- Some commands may require administrator rights to return full results.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,

    [string]$OutputRoot = (Join-Path -Path $PSScriptRoot -ChildPath 'floor6-diagnostic-output'),

    [int]$LookbackHours = 24,

    [int]$TopCount = 10,

    [string]$TargetAppName,

    [string]$TargetProcessName,

    [string]$TargetServiceName,

    [string]$TargetRegistryPath,

    [string]$TargetUninstallRegistryPath,

    [string]$StartupFolderPath,

    [string[]]$AdditionalEventLogs = @()
)

Set-StrictMode -Version 2.0

# Section 0: Shared helpers and execution metadata.
# These helper functions centralize read-only collection, dry-run reporting,
# per-check error handling, and output writing.

$script:RunTimestamp = Get-Date
$script:RunStamp = $script:RunTimestamp.ToString('yyyyMMdd-HHmmss')
$script:SessionRoot = Join-Path -Path $OutputRoot -ChildPath $script:RunStamp
$script:Summary = [ordered]@{
    Header = 'AI-generated first version — not yet hand-verified'
    Mode = if ($DryRun) { 'DryRun' } else { 'Collect' }
    RunTimestamp = $script:RunTimestamp.ToString('yyyy-MM-dd HH:mm:ss')
    ComputerName = $env:COMPUTERNAME
    UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    IsAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    LookbackHours = $LookbackHours
    TargetAppName = if ($TargetAppName) { $TargetAppName } else { 'NEED TO VERIFY' }
    TargetProcessName = if ($TargetProcessName) { $TargetProcessName } else { 'NEED TO VERIFY' }
    TargetServiceName = if ($TargetServiceName) { $TargetServiceName } else { 'NEED TO VERIFY' }
    TargetRegistryPath = if ($TargetRegistryPath) { $TargetRegistryPath } else { 'NEED TO VERIFY' }
    TargetUninstallRegistryPath = if ($TargetUninstallRegistryPath) { $TargetUninstallRegistryPath } else { 'NEED TO VERIFY' }
    StartupFolderPath = if ($StartupFolderPath) { $StartupFolderPath } else { 'NEED TO VERIFY' }
}

function New-OutputDirectory {
    if (-not (Test-Path -Path $script:SessionRoot)) {
        New-Item -Path $script:SessionRoot -ItemType Directory -Force | Out-Null
    }
}

function ConvertTo-SafeFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $safeName = $Name
    foreach ($char in $invalidChars) {
        $safeName = $safeName.Replace($char, '_')
    }

    return $safeName
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $Data
    )

    $path = Join-Path -Path $script:SessionRoot -ChildPath ((ConvertTo-SafeFileName -Name $Name) + '.json')
    $Data | ConvertTo-Json -Depth 6 | Out-File -FilePath $path -Encoding utf8
    return $path
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string[]]$Lines
    )

    $path = Join-Path -Path $script:SessionRoot -ChildPath ((ConvertTo-SafeFileName -Name $Name) + '.txt')
    $Lines | Out-File -FilePath $path -Encoding utf8
    return $path
}

function Get-AdminRequirementLabel {
    param(
        [bool]$MayNeedAdmin
    )

    if ($MayNeedAdmin) {
        return 'May require administrator access for full results'
    }

    return 'Standard user context usually sufficient'
}

function Invoke-ReadOnlyCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$CommandCategory,

        [Parameter(Mandatory = $true)]
        [string]$OutputName,

        [Parameter(Mandatory = $true)]
        [string]$Purpose,

        [Parameter(Mandatory = $true)]
        [bool]$RequiresLocalValidation,

        [Parameter(Mandatory = $true)]
        [bool]$MayNeedAdmin,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    $planRecord = [pscustomobject]@{
        CheckName = $Name
        CommandCategory = $CommandCategory
        OutputPath = Join-Path -Path $script:SessionRoot -ChildPath $OutputName
        Purpose = $Purpose
        AccessRequirement = Get-AdminRequirementLabel -MayNeedAdmin $MayNeedAdmin
        LocalValidation = if ($RequiresLocalValidation) { 'NEED TO VERIFY locally' } else { 'Not specifically required' }
    }

    if ($DryRun) {
        return [pscustomobject]@{
            CheckName = $Name
            Status = 'DryRunOnly'
            Plan = $planRecord
        }
    }

    try {
        $data = & $ScriptBlock
        $outputPath = Write-JsonFile -Name $OutputName -Data $data

        return [pscustomobject]@{
            CheckName = $Name
            Status = 'Collected'
            OutputPath = $outputPath
            AccessRequirement = $planRecord.AccessRequirement
            LocalValidation = $planRecord.LocalValidation
            Error = $null
        }
    }
    catch {
        return [pscustomobject]@{
            CheckName = $Name
            Status = 'Error'
            OutputPath = $null
            AccessRequirement = $planRecord.AccessRequirement
            LocalValidation = $planRecord.LocalValidation
            Error = $_.Exception.Message
        }
    }
}

function Get-PendingRebootIndicators {
    $checks = @(
        @{ Name = 'CBS RebootPending'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'; ValueName = $null },
        @{ Name = 'Windows Update RebootRequired'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'; ValueName = $null },
        @{ Name = 'PendingFileRenameOperations'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; ValueName = 'PendingFileRenameOperations' }
    )

    foreach ($check in $checks) {
        $isPresent = $false
        if ($check.ValueName) {
            $item = Get-ItemProperty -Path $check.Path -Name $check.ValueName -ErrorAction SilentlyContinue
            $isPresent = $null -ne $item.$($check.ValueName)
        }
        else {
            $isPresent = Test-Path -Path $check.Path
        }

        [pscustomobject]@{
            Name = $check.Name
            Path = $check.Path
            IsPresent = $isPresent
            AdminNote = 'Registry read; local policy may limit visibility'
        }
    }
}

function Get-RecentErrorEvents {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$LogNames,

        [Parameter(Mandatory = $true)]
        [datetime]$StartTime
    )

    foreach ($logName in $LogNames) {
        try {
            Get-WinEvent -FilterHashtable @{ LogName = $logName; Level = 2; StartTime = $StartTime } -ErrorAction Stop |
                Select-Object TimeCreated, LogName, Id, ProviderName, LevelDisplayName,
                    @{ Name = 'Message'; Expression = {
                        if ($_.Message -and $_.Message.Length -gt 400) {
                            $_.Message.Substring(0, 400) + '...'
                        }
                        else {
                            $_.Message
                        }
                    }}
        }
        catch {
            [pscustomobject]@{
                TimeCreated = $null
                LogName = $logName
                Id = $null
                ProviderName = $null
                LevelDisplayName = 'Unavailable'
                Message = $_.Exception.Message
            }
        }
    }
}

function Get-StartupArtifacts {
    param(
        [string]$ProcessName,
        [string]$ServiceName,
        [string]$RegistryPath,
        [string]$StartupPath
    )

    $results = [ordered]@{}

    $results.RunRegistryCurrentUser = @(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue |
        Select-Object -Property *)
    $results.RunRegistryLocalMachine = @(Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue |
        Select-Object -Property *)
    $results.StartupCommands = @(Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction SilentlyContinue |
        Select-Object Name, Command, Location, User)

    if ($StartupPath) {
        $results.CustomStartupFolder = if (Test-Path -Path $StartupPath) {
            @(Get-ChildItem -Path $StartupPath -Force -ErrorAction SilentlyContinue |
                Select-Object Name, FullName, CreationTime, LastWriteTime)
        }
        else {
            @([pscustomobject]@{ Note = 'Configured startup folder path not found'; Path = $StartupPath })
        }
    }
    else {
        $results.CustomStartupFolder = @([pscustomobject]@{ Note = 'NEED TO VERIFY startup folder path'; Path = $null })
    }

    if ($RegistryPath) {
        $results.TargetRegistryPath = if (Test-Path -Path $RegistryPath) {
            @(Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue |
                Select-Object -Property *)
        }
        else {
            @([pscustomobject]@{ Note = 'Configured target registry path not found'; Path = $RegistryPath })
        }
    }
    else {
        $results.TargetRegistryPath = @([pscustomobject]@{ Note = 'NEED TO VERIFY target registry path'; Path = $null })
    }

    $results.TargetProcessStartupIndicator = if ($ProcessName) {
        @(Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction SilentlyContinue |
            Where-Object { $_.Command -match [regex]::Escape($ProcessName) -or $_.Name -match [regex]::Escape($ProcessName) } |
            Select-Object Name, Command, Location, User)
    }
    else {
        @([pscustomobject]@{ Note = 'NEED TO VERIFY target process name'; Value = $null })
    }

    $results.TargetServiceState = if ($ServiceName) {
        @(Get-Service -Name $ServiceName -ErrorAction SilentlyContinue |
            Select-Object Name, DisplayName, Status, StartType)
    }
    else {
        @([pscustomobject]@{ Note = 'NEED TO VERIFY target service name'; Value = $null })
    }

    return [pscustomobject]$results
}

function Get-TargetApplicationPresence {
    param(
        [string]$AppName,
        [string]$ProcessName,
        [string]$ServiceName,
        [string]$UninstallRegistryPath
    )

    $result = [ordered]@{}

    $result.Processes = if ($ProcessName) {
        @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
            Select-Object ProcessName, Id,
                @{ Name = 'CPUSeconds'; Expression = { $_.CPU } },
                @{ Name = 'WorkingSetMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) } },
                StartTime,
                Path,
                FileVersion)
    }
    else {
        @([pscustomobject]@{ Note = 'NEED TO VERIFY target process name'; Value = $null })
    }

    $result.Services = if ($ServiceName) {
        @(Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f $ServiceName) -ErrorAction SilentlyContinue |
            Select-Object Name, DisplayName, State, StartMode, PathName)
    }
    else {
        @([pscustomobject]@{ Note = 'NEED TO VERIFY target service name'; Value = $null })
    }

    $result.InstalledProductHints = if ($AppName -and $UninstallRegistryPath -and (Test-Path -Path $UninstallRegistryPath)) {
        @(Get-ChildItem -Path $UninstallRegistryPath -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue } |
            Where-Object { $_.DisplayName -like ('*' + $AppName + '*') } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate)
    }
    elseif ($AppName) {
        @([pscustomobject]@{ Note = 'App name provided but uninstall registry path is NEED TO VERIFY or not found'; Value = $UninstallRegistryPath })
    }
    else {
        @([pscustomobject]@{ Note = 'NEED TO VERIFY target app name'; Value = $null })
    }

    return [pscustomobject]$result
}

# Section 1: Dry-run plan reporting.
# In DryRun mode, list every planned check, command category, output path,
# and access requirement without collecting data.

$checkDefinitions = @(
    @{
        Name = 'ExecutionContext'; CommandCategory = 'Environment'; OutputName = '01-execution-context';
        Purpose = 'Capture timestamp, computer name, user context, and admin context for evidence provenance';
        RequiresLocalValidation = $false; MayNeedAdmin = $false;
        ScriptBlock = {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            [pscustomobject]@{
                Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                ComputerName = $env:COMPUTERNAME
                CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                IsAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
                LastBootUpTime = $os.LastBootUpTime
                Uptime = ((Get-Date) - $os.LastBootUpTime).ToString()
            }
        }
    },
    @{
        Name = 'OsDiskAndPendingReboot'; CommandCategory = 'StorageAndRegistry'; OutputName = '02-os-disk-pending-reboot';
        Purpose = 'Capture free OS disk space and pending reboot indicators relevant to post-deployment or post-migration slowness';
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            $osDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
            [pscustomobject]@{
                OSDisk = [pscustomobject]@{
                    DeviceID = $osDisk.DeviceID
                    FreeGB = [math]::Round($osDisk.FreeSpace / 1GB, 2)
                    SizeGB = [math]::Round($osDisk.Size / 1GB, 2)
                    FreePercent = [math]::Round(($osDisk.FreeSpace / $osDisk.Size) * 100, 2)
                }
                PendingRebootIndicators = @(Get-PendingRebootIndicators)
            }
        }
    },
    @{
        Name = 'TopProcesses'; CommandCategory = 'ProcessInspection'; OutputName = '03-top-processes';
        Purpose = 'Capture top processes by CPU and working set to test for app-driven startup or resource overhead';
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            [pscustomobject]@{
                TopByCpu = @(Get-Process -ErrorAction SilentlyContinue |
                    Where-Object { $null -ne $_.CPU } |
                    Sort-Object -Property CPU -Descending |
                    Select-Object -First $TopCount ProcessName, Id,
                        @{ Name = 'CPUSeconds'; Expression = { [math]::Round($_.CPU, 2) } },
                        @{ Name = 'WorkingSetMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) } },
                        StartTime, Path)
                TopByWorkingSet = @(Get-Process -ErrorAction SilentlyContinue |
                    Sort-Object -Property WorkingSet64 -Descending |
                    Select-Object -First $TopCount ProcessName, Id,
                        @{ Name = 'WorkingSetMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) } },
                        @{ Name = 'CPUSeconds'; Expression = { [math]::Round($_.CPU, 2) } },
                        StartTime, Path)
            }
        }
    },
    @{
        Name = 'TargetAppPresence'; CommandCategory = 'ApplicationPresence'; OutputName = '04-target-app-presence';
        Purpose = 'Record process, service, and installed-product hints for the Friday deployment only when exact app identifiers are supplied';
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            Get-TargetApplicationPresence -AppName $TargetAppName -ProcessName $TargetProcessName -ServiceName $TargetServiceName -UninstallRegistryPath $TargetUninstallRegistryPath
        }
    },
    @{
        Name = 'RecentErrors'; CommandCategory = 'EventLogs'; OutputName = '05-recent-errors';
        Purpose = 'Collect recent System and Application errors within the configured lookback for deployment or logon clues';
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            $startTime = (Get-Date).AddHours(-1 * $LookbackHours)
            $logNames = @('System', 'Application') + $AdditionalEventLogs
            [pscustomobject]@{
                LookbackStart = $startTime
                Events = @(Get-RecentErrorEvents -LogNames $logNames -StartTime $startTime)
            }
        }
    },
    @{
        Name = 'StartupAndLogonIndicators'; CommandCategory = 'StartupInspection'; OutputName = '06-startup-logon-indicators';
        Purpose = 'Collect startup and logon indicators only where available to test for new startup hooks, services, or shell-load issues';
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            Get-StartupArtifacts -ProcessName $TargetProcessName -ServiceName $TargetServiceName -RegistryPath $TargetRegistryPath -StartupPath $StartupFolderPath
        }
    }
)

if (-not $DryRun) {
    New-OutputDirectory
}

$results = @()
foreach ($check in $checkDefinitions) {
    $results += Invoke-ReadOnlyCheck @check
}

if ($DryRun) {
    $dryRunLines = @(
        'AI-generated first version — not yet hand-verified',
        'DryRun mode: no data collected.',
        ('Output root that would be used: {0}' -f $script:SessionRoot),
        ''
    )

    foreach ($result in $results) {
        $dryRunLines += ('Check: {0}' -f $result.Plan.CheckName)
        $dryRunLines += ('  Command category: {0}' -f $result.Plan.CommandCategory)
        $dryRunLines += ('  Output path: {0}.json' -f $result.Plan.OutputPath)
        $dryRunLines += ('  Access requirement: {0}' -f $result.Plan.AccessRequirement)
        $dryRunLines += ('  Local validation: {0}' -f $result.Plan.LocalValidation)
        $dryRunLines += ('  Purpose: {0}' -f $result.Plan.Purpose)
        $dryRunLines += ''
    }

    $dryRunLines += 'Parameters still NEED TO VERIFY unless supplied:'
    $dryRunLines += '- TargetAppName'
    $dryRunLines += '- TargetProcessName'
    $dryRunLines += '- TargetServiceName'
    $dryRunLines += '- TargetRegistryPath'
    $dryRunLines += '- TargetUninstallRegistryPath'
    $dryRunLines += '- StartupFolderPath'
    $dryRunLines | ForEach-Object { Write-Output $_ }
    return
}

# Section 2: Persist execution summary and check outcomes.
# This provides a single index of what the script attempted, what succeeded,
# and which items require elevated access or local validation.

$indexData = [pscustomobject]@{
    Summary = [pscustomobject]$script:Summary
    RollbackPlan = 'No rollback actions required; script is designed to be read-only. Only generated output files may be deleted if no longer needed.'
    Results = $results
}

$indexPath = Write-JsonFile -Name '00-run-index' -Data $indexData

$summaryLines = @(
    'AI-generated first version — not yet hand-verified',
    ('Run timestamp: {0}' -f $script:Summary.RunTimestamp),
    ('Computer name: {0}' -f $script:Summary.ComputerName),
    ('Current user: {0}' -f $script:Summary.UserName),
    ('Administrator context: {0}' -f $script:Summary.IsAdministrator),
    ('Lookback hours: {0}' -f $script:Summary.LookbackHours),
    ('Output folder: {0}' -f $script:SessionRoot),
    ('Index file: {0}' -f $indexPath),
    '',
    'Check results:'
)

foreach ($result in $results) {
    $summaryLines += ('- {0}: {1}' -f $result.CheckName, $result.Status)
    if ($result.OutputPath) {
        $summaryLines += ('  Output: {0}' -f $result.OutputPath)
    }
    $summaryLines += ('  Access: {0}' -f $result.AccessRequirement)
    $summaryLines += ('  Validation: {0}' -f $result.LocalValidation)
    if ($result.Error) {
        $summaryLines += ('  Error: {0}' -f $result.Error)
    }
}

Write-TextFile -Name '00-run-summary' -Lines $summaryLines | Out-Null
$summaryLines | ForEach-Object { Write-Output $_ }