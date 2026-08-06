#requires -Version 5.1
<#!
.SYNOPSIS
Safely archives and cleans up selected Windows Event Logs.

.DESCRIPTION
This script is designed for DWP endpoint use with safety-first behavior.
It supports dry run, age-based targeting, timestamped logging, summary reporting,
manifest-based rollback, and idempotent archive checks.
#>

[CmdletBinding(DefaultParameterSetName = 'Cleanup')]
param(
    # Section 0: Cleanup parameters
    # Controls normal archive and cleanup behavior.
    [Parameter(ParameterSetName = 'Cleanup')]
    [ValidateRange(1, 3650)]
    [int]$OlderThanDays = 3,

    [Parameter(ParameterSetName = 'Cleanup')]
    [string[]]$LogNames = @('Application', 'System'),

    [Parameter(ParameterSetName = 'Cleanup')]
    [Parameter(ParameterSetName = 'Rollback')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Cleanup')]
    [Parameter(ParameterSetName = 'Rollback')]
    [string]$WorkingRoot,

    # Section 0A: Rollback parameters
    # Controls restore behavior from a previous manifest.
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [switch]$Rollback,

    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [string]$RollbackManifestPath
)

# Section 1: Run metadata and counters
# Initializes timestamps, paths, and summary counters used across the script.
$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$todayStamp = Get-Date -Format 'yyyyMMdd'
$scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Path $PSCommandPath -Parent
}
else {
    (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($WorkingRoot)) {
    $WorkingRoot = Join-Path -Path $scriptRoot -ChildPath 'eventlog-work'
}

$summary = [ordered]@{
    LogsEvaluated = 0
    LogsTargeted = 0
    LogsArchived = 0
    LogsCleared = 0
    LogsSkippedNoEvents = 0
    LogsSkippedNotOldEnough = 0
    LogsSkippedArchiveExists = 0
    LogsSkippedInaccessible = 0
    LogsFailed = 0
    RecordsPlannedDelete = 0
    RecordsDeleted = 0
    RollbackFilesPlanned = 0
    RollbackFilesRestored = 0
    RollbackFilesMissing = 0
}

# Section 2: Folder layout
# Defines folders for logs, archives, manifests, and rollback output.
$logRoot = Join-Path -Path $scriptRoot -ChildPath 'logs'
$archiveRoot = Join-Path -Path $WorkingRoot -ChildPath 'archives'
$manifestRoot = Join-Path -Path $WorkingRoot -ChildPath 'manifests'
$restoreRoot = Join-Path -Path $WorkingRoot -ChildPath 'rollback-restored'

# Section 3: Helper functions
# Implements logging, directory creation, command wrappers, and summary output.
function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        throw "Unable to create or access directory '$Path'. $($_.Exception.Message)"
    }
}

Ensure-Directory -Path $logRoot
Ensure-Directory -Path $archiveRoot
Ensure-Directory -Path $manifestRoot
Ensure-Directory -Path $restoreRoot

$logFile = Join-Path -Path $logRoot -ChildPath ("eventlog-cleanup-{0}.log" -f $runTimestamp)

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    try {
        Add-Content -Path $logFile -Value $line -ErrorAction Stop
    }
    catch {
        Write-Output "[LOGGING-ERROR] $line"
    }

    Write-Output $line
}

function Invoke-Wevtutil {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    try {
        $output = & wevtutil @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $errorText = if ($output) { ($output | Out-String).Trim() } else { 'No error output returned.' }
            throw "wevtutil failed with exit code $exitCode. Args: $($Arguments -join ' '). Error: $errorText"
        }
        return $output
    }
    catch {
        throw "Failed to run wevtutil. $($_.Exception.Message)"
    }
}

function Get-SafeLogFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogName
    )

    try {
        return ($LogName -replace '[^a-zA-Z0-9._-]', '_')
    }
    catch {
        throw "Unable to build file name for log '$LogName'. $($_.Exception.Message)"
    }
}

function Resolve-LogNameList {
    param(
        [string[]]$RawNames
    )

    $resolved = New-Object System.Collections.Generic.List[string]

    foreach ($raw in $RawNames) {
        try {
            if ([string]::IsNullOrWhiteSpace($raw)) {
                continue
            }

            foreach ($part in ($raw -split ',')) {
                $name = $part.Trim()
                if (-not [string]::IsNullOrWhiteSpace($name)) {
                    $resolved.Add($name) | Out-Null
                }
            }
        }
        catch {
            throw "Unable to parse log name input '$raw'. $($_.Exception.Message)"
        }
    }

    return $resolved.ToArray()
}

function Write-Summary {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    try {
        Write-Log -Message ('=' * 70)
        Write-Log -Message ("Summary for mode: {0}" -f $Mode)
        foreach ($entry in $Data.GetEnumerator()) {
            Write-Log -Message ("{0}: {1}" -f $entry.Key, $entry.Value)
        }
        Write-Log -Message ("Log file: {0}" -f $logFile)

        Write-Output ''
        Write-Output ('=' * 70)
        Write-Output ("Summary for mode: {0}" -f $Mode)
        foreach ($entry in $Data.GetEnumerator()) {
            Write-Output ("{0}: {1}" -f $entry.Key, $entry.Value)
        }
        Write-Output ("Log file: {0}" -f $logFile)
    }
    catch {
        Write-Output "Failed to print summary. $($_.Exception.Message)"
    }
}

