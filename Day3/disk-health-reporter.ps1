#requires -Version 5.1
<#!
.SYNOPSIS
Read-only disk health and optimization status reporter for DWP endpoint engineers.

.DESCRIPTION
Collects disk and volume information without changing disk state.

This script MUST remain read-only. It does not call any disk-modifying commands.
Specifically, it does not run:
- Optimize-Volume
- defrag.exe
- Repair-Volume
- Clear-Disk
- Format-Volume
or similar commands that modify disk state.

The script writes only:
- A timestamped log file
- A timestamped CSV report file
#>

[CmdletBinding()]
param(
    # Section 0: Input parameters
    # This section defines runtime options for output location and event lookup window.
    [Parameter(Mandatory = $false)]
    [string]$OutputRoot,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 3650)]
    [int]$OptimizationEventLookbackDays = 30,

    [Parameter(Mandatory = $false)]
    [switch]$SkipOptimizationEventLookup
)

# Section 1: Verification markers before running
# This section flags lines the engineer should verify before execution.
# VERIFY BEFORE RUNNING: Confirm writing logs/reports under the script folder is allowed by local policy.
# VERIFY BEFORE RUNNING: Confirm OptimizationEventLookbackDays (default 30) suits your incident time window.
# VERIFY BEFORE RUNNING: If event log collection is restricted, use -SkipOptimizationEventLookup.
# VERIFY BEFORE RUNNING: This script is designed for PowerShell 5.1 and read-only data collection only.

# Section 2: Shared metadata and defaults
# This section resolves script paths and output file names used throughout the run.
$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$scriptRoot = $null

try {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $scriptRoot = $PSScriptRoot
    }
    elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $scriptRoot = Split-Path -Path $PSCommandPath -Parent
    }
    else {
        $scriptRoot = (Get-Location).Path
    }
}
catch {
    Write-Error ("Failed to resolve script root path. {0}" -f $_.Exception.Message)
    exit 1
}

try {
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        # VERIFY BEFORE RUNNING: Default output root is the script directory.
        $OutputRoot = $scriptRoot
    }
}
catch {
    Write-Error ("Failed to determine output root. {0}" -f $_.Exception.Message)
    exit 1
}

$logRoot = $null
$reportRoot = $null
$logFile = $null
$csvFile = $null

try {
    $logRoot = Join-Path -Path $OutputRoot -ChildPath 'logs'
}
catch {
    Write-Error ("Failed to build log folder path. {0}" -f $_.Exception.Message)
    exit 1
}

try {
    $reportRoot = Join-Path -Path $OutputRoot -ChildPath 'reports'
}
catch {
    Write-Error ("Failed to build report folder path. {0}" -f $_.Exception.Message)
    exit 1
}

try {
    $logFile = Join-Path -Path $logRoot -ChildPath ("disk-health-reporter-{0}.log" -f $runTimestamp)
}
catch {
    Write-Error ("Failed to build log file path. {0}" -f $_.Exception.Message)
    exit 1
}

try {
    $csvFile = Join-Path -Path $reportRoot -ChildPath ("disk-health-report-{0}.csv" -f $runTimestamp)
}
catch {
    Write-Error ("Failed to build CSV file path. {0}" -f $_.Exception.Message)
    exit 1
}

# Section 3: Summary counters
# This section tracks final totals required by engineering reporting.
$summary = [ordered]@{
    TotalDisksChecked = 0
    HealthyDisks = 0
    WarningOrUnhealthyDisks = 0
    SkippedChecks = 0
    Errors = 0
}

# Section 4: Helper functions
# This section provides reusable functions for logging, safe directory creation, and status normalization.
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
        Write-Warning ("Log write failed: {0}" -f $_.Exception.Message)
        $summary.Errors++
    }

    Write-Output $line
}

