#requires -Version 5.1
<#
.SYNOPSIS
Hand-corrected version — requires controlled-device validation.

.DESCRIPTION
Read-only diagnostic script for one Floor 6 Windows 11 device.
Collects evidence relevant to the current ranked differential, with emphasis on:
- Rank 1: Friday document-management app deployment introduced login/startup overhead
- Rank 1: Friday deployment may have changed document visibility or indexing behavior
- Related checks for ranked login/performance hypotheses only

The script does not remediate, uninstall, stop processes, edit registry,
or trigger policy sync. In normal mode it performs read-only collection only.

.ROLLBACK PLAN
No system rollback is required because the script is designed to avoid changing
system state. The only artifacts created are output files under the chosen
output folder, which may be deleted after evidence is reviewed.

.ERROR HANDLING
Each check runs in its own try/catch path and the script continues on error.
Errors are recorded in the run index and summary so another engineer can see
what failed due to permissions, access, or missing local identifiers.

.NOTES
- Do not guess the Friday app executable, service name, package identity,
  uninstall registry path, startup path, or repository connector details.
  Supply them as parameters only when locally validated.
- Some fields require administrator access for full visibility.
- CPU values in this script are cumulative processor seconds since process
  start, not real-time CPU percent.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,

    [string]$OutputRoot = (Join-Path -Path $PSScriptRoot -ChildPath 'floor6-diagnostic-output'),

    [ValidateRange(1, 168)]
    [int]$LookbackHours = 24,

    [ValidateRange(1, 50)]
    [int]$TopCount = 10,

    [string]$TargetAppName,

    [string]$TargetProcessName,

    [string]$TargetServiceName,

    [string[]]$TargetRegistryPath,

    [string[]]$TargetUninstallRegistryPath,

    [string[]]$StartupFolderPath,

    [string[]]$AdditionalEventLogs = @()
)

Set-StrictMode -Version 2.0

# Section 0: Shared helpers and execution metadata.
# These helpers keep collection read-only, make property access safer,
# and standardize per-check output for another engineer to review.

