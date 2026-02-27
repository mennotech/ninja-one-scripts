# ==============================================================================
# Script Name: Remove Windows Bloatware
# ==============================================================================
#
# Description:
#   Remove common Windows bloatware applications from the system.
#
# Metadata:
#   - NinjaOne Script ID: 93
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-18
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-18 22:36:42
#   - Active: True
# Script Variables (NinjaOne):
#   - additionalPackages (TEXT, Optional): Comma-separated list of additional package names to remove.
#   - dryRun (CHECKBOX, Optional): If checked, list packages to be removed without actually removing them.
#     Default: false
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Removes common Windows bloatware applications.
.DESCRIPTION
    This script removes common Windows bloatware applications from the system.
    It can optionally accept a list of additional package names to remove.
    The script requires administrative privileges to run.

    The script can be run with the following parameters:
        -AdditionalPackages: Comma-separated list of additional package names to remove.
        -DryRun: If specified, list packages to be removed without actually removing them.

.EXAMPLE
    Remove-WindowsBloatware.ps1

    Removing bloatware packages...
    Removed: Microsoft.BingWeather
    Removed: Microsoft.GetHelp
    Done. Removed 2 package(s).

.EXAMPLE
    Remove-WindowsBloatware.ps1 -DryRun

    [DryRun] Would remove: Microsoft.BingWeather
    [DryRun] Would remove: Microsoft.GetHelp
    Done. Would remove 2 package(s).

.NOTES
    2025-06-18: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/93-Remove%20Windows%20Bloatware.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$AdditionalPackages,
    [Parameter()]
    [Switch]$DryRun = [System.Convert]::ToBoolean($env:dryRun)
)

begin {
    # If script form variables are used replace the command line parameters.
    if ($env:additionalPackages -and $env:additionalPackages -notlike "null") { $AdditionalPackages = $env:additionalPackages }

    # Default list of bloatware packages to remove
    $BloatwarePackages = @(
        "Microsoft.3DBuilder"
        "Microsoft.BingFinance"
        "Microsoft.BingNews"
        "Microsoft.BingSports"
        "Microsoft.BingWeather"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.Messaging"
        "Microsoft.Microsoft3DViewer"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.MixedReality.Portal"
        "Microsoft.NetworkSpeedTest"
        "Microsoft.News"
        "Microsoft.Office.Sway"
        "Microsoft.OneConnect"
        "Microsoft.People"
        "Microsoft.Print3D"
        "Microsoft.RemoteDesktop"
        "Microsoft.SkypeApp"
        "Microsoft.Todos"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.WindowsMaps"
        "Microsoft.WindowsSoundRecorder"
        "Microsoft.Xbox.TCUI"
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.YourPhone"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
    )

    # If additional packages are provided, add them to the list
    if ($AdditionalPackages) {
        $AdditionalPackageList = $AdditionalPackages -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $BloatwarePackages += $AdditionalPackageList
    }

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    $ExitCode = 0
}
process {
    # If the script is not running with elevated privileges, display an error and exit
    if (!(Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    $RemovedCount = 0

    Write-Host -Object "$(if ($DryRun) { '[DryRun] ' })Processing bloatware packages..."

    foreach ($Package in $BloatwarePackages) {
        try {
            $AppxPackage = Get-AppxPackage -Name $Package -AllUsers -ErrorAction SilentlyContinue
            $ProvisionedPackage = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $Package }

            if ($AppxPackage -or $ProvisionedPackage) {
                if ($DryRun) {
                    Write-Host -Object "[DryRun] Would remove: $Package"
                    $RemovedCount++
                }
                else {
                    if ($AppxPackage) {
                        $AppxPackage | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    }
                    if ($ProvisionedPackage) {
                        $ProvisionedPackage | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                    }
                    Write-Host -Object "Removed: $Package"
                    $RemovedCount++
                }
            }
        }
        catch {
            Write-Host -Object "[Error] Failed to remove package '$Package': $($_.Exception.Message)"
            $ExitCode = 1
        }
    }

    if ($DryRun) {
        Write-Host -Object "Done. Would remove $RemovedCount package(s)."
    }
    else {
        Write-Host -Object "Done. Removed $RemovedCount package(s)."
    }

    exit $ExitCode
}
end {
    
    
    
}