function Convert-ToSizeGB {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Bytes
    )

    try {
        if ($null -eq $Bytes) {
            return $null
        }

        return [math]::Round(([double]$Bytes / 1GB), 2)
    }
    catch {
        $summary.Errors++
        Write-Log -Level 'WARN' -Message ("Failed to convert bytes to GB: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Convert-ToPercent {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Numerator,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Denominator
    )

    try {
        if ($null -eq $Numerator -or $null -eq $Denominator) {
            return $null
        }

        if ([double]$Denominator -le 0) {
            return $null
        }

        return [math]::Round((([double]$Numerator / [double]$Denominator) * 100), 2)
    }
    catch {
        $summary.Errors++
        Write-Log -Level 'WARN' -Message ("Failed to calculate percent value: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Normalize-StatusText {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$StatusValue
    )

    try {
        if ($null -eq $StatusValue) {
            return 'Unavailable'
        }

        if ($StatusValue -is [System.Array]) {
            if ($StatusValue.Count -eq 0) {
                return 'Unavailable'
            }

            return ($StatusValue | ForEach-Object { $_.ToString() }) -join '; '
        }

        $text = $StatusValue.ToString()
        if ([string]::IsNullOrWhiteSpace($text)) {
            return 'Unavailable'
        }

        return $text
    }
    catch {
        $summary.Errors++
        Write-Log -Level 'WARN' -Message ("Failed to normalize status text: {0}" -f $_.Exception.Message)
        return 'Unavailable'
    }
}

function Test-IsWarningStatus {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$StatusTexts
    )

    try {
        if ($null -eq $StatusTexts) {
            return $false
        }

        $warningTokens = @(
            'warning',
            'unhealthy',
            'failed',
            'offline',
            'critical',
            'lost communication',
            'predictive failure',
            'error',
            'degraded'
        )

        foreach ($status in $StatusTexts) {
            if ([string]::IsNullOrWhiteSpace($status)) {
                continue
            }

            $statusLower = $status.ToLowerInvariant()
            foreach ($token in $warningTokens) {
                if ($statusLower.Contains($token)) {
                    return $true
                }
            }
        }

        return $false
    }
    catch {
        $summary.Errors++
        Write-Log -Level 'WARN' -Message ("Failed to evaluate warning status text: {0}" -f $_.Exception.Message)
        return $true
    }
}

function Get-LatestOptimizationStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter,

        [Parameter(Mandatory = $true)]
        [int]$LookbackDays
    )

    $result = [ordered]@{
        OptimizationStatus = 'NotChecked'
        OptimizationEventTime = $null
        OptimizationEventId = $null
        OptimizationEventMessage = 'Lookup not attempted.'
        Skipped = $false
        Error = $false
    }

    try {
        $logName = 'Microsoft-Windows-Defrag/Operational'
        $startTime = (Get-Date).AddDays(-1 * $LookbackDays)

        $eventFilter = @{
            LogName = $logName
            StartTime = $startTime
        }

        $events = Get-WinEvent -FilterHashtable $eventFilter -ErrorAction Stop

        $drivePattern = "\({0}:\)" -f [regex]::Escape($DriveLetter)

        $latestDriveEvent = $events |
            Where-Object { $_.Message -match $drivePattern } |
            Sort-Object -Property TimeCreated -Descending |
            Select-Object -First 1

        if ($null -eq $latestDriveEvent) {
            $result.OptimizationStatus = 'NoRecentData'
            $result.OptimizationEventMessage = ("No optimization or analysis events found in {0} for drive {1}: within lookback window." -f $logName, $DriveLetter)
            return [pscustomobject]$result
        }

        $trimmedMessage = $latestDriveEvent.Message
        if (-not [string]::IsNullOrWhiteSpace($trimmedMessage)) {
            $trimmedMessage = $trimmedMessage.Trim()
            if ($trimmedMessage.Length -gt 220) {
                $trimmedMessage = $trimmedMessage.Substring(0, 220) + '...'
            }
        }

        $result.OptimizationStatus = 'EventFound'
        $result.OptimizationEventTime = $latestDriveEvent.TimeCreated
        $result.OptimizationEventId = $latestDriveEvent.Id
        $result.OptimizationEventMessage = $trimmedMessage

        return [pscustomobject]$result
    }
    catch {
        $result.OptimizationStatus = 'Skipped'
        $result.OptimizationEventMessage = ("Event log lookup failed: {0}" -f $_.Exception.Message)
        $result.Skipped = $true
        $result.Error = $true
        return [pscustomobject]$result
    }
}

