#requires -Version 5.1
<#!
.SYNOPSIS
Finds and reports large files on a Windows endpoint in a strictly read-only way.

.DESCRIPTION
This script scans a target folder for files larger than a size threshold and exports a report.
It never deletes, moves, renames, compresses, or modifies scanned files.

The only write operations are:
- Writing a timestamped log file
- Writing a timestamped CSV report file

Designed for PowerShell 5.1.
#>

[CmdletBinding()]
param(
    # Section 0: Input parameters
    # This section defines what the engineer can configure at runtime.
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1048576)]
    [double]$ThresholdMB = 100,

    [Parameter(Mandatory = $false)]
    [string]$ScanPath
)

# Section 1: Verification markers before running
# This section flags lines the engineer should verify for their environment.
# VERIFY BEFORE RUNNING: Confirm the default threshold of 100 MB is suitable for this endpoint.
# VERIFY BEFORE RUNNING: Confirm the default scan location (current user's profile) is appropriate.
# VERIFY BEFORE RUNNING: Confirm output folders under this script location are allowed by local policy.

# Section 2: Shared metadata and defaults
# This section resolves paths and creates run metadata used by logging and output files.
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

if ([string]::IsNullOrWhiteSpace($ScanPath)) {
    # VERIFY BEFORE RUNNING: This defaults to the current user profile when -ScanPath is omitted.
    $ScanPath = $env:USERPROFILE
}

# Section 3: Output locations for logs and reports
# This section defines where the script writes run artifacts.
$logRoot = Join-Path -Path $scriptRoot -ChildPath 'logs'
$reportRoot = Join-Path -Path $scriptRoot -ChildPath 'reports'
$logFile = Join-Path -Path $logRoot -ChildPath ("large-file-finder-{0}.log" -f $runTimestamp)
$csvFile = Join-Path -Path $reportRoot -ChildPath ("large-file-report-{0}.csv" -f $runTimestamp)

# Section 4: Summary counters
# This section tracks scan outcomes and is printed at the end.
$summary = [ordered]@{
    TotalFilesScanned = 0
    LargeFilesFound = 0
    SkippedItems = 0
    Errors = 0
}

# Section 5: Helper functions
# This section contains reusable functions for directory setup and logging.
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
        throw "Failed to create or validate directory [$Path]. $($_.Exception.Message)"
    }
}

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

    try {
        Add-Content -Path $logFile -Value $line -ErrorAction Stop
    }
    catch {
        # If logging fails, still write to console so the run remains observable.
        Write-Warning ("Log write failed: {0}" -f $_.Exception.Message)
        $summary.Errors++
    }

    Write-Output $line
}

function Get-FileOwnerSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        return $acl.Owner
    }
    catch {
        $summary.Errors++
        Write-Log -Level 'WARN' -Message ("Owner lookup failed for [{0}]: {1}" -f $Path, $_.Exception.Message)
        return 'Unavailable'
    }
}

