#requires -Version 5.1
<#!
.SYNOPSIS
Audits Windows startup programs and optionally disables a named startup item safely.

.DESCRIPTION
Default mode is read-only audit mode. It lists startup programs from common startup locations.

When -Disable is used, only startup items that exactly match the provided name are disabled.
This script never permanently deletes startup entries. Registry entries are moved to a dedicated
disabled key, and startup-folder files are moved to a backup folder after rollback data is captured.

This script is designed for PowerShell 5.1 and production-safe endpoint operations.
#>

[CmdletBinding(DefaultParameterSetName = 'Audit')]
param(
	# Section 0A: Disable mode parameter
	# Provide the exact startup item name to disable (case-insensitive exact match).
	[Parameter(Mandatory = $true, ParameterSetName = 'Disable')]
	[Alias('DisableName')]
	[string]$Disable,

	# Section 0B: Shared behavior parameter
	# When set, script shows intended actions but does not change state.
	[Parameter(ParameterSetName = 'Audit')]
	[Parameter(ParameterSetName = 'Disable')]
	[switch]$DryRun,

	# Section 0C: Optional working root parameter
	# Controls where logs and rollback/backup artifacts are stored.
	[Parameter(ParameterSetName = 'Audit')]
	[Parameter(ParameterSetName = 'Disable')]
	[string]$WorkingRoot
)

# Section 1: Verify-before-run guidance
# These warnings flag lines/settings an engineer should verify before making changes.
Write-Warning 'VERIFY BEFORE RUN: If you plan to disable Local Machine startup items, run PowerShell as Administrator.'
Write-Warning 'VERIFY BEFORE RUN: Confirm the exact startup name passed to -Disable to avoid disabling the wrong item.'
Write-Warning 'VERIFY BEFORE RUN: Review DryRun output first on production endpoints.'

# Section 2: Runtime metadata, paths, and summary counters
# This section initializes reusable paths and end-of-run counters.
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
	$WorkingRoot = Join-Path -Path $scriptRoot -ChildPath 'startup-auditor-work'
}

$logRoot = Join-Path -Path $scriptRoot -ChildPath 'logs'
$backupRoot = Join-Path -Path $WorkingRoot -ChildPath 'backups'
$registryBackupRoot = Join-Path -Path $backupRoot -ChildPath 'registry'
$startupFileBackupRoot = Join-Path -Path $backupRoot -ChildPath 'startup-files'
$stateRoot = Join-Path -Path $WorkingRoot -ChildPath 'state'

$summary = [ordered]@{
	TotalStartupItemsFound = 0
	DisabledItems = New-Object System.Collections.Generic.List[string]
	SkippedItems = New-Object System.Collections.Generic.List[string]
	Errors = New-Object System.Collections.Generic.List[string]
}

# Section 3: Startup location definitions
# These are the required common startup locations for audit and disable operations.
$registryLocations = @(
	[pscustomobject]@{
		Scope = 'CurrentUser'
		SourceLabel = 'Current User Run Registry Key'
		RunPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
		DisabledPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run-Disabled-DWP'
	},
	[pscustomobject]@{
		Scope = 'LocalMachine'
		SourceLabel = 'Local Machine Run Registry Key'
		RunPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
		DisabledPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run-Disabled-DWP'
	}
)

$startupFolderLocations = @(
	[pscustomobject]@{
		Scope = 'CurrentUser'
		SourceLabel = 'Current User Startup Folder'
		FolderPath = [Environment]::GetFolderPath('Startup')
	},
	[pscustomobject]@{
		Scope = 'AllUsers'
		SourceLabel = 'All Users Startup Folder'
		FolderPath = [Environment]::GetFolderPath('CommonStartup')
	}
)

# Section 4: Utility helpers
# Helper functions for directory setup, logging, summary output, and state persistence.
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
Ensure-Directory -Path $stateRoot

$logFile = Join-Path -Path $logRoot -ChildPath ("startup-auditor-{0}.log" -f $runTimestamp)

function Write-Log {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message,

		[Parameter()]
		[ValidateSet('INFO', 'WARN', 'ERROR')]
		[string]$Level = 'INFO'
	)

	$line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
	Add-Content -LiteralPath $logFile -Value $line
	Write-Host $line
}

