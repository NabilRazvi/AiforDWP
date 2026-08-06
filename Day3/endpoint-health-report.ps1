#requires -Version 5.1
<#!
.SYNOPSIS
Read-only endpoint health report for DWP engineering triage.

.DESCRIPTION
Collects and prints:
1) System uptime
2) Free disk space
3) Pending reboot status (registry checks)
4) Top 5 processes by memory (working set)
5) Top 5 processes by CPU time
6) Last 5 system log errors

This script is strictly read-only. It does not modify system state.
#>

[CmdletBinding()]
param()

function Get-ExecutablePath {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process
    )

    if ($Process.Path) {
        return $Process.Path
    }

    try {
        $mainModulePath = $Process.MainModule.FileName
        if ([string]::IsNullOrWhiteSpace($mainModulePath)) {
            return '[Access denied or unavailable]'
        }

        return $mainModulePath
    }
    catch {
        return '[Access denied or unavailable]'
    }
}

# Section 0: Shared settings
# This section defines report settings used in later sections.
# VERIFY BEFORE RUNNING: Confirm these values match your triage requirement.
$TopCount = 5
# VERIFY BEFORE RUNNING: Confirm the target event log name is correct for your environment.
$SystemLogName = 'System'
# VERIFY BEFORE RUNNING: Confirm the number of latest error events to retrieve.
$ErrorEventsToFetch = 5

Write-Output '============================================================'
Write-Output 'DWP Endpoint Health Report (Read-Only)'
Write-Output ("Generated: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Output '============================================================'

# Section 1: System uptime
# This section reads the last OS boot time and calculates uptime duration.
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $lastBoot = $os.LastBootUpTime
    $uptime = (Get-Date) - $lastBoot

    Write-Output "`n[1] System Uptime"
    Write-Output ("Last Boot Time : {0}" -f $lastBoot)
    Write-Output ("Uptime         : {0} days {1} hours {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
}
catch {
    Write-Warning ("[1] Unable to retrieve uptime: {0}" -f $_.Exception.Message)
}

# Section 2: Free disk space
# This section reports used and free space for file system drives visible to PowerShell.
try {
    Write-Output "`n[2] Free Disk Space"
    Get-PSDrive -PSProvider FileSystem |
        Select-Object Name,
            @{Name = 'UsedGB'; Expression = { [math]::Round($_.Used / 1GB, 2) }},
            @{Name = 'FreeGB'; Expression = { [math]::Round($_.Free / 1GB, 2) }},
            @{Name = 'TotalGB'; Expression = { [math]::Round(($_.Used + $_.Free) / 1GB, 2) }},
            @{Name = 'FreePercent'; Expression = {
                if (($_.Used + $_.Free) -gt 0) {
                    [math]::Round(($_.Free / ($_.Used + $_.Free)) * 100, 2)
                }
                else {
                    $null
                }
            }} |
        Format-Table -AutoSize
}
catch {
    Write-Warning ("[2] Unable to retrieve disk usage: {0}" -f $_.Exception.Message)
}

# Section 3: Pending reboot (registry checks)
# This section performs read-only checks of common registry paths used to indicate reboot pending state.
try {
    Write-Output "`n[3] Pending Reboot Status (Registry)"

    $rebootChecks = [ordered]@{
        'CBS RebootPending' = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'Windows Update RebootRequired' = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        'PendingFileRenameOperations value' = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    }

    $pendingDetails = @()

    foreach ($checkName in $rebootChecks.Keys) {
        $path = $rebootChecks[$checkName]

        if ($checkName -eq 'PendingFileRenameOperations value') {
            $pendingRename = $false
            if (Test-Path -Path $path) {
                $sessionMgr = Get-ItemProperty -Path $path -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
                $pendingRename = $null -ne $sessionMgr.PendingFileRenameOperations
            }
            $pendingDetails += [pscustomobject]@{
                CheckName = $checkName
                Path = $path
                IsPending = $pendingRename
            }
        }
        else {
            $pendingDetails += [pscustomobject]@{
                CheckName = $checkName
                Path = $path
                IsPending = (Test-Path -Path $path)
            }
        }
    }

    $overallPending = ($pendingDetails | Where-Object { $_.IsPending }).Count -gt 0

    Write-Output ("Pending Reboot Overall: {0}" -f $(if ($overallPending) { 'YES' } else { 'NO' }))
    $pendingDetails | Format-Table -AutoSize
}
catch {
    Write-Warning ("[3] Unable to determine reboot pending status: {0}" -f $_.Exception.Message)
}

# Section 4: Top 5 processes by memory (working set)
# This section lists processes currently using the most RAM based on WorkingSet64,
# including the executable file name and full path where available.
try {
    Write-Output "`n[4] Top $TopCount Processes by Memory (Working Set)"
    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object -Property WorkingSet64 -Descending |
        Select-Object -First $TopCount ProcessName, Id,
            @{Name = 'WorkingSetMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) }},
            @{Name = 'ExecutablePath'; Expression = { Get-ExecutablePath -Process $_ }} |
        Format-Table -AutoSize
}
catch {
    Write-Warning ("[4] Unable to retrieve top memory processes: {0}" -f $_.Exception.Message)
}

# Section 5: Top 5 processes by CPU
# This section lists processes by cumulative CPU time since process start.
# It also includes the executable file name and full path where available.
# VERIFY BEFORE RUNNING: CPU here is total processor seconds, not real-time CPU percent.
try {
    Write-Output "`n[5] Top $TopCount Processes by CPU Time"
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $null -ne $_.CPU } |
        Sort-Object -Property CPU -Descending |
        Select-Object -First $TopCount ProcessName, Id,
            @{Name = 'CPUSeconds'; Expression = { [math]::Round($_.CPU, 2) }},
            @{Name = 'ExecutablePath'; Expression = { Get-ExecutablePath -Process $_ }} |
        Format-Table -AutoSize
}
catch {
    Write-Warning ("[5] Unable to retrieve top CPU processes: {0}" -f $_.Exception.Message)
}

# Section 6: Last 5 system log errors
# This section reads the newest error-level events from the configured system event log.
try {
    Write-Output "`n[6] Last $ErrorEventsToFetch Errors from '$SystemLogName' Log"

    Get-WinEvent -FilterHashtable @{ LogName = $SystemLogName; Level = 2 } -MaxEvents $ErrorEventsToFetch -ErrorAction Stop |
        Select-Object TimeCreated, Id, ProviderName,
            @{Name = 'Message'; Expression = {
                if ($_.Message.Length -gt 180) {
                    $_.Message.Substring(0, 180) + '...'
                }
                else {
                    $_.Message
                }
            }} |
        Format-Table -Wrap -AutoSize
}
catch {
    Write-Warning ("[6] Unable to retrieve system log errors: {0}" -f $_.Exception.Message)
}

Write-Output "`nReport complete. Script performed read-only checks only."