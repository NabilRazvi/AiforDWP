#requires -Version 5.1
<#!
.SYNOPSIS
Compatibility wrapper for temp-file-cleanup-safe.ps1.

.DESCRIPTION
This wrapper forwards all arguments to temp-file-cleanup-safe.ps1 so older command
examples using temp-cleanup.ps1 continue to work.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$RemainingArguments
)

# Section 1: Resolve the real script path
# This section locates the main cleanup script in the same folder as this wrapper.
$scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Path $PSCommandPath -Parent
}
else {
    (Get-Location).Path
}

$targetScript = Join-Path -Path $scriptRoot -ChildPath 'temp-file-cleanup-safe.ps1'

# Section 2: Forward execution
# This section calls the main script and passes through all original arguments unchanged.
if (-not (Test-Path -LiteralPath $targetScript)) {
    throw "Required script not found: $targetScript"
}

& $targetScript @RemainingArguments
exit $LASTEXITCODE