$script:RunTimestamp = Get-Date
$script:RunStamp = $script:RunTimestamp.ToString('yyyyMMdd-HHmmss')
$script:SessionRoot = Join-Path -Path $OutputRoot -ChildPath $script:RunStamp
$script:Summary = [ordered]@{
    Header = 'Hand-corrected version — requires controlled-device validation'
    SchemaVersion = '1.0'
    Mode = if ($DryRun) { 'DryRun' } else { 'Collect' }
    RunTimestamp = $script:RunTimestamp.ToString('yyyy-MM-dd HH:mm:ss')
    ComputerName = $env:COMPUTERNAME
    UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    IsAdministrator = ([Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    LookbackHours = $LookbackHours
    TopCount = $TopCount
    CpuMetricNote = 'CPUSeconds is cumulative processor time since process start, not instantaneous CPU percent.'
    TargetAppName = if ($TargetAppName) { $TargetAppName } else { 'NEED TO VERIFY' }
    TargetProcessName = if ($TargetProcessName) { $TargetProcessName } else { 'NEED TO VERIFY' }
    TargetServiceName = if ($TargetServiceName) { $TargetServiceName } else { 'NEED TO VERIFY' }
    TargetRegistryPath = if ($TargetRegistryPath) { $TargetRegistryPath } else { @('NEED TO VERIFY') }
    TargetUninstallRegistryPath = if ($TargetUninstallRegistryPath) { $TargetUninstallRegistryPath } else { @('NEED TO VERIFY') }
    StartupFolderPath = if ($StartupFolderPath) { $StartupFolderPath } else { @('NEED TO VERIFY') }
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

    $safeName = $Name
    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safeName = $safeName.Replace($invalidChar, '_')
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
    $Data | ConvertTo-Json -Depth 8 | Out-File -FilePath $path -Encoding utf8
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

function Get-SafeProcessProperty {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    try {
        return $Process.$PropertyName
    }
    catch {
        return $null
    }
}

function Get-SafeProcessPath {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process
    )

    $path = Get-SafeProcessProperty -Process $Process -PropertyName 'Path'
    if ($path) {
        return $path
    }

    try {
        if ($Process.MainModule -and $Process.MainModule.FileName) {
            return $Process.MainModule.FileName
        }
    }
    catch {
    }

    return $null
}

function Get-SafeProcessFileVersion {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process
    )

    try {
        if ($Process.MainModule -and $Process.MainModule.FileVersionInfo) {
            return $Process.MainModule.FileVersionInfo.FileVersion
        }
    }
    catch {
    }

    return $null
}

function ConvertTo-ProcessRecord {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process
    )

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

function Get-PendingRebootIndicators {
    $checks = @(
        @{ Name = 'CBS RebootPending'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'; ValueName = $null },
        @{ Name = 'Windows Update RebootRequired'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'; ValueName = $null },
        @{ Name = 'PendingFileRenameOperations'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; ValueName = 'PendingFileRenameOperations' }
    )

    foreach ($check in $checks) {
        try {
            $isPresent = $false
            if ($check.ValueName) {
                $item = Get-ItemProperty -Path $check.Path -Name $check.ValueName -ErrorAction Stop
                $isPresent = $null -ne $item.$($check.ValueName)
            }
            else {
                $isPresent = Test-Path -Path $check.Path
            }

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

function Get-RegistryPathSnapshot {
    param(
        [string[]]$Paths
    )

    if (-not $Paths) {
        return @([pscustomobject]@{ Note = 'NEED TO VERIFY target registry path'; Path = $null })
    }

    $items = foreach ($path in $Paths) {
        if (-not $path) {
            continue
        }

        if (Test-Path -Path $path) {
            try {
                Get-ItemProperty -Path $path -ErrorAction Stop | Select-Object -Property *
            }
            catch {
                [pscustomobject]@{ Path = $path; Error = $_.Exception.Message }
            }
        }
        else {
            [pscustomobject]@{ Note = 'Configured path not found'; Path = $path }
        }
    }

    if ($items) {
        return @($items)
    }

    return @([pscustomobject]@{ Note = 'NEED TO VERIFY target registry path'; Path = $null })
}

function Get-StartupArtifacts {
    param(
        [string]$ProcessName,
        [string]$ServiceName,
        [string[]]$RegistryPath,
        [string[]]$StartupPath
    )

    $results = [ordered]@{}

    $results.RunRegistryCurrentUser = @(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Select-Object -Property *)
    $results.RunRegistryLocalMachine = @(Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue | Select-Object -Property *)
    $results.StartupCommands = @(Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction SilentlyContinue |
        Select-Object Name, Command, Location, User)
    $results.CustomStartupFolders = @()

    if ($StartupPath) {
        foreach ($path in $StartupPath) {
            if (Test-Path -Path $path) {
                $results.CustomStartupFolders += @(Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
                    Select-Object Name, FullName, CreationTime, LastWriteTime)
            }
            else {
                $results.CustomStartupFolders += [pscustomobject]@{ Note = 'Configured startup folder path not found'; Path = $path }
            }
        }
    }
    else {
        $results.CustomStartupFolders = @([pscustomobject]@{ Note = 'NEED TO VERIFY startup folder path'; Path = $null })
    }

    $results.TargetRegistryPath = @(Get-RegistryPathSnapshot -Paths $RegistryPath)
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
        [string[]]$UninstallRegistryPath
    )

    $result = [ordered]@{}

    $result.Processes = if ($ProcessName) {
        @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
            ForEach-Object { ConvertTo-ProcessRecord -Process $_ })
    }
    else {
        @([pscustomobject]@{ Note = 'NEED TO VERIFY target process name'; Value = $null })
    }

    $result.Services = if ($ServiceName) {
        $safeServiceName = $ServiceName -replace "'", "''"
        @(Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f $safeServiceName) -ErrorAction SilentlyContinue |
            Select-Object Name, DisplayName, State, StartMode, PathName)
    }
    else {
        @([pscustomobject]@{ Note = 'NEED TO VERIFY target service name'; Value = $null })
    }

    if ($AppName -and $UninstallRegistryPath) {
        $installedHints = foreach ($path in $UninstallRegistryPath) {
            if (-not $path) {
                continue
            }

            if (Test-Path -Path $path) {
                Get-ChildItem -Path $path -ErrorAction SilentlyContinue |
                    ForEach-Object { Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue } |
                    Where-Object { $_.DisplayName -like ('*' + $AppName + '*') } |
                    Select-Object @{ Name = 'RegistryPath'; Expression = { $path } }, DisplayName, DisplayVersion, Publisher, InstallDate
            }
            else {
                [pscustomobject]@{ Note = 'Configured uninstall registry path not found'; RegistryPath = $path }
            }
        }

        $result.InstalledProductHints = if ($installedHints) { @($installedHints) } else { @([pscustomobject]@{ Note = 'No matching installed product hints found'; AppName = $AppName }) }
    }
    elseif ($AppName) {
        $result.InstalledProductHints = @([pscustomobject]@{ Note = 'App name provided but uninstall registry path is NEED TO VERIFY'; Value = $null })
    }
    else {
        $result.InstalledProductHints = @([pscustomobject]@{ Note = 'NEED TO VERIFY target app name'; Value = $null })
    }

    return [pscustomobject]$result
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
        [string[]]$HypothesisMap,

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
        HypothesisMap = $HypothesisMap
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

        return [pscustomobject]@{
            CheckName = $Name
            Status = 'Collected'
            OutputPath = $outputPath
            AccessRequirement = $planRecord.AccessRequirement
            LocalValidation = $planRecord.LocalValidation
            HypothesisMap = $HypothesisMap
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
            HypothesisMap = $HypothesisMap
            Error = $_.Exception.Message
        }
    }
}

# Section 1: Check definitions.
# Every check is tied to one or more current ranked hypotheses so the output
# stays within the scope of the differential and does not widen collection.

$checkDefinitions = @(
    @{
        Name = 'ExecutionContext'; CommandCategory = 'Environment'; OutputName = '01-execution-context';
        Purpose = 'Capture timestamp, computer name, current user context, last boot, and uptime for evidence provenance and login timing context';
        HypothesisMap = @('Rank 1 deployment timing context', 'Rank 2 post-migration login context', 'Rank 4 startup-load timing context');
        RequiresLocalValidation = $false; MayNeedAdmin = $false;
        ScriptBlock = {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            [pscustomobject]@{
                Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                ComputerName = $env:COMPUTERNAME
                CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                IsAdministrator = ([Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
                SystemDrive = $os.SystemDrive
                LastBootUpTime = $os.LastBootUpTime
                Uptime = ((Get-Date) - $os.LastBootUpTime).ToString()
            }
        }
    },
    @{
        Name = 'OsDiskAndPendingReboot'; CommandCategory = 'StorageAndRegistry'; OutputName = '02-os-disk-pending-reboot';
        Purpose = 'Capture free OS disk space and pending reboot indicators relevant to deployment or migration slowness';
        HypothesisMap = @('Rank 1 deployment overhead', 'Rank 2 post-migration policy and reboot state', 'Rank 4 background processing');
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
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
        }
    },
    @{
        Name = 'TopProcesses'; CommandCategory = 'ProcessInspection'; OutputName = '03-top-processes';
        Purpose = 'Capture top processes by cumulative CPU time and working set to test for startup or runtime overhead';
        HypothesisMap = @('Rank 1 deployment overhead', 'Rank 4 background processing');
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            $allProcesses = @(Get-Process -ErrorAction SilentlyContinue)
            [pscustomobject]@{
                CpuMetricNote = 'CPUSeconds is cumulative processor time since process start, not current CPU percent.'
                TopByCpu = @($allProcesses |
                    Where-Object { $null -ne $_.CPU } |
                    Sort-Object -Property CPU -Descending |
                    Select-Object -First $TopCount |
                    ForEach-Object { ConvertTo-ProcessRecord -Process $_ })
                TopByWorkingSet = @($allProcesses |
                    Sort-Object -Property WorkingSet64 -Descending |
                    Select-Object -First $TopCount |
                    ForEach-Object { ConvertTo-ProcessRecord -Process $_ })
            }
        }
    },
    @{
        Name = 'TargetAppPresence'; CommandCategory = 'ApplicationPresence'; OutputName = '04-target-app-presence';
        Purpose = 'Record process, service, and installed-product hints for the Friday deployment only when exact identifiers are supplied';
        HypothesisMap = @('Rank 1 Friday deployment correlation');
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            Get-TargetApplicationPresence -AppName $TargetAppName -ProcessName $TargetProcessName -ServiceName $TargetServiceName -UninstallRegistryPath $TargetUninstallRegistryPath
        }
    },
    @{
        Name = 'RecentErrors'; CommandCategory = 'EventLogs'; OutputName = '05-recent-errors';
        Purpose = 'Collect recent System and Application errors within the configured lookback for deployment, startup, and logon clues';
        HypothesisMap = @('Rank 1 Friday deployment correlation', 'Rank 2 post-migration and Intune processing', 'Rank 4 background processing', 'Rank 5 profile or shell-path issues');
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            $startTime = (Get-Date).AddHours(-1 * $LookbackHours)
            $logNames = @('System', 'Application') + $AdditionalEventLogs | Select-Object -Unique
            [pscustomobject]@{
                LookbackStart = $startTime
                Events = @(Get-RecentErrorEvents -LogNames $logNames -StartTime $startTime)
            }
        }
    },
    @{
        Name = 'StartupAndLogonIndicators'; CommandCategory = 'StartupInspection'; OutputName = '06-startup-logon-indicators';
        Purpose = 'Collect startup and logon indicators only where available to test for new startup hooks, services, shell-load delays, or profile-side effects';
        HypothesisMap = @('Rank 1 deployment overhead', 'Rank 2 post-migration and Intune processing', 'Rank 5 profile or desktop redirection issues');
        RequiresLocalValidation = $true; MayNeedAdmin = $true;
        ScriptBlock = {
            Get-StartupArtifacts -ProcessName $TargetProcessName -ServiceName $TargetServiceName -RegistryPath $TargetRegistryPath -StartupPath $StartupFolderPath
        }
    }
)