# Section 6: Script initialization
# This section validates inputs and prepares the output folders.
try {
    Ensure-Directory -Path $logRoot
    Ensure-Directory -Path $reportRoot
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

Write-Log -Message 'Starting large file scan (read-only mode).'
Write-Log -Message ("ThresholdMB: {0}" -f $ThresholdMB)
Write-Log -Message ("ScanPath: {0}" -f $ScanPath)
Write-Log -Message ("LogFile: {0}" -f $logFile)
Write-Log -Message ("CsvFile: {0}" -f $csvFile)

try {
    if (-not (Test-Path -LiteralPath $ScanPath)) {
        throw "Scan path does not exist: $ScanPath"
    }
}
catch {
    Write-Log -Level 'ERROR' -Message $_.Exception.Message
    $summary.Errors++
    Write-Output ''
    Write-Output 'Summary'
    Write-Output ('Total files scanned: {0}' -f $summary.TotalFilesScanned)
    Write-Output ('Large files found: {0}' -f $summary.LargeFilesFound)
    Write-Output ('Skipped items: {0}' -f $summary.SkippedItems)
    Write-Output ('Errors: {0}' -f $summary.Errors)
    exit 1
}

# Section 7: Read-only recursive scanning engine
# This section traverses directories safely and continues on access errors.
$results = New-Object System.Collections.Generic.List[object]
$pendingDirs = New-Object System.Collections.Generic.Queue[string]
$pendingDirs.Enqueue($ScanPath)

while ($pendingDirs.Count -gt 0) {
    $currentDir = $pendingDirs.Dequeue()
    Write-Log -Message ("Scanning directory: {0}" -f $currentDir)

    try {
        $items = Get-ChildItem -LiteralPath $currentDir -Force -ErrorAction Stop
    }
    catch {
        $summary.SkippedItems++
        $summary.Errors++
        Write-Log -Level 'WARN' -Message ("Access denied or unreadable directory skipped [{0}]: {1}" -f $currentDir, $_.Exception.Message)
        continue
    }

    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            $pendingDirs.Enqueue($item.FullName)
            continue
        }

        $summary.TotalFilesScanned++

        try {
            $sizeMB = [math]::Round(($item.Length / 1MB), 2)

            if ($item.Length -gt ($ThresholdMB * 1MB)) {
                $owner = Get-FileOwnerSafe -Path $item.FullName

                $result = [pscustomobject]@{
                    FileName = $item.Name
                    FullPath = $item.FullName
                    SizeMB = $sizeMB
                    LastModified = $item.LastWriteTime
                    Owner = $owner
                }

                $results.Add($result) | Out-Null
                $summary.LargeFilesFound++

                Write-Log -Message ("Large file found: {0} ({1} MB)" -f $item.FullName, $sizeMB)
            }
        }
        catch {
            $summary.SkippedItems++
            $summary.Errors++
            Write-Log -Level 'WARN' -Message ("File processing skipped [{0}]: {1}" -f $item.FullName, $_.Exception.Message)
            continue
        }
    }
}

# Section 8: CSV export
# This section writes the report to a timestamped CSV file.
try {
    $results |
        Sort-Object -Property SizeMB -Descending |
        Export-Csv -LiteralPath $csvFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop

    Write-Log -Message ("CSV report exported successfully: {0}" -f $csvFile)
}
catch {
    $summary.Errors++
    Write-Log -Level 'ERROR' -Message ("Failed to export CSV report: {0}" -f $_.Exception.Message)
}

# Section 9: Final summary output
# This section prints and logs the run totals for engineering reporting.
Write-Log -Message ('=' * 70)
Write-Log -Message ('Run summary:')
Write-Log -Message ('Total files scanned: {0}' -f $summary.TotalFilesScanned)
Write-Log -Message ('Large files found: {0}' -f $summary.LargeFilesFound)
Write-Log -Message ('Skipped items: {0}' -f $summary.SkippedItems)
Write-Log -Message ('Errors: {0}' -f $summary.Errors)
Write-Log -Message ('CSV file: {0}' -f $csvFile)
Write-Log -Message ('Log file: {0}' -f $logFile)

Write-Output ''
Write-Output ('=' * 70)
Write-Output 'Large File Finder Summary'
Write-Output ('Total files scanned: {0}' -f $summary.TotalFilesScanned)
Write-Output ('Large files found: {0}' -f $summary.LargeFilesFound)
Write-Output ('Skipped items: {0}' -f $summary.SkippedItems)
Write-Output ('Errors: {0}' -f $summary.Errors)
Write-Output ('CSV file: {0}' -f $csvFile)
Write-Output ('Log file: {0}' -f $logFile)

# Section 10: Idempotence and safety note
# This script is idempotent regarding endpoint data because it only reads file metadata
# and generates report artifacts (log and CSV). It does not alter scanned files.