# Section 5: Initialization and safety banner
# This section prepares output folders and records safety constraints in the log.
try {
    Ensure-Directory -Path $logRoot
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

try {
    Ensure-Directory -Path $reportRoot
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

Write-Log -Message 'Starting disk health reporter in strict read-only mode.'
Write-Log -Message 'Safety guard: script does not call Optimize-Volume, defrag.exe, Repair-Volume, Clear-Disk, or Format-Volume.'
Write-Log -Message ("OutputRoot: {0}" -f $OutputRoot)
Write-Log -Message ("LogFile: {0}" -f $logFile)
Write-Log -Message ("CsvFile: {0}" -f $csvFile)
Write-Log -Message ("OptimizationEventLookbackDays: {0}" -f $OptimizationEventLookbackDays)
Write-Log -Message ("SkipOptimizationEventLookup: {0}" -f $SkipOptimizationEventLookup.IsPresent)

# Section 6: Preload optional data sources
# This section checks whether optional storage cmdlets are available and preloads physical disk data.
$storageCmdletAvailability = [ordered]@{
    GetVolume = $false
    GetPartition = $false
    GetDisk = $false
    GetPhysicalDisk = $false
}

try {
    $null = Get-Command -Name Get-Volume -ErrorAction Stop
    $storageCmdletAvailability.GetVolume = $true
}
catch {
    $summary.SkippedChecks++
    Write-Log -Level 'WARN' -Message ("Get-Volume not available. Volume health fields may be unavailable. {0}" -f $_.Exception.Message)
}

try {
    $null = Get-Command -Name Get-Partition -ErrorAction Stop
    $storageCmdletAvailability.GetPartition = $true
}
catch {
    $summary.SkippedChecks++
    Write-Log -Level 'WARN' -Message ("Get-Partition not available. Disk mapping may be unavailable. {0}" -f $_.Exception.Message)
}

try {
    $null = Get-Command -Name Get-Disk -ErrorAction Stop
    $storageCmdletAvailability.GetDisk = $true
}
catch {
    $summary.SkippedChecks++
    Write-Log -Level 'WARN' -Message ("Get-Disk not available. Disk health fields may be unavailable. {0}" -f $_.Exception.Message)
}

try {
    $null = Get-Command -Name Get-PhysicalDisk -ErrorAction Stop
    $storageCmdletAvailability.GetPhysicalDisk = $true
}
catch {
    $summary.SkippedChecks++
    Write-Log -Level 'WARN' -Message ("Get-PhysicalDisk not available. Media type fields may be unavailable. {0}" -f $_.Exception.Message)
}

$physicalDiskCache = @()
if ($storageCmdletAvailability.GetPhysicalDisk) {
    try {
        $physicalDiskCache = @(Get-PhysicalDisk -ErrorAction Stop)
        Write-Log -Message ("Loaded physical disk cache entries: {0}" -f $physicalDiskCache.Count)
    }
    catch {
        $summary.Errors++
        $summary.SkippedChecks++
        Write-Log -Level 'WARN' -Message ("Unable to preload physical disk data: {0}" -f $_.Exception.Message)
        $physicalDiskCache = @()
    }
}

# Section 7: Collect local disk list
# This section retrieves all local disks (DriveType=3) from Win32_LogicalDisk.
$localDisks = @()
try {
    $localDisks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" -ErrorAction Stop)
    Write-Log -Message ("Detected local disks: {0}" -f $localDisks.Count)
}
catch {
    $summary.Errors++
    Write-Log -Level 'ERROR' -Message ("Failed to retrieve local disks from Win32_LogicalDisk: {0}" -f $_.Exception.Message)
    Write-Output ''
    Write-Output 'Disk Health Reporter Summary'
    Write-Output ('Total disks checked: {0}' -f $summary.TotalDisksChecked)
    Write-Output ('Healthy disks: {0}' -f $summary.HealthyDisks)
    Write-Output ('Warning or unhealthy disks: {0}' -f $summary.WarningOrUnhealthyDisks)
    Write-Output ('Skipped checks: {0}' -f $summary.SkippedChecks)
    Write-Output ('Errors: {0}' -f $summary.Errors)
    exit 1
}

# Section 8: Per-disk read-only analysis
# This section gathers volume, physical disk, and optimization status for each local disk.
$results = New-Object System.Collections.Generic.List[object]

foreach ($disk in $localDisks) {
    $summary.TotalDisksChecked++

    $driveLetter = $null
    $volumeLabel = 'Unavailable'
    $fileSystem = 'Unavailable'
    $totalSizeGB = $null
    $freeSpaceGB = $null
    $freePercent = $null
    $volumeHealthStatus = 'Unavailable'
    $volumeOperationalStatus = 'Unavailable'
    $diskHealthStatus = 'Unavailable'
    $diskOperationalStatus = 'Unavailable'
    $physicalMediaType = 'Unavailable'
    $physicalHealthStatus = 'Unavailable'
    $physicalOperationalStatus = 'Unavailable'
    $optimizationStatus = 'NotChecked'
    $optimizationEventTime = $null
    $optimizationEventId = $null
    $optimizationEventMessage = 'Not collected.'
    $classification = 'Unknown'
    $diskWarnings = @()

    try {
        $driveLetter = $disk.DeviceID.TrimEnd(':')
        Write-Log -Message ("Collecting disk data for drive {0}:" -f $driveLetter)
    }
    catch {
        $summary.Errors++
        $summary.SkippedChecks++
        Write-Log -Level 'WARN' -Message ("Unable to parse drive letter. {0}" -f $_.Exception.Message)
        continue
    }

    try {
        $volumeLabel = if ([string]::IsNullOrWhiteSpace($disk.VolumeName)) { 'NoLabel' } else { $disk.VolumeName }
    }
    catch {
        $summary.Errors++
        $summary.SkippedChecks++
        Write-Log -Level 'WARN' -Message ("Failed to read volume label for {0}: {1}" -f $driveLetter, $_.Exception.Message)
    }

    try {
        $fileSystem = if ([string]::IsNullOrWhiteSpace($disk.FileSystem)) { 'Unavailable' } else { $disk.FileSystem }
    }
    catch {
        $summary.Errors++
        $summary.SkippedChecks++
        Write-Log -Level 'WARN' -Message ("Failed to read file system for {0}: {1}" -f $driveLetter, $_.Exception.Message)
    }

    try {
        $totalSizeGB = Convert-ToSizeGB -Bytes $disk.Size
    }
    catch {
        $summary.Errors++
        $summary.SkippedChecks++
        Write-Log -Level 'WARN' -Message ("Failed to read total size for {0}: {1}" -f $driveLetter, $_.Exception.Message)
    }

    try {
        $freeSpaceGB = Convert-ToSizeGB -Bytes $disk.FreeSpace
    }
    catch {
        $summary.Errors++
        $summary.SkippedChecks++
        Write-Log -Level 'WARN' -Message ("Failed to read free space for {0}: {1}" -f $driveLetter, $_.Exception.Message)
    }

    try {
        $freePercent = Convert-ToPercent -Numerator $disk.FreeSpace -Denominator $disk.Size
    }
    catch {
        $summary.Errors++
        $summary.SkippedChecks++
        Write-Log -Level 'WARN' -Message ("Failed to calculate free percent for {0}: {1}" -f $driveLetter, $_.Exception.Message)
    }

    if ($storageCmdletAvailability.GetVolume) {
        try {
            $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
            $volumeHealthStatus = Normalize-StatusText -StatusValue $volume.HealthStatus
            $volumeOperationalStatus = Normalize-StatusText -StatusValue $volume.OperationalStatus
        }
        catch {
            $summary.Errors++
            $summary.SkippedChecks++
            Write-Log -Level 'WARN' -Message ("Get-Volume failed for {0}: {1}" -f $driveLetter, $_.Exception.Message)
        }
    }
    else {
        $summary.SkippedChecks++
    }

    $mappedDiskNumber = $null
    $mappedDiskFriendlyName = $null

    if ($storageCmdletAvailability.GetPartition) {
        try {
            $partition = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop | Select-Object -First 1
            if ($null -ne $partition) {
                $mappedDiskNumber = $partition.DiskNumber
            }
            else {
                $summary.SkippedChecks++
                Write-Log -Level 'WARN' -Message ("No partition mapping found for drive {0}." -f $driveLetter)
            }
        }
        catch {
            $summary.Errors++
            $summary.SkippedChecks++
            Write-Log -Level 'WARN' -Message ("Get-Partition failed for {0}: {1}" -f $driveLetter, $_.Exception.Message)
        }
    }
    else {
        $summary.SkippedChecks++
    }

    if ($null -ne $mappedDiskNumber -and $storageCmdletAvailability.GetDisk) {
        $diskObject = $null
        try {
            $diskObject = Get-Disk -Number $mappedDiskNumber -ErrorAction Stop
            $diskHealthStatus = Normalize-StatusText -StatusValue $diskObject.HealthStatus
            $diskOperationalStatus = Normalize-StatusText -StatusValue $diskObject.OperationalStatus
            $mappedDiskFriendlyName = $diskObject.FriendlyName
        }
        catch {
            $summary.Errors++
            $summary.SkippedChecks++
            Write-Log -Level 'WARN' -Message ("Get-Disk failed for disk number {0} ({1}:): {2}" -f $mappedDiskNumber, $driveLetter, $_.Exception.Message)
        }

        if ($null -ne $diskObject -and $storageCmdletAvailability.GetPhysicalDisk -and $physicalDiskCache.Count -gt 0) {
            try {
                $physicalDiskMatch = $physicalDiskCache |
                    Where-Object {
                        ($_.DeviceId -eq $mappedDiskNumber) -or
                        ((-not [string]::IsNullOrWhiteSpace($_.FriendlyName)) -and ($_.FriendlyName -eq $mappedDiskFriendlyName))
                    } |
                    Select-Object -First 1

                if ($null -ne $physicalDiskMatch) {
                    $physicalMediaType = Normalize-StatusText -StatusValue $physicalDiskMatch.MediaType
                    $physicalHealthStatus = Normalize-StatusText -StatusValue $physicalDiskMatch.HealthStatus
                    $physicalOperationalStatus = Normalize-StatusText -StatusValue $physicalDiskMatch.OperationalStatus
                }
                else {
                    $summary.SkippedChecks++
                    Write-Log -Level 'WARN' -Message ("No physical disk match found for drive {0}: (DiskNumber {1})." -f $driveLetter, $mappedDiskNumber)
                }
            }
            catch {
                $summary.Errors++
                $summary.SkippedChecks++
                Write-Log -Level 'WARN' -Message ("Physical disk mapping failed for {0}: {1}" -f $driveLetter, $_.Exception.Message)
            }
        }
        elseif (-not $storageCmdletAvailability.GetPhysicalDisk) {
            $summary.SkippedChecks++
        }
    }
    else {
        if ($null -eq $mappedDiskNumber) {
            $summary.SkippedChecks++
        }

        if (-not $storageCmdletAvailability.GetDisk) {
            $summary.SkippedChecks++
        }
    }

    if ($SkipOptimizationEventLookup.IsPresent) {
        $optimizationStatus = 'SkippedByParameter'
        $optimizationEventMessage = 'Skipped because -SkipOptimizationEventLookup was provided.'
        $summary.SkippedChecks++
    }
    else {
        try {
            $optimizationData = Get-LatestOptimizationStatus -DriveLetter $driveLetter -LookbackDays $OptimizationEventLookbackDays
            $optimizationStatus = $optimizationData.OptimizationStatus
            $optimizationEventTime = $optimizationData.OptimizationEventTime
            $optimizationEventId = $optimizationData.OptimizationEventId
            $optimizationEventMessage = $optimizationData.OptimizationEventMessage

            if ($optimizationData.Skipped) {
                $summary.SkippedChecks++
            }

            if ($optimizationData.Error) {
                $summary.Errors++
                Write-Log -Level 'WARN' -Message ("Optimization status lookup failed for {0}: {1}" -f $driveLetter, $optimizationEventMessage)
            }
        }
        catch {
            $summary.Errors++
            $summary.SkippedChecks++
            $optimizationStatus = 'Skipped'
            $optimizationEventMessage = ("Optimization status lookup failed with exception: {0}" -f $_.Exception.Message)
            Write-Log -Level 'WARN' -Message ("Optimization status lookup exception for {0}: {1}" -f $driveLetter, $_.Exception.Message)
        }
    }

    try {
        $statusTextsToCheck = @(
            $volumeHealthStatus,
            $volumeOperationalStatus,
            $diskHealthStatus,
            $diskOperationalStatus,
            $physicalHealthStatus,
            $physicalOperationalStatus
        )

        $hasWarningStatus = Test-IsWarningStatus -StatusTexts $statusTextsToCheck

        $availableHealthStatusCount = @(
            $volumeHealthStatus,
            $diskHealthStatus,
            $physicalHealthStatus
        ) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne 'Unavailable' } |
        Measure-Object |
        Select-Object -ExpandProperty Count

        if ($hasWarningStatus) {
            $classification = 'WarningOrUnhealthy'
            $summary.WarningOrUnhealthyDisks++
        }
        elseif ($availableHealthStatusCount -gt 0) {
            $classification = 'Healthy'
            $summary.HealthyDisks++
        }
        else {
            $classification = 'WarningOrUnhealthy'
            $summary.WarningOrUnhealthyDisks++
            $diskWarnings += 'No health status available from storage providers.'
        }
    }
    catch {
        $summary.Errors++
        $classification = 'WarningOrUnhealthy'
        $summary.WarningOrUnhealthyDisks++
        $diskWarnings += ("Classification fallback applied due to exception: {0}" -f $_.Exception.Message)
    }

    try {
        $row = [pscustomobject]@{
            ComputerName = $env:COMPUTERNAME
            CollectedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            DriveLetter = $driveLetter
            VolumeLabel = $volumeLabel
            FileSystem = $fileSystem
            TotalSizeGB = $totalSizeGB
            FreeSpaceGB = $freeSpaceGB
            FreeSpacePercent = $freePercent
            VolumeHealthStatus = $volumeHealthStatus
            VolumeOperationalStatus = $volumeOperationalStatus
            DiskHealthStatus = $diskHealthStatus
            DiskOperationalStatus = $diskOperationalStatus
            PhysicalMediaType = $physicalMediaType
            PhysicalHealthStatus = $physicalHealthStatus
            PhysicalOperationalStatus = $physicalOperationalStatus
            OptimizationStatus = $optimizationStatus
            OptimizationEventTime = $optimizationEventTime
            OptimizationEventId = $optimizationEventId
            OptimizationEventMessage = $optimizationEventMessage
            Classification = $classification
            Notes = if ($diskWarnings.Count -gt 0) { $diskWarnings -join '; ' } else { '' }
        }

        $results.Add($row) | Out-Null
        Write-Log -Message ("Completed drive {0}: classification {1}." -f $driveLetter, $classification)
    }
    catch {
        $summary.Errors++
        Write-Log -Level 'ERROR' -Message ("Failed to build output row for drive {0}: {1}" -f $driveLetter, $_.Exception.Message)
    }
}

# Section 9: CSV export
# This section exports the collected report rows to a timestamped CSV file.
try {
    $results |
        Sort-Object -Property DriveLetter |
        Export-Csv -LiteralPath $csvFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop

    Write-Log -Message ("CSV report exported successfully: {0}" -f $csvFile)
}
catch {
    $summary.Errors++
    Write-Log -Level 'ERROR' -Message ("Failed to export CSV report: {0}" -f $_.Exception.Message)
}

# Section 10: Final summary
# This section logs and prints end-of-run counters required by the request.
Write-Log -Message ('=' * 72)
Write-Log -Message 'Run summary:'
Write-Log -Message ('Total disks checked: {0}' -f $summary.TotalDisksChecked)
Write-Log -Message ('Healthy disks: {0}' -f $summary.HealthyDisks)
Write-Log -Message ('Warning or unhealthy disks: {0}' -f $summary.WarningOrUnhealthyDisks)
Write-Log -Message ('Skipped checks: {0}' -f $summary.SkippedChecks)
Write-Log -Message ('Errors: {0}' -f $summary.Errors)
Write-Log -Message ('CSV file: {0}' -f $csvFile)
Write-Log -Message ('Log file: {0}' -f $logFile)

Write-Output ''
Write-Output ('=' * 72)
Write-Output 'Disk Health Reporter Summary'
Write-Output ('Total disks checked: {0}' -f $summary.TotalDisksChecked)
Write-Output ('Healthy disks: {0}' -f $summary.HealthyDisks)
Write-Output ('Warning or unhealthy disks: {0}' -f $summary.WarningOrUnhealthyDisks)
Write-Output ('Skipped checks: {0}' -f $summary.SkippedChecks)
Write-Output ('Errors: {0}' -f $summary.Errors)
Write-Output ('CSV file: {0}' -f $csvFile)
Write-Output ('Log file: {0}' -f $logFile)

# Section 11: Idempotence note
# This script is idempotent regarding endpoint disk state because it only reads data and writes
# new timestamped log/report files. It does not alter disks, volumes, partitions, or file systems.