function Add-ErrorSummary {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	$summary.Errors.Add($Message) | Out-Null
	Write-Log -Level 'ERROR' -Message $Message
}

function Write-Summary {
	Write-Output ''
	Write-Output ('=' * 78)
	Write-Output 'Startup Program Auditor Summary'
	Write-Output ('=' * 78)
	Write-Output ("Total startup items found: {0}" -f $summary.TotalStartupItemsFound)
	Write-Output ("Disabled items count: {0}" -f $summary.DisabledItems.Count)
	Write-Output ("Skipped items count: {0}" -f $summary.SkippedItems.Count)
	Write-Output ("Errors count: {0}" -f $summary.Errors.Count)
	Write-Output ("Log file: {0}" -f $logFile)

	Write-Output ''
	Write-Output 'Disabled items:'
	if ($summary.DisabledItems.Count -eq 0) {
		Write-Output ' - None'
	}
	else {
		foreach ($item in $summary.DisabledItems) {
			Write-Output (" - {0}" -f $item)
		}
	}

	Write-Output ''
	Write-Output 'Skipped items:'
	if ($summary.SkippedItems.Count -eq 0) {
		Write-Output ' - None'
	}
	else {
		foreach ($item in $summary.SkippedItems) {
			Write-Output (" - {0}" -f $item)
		}
	}

	Write-Output ''
	Write-Output 'Errors:'
	if ($summary.Errors.Count -eq 0) {
		Write-Output ' - None'
	}
	else {
		foreach ($item in $summary.Errors) {
			Write-Output (" - {0}" -f $item)
		}
	}

	Write-Log -Message ("Summary totals: Found={0}, Disabled={1}, Skipped={2}, Errors={3}" -f $summary.TotalStartupItemsFound, $summary.DisabledItems.Count, $summary.SkippedItems.Count, $summary.Errors.Count)
}

function Get-FileOwnerSafe {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	try {
		return (Get-Acl -LiteralPath $Path -ErrorAction Stop).Owner
	}
	catch {
		return 'OwnerUnavailable'
	}
}

function Get-StateFilePath {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Kind
	)

	return (Join-Path -Path $stateRoot -ChildPath ("{0}-state.json" -f $Kind))
}

function Load-StateFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	if (-not (Test-Path -LiteralPath $Path)) {
		return @()
	}

	try {
		$raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
		if ([string]::IsNullOrWhiteSpace($raw)) {
			return @()
		}

		$obj = $raw | ConvertFrom-Json
		if ($obj -is [System.Array]) {
			return $obj
		}

		return @($obj)
	}
	catch {
		Add-ErrorSummary -Message ("Failed to load state file '{0}': {1}" -f $Path, $_.Exception.Message)
		return @()
	}
}

function Save-StateFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter(Mandatory = $true)]
		[System.Collections.IEnumerable]$Entries
	)

	try {
		@($Entries) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
	}
	catch {
		Add-ErrorSummary -Message ("Failed to save state file '{0}': {1}" -f $Path, $_.Exception.Message)
	}
}

