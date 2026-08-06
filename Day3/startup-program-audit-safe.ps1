#requires -Version 5.1
<#!
.SYNOPSIS
Safely audits, disables, and restores Windows startup programs on endpoints.

.DESCRIPTION
This script is designed for production-safe startup program management:
- Lists startup items from common registry and startup folder locations.
- Supports dry run mode for no-change previews.
- Disables startup items by name only after rollback data is captured.
- Restores disabled items from a rollback state file.
- Logs every action to a timestamped log file.

Compatible with PowerShell 5.1.
#>

[CmdletBinding(DefaultParameterSetName = 'List')]
param(
    # Section 0: Shared mode parameters
    # Dry run previews actions without making changes.
    [Parameter(ParameterSetName = 'List')]
    [Parameter(ParameterSetName = 'Disable')]
    [Parameter(ParameterSetName = 'Rollback')]
    [switch]$DryRun,

    # Section 0A: Disable mode parameters
    # Disable a startup item by its display name.
    [Parameter(Mandatory = $true, ParameterSetName = 'Disable')]
    [Alias('Disable')]
    [string]$DisableName,

    # Section 0B: Rollback mode parameters
    # Restore startup items from a previous rollback state file.
    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [switch]$Rollback,

    [Parameter(Mandatory = $true, ParameterSetName = 'Rollback')]
    [Alias('RollbackFrom')]
    [string]$RollbackFile,

    # Section 0C: Optional working root override
    # Controls where logs, backups, and state files are stored.
    [Parameter(ParameterSetName = 'List')]
    [Parameter(ParameterSetName = 'Disable')]
    [Parameter(ParameterSetName = 'Rollback')]
    [string]$WorkingRoot
)

# Section 1: Runtime metadata and default paths
# This section creates stable root paths and summary counters for the run.
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
    $WorkingRoot = Join-Path -Path $scriptRoot -ChildPath 'startup-work'
}

$logRoot = Join-Path -Path $scriptRoot -ChildPath 'logs'
$registryBackupRoot = Join-Path -Path $WorkingRoot -ChildPath 'registry-backups'
$startupFileBackupRoot = Join-Path -Path $WorkingRoot -ChildPath 'startup-file-backups'
$rollbackStateRoot = Join-Path -Path $WorkingRoot -ChildPath 'rollback-state'

$summary = [ordered]@{
    TotalStartupItemsFound = 0
    ItemsListed = New-Object System.Collections.Generic.List[string]
    ItemsDisabled = New-Object System.Collections.Generic.List[string]
    ItemsSkipped = New-Object System.Collections.Generic.List[string]
    ErrorsEncountered = New-Object System.Collections.Generic.List[string]
    RollbackFileOrBackupLocation = 'Not generated'
}

# Section 2: Location definitions for startup item discovery
# These are the requested common startup locations across user and machine scope.
$registryLocations = @(
    [pscustomobject]@{
        Scope = 'CurrentUser'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        HivePathForRegExe = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'
    },
    [pscustomobject]@{
        Scope = 'LocalMachine'
        Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
        HivePathForRegExe = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Run'
    }
)

$startupFolderLocations = @(
    [pscustomobject]@{
        Scope = 'CurrentUser'
        Path = [Environment]::GetFolderPath('Startup')
    },
    [pscustomobject]@{
        Scope = 'Common'
        Path = [Environment]::GetFolderPath('CommonStartup')
    }
)

# Section 3: Utility functions
# Helpers for directory setup, logging, and consistent summary output.
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
Ensure-Directory -Path $registryBackupRoot
Ensure-Directory -Path $startupFileBackupRoot
Ensure-Directory -Path $rollbackStateRoot

$logFile = Join-Path -Path $logRoot -ChildPath ("startup-audit-{0}.log" -f $runTimestamp)

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
    Write-Host $line
}

function Add-SummaryError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $summary.ErrorsEncountered.Add($Message) | Out-Null
    Write-Log -Level 'ERROR' -Message $Message
}

