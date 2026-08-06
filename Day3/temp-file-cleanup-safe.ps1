#requires -Version 5.1
<#!
.SYNOPSIS
Safely cleans up temp files on a Windows endpoint with dry-run, logging, and rollback support.

.DESCRIPTION
In cleanup mode, this script targets files in temp locations that are older than a configurable
number of days and moves them into a timestamped rollback store instead of permanently deleting them.
That provides a safe rollback path.

In dry-run mode, the script only prints and logs the files it would clean up.

In rollback mode, the script restores files from a previously generated manifest.

This script is designed for PowerShell 5.1.
#>

[CmdletBinding(DefaultParameterSetName = 'Cleanup')]
param(
    # Section 0: Cleanup mode parameters
    # These parameters control normal cleanup behavior.
    [Parameter(ParameterSetName = 'Cleanup')]
    [string[]]$TargetPaths = @($env:TEMP, (Join-Path -Path $env:WINDIR -ChildPath 'Temp')),

    [Parameter(ParameterSetName = 'Cleanup')]
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 0,

    [Parameter(ParameterSetName = 'Cleanup')]
    [Parameter(ParameterSetName = 'Rollback')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Cleanup')]
    [Parameter(ParameterSetName = 'Rollback')]
    [string]$WorkingRoot,

    # Section 0A: Rollback mode parameters
    # These parameters control restoration from a previous cleanup run.
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [Alias('EnableRollback')]
    [switch]$Rollback,

    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [Alias('RollbackFromManifest')]
    [string]$RollbackManifestPath
)

# Section 1: Shared run metadata
# This section creates timestamped names and summary counters used throughout the script.
$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
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
    $WorkingRoot = Join-Path -Path $scriptRoot -ChildPath 'cleanup-work'
}

$summary = [ordered]@{
    FilesScanned = 0
    CandidateFiles = 0
    FilesMovedToRollback = 0
    FilesRestored = 0
    FilesSkippedLocked = 0
    FilesSkippedMissing = 0
    FilesSkippedInUse = 0
    FilesSkippedAlreadyExists = 0
    FilesFailed = 0
}

# Section 2: Folder layout
# This section defines where logs, rollback content, and manifests are stored.
$logRoot = Join-Path -Path $scriptRoot -ChildPath 'logs'
$rollbackRoot = Join-Path -Path $WorkingRoot -ChildPath 'rollback'
$manifestRoot = Join-Path -Path $WorkingRoot -ChildPath 'manifests'

# Section 3: Helper functions
# These functions handle logging, path preparation, lock checks, cleanup, rollback, and summary output.
function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

Ensure-Directory -Path $logRoot
Ensure-Directory -Path $rollbackRoot
Ensure-Directory -Path $manifestRoot

$logFile = Join-Path -Path $logRoot -ChildPath ("temp-cleanup-{0}.log" -f $runTimestamp)

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message
    Add-Content -Path $logFile -Value $line
    Write-Output $line
}

function Convert-ToSafeRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $safePath = $FullPath -replace ':', '$' -replace '^[\\/]+', '' -replace '[\\/]+', '\\'
    return $safePath.TrimStart('\\')
}

function Test-FileLocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $fileStream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        $fileStream.Close()
        return $false
    }
    catch {
        return $true
    }
}

function Write-Summary {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

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

function Invoke-Cleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths,

        [Parameter(Mandatory = $true)]
        [int]$AgeInDays,

        [Parameter(Mandatory = $true)]
        [bool]$IsDryRun
    )

    $cutoffDate = (Get-Date).AddDays(-1 * $AgeInDays)
    $runRollbackFolder = Join-Path -Path $rollbackRoot -ChildPath ("run-{0}" -f $runTimestamp)
    $manifestPath = Join-Path -Path $manifestRoot -ChildPath ("manifest-{0}.csv" -f $runTimestamp)
    $manifestRows = New-Object System.Collections.Generic.List[object]

    Ensure-Directory -Path $runRollbackFolder

    Write-Log -Message 'Starting cleanup mode.'
    Write-Log -Message ("DryRun: {0}" -f $IsDryRun)
    Write-Log -Message ("OlderThanDays: {0}" -f $AgeInDays)
    Write-Log -Message ("CutoffDate: {0}" -f $cutoffDate)
    Write-Log -Message ("RollbackFolder: {0}" -f $runRollbackFolder)
    Write-Log -Message ("ManifestPath: {0}" -f $manifestPath)

    foreach ($targetPath in $Paths) {
        if ([string]::IsNullOrWhiteSpace($targetPath)) {
            continue
        }

        if (-not (Test-Path -LiteralPath $targetPath)) {
            Write-Log -Level 'WARN' -Message ("Target path not found, skipping: {0}" -f $targetPath)
            continue
        }

        Write-Log -Message ("Scanning target path: {0}" -f $targetPath)

        try {
            $files = Get-ChildItem -LiteralPath $targetPath -File -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoffDate }
        }
        catch {
            Write-Log -Level 'ERROR' -Message ("Failed to enumerate target path {0}: {1}" -f $targetPath, $_.Exception.Message)
            $summary.FilesFailed++
            continue
        }

        foreach ($file in $files) {
            $summary.FilesScanned++
            $summary.CandidateFiles++

            try {
                if (Test-FileLocked -Path $file.FullName) {
                    Write-Log -Level 'WARN' -Message ("Locked or unavailable, skipped: {0}" -f $file.FullName)
                    $summary.FilesSkippedLocked++
                    continue
                }

                $safeRelativePath = Convert-ToSafeRelativePath -FullPath $file.FullName
                $destinationPath = Join-Path -Path $runRollbackFolder -ChildPath $safeRelativePath
                $destinationDirectory = Split-Path -Path $destinationPath -Parent

                if ($IsDryRun) {
                    Write-Log -Message ("DRY RUN - would move: {0} -> {1}" -f $file.FullName, $destinationPath)
                    continue
                }

                $manifestRows.Add([pscustomobject]@{
                    OriginalPath = $file.FullName
                    RollbackPath = $destinationPath
                    LastWriteTime = $file.LastWriteTime
                    Length = $file.Length
                    CleanedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                }) | Out-Null

                Ensure-Directory -Path $destinationDirectory
                Move-Item -LiteralPath $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                Write-Log -Message ("Moved to rollback store: {0} -> {1}" -f $file.FullName, $destinationPath)
                $summary.FilesMovedToRollback++
            }
            catch {
                Write-Log -Level 'ERROR' -Message ("Failed to process file {0}: {1}" -f $file.FullName, $_.Exception.Message)
                $summary.FilesFailed++
            }
        }
    }

    if ($IsDryRun) {
        Write-Log -Message 'Dry run completed. No manifest written.'
    }
    elseif ($manifestRows.Count -gt 0) {
        $manifestRows | Export-Csv -Path $manifestPath -NoTypeInformation
        Write-Log -Message ("Manifest written: {0}" -f $manifestPath)
    }
    else {
        Write-Log -Message 'No candidate files found. No manifest written.'
    }
}