# Section 5: Startup item discovery
# Enumerates startup entries from required registry keys and startup folders.
function Get-StartupItems {
	$allItems = New-Object System.Collections.Generic.List[object]

	foreach ($reg in $registryLocations) {
		try {
			if (-not (Test-Path -LiteralPath $reg.RunPath)) {
				$skip = "Registry run path not found: {0}" -f $reg.RunPath
				Write-Log -Level 'WARN' -Message $skip
				$summary.SkippedItems.Add($skip) | Out-Null
				continue
			}

			$key = Get-Item -LiteralPath $reg.RunPath -ErrorAction Stop
			foreach ($valueName in $key.GetValueNames()) {
				if ([string]::IsNullOrWhiteSpace($valueName)) {
					continue
				}

				try {
					$valueData = (Get-ItemProperty -LiteralPath $reg.RunPath -Name $valueName -ErrorAction Stop).$valueName
					$kind = $key.GetValueKind($valueName)

					$allItems.Add([pscustomobject]@{
						Name = $valueName
						SourceLocation = $reg.SourceLabel
						Command = [string]$valueData
						Status = 'Enabled'
						ItemType = 'Registry'
						Scope = $reg.Scope
						RegistryPath = $reg.RunPath
						DisabledRegistryPath = $reg.DisabledPath
						RegistryValueKind = [string]$kind
						FilePath = $null
						Owner = $null
					}) | Out-Null
				}
				catch {
					$err = "Failed reading registry item '{0}' from '{1}': {2}" -f $valueName, $reg.RunPath, $_.Exception.Message
					Add-ErrorSummary -Message $err
					$summary.SkippedItems.Add("Skipped registry item: $valueName") | Out-Null
					continue
				}
			}
		}
		catch {
			$err = "Failed accessing registry path '{0}': {1}" -f $reg.RunPath, $_.Exception.Message
			Add-ErrorSummary -Message $err
			$summary.SkippedItems.Add("Skipped registry path: $($reg.RunPath)") | Out-Null
			continue
		}
	}

	foreach ($folder in $startupFolderLocations) {
		try {
			if ([string]::IsNullOrWhiteSpace($folder.FolderPath) -or -not (Test-Path -LiteralPath $folder.FolderPath)) {
				$skip = "Startup folder not found: {0}" -f $folder.FolderPath
				Write-Log -Level 'WARN' -Message $skip
				$summary.SkippedItems.Add($skip) | Out-Null
				continue
			}

			$files = Get-ChildItem -LiteralPath $folder.FolderPath -File -Force -ErrorAction Stop
			foreach ($file in $files) {
				try {
					if ($file.Name -ieq 'desktop.ini') {
						$skip = "Skipping metadata file: {0}" -f $file.FullName
						Write-Log -Message $skip
						$summary.SkippedItems.Add($skip) | Out-Null
						continue
					}

					$allItems.Add([pscustomobject]@{
						Name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
						SourceLocation = $folder.SourceLabel
						Command = $file.FullName
						Status = 'Enabled'
						ItemType = 'StartupFolder'
						Scope = $folder.Scope
						RegistryPath = $null
						DisabledRegistryPath = $null
						RegistryValueKind = $null
						FilePath = $file.FullName
						Owner = (Get-FileOwnerSafe -Path $file.FullName)
					}) | Out-Null
				}
				catch {
					$err = "Failed reading startup folder item '{0}': {1}" -f $file.FullName, $_.Exception.Message
					Add-ErrorSummary -Message $err
					$summary.SkippedItems.Add("Skipped startup file: $($file.FullName)") | Out-Null
					continue
				}
			}
		}
		catch {
			$err = "Failed accessing startup folder '{0}': {1}" -f $folder.FolderPath, $_.Exception.Message
			Add-ErrorSummary -Message $err
			$summary.SkippedItems.Add("Skipped startup folder: $($folder.FolderPath)") | Out-Null
			continue
		}
	}

	return $allItems
}

# Section 6: Audit output
# Displays startup entries with required fields in a consistent format.
function Show-StartupItems {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.Generic.List[object]]$Items
	)

	if ($Items.Count -eq 0) {
		Write-Output 'No startup programs found in configured locations.'
		Write-Log -Message 'No startup programs found in configured locations.'
		return
	}

	Write-Output ''
	Write-Output ('-' * 78)
	Write-Output 'Startup Programs'
	Write-Output ('-' * 78)

	foreach ($item in $Items) {
		$line = "Name='{0}' | Source='{1}' | Command='{2}' | Status='{3}'" -f $item.Name, $item.SourceLocation, $item.Command, $item.Status
		Write-Output $line
		Write-Log -Message ("Audit item: {0}" -f $line)
	}
}