# Section 2: Dry-run behavior.
# In DryRun mode, list every planned check, command category, output path,
# access requirement, and local validation requirement without collecting data.

if (-not $DryRun) {
    New-OutputDirectory
}

$results = @()
foreach ($check in $checkDefinitions) {
    $results += Invoke-ReadOnlyCheck @check
}

if ($DryRun) {
    $dryRunLines = @(
        'Hand-corrected version — requires controlled-device validation',
        'DryRun mode: no data collected.',
        ('Output root that would be used: {0}' -f $script:SessionRoot),
        ('CPU metric note: {0}' -f $script:Summary.CpuMetricNote),
        ''
    )

    foreach ($result in $results) {
        $dryRunLines += ('Check: {0}' -f $result.Plan.CheckName)
        $dryRunLines += ('  Command category: {0}' -f $result.Plan.CommandCategory)
        $dryRunLines += ('  Output path: {0}.json' -f $result.Plan.OutputPath)
        $dryRunLines += ('  Access requirement: {0}' -f $result.Plan.AccessRequirement)
        $dryRunLines += ('  Local validation: {0}' -f $result.Plan.LocalValidation)
        $dryRunLines += ('  Hypothesis map: {0}' -f ($result.Plan.HypothesisMap -join '; '))
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

# Section 3: Persist execution summary and check outcomes.
# This creates a single run index and a text summary for another engineer.

$indexData = [pscustomobject]@{
    Summary = [pscustomobject]$script:Summary
    RollbackPlan = 'No system rollback required. Delete the generated output folder if the evidence package is no longer needed.'
    ErrorHandling = 'Per-check try/catch with continue-on-error. Failures are recorded in Results.'
    Results = $results
}

$indexPath = Write-JsonFile -Name '00-run-index' -Data $indexData

$summaryLines = @(
    'Hand-corrected version — requires controlled-device validation',
    ('Run timestamp: {0}' -f $script:Summary.RunTimestamp),
    ('Computer name: {0}' -f $script:Summary.ComputerName),
    ('Current user: {0}' -f $script:Summary.UserName),
    ('Administrator context: {0}' -f $script:Summary.IsAdministrator),
    ('Lookback hours: {0}' -f $script:Summary.LookbackHours),
    ('Top count: {0}' -f $script:Summary.TopCount),
    ('CPU metric note: {0}' -f $script:Summary.CpuMetricNote),
    ('Output folder: {0}' -f $script:SessionRoot),
    ('Index file: {0}' -f $indexPath),
    ('Rollback plan: {0}' -f $indexData.RollbackPlan),
    '' ,
    'Check results:'
)

foreach ($result in $results) {
    $summaryLines += ('- {0}: {1}' -f $result.CheckName, $result.Status)
    $summaryLines += ('  Hypothesis map: {0}' -f ($result.HypothesisMap -join '; '))
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