function Invoke-Rollback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [bool]$IsDryRun
    )

    Write-Log -Message 'Starting rollback mode.'
    Write-Log -Message ("DryRun: {0}" -f $IsDryRun)
    Write-Log -Message ("Rollback manifest: {0}" -f $ManifestPath)

    if ($ManifestPath -match 'YYYYMMDD-HHMMSS') {
        throw 'RollbackManifestPath still contains the README placeholder YYYYMMDD-HHMMSS. Replace it with an actual manifest file name from Day3\cleanup-work\manifests.'
    }

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Rollback manifest not found: $ManifestPath. Use an actual manifest file created by a cleanup run, for example manifest-20260805-051533.csv."
    }

    $manifestRows = Import-Csv -Path $ManifestPath

    foreach ($row in $manifestRows) {
        try {
            if (-not (Test-Path -LiteralPath $row.RollbackPath)) {
                Write-Log -Level 'WARN' -Message ("Rollback source missing, skipped: {0}" -f $row.RollbackPath)
                $summary.FilesSkippedMissing++
                continue
            }

            if (Test-Path -LiteralPath $row.OriginalPath) {
                Write-Log -Level 'WARN' -Message ("Original path already exists, skipped: {0}" -f $row.OriginalPath)
                $summary.FilesSkippedAlreadyExists++
                continue
            }

            if (Test-FileLocked -Path $row.RollbackPath) {
                Write-Log -Level 'WARN' -Message ("Rollback file locked or unavailable, skipped: {0}" -f $row.RollbackPath)
                $summary.FilesSkippedInUse++
                continue
            }

            $originalDirectory = Split-Path -Path $row.OriginalPath -Parent

            if ($IsDryRun) {
                Write-Log -Message ("DRY RUN - would restore: {0} -> {1}" -f $row.RollbackPath, $row.OriginalPath)
                continue
            }

            Ensure-Directory -Path $originalDirectory
            Move-Item -LiteralPath $row.RollbackPath -Destination $row.OriginalPath -Force -ErrorAction Stop
            Write-Log -Message ("Restored file: {0} -> {1}" -f $row.RollbackPath, $row.OriginalPath)
            $summary.FilesRestored++
        }
        catch {
            Write-Log -Level 'ERROR' -Message ("Failed to restore file {0}: {1}" -f $row.OriginalPath, $_.Exception.Message)
            $summary.FilesFailed++
        }
    }
}

# Section 4: Main execution flow
# This section selects cleanup or rollback mode and runs the requested operation.
try {
    Write-Log -Message ("Script path: {0}" -f $PSCommandPath)
    Write-Log -Message ("Host: {0}" -f $env:COMPUTERNAME)
    Write-Log -Message ("User: {0}" -f $env:USERNAME)

    if ($PSCmdlet.ParameterSetName -eq 'Rollback') {
        Invoke-Rollback -ManifestPath $RollbackManifestPath -IsDryRun:$DryRun.IsPresent
        Write-Summary -Data $summary -Mode $(if ($DryRun) { 'Rollback-DryRun' } else { 'Rollback' })
    }
    else {
        Invoke-Cleanup -Paths $TargetPaths -AgeInDays $OlderThanDays -IsDryRun:$DryRun.IsPresent
        Write-Summary -Data $summary -Mode $(if ($DryRun) { 'Cleanup-DryRun' } else { 'Cleanup' })
    }
}
catch {
    Write-Log -Level 'ERROR' -Message ("Fatal error: {0}" -f $_.Exception.Message)
    Write-Summary -Data $summary -Mode 'Aborted'
    throw
}