# Section 7: Registry backup and disable functions
# Safely backs up and disables matching registry startup entries.
function Backup-RegistryKey {
	param(
		[Parameter(Mandatory = $true)]
		[string]$RegistryPath,

		[Parameter(Mandatory = $true)]
		[string]$Name
	)

	$safeName = ($Name -replace '[^a-zA-Z0-9._-]', '_')
	$backupFile = Join-Path -Path $registryBackupRoot -ChildPath ("{0}-{1}.reg" -f $runTimestamp, $safeName)

	# VERIFY BEFORE RUN: This export captures the full Run key for rollback/import safety.
	$regExePath = $RegistryPath -replace '^HKCU:', 'HKEY_CURRENT_USER' -replace '^HKLM:', 'HKEY_LOCAL_MACHINE'
	$null = & reg.exe export "$regExePath" "$backupFile" /y

	if (-not (Test-Path -LiteralPath $backupFile)) {
		throw "Registry backup not created for path: $RegistryPath"
	}

	Write-Log -Message ("Registry backup created: {0}" -f $backupFile)
	return $backupFile
}

function Disable-RegistryItem {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$Item,

		[Parameter(Mandatory = $true)]
		[bool]$IsDryRun
	)

	try {
		if ($IsDryRun) {
			$msg = "DRY RUN: Would disable registry startup item '{0}' at '{1}'" -f $Item.Name, $Item.RegistryPath
			Write-Output $msg
			Write-Log -Message $msg
			$summary.SkippedItems.Add($msg) | Out-Null
			return
		}

		Ensure-Directory -Path $registryBackupRoot
		$backupFile = Backup-RegistryKey -RegistryPath $Item.RegistryPath -Name $Item.Name

		if (-not (Test-Path -LiteralPath $Item.DisabledRegistryPath)) {
			New-Item -Path $Item.DisabledRegistryPath -Force -ErrorAction Stop | Out-Null
		}

		$disabledAlready = $null
		try {
			$disabledAlready = (Get-ItemProperty -LiteralPath $Item.DisabledRegistryPath -Name $Item.Name -ErrorAction Stop).$($Item.Name)
		}
		catch {
			$disabledAlready = $null
		}

		if ($null -ne $disabledAlready) {
			$skip = "Registry item already disabled (exists in disabled key): {0}" -f $Item.Name
			Write-Log -Level 'WARN' -Message $skip
			$summary.SkippedItems.Add($skip) | Out-Null
			return
		}

		New-ItemProperty -LiteralPath $Item.DisabledRegistryPath -Name $Item.Name -Value $Item.Command -PropertyType $Item.RegistryValueKind -Force -ErrorAction Stop | Out-Null
		Remove-ItemProperty -LiteralPath $Item.RegistryPath -Name $Item.Name -ErrorAction Stop

		$statePath = Get-StateFilePath -Kind 'registry-disable'
		$stateEntries = Load-StateFile -Path $statePath
		$stateEntries = @($stateEntries) + @([pscustomobject]@{
			Name = $Item.Name
			SourcePath = $Item.RegistryPath
			DisabledPath = $Item.DisabledRegistryPath
			Value = $Item.Command
			ValueKind = $Item.RegistryValueKind
			BackupFile = $backupFile
			DisabledAt = (Get-Date).ToString('o')
		})
		Save-StateFile -Path $statePath -Entries $stateEntries

		$ok = "Disabled registry startup item '{0}' by moving value to '{1}' (backup: {2})" -f $Item.Name, $Item.DisabledRegistryPath, $backupFile
		Write-Output $ok
		Write-Log -Message $ok
		$summary.DisabledItems.Add($ok) | Out-Null
	}
	catch {
		$err = "Failed disabling registry item '{0}': {1}" -f $Item.Name, $_.Exception.Message
		Add-ErrorSummary -Message $err
		$summary.SkippedItems.Add("Skipped disable for registry item: $($Item.Name)") | Out-Null
	}
}

