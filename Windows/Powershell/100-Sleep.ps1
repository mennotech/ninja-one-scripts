# ==============================================================================
# Script Name: Sleep
# ==============================================================================
#
# Description:
#   Used to delay automations in a queue.
#
# Metadata:
#   - NinjaOne Script ID: 100
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-06
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-06 17:56:15
#   - Active: True
# Script Variables (NinjaOne):
#   - seconds (INTEGER, Required): Seconds the script should sleep.
#     Default: 300
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Simple sleep function.
.DESCRIPTION
    Waits for the specified number of seconds then exits. Used to introduce delays between automations in a NinjaOne queue.
.PARAMETER Seconds
    The number of seconds to sleep. Defaults to 60.
.EXAMPLE
    -Seconds 300
    Sleeps for 5 minutes.
.OUTPUTS
    None
.NOTES
    2025-06-06: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/Powershell/100-Sleep.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [Alias("S", "Sec")]
    [Int]$Seconds = 60
)

begin {
    if ($env:Seconds -and $env:Seconds -notlike "null") { $Seconds = $env:Seconds }
}
process {
    Write-Host "[info] $(Get-Date) - Sleeping for $Seconds seconds..."
    Start-Sleep -Seconds $Seconds
    Write-Host "[info] $(Get-Date) - Done sleeping."
    exit 0
}
end {
}