function Write-Summary {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Data
    )

    Write-Output ''
    Write-Output ('=' * 80)
    Write-Output 'Startup Program Management Summary'
    Write-Output ('=' * 80)
    Write-Output ("Total startup items found: {0}" -f $Data.TotalStartupItemsFound)

    Write-Output ''
    Write-Output 'Items listed:'
    if ($Data.ItemsListed.Count -gt 0) {
        foreach ($item in $Data.ItemsListed) {
            Write-Output (" - {0}" -f $item)
        }
    }
    else {
        Write-Output ' - None'
    }

    Write-Output ''
    Write-Output 'Items disabled:'
    if ($Data.ItemsDisabled.Count -gt 0) {
        foreach ($item in $Data.ItemsDisabled) {
            Write-Output (" - {0}" -f $item)
        }
    }
    else {
        Write-Output ' - None'
    }

    Write-Output ''
    Write-Output 'Items skipped:'
    if ($Data.ItemsSkipped.Count -gt 0) {
        foreach ($item in $Data.ItemsSkipped) {
            Write-Output (" - {0}" -f $item)
        }
    }
    else {
        Write-Output ' - None'
    }

    Write-Output ''
    Write-Output 'Errors encountered:'
    if ($Data.ErrorsEncountered.Count -gt 0) {
        foreach ($err in $Data.ErrorsEncountered) {
            Write-Output (" - {0}" -f $err)
        }
    }
    else {
        Write-Output ' - None'
    }

    Write-Output ''
    Write-Output ("Rollback file or backup location: {0}" -f $Data.RollbackFileOrBackupLocation)
    Write-Output ("Log file: {0}" -f $logFile)

    Write-Log -Message ('=' * 80)
    Write-Log -Message 'Summary written to console.'
    Write-Log -Message ("Total startup items found: {0}" -f $Data.TotalStartupItemsFound)
    Write-Log -Message ("Items listed count: {0}" -f $Data.ItemsListed.Count)
    Write-Log -Message ("Items disabled count: {0}" -f $Data.ItemsDisabled.Count)
    Write-Log -Message ("Items skipped count: {0}" -f $Data.ItemsSkipped.Count)
    Write-Log -Message ("Errors encountered count: {0}" -f $Data.ErrorsEncountered.Count)
    Write-Log -Message ("Rollback file or backup location: {0}" -f $Data.RollbackFileOrBackupLocation)
    Write-Log -Message ("Log file: {0}" -f $logFile)
}