# Section 4: Cleanup mode
# Archives and clears selected logs only when they are older than cutoff age.
function Invoke-EventLogCleanup {
    param(
        [Parameter(Mandatory = $true)]
        [int]$AgeInDays,

        [Parameter(Mandatory = $true)]
        [bool]$IsDryRun,

        [string[]]$SelectedLogNames
    )

    $cutoffDate = (Get-Date).AddDays(-1 * $AgeInDays)
    $archiveDateFolder = Join-Path -Path $archiveRoot -ChildPath $todayStamp
    $manifestPath = Join-Path -Path $manifestRoot -ChildPath ("manifest-{0}.csv" -f $runTimestamp)
    $manifestRows = New-Object System.Collections.Generic.List[object]

    try {
        Ensure-Directory -Path $archiveDateFolder
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Failed to prepare archive folder. $($_.Exception.Message)"
        throw
    }

    Write-Log -Message 'Starting cleanup mode.'
    Write-Log -Message ("DryRun: {0}" -f $IsDryRun)
    Write-Log -Message ("OlderThanDays: {0}" -f $AgeInDays)
    Write-Log -Message ("CutoffDate: {0}" -f $cutoffDate)
    Write-Log -Message ("ArchiveDateFolder: {0}" -f $archiveDateFolder)
    Write-Log -Message ("ManifestPath: {0}" -f $manifestPath)

    $logsToInspect = @()

    try {
        $logsToInspect = Resolve-LogNameList -RawNames $SelectedLogNames
    }
    catch {
        Write-Log -Level 'ERROR' -Message ("Invalid log name input: {0}" -f $_.Exception.Message)
        throw
    }

    foreach ($logName in $logsToInspect) {
        $summary.LogsEvaluated++

        try {
            $logInfo = Get-WinEvent -ListLog $logName -ErrorAction Stop
        }
        catch {
            Write-Log -Level 'WARN' -Message ("Skipping inaccessible or missing log '{0}': {1}" -f $logName, $_.Exception.Message)
            $summary.LogsSkippedInaccessible++
            continue
        }

        try {
            $recordCount = [int64]$logInfo.RecordCount
        }
        catch {
            Write-Log -Level 'ERROR' -Message ("Failed to read record count for '{0}': {1}" -f $logName, $_.Exception.Message)
            $summary.LogsFailed++
            continue
        }

        if ($recordCount -le 0) {
            Write-Log -Message ("Skipping log with no events: {0}" -f $logName)
            $summary.LogsSkippedNoEvents++
            continue
        }

        $oldestEvent = $null
        try {
            $oldestEvent = Get-WinEvent -LogName $logName -Oldest -MaxEvents 1 -ErrorAction Stop
        }
        catch {
            Write-Log -Level 'WARN' -Message ("Unable to read oldest event for '{0}'. Skipping. {1}" -f $logName, $_.Exception.Message)
            $summary.LogsFailed++
            continue
        }

        if (-not $oldestEvent -or -not $oldestEvent.TimeCreated) {
            Write-Log -Level 'WARN' -Message ("Skipping log with unreadable oldest timestamp: {0}" -f $logName)
            $summary.LogsFailed++
            continue
        }

        if ($oldestEvent.TimeCreated -ge $cutoffDate) {
            Write-Log -Message ("Skipping log not older than cutoff: {0}" -f $logName)
            $summary.LogsSkippedNotOldEnough++
            continue
        }

        $summary.LogsTargeted++
        $summary.RecordsPlannedDelete += $recordCount

        $safeLogName = Get-SafeLogFileName -LogName $logName
        $archivePath = Join-Path -Path $archiveDateFolder -ChildPath ("{0}.evtx" -f $safeLogName)

        if (Test-Path -LiteralPath $archivePath) {
            Write-Log -Level 'WARN' -Message ("Idempotent skip: today's archive already exists for '{0}': {1}" -f $logName, $archivePath)
            $summary.LogsSkippedArchiveExists++
            continue
        }

        if ($IsDryRun) {
            Write-Log -Message ("DRY RUN - would archive and clear '{0}' with {1} records. Archive: {2}" -f $logName, $recordCount, $archivePath)
            continue
        }

        try {
            Invoke-Wevtutil -Arguments @('epl', $logName, $archivePath) | Out-Null
            Write-Log -Message ("Archived '{0}' to {1}" -f $logName, $archivePath)
            $summary.LogsArchived++
        }
        catch {
            Write-Log -Level 'ERROR' -Message ("Archive failed for '{0}': {1}" -f $logName, $_.Exception.Message)
            $summary.LogsFailed++
            continue
        }

        try {
            $manifestRows.Add([pscustomobject]@{
                LogName = $logName
                ArchivePath = $archivePath
                RecordCountBeforeClear = $recordCount
                OldestEventTime = $oldestEvent.TimeCreated
                ArchivedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                CleanupRunTimestamp = $runTimestamp
            }) | Out-Null
        }
        catch {
            Write-Log -Level 'ERROR' -Message ("Failed to add manifest row for '{0}': {1}" -f $logName, $_.Exception.Message)
            $summary.LogsFailed++
            continue
        }

        try {
            Invoke-Wevtutil -Arguments @('cl', $logName) | Out-Null
            Write-Log -Message ("Cleared '{0}'" -f $logName)
            $summary.LogsCleared++
            $summary.RecordsDeleted += $recordCount
        }
        catch {
            Write-Log -Level 'ERROR' -Message ("Clear failed for '{0}': {1}" -f $logName, $_.Exception.Message)
            $summary.LogsFailed++
        }
    }

    if ($IsDryRun) {
        Write-Log -Message ("DRY RUN total records that would be deleted: {0}" -f $summary.RecordsPlannedDelete)
        return
    }

    try {
        if ($manifestRows.Count -gt 0) {
            $manifestRows | Export-Csv -Path $manifestPath -NoTypeInformation -ErrorAction Stop
            Write-Log -Message ("Manifest written: {0}" -f $manifestPath)
        }
        else {
            Write-Log -Message 'No logs archived. Manifest not written.'
        }
    }
    catch {
        Write-Log -Level 'ERROR' -Message ("Failed to write manifest: {0}" -f $_.Exception.Message)
        $summary.LogsFailed++
    }
}