# Section 8: Startup-folder disable function
# Safely disables folder-based startup items by moving them to backup storage.
function Disable-StartupFolderItem {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$Item,

		[Parameter(Mandatory = $true)]
		[bool]$IsDryRun
	)

	try {
		$scopeFolder = Join-Path -Path $startupFileBackupRoot -ChildPath $Item.Scope
		Ensure-Directory -Path $scopeFolder

		$backupPath = Join-Path -Path $scopeFolder -ChildPath ([System.IO.Path]::GetFileName($Item.FilePath))

		if ($IsDryRun) {
			$msg = "DRY RUN: Would move startup file '{0}' to '{1}'" -f $Item.FilePath, $backupPath
			Write-Output $msg
			Write-Log -Message $msg
			$summary.SkippedItems.Add($msg) | Out-Null
			return
		}

		$alreadyDisabled = (-not (Test-Path -LiteralPath $Item.FilePath)) -and (Test-Path -LiteralPath $backupPath)
		if ($alreadyDisabled) {
			$skip = "Startup file already disabled: {0}" -f $Item.FilePath
			Write-Log -Level 'WARN' -Message $skip
			$summary.SkippedItems.Add($skip) | Out-Null
			return
		}

		if (Test-Path -LiteralPath $backupPath) {
			$backupPath = Join-Path -Path $scopeFolder -ChildPath (("{0}-{1}{2}" -f [System.IO.Path]::GetFileNameWithoutExtension($Item.FilePath), $runTimestamp, [System.IO.Path]::GetExtension($Item.FilePath)))
		}

		Move-Item -LiteralPath $Item.FilePath -Destination $backupPath -Force -ErrorAction Stop

		$statePath = Get-StateFilePath -Kind 'startupfile-disable'
		$stateEntries = Load-StateFile -Path $statePath
		$stateEntries = @($stateEntries) + @([pscustomobject]@{
			Name = $Item.Name
			SourcePath = $Item.FilePath
			BackupPath = $backupPath
			Scope = $Item.Scope
			DisabledAt = (Get-Date).ToString('o')
		})
		Save-StateFile -Path $statePath -Entries $stateEntries

		$ok = "Disabled startup file '{0}' by moving to '{1}'" -f $Item.FilePath, $backupPath
		Write-Output $ok
		Write-Log -Message $ok
		$summary.DisabledItems.Add($ok) | Out-Null
	}
	catch {
		$err = "Failed disabling startup file '{0}': {1}" -f $Item.FilePath, $_.Exception.Message
		Add-ErrorSummary -Message $err
		$summary.SkippedItems.Add("Skipped disable for startup file: $($Item.FilePath)") | Out-Null
	}
}

# Section 9: Disable orchestration
# Performs exact-name matching and processes each match safely and independently.
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
		$msg = "No startup items matched name '{0}'." -f $TargetName
		Write-Output $msg
		Write-Log -Level 'WARN' -Message $msg
		$summary.SkippedItems.Add($msg) | Out-Null
		return
	}

	foreach ($match in $matches) {
		if ($match.ItemType -eq 'Registry') {
			Disable-RegistryItem -Item $match -IsDryRun $IsDryRun
		}
		elseif ($match.ItemType -eq 'StartupFolder') {
			Disable-StartupFolderItem -Item $match -IsDryRun $IsDryRun
		}
		else {
			$skip = "Unknown startup item type for '{0}', skipping." -f $match.Name
			Write-Log -Level 'WARN' -Message $skip
			$summary.SkippedItems.Add($skip) | Out-Null
		}
	}
}

# Section 10: Main execution flow
# Runs audit by default and optional disable mode when requested.
Write-Log -Message 'Starting startup-program-auditor.ps1 run.'
Write-Log -Message ("ParameterSet: {0}; DryRun: {1}" -f $PSCmdlet.ParameterSetName, [bool]$DryRun)
Write-Log -Message ("WorkingRoot: {0}" -f $WorkingRoot)

try {
	$items = Get-StartupItems
	$summary.TotalStartupItemsFound = $items.Count
	Show-StartupItems -Items $items

	if ($PSCmdlet.ParameterSetName -eq 'Disable') {
		Invoke-DisableByName -Items $items -TargetName $Disable -IsDryRun ([bool]$DryRun)
	}
	else {
		if ($DryRun) {
			Write-Log -Message 'DryRun audit completed. No changes were made.'
		}
		else {
			Write-Log -Message 'Read-only audit completed. No changes were made.'
		}
	}
}
catch {
	Add-ErrorSummary -Message ("Unexpected script-level failure: {0}" -f $_.Exception.Message)
}
finally {
	Write-Summary
}