# Section 4: Startup item discovery
# Reads startup entries from registry Run keys and startup folders.
function Get-StartupItems {
    $items = New-Object System.Collections.Generic.List[object]

    foreach ($regLoc in $registryLocations) {
        try {
            if (-not (Test-Path -LiteralPath $regLoc.Path)) {
                Write-Log -Level 'WARN' -Message ("Registry path not found, skipping: {0}" -f $regLoc.Path)
                continue
            }

            $key = Get-Item -LiteralPath $regLoc.Path -ErrorAction Stop
            $values = $key.GetValueNames()

            foreach ($valueName in $values) {
                if ([string]::IsNullOrWhiteSpace($valueName)) {
                    continue
                }

                try {
                    $valueData = (Get-ItemProperty -LiteralPath $regLoc.Path -Name $valueName -ErrorAction Stop).$valueName
                    $valueKind = $key.GetValueKind($valueName)

                    $items.Add([pscustomobject]@{
                        Name = $valueName
                        CommandOrPath = [string]$valueData
                        ItemType = 'Registry'
                        Scope = $regLoc.Scope
                        Location = $regLoc.Path
                        HivePathForRegExe = $regLoc.HivePathForRegExe
                        RegistryValueKind = [string]$valueKind
                        FileName = $null
                    }) | Out-Null
                }
                catch {
                    $message = "Unable to read registry startup value '{0}' at '{1}': {2}" -f $valueName, $regLoc.Path, $_.Exception.Message
                    Add-SummaryError -Message $message
                    $summary.ItemsSkipped.Add("Skipped registry item: {0} ({1})" -f $valueName, $regLoc.Path) | Out-Null
                    continue
                }
            }
        }
        catch {
            $message = "Unable to access registry startup path '{0}': {1}" -f $regLoc.Path, $_.Exception.Message
            Add-SummaryError -Message $message
            $summary.ItemsSkipped.Add("Skipped registry path: {0}" -f $regLoc.Path) | Out-Null
            continue
        }
    }

    foreach ($folderLoc in $startupFolderLocations) {
        try {
            if ([string]::IsNullOrWhiteSpace($folderLoc.Path) -or -not (Test-Path -LiteralPath $folderLoc.Path)) {
                Write-Log -Level 'WARN' -Message ("Startup folder not found, skipping: {0}" -f $folderLoc.Path)
                continue
            }

            $files = Get-ChildItem -LiteralPath $folderLoc.Path -File -Force -ErrorAction Stop
            foreach ($file in $files) {
                if ($file.Name -ieq 'desktop.ini') {
                    Write-Log -Message ("Skipping metadata file in startup folder: {0}" -f $file.FullName)
                    $summary.ItemsSkipped.Add("Skipped metadata file: {0}" -f $file.FullName) | Out-Null
                    continue
                }

                $items.Add([pscustomobject]@{
                    Name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    CommandOrPath = $file.FullName
                    ItemType = 'StartupFolder'
                    Scope = $folderLoc.Scope
                    Location = $folderLoc.Path
                    HivePathForRegExe = $null
                    RegistryValueKind = $null
                    FileName = $file.Name
                }) | Out-Null
            }
        }
        catch {
            $message = "Unable to access startup folder '{0}': {1}" -f $folderLoc.Path, $_.Exception.Message
            Add-SummaryError -Message $message
            $summary.ItemsSkipped.Add("Skipped startup folder: {0}" -f $folderLoc.Path) | Out-Null
            continue
        }
    }

    return $items
}

