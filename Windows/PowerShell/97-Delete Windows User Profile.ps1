# ==============================================================================
# Script Name: Delete Windows User Profile
# ==============================================================================
#
# Description:
#   Deletes a local Windows user profile directory and corresponding registry entry.
#
# Metadata:
#   - NinjaOne Script ID: 97
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-05-31
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-18 22:06:14
#   - Active: True
# Script Variables (NinjaOne):
#   - userfolder (TEXT, Required): The name of the user's profile folder
#     Default: John
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Removes a local Windows user profile and its corresponding registry entry.
.DESCRIPTION
    The script allows you to delete a local user profile by specifying the user's folder name.
    It searches for user profiles matching the specified folder name and removes them if found.
    If no matching profiles are found, it provides an error message.

    The script takes the following parameter:
      -UserFolder (REQUIRED)   The name of the user's folder to search for and delete.
.PARAMETER UserFolder
    The name of the user's profile folder to search for and delete. Defaults to "Default".
.OUTPUTS
    Progress messages written to the host. Exits with code 1 if the profile is not found or deletion fails.
.NOTES
    2025-06-18: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/97-Delete%20Windows%20User%20Profile.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
Param(
    [Parameter()]
    [string]$UserFolder = "Default"
)

begin {
    # Replace parameters with dynamic script variables.
    if ($env:UserFolder -and $env:UserFolder -notlike "null") { $UserFolder = $env:UserFolder }

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

    $UserProfiles = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.LocalPath -match $UserFolder }

    if ($UserProfiles) {
        try {
            foreach ($Profile in $UserProfiles) {
                Write-Host "Found matching profile: $($Profile.LocalPath). Deleting..."
                $Profile | Remove-WmiObject
            }
        } catch {
            Write-Warning "An error occurred while attempting to delete profile"
            exit 1
        }
    } else {
        Write-Warning "No matching profiles found for $($UserFolder)"
        exit 1
    }

    Write-Host "Done."
    exit 0
}
end {
}
