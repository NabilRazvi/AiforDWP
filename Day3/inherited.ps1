<#
.SYNOPSIS
     Reports a summary of the computer's hardware, disk space, processes, system errors, and stale user profiles.

.DESCRIPTION
     Reads system information and displays the computer name, total physical memory, free space on drive C,
     the five processes using the most working-set memory, recent System log errors, and the number of user
     profiles that have not been used in the last 90 days. The script does not change system settings or data.

.NOTES
     Author: Not specified

.EXAMPLE
     .\inherited.ps1

     Run from a PowerShell prompt in the script's directory. If script execution is restricted, use:
     powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\inherited.ps1"
#>

# Read general computer information, including its name and total physical memory.
$computerSystem = Get-CimInstance Win32_ComputerSystem

# Read the amount of free space, in bytes, on drive C.
$freeDiskSpaceBytes = Get-PSDrive C | Select-Object -ExpandProperty Free

# Select the five running processes with the largest working-set memory usage.
$topMemoryProcesses = Get-Process | Sort-Object WS -Descending | Select-Object -First 5

# Read the 10 most recent System log events and retain only error-level events.
$recentSystemErrors = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object { $_.Level -eq 2 }

# Read user profiles and begin filtering out special or recently used profiles.
$staleUserProfiles = Get-CimInstance Win32_UserProfile | Where-Object {
     # Retain non-special profiles whose last-use time is more than 90 days ago.
     -not $_.Special -and $_.LastUseTime -lt (Get-Date).AddDays(-90)
# Finish the user-profile filter.
}

# Display the computer name and total physical memory in bytes.
Write-Host $computerSystem.Name $computerSystem.TotalPhysicalMemory

# Convert free disk space to gigabytes, round it to two decimal places, and display it.
Write-Host ([math]::Round($freeDiskSpaceBytes / 1GB, 2)) 'GB free'

# Display the name and working-set memory, in bytes, for each selected process.
$topMemoryProcesses | ForEach-Object { Write-Host $_.Name $_.WS }

# Display the creation time and message for each recent System log error.
$recentSystemErrors | ForEach-Object { Write-Host $_.TimeCreated $_.Message }

# Display the number of stale profiles when at least one profile was found.
if ($staleUserProfiles.Count -gt 0) { Write-Host 'Stale profiles:' $staleUserProfiles.Count }