# Section 5: Item listing
# Prints each startup item and records a normalized display line for the summary.
function Show-StartupItems {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Items
    )

    if ($Items.Count -eq 0) {
        Write-Output 'No startup items found in configured locations.'
        Write-Log -Message 'No startup items found in configured locations.'
        return
    }

    Write-Output ''
    Write-Output ('-' * 80)
    Write-Output 'Startup Items'
    Write-Output ('-' * 80)

    foreach ($item in $Items) {
        $line = "Name='{0}' | Type={1} | Scope={2} | Location={3} | Value='{4}'" -f `
            $item.Name, $item.ItemType, $item.Scope, $item.Location, $item.CommandOrPath

        Write-Output $line
        Write-Log -Message ("Listed item: {0}" -f $line)
        $summary.ItemsListed.Add($line) | Out-Null
    }
}

# Section 6: Registry backup and disable helpers
# Handles safe backup and disable for registry-based startup entries.
function Backup-RegistryRunKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HivePathForRegExe,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $safeName = ($Name -replace '[^a-zA-Z0-9._-]', '_')
    $backupFile = Join-Path -Path $registryBackupRoot -ChildPath ("{0}-{1}-{2}.reg" -f $runTimestamp, $safeName, [guid]::NewGuid().ToString('N'))

    $null = & reg.exe export "$HivePathForRegExe" "$backupFile" /y

    if (-not (Test-Path -LiteralPath $backupFile)) {
        throw "Registry backup file was not created for key: $HivePathForRegExe"
    }

    Write-Log -Message ("Registry backup created: {0}" -f $backupFile)
    return $backupFile
}

function Disable-RegistryStartupItem {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Item,

        [Parameter(Mandatory = $true)]
        [bool]$IsDryRun,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RollbackRecords
    )

    try {
        if ($IsDryRun) {
            $message = "DRY RUN: Would disable registry startup value '{0}' in '{1}'" -f $Item.Name, $Item.Location
            Write-Output $message
            Write-Log -Message $message
            $summary.ItemsSkipped.Add($message) | Out-Null
            return
        }

        $backupFile = Backup-RegistryRunKey -HivePathForRegExe $Item.HivePathForRegExe -Name $Item.Name

        $rollbackRecords.Add([pscustomobject]@{
            ItemType = 'Registry'
            Name = $Item.Name
            Scope = $Item.Scope
            Location = $Item.Location
            HivePathForRegExe = $Item.HivePathForRegExe
            CommandOrPath = $Item.CommandOrPath
            RegistryValueKind = $Item.RegistryValueKind
            RegistryBackupFile = $backupFile
            DisabledAt = (Get-Date).ToString('o')
            StartupFileOriginalPath = $null
            StartupFileBackupPath = $null
        }) | Out-Null

        Remove-ItemProperty -LiteralPath $Item.Location -Name $Item.Name -ErrorAction Stop

        $successMessage = "Disabled registry startup value '{0}' in '{1}'" -f $Item.Name, $Item.Location
        Write-Output $successMessage
        Write-Log -Message $successMessage
        $summary.ItemsDisabled.Add($successMessage) | Out-Null
    }
    catch {
        $errorMessage = "Failed to disable registry startup value '{0}' in '{1}': {2}" -f $Item.Name, $Item.Location, $_.Exception.Message
        Add-SummaryError -Message $errorMessage
        $summary.ItemsSkipped.Add("Skipped registry disable: {0} ({1})" -f $Item.Name, $Item.Location) | Out-Null
    }
}

# Section 7: Startup folder disable helper
# Disables startup files by moving them to a backup folder for later rollback.
function Disable-StartupFolderItem {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Item,

        [Parameter(Mandatory = $true)]
        [bool]$IsDryRun,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$RollbackRecords
    )

    try {
        if ($IsDryRun) {
            $message = "DRY RUN: Would move startup file '{0}' from '{1}'" -f $Item.FileName, $Item.Location
            Write-Output $message
            Write-Log -Message $message
            $summary.ItemsSkipped.Add($message) | Out-Null
            return
        }

        $runBackupFolder = Join-Path -Path $startupFileBackupRoot -ChildPath ("run-{0}" -f $runTimestamp)
        Ensure-Directory -Path $runBackupFolder

        $destinationPath = Join-Path -Path $runBackupFolder -ChildPath $Item.FileName
        if (Test-Path -LiteralPath $destinationPath) {
            $destinationPath = Join-Path -Path $runBackupFolder -ChildPath (("{0}-{1}{2}" -f [System.IO.Path]::GetFileNameWithoutExtension($Item.FileName), [guid]::NewGuid().ToString('N'), [System.IO.Path]::GetExtension($Item.FileName)))
        }

        Move-Item -LiteralPath $Item.CommandOrPath -Destination $destinationPath -Force -ErrorAction Stop

        $rollbackRecords.Add([pscustomobject]@{
            ItemType = 'StartupFolder'
            Name = $Item.Name
            Scope = $Item.Scope
            Location = $Item.Location
            HivePathForRegExe = $null
            CommandOrPath = $Item.CommandOrPath
            RegistryValueKind = $null
            RegistryBackupFile = $null
            DisabledAt = (Get-Date).ToString('o')
            StartupFileOriginalPath = $Item.CommandOrPath
            StartupFileBackupPath = $destinationPath
        }) | Out-Null

        $successMessage = "Disabled startup file '{0}' by moving to '{1}'" -f $Item.FileName, $destinationPath
        Write-Output $successMessage
        Write-Log -Message $successMessage
        $summary.ItemsDisabled.Add($successMessage) | Out-Null
    }
    catch {
        $errorMessage = "Failed to disable startup file '{0}' from '{1}': {2}" -f $Item.FileName, $Item.Location, $_.Exception.Message
        Add-SummaryError -Message $errorMessage
        $summary.ItemsSkipped.Add("Skipped startup file disable: {0} ({1})" -f $Item.FileName, $Item.Location) | Out-Null
    }
}

# Section 8: Disable flow
# Finds matching items by name and disables each with per-item error isolation.
function Invoke-DisableByName {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[object]]$Items,

        [Parameter(Mandatory = $true)]
        [string]$TargetName,

        [Parameter(Mandatory = $true)]
        [bool]$IsDryRun
    )

    $matches = $Items | Where-Object { $_.Name -ieq $TargetName }

    if (-not $matches -or $matches.Count -eq 0) {
        $message = "No startup items matched the name '{0}'." -f $TargetName
        Write-Output $message
        Write-Log -Level 'WARN' -Message $message
        $summary.ItemsSkipped.Add($message) | Out-Null
        return
    }

    $rollbackRecords = New-Object System.Collections.Generic.List[object]

    foreach ($match in $matches) {
        if ($match.ItemType -eq 'Registry') {
            Disable-RegistryStartupItem -Item $match -IsDryRun $IsDryRun -RollbackRecords $rollbackRecords
        }
        elseif ($match.ItemType -eq 'StartupFolder') {
            Disable-StartupFolderItem -Item $match -IsDryRun $IsDryRun -RollbackRecords $rollbackRecords
        }
        else {
            $unknownMessage = "Unknown item type for '{0}', skipping." -f $match.Name
            Write-Log -Level 'WARN' -Message $unknownMessage
            $summary.ItemsSkipped.Add($unknownMessage) | Out-Null
        }
    }

    if (-not $IsDryRun -and $rollbackRecords.Count -gt 0) {
        $rollbackFilePath = Join-Path -Path $rollbackStateRoot -ChildPath ("startup-rollback-{0}.json" -f $runTimestamp)
        $rollbackRecords | ConvertTo-Json -Depth 6 | Set-Content -Path $rollbackFilePath -Encoding UTF8

        $summary.RollbackFileOrBackupLocation = $rollbackFilePath
        Write-Log -Message ("Rollback state file created: {0}" -f $rollbackFilePath)
    }
    elseif ($IsDryRun) {
        $summary.RollbackFileOrBackupLocation = "Dry run only - no rollback state file created. Registry backups would be created under: $registryBackupRoot"
    }
}

# Section 9: Rollback flow
# Restores disabled startup items from the rollback state file.
function Invoke-Rollback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateFile,

        [Parameter(Mandatory = $true)]
        [bool]$IsDryRun
    )

    if (-not (Test-Path -LiteralPath $StateFile)) {
        throw "Rollback file not found: $StateFile"
    }

    Write-Log -Message ("Starting rollback from state file: {0}" -f $StateFile)

    $records = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    if ($null -eq $records) {
        throw "Rollback file is empty or invalid JSON: $StateFile"
    }

    if ($records -isnot [System.Array]) {
        $records = @($records)
    }

    foreach ($record in $records) {
        try {
            if ($record.ItemType -eq 'Registry') {
                if ($IsDryRun) {
                    $msg = "DRY RUN: Would restore registry startup value '{0}' in '{1}'" -f $record.Name, $record.Location
                    Write-Output $msg
                    Write-Log -Message $msg
                    $summary.ItemsSkipped.Add($msg) | Out-Null
                    continue
                }

                try {
                    New-ItemProperty -LiteralPath $record.Location -Name $record.Name -Value $record.CommandOrPath -PropertyType $record.RegistryValueKind -Force -ErrorAction Stop | Out-Null
                    $okMsg = "Restored registry startup value '{0}' in '{1}' using saved item details" -f $record.Name, $record.Location
                    Write-Output $okMsg
                    Write-Log -Message $okMsg
                    $summary.ItemsDisabled.Add("Rollback restored: {0}" -f $okMsg) | Out-Null
                }
                catch {
                    if (-not [string]::IsNullOrWhiteSpace($record.RegistryBackupFile) -and (Test-Path -LiteralPath $record.RegistryBackupFile)) {
                        $null = & reg.exe import "$record.RegistryBackupFile"

                        $okMsg = "Restored registry startup value '{0}' by importing backup '{1}'" -f $record.Name, $record.RegistryBackupFile
                        Write-Output $okMsg
                        Write-Log -Message $okMsg
                        $summary.ItemsDisabled.Add("Rollback restored via .reg import: {0}" -f $record.Name) | Out-Null
                    }
                    else {
                        throw
                    }
                }
            }
            elseif ($record.ItemType -eq 'StartupFolder') {
                if ($IsDryRun) {
                    $msg = "DRY RUN: Would restore startup file '{0}' to '{1}'" -f $record.StartupFileBackupPath, $record.StartupFileOriginalPath
                    Write-Output $msg
                    Write-Log -Message $msg
                    $summary.ItemsSkipped.Add($msg) | Out-Null
                    continue
                }

                if (-not (Test-Path -LiteralPath $record.StartupFileBackupPath)) {
                    $missingMsg = "Startup backup file missing, cannot restore: {0}" -f $record.StartupFileBackupPath
                    Write-Log -Level 'WARN' -Message $missingMsg
                    $summary.ItemsSkipped.Add($missingMsg) | Out-Null
                    continue
                }

                $targetFolder = Split-Path -Path $record.StartupFileOriginalPath -Parent
                Ensure-Directory -Path $targetFolder

                Move-Item -LiteralPath $record.StartupFileBackupPath -Destination $record.StartupFileOriginalPath -Force -ErrorAction Stop
                $okMsg = "Restored startup file to '{0}'" -f $record.StartupFileOriginalPath
                Write-Output $okMsg
                Write-Log -Message $okMsg
                $summary.ItemsDisabled.Add("Rollback restored: {0}" -f $okMsg) | Out-Null
            }
            else {
                $unknownMsg = "Unknown rollback item type '{0}', skipping record." -f $record.ItemType
                Write-Log -Level 'WARN' -Message $unknownMsg
                $summary.ItemsSkipped.Add($unknownMsg) | Out-Null
            }
        }
        catch {
            $errorMessage = "Rollback failed for item '{0}' ({1}): {2}" -f $record.Name, $record.ItemType, $_.Exception.Message
            Add-SummaryError -Message $errorMessage
            $summary.ItemsSkipped.Add("Rollback skipped for item: {0}" -f $record.Name) | Out-Null
            continue
        }
    }

    if ($IsDryRun) {
        $summary.RollbackFileOrBackupLocation = "Rollback dry run used file: $StateFile"
    }
    else {
        $summary.RollbackFileOrBackupLocation = "Rollback executed from file: $StateFile"
    }
}

# Section 10: Main execution
# Drives list, disable, and rollback modes and always prints a final summary.
Write-Log -Message 'Starting startup program management script.'
Write-Log -Message ("Parameter set: {0}" -f $PSCmdlet.ParameterSetName)
Write-Log -Message ("DryRun: {0}" -f [bool]$DryRun)
Write-Log -Message ("WorkingRoot: {0}" -f $WorkingRoot)

try {
    if ($PSCmdlet.ParameterSetName -eq 'Rollback') {
        Invoke-Rollback -StateFile $RollbackFile -IsDryRun ([bool]$DryRun)
    }
    else {
        $startupItems = Get-StartupItems
        $summary.TotalStartupItemsFound = $startupItems.Count

        Show-StartupItems -Items $startupItems

        if ($PSCmdlet.ParameterSetName -eq 'Disable') {
            Invoke-DisableByName -Items $startupItems -TargetName $DisableName -IsDryRun ([bool]$DryRun)
        }
        else {
            if ($DryRun) {
                Write-Log -Message 'Dry run list mode completed. No changes were made.'
                $summary.RollbackFileOrBackupLocation = "Dry run only - no changes made. Backup roots: $registryBackupRoot ; $startupFileBackupRoot"
            }
            else {
                $summary.RollbackFileOrBackupLocation = "No disable action requested. Backup roots: $registryBackupRoot ; $startupFileBackupRoot"
            }
        }
    }
}
catch {
    Add-SummaryError -Message ("Unexpected script-level failure: {0}" -f $_.Exception.Message)
}
finally {
    Write-Summary -Data $summary
}
