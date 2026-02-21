# ==============================================================================
# Script Name: Set ShadowCopies MaxSize
# ==============================================================================
#
# Description:
#   Changes the maximum size used for Windows Shadow Copies storage.
#
# Metadata:
#   - NinjaOne Script ID: 102
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-12
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-18 22:07:49
#   - Active: True
# Script Variables (NinjaOne):
#   - size (INTEGER, Required): Max Shadow Copies Storage as percentage of 100
#     Default: 10
#   - drive (TEXT, Optional): The drive letter
#     Default: C
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Sets the maximum size for Windows Shadow Copies on a specified drive.
.DESCRIPTION
    The script allows you to set the maximum size for Shadow Copies on a specified drive (default is C:).
    It checks the current configuration, attempts to update the maximum size, and displays the new configuration.
    If the update fails, it provides an error message.

    The script takes the following parameters:
      -Size (REQUIRED)   An integer used as the total percentage that Windows can allocate to Shadow Copies.
      -Drive             A single letter for the drive to configure, default value is "C".
.PARAMETER Size
    An integer used as the total percentage that Windows can allocate to Shadow Copies. Required.
.PARAMETER Drive
    A single letter for the drive to configure. Default value is "C".
.OUTPUTS
    Displays the current and new configuration of Shadow Copies on the specified drive.
    If the update fails, an error message is displayed.
.NOTES
    2025-06-18: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/102-Set%20ShadowCopies%20MaxSize.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [int]$Size = 0,
    [Parameter()]
    [string]$Drive = "C"
)

begin {
    # Replace parameters with dynamic script variables.
    if ($env:Size -and $env:Size -notlike "null") { $Size = $env:Size }
    if ($env:Drive -and $env:Drive -notlike "null") { $Drive = $env:Drive }

    function Test-IsElevated {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error "This script requires administrative privileges."
        exit 1
    }

    if ($Size -eq 0) {
        Write-Host "Usage: Set-ShadowCopiesMaxSize.ps1 -Size [int] -Drive [drive letter]"
        exit 1
    }

    if ($Size -lt 2) {
        Write-Host "Minimum Size is 2%, exiting (Got $Size)"
        exit 10
    }

    if ($Size -gt 50) {
        Write-Host "Maximum Size is 50%, exiting"
        exit 10
    }

    if ((Get-PSDrive -Name $Drive -ErrorAction SilentlyContinue).Count -ne 1) {
        Write-Host "Drive $Drive is invalid."
        exit 11
    }

    Write-Host "Current configuration:"
    $currentConfig = C:\Windows\System32\vssadmin.exe List ShadowStorage /On="$($Drive):"
    $currentConfig | Where-Object { $_ -match "Used|Allocated|Maximum" } | ForEach-Object { Write-Host " $($_.Trim())" }

    Write-Host "Attempting to update max size to $($Size)%"
    $update = C:\Windows\System32\vssadmin.exe Resize ShadowStorage /For="$($Drive):" /On="$($Drive):" /MaxSize="$($Size)%"

    if ($update -match "Successfully resized") {
        Write-Host "New configuration:"
        $newConfig = C:\Windows\System32\vssadmin.exe List ShadowStorage /On="$($Drive):"
        $newConfig | Where-Object { $_ -match "Used|Allocated|Maximum" } | ForEach-Object { Write-Host " $($_.Trim())" }
    } else {
        Write-Host "Update failed:"
        $update | Select-Object -Skip 3 | ForEach-Object { Write-Host " $($_.Trim())" }
        exit 2
    }
}
end {
}