# Section 5: Rollback mode
# Restores archive files listed in a manifest to a timestamped restore folder.
function Invoke-EventLogRollback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [bool]$IsDryRun
    )

    Write-Log -Message 'Starting rollback mode.'
    Write-Log -Message ("DryRun: {0}" -f $IsDryRun)
    Write-Log -Message ("RollbackManifestPath: {0}" -f $ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Rollback manifest not found: $ManifestPath"
    }

    $rows = $null
    try {
        $rows = Import-Csv -Path $ManifestPath -ErrorAction Stop
    }
    catch {
        throw "Failed to read rollback manifest '$ManifestPath'. $($_.Exception.Message)"
    }

    $restoreRunFolder = Join-Path -Path $restoreRoot -ChildPath ("restore-{0}" -f $runTimestamp)
    try {
        Ensure-Directory -Path $restoreRunFolder
    }
    catch {
        Write-Log -Level 'ERROR' -Message $_.Exception.Message
        throw
    }

    foreach ($row in $rows) {
        $summary.RollbackFilesPlanned++

        try {
            if (-not $row.ArchivePath) {
                Write-Log -Level 'WARN' -Message 'Manifest row missing ArchivePath. Skipping row.'
                $summary.RollbackFilesMissing++
                continue
            }

            if (-not (Test-Path -LiteralPath $row.ArchivePath)) {
                Write-Log -Level 'WARN' -Message ("Archive missing for rollback: {0}" -f $row.ArchivePath)
                $summary.RollbackFilesMissing++
                continue
            }

            $safeName = Get-SafeLogFileName -LogName $row.LogName
            $restorePath = Join-Path -Path $restoreRunFolder -ChildPath ("{0}.evtx" -f $safeName)

            if ($IsDryRun) {
                Write-Log -Message ("DRY RUN - would restore archive copy: {0} -> {1}" -f $row.ArchivePath, $restorePath)
                continue
            }

            Copy-Item -LiteralPath $row.ArchivePath -Destination $restorePath -Force -ErrorAction Stop
            Write-Log -Message ("Restored archive copy: {0} -> {1}" -f $row.ArchivePath, $restorePath)
            $summary.RollbackFilesRestored++
        }
        catch {
            Write-Log -Level 'ERROR' -Message ("Rollback failed for log '{0}': {1}" -f $row.LogName, $_.Exception.Message)
            $summary.LogsFailed++
        }
    }

    Write-Log -Message ("Rollback restore folder: {0}" -f $restoreRunFolder)
}

# Section 6: Main execution flow
# Runs cleanup or rollback mode and prints an end-of-run summary.
try {
    Write-Log -Message ("Script path: {0}" -f $PSCommandPath)
    Write-Log -Message ("Host: {0}" -f $env:COMPUTERNAME)
    Write-Log -Message ("User: {0}" -f $env:USERNAME)

    if ($PSCmdlet.ParameterSetName -eq 'Rollback') {
        Invoke-EventLogRollback -ManifestPath $RollbackManifestPath -IsDryRun:$DryRun.IsPresent
        Write-Summary -Data $summary -Mode $(if ($DryRun) { 'Rollback-DryRun' } else { 'Rollback' })
    }
    else {
        Invoke-EventLogCleanup -AgeInDays $OlderThanDays -IsDryRun:$DryRun.IsPresent -SelectedLogNames $LogNames
        Write-Summary -Data $summary -Mode $(if ($DryRun) { 'Cleanup-DryRun' } else { 'Cleanup' })
    }
}
catch {
    Write-Log -Level 'ERROR' -Message ("Fatal error: {0}" -f $_.Exception.Message)
    Write-Summary -Data $summary -Mode 'Aborted'
    throw
}
