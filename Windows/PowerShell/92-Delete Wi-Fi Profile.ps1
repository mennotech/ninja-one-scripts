# ==============================================================================
# Script Name: Delete Wi-Fi Profile
# ==============================================================================
#
# Description:
#   Delete a Wi-Fi profile from a device.
#
# Metadata:
#   - NinjaOne Script ID: 92
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-18
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-18 22:36:42
#   - Active: True
# Script Variables (NinjaOne):
#   - ssid (TEXT, Required): Specify the Wi-Fi SSID/name.
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Deletes a Wi-Fi profile from a device.
.DESCRIPTION
    This script deletes a Wi-Fi profile from a device using netsh.
    The script requires administrative privileges to run.

    The script can be run with the following parameters:
        -SSID: Specifies the Wi-Fi SSID/name to delete.

.EXAMPLE
    -SSID "cookiemonster"

    Deleting Wi-Fi profile 'cookiemonster'.
    ExitCode: 0
    Profile "cookiemonster" is deleted from interface "Wi-Fi".

.PARAMETER SSID
    Specify the Wi-Fi SSID/name to delete.
.NOTES
    2025-06-18: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/92-Delete%20Wi-Fi%20Profile.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$SSID
)

begin {
    # If script form variables are used replace the command line parameters.
    if ($env:ssid -and $env:ssid -notlike "null") { $SSID = $env:ssid }

    # If no Wi-Fi interfaces exist or the wireless service is not running, display an error message indicating that they are required.
    try {
        $WifiAdapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.PhysicalMediaType -match '802\.11' }
        if (!$WifiAdapters) {
            Write-Host -Object "[Error] No Wi-Fi network interfaces exist on the system."
            exit 1
        }

        $WlanService = Get-Service -Name 'wlansvc' -ErrorAction Stop | Where-Object { $_.Status -eq 'Running' }
        if (!$WlanService) {
            Write-Host -Object "[Error] The service 'wlansvc' is not running. The service 'wlansvc' is required to manage Wi-Fi profiles."
            exit 1
        }
    }
    catch {
        Write-Host -Object "[Error] Unable to verify if a Wi-Fi network interface exists and that the 'wlansvc' service is running."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # If $SSID is provided, trim any leading or trailing whitespace from the SSID
    if ($SSID) {
        $SSID = $SSID.Trim()
    }

    # If $SSID is not provided or is empty after trimming, display an error message indicating the SSID is required
    if (!$SSID) {
        Write-Host -Object "[Error] The Wi-Fi SSID/name is required to delete a Wi-Fi profile from the device."
        exit 1
    }

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # If the script is not running with elevated privileges, display an error and exit
    if (!(Test-IsElevated)) {
        Write-Host -Object "[Error] Access Denied. Please run with Administrator privileges."
        exit 1
    }

    # Define the paths for standard error and output logs
    $StandardErrorPath = "$env:TEMP\wi-fi.$(New-Guid).err.log"
    $StandardOutputPath = "$env:TEMP\wi-fi.$(New-Guid).out.log"

    # Define the arguments for the netsh command to delete the Wi-Fi profile
    $NetshArguments = @(
        "wlan"
        "delete"
        "profile"
        "name=`"$SSID`""
    )

    # Define the arguments for starting the netsh process
    $NetShProcessArguments = @{
        Wait                   = $True
        PassThru               = $True
        NoNewWindow            = $True
        ArgumentList           = $NetshArguments
        RedirectStandardError  = $StandardErrorPath
        RedirectStandardOutput = $StandardOutputPath
        FilePath               = "$env:SystemRoot\System32\netsh.exe"
    }

    # Attempt to start the netsh process to delete the Wi-Fi profile
    try {
        Write-Host -Object "Deleting Wi-Fi profile '$SSID'."
        $NetshProcess = Start-Process @NetShProcessArguments -ErrorAction Stop
    }
    catch {
        # If an error occurs while starting netsh, display an error message and exit
        Write-Host -Object "[Error] Failed to start netsh."
        Write-Host -Object "[Error] $($_.Exception.Message)"
        exit 1
    }

    # Display the exit code of the netsh process
    Write-Host -Object "ExitCode: $($NetshProcess.ExitCode)"

    # If the exit code indicates failure, display an error message
    if ($NetshProcess.ExitCode -ne 0) {
        Write-Host -Object "[Error] Exit code does not indicate success. Failed to delete Wi-Fi profile."
        $ExitCode = 1
    }

    # If the standard error log file exists, read its content
    if (Test-Path -Path $StandardErrorPath -ErrorAction SilentlyContinue) {
        $NetshErrors = Get-Content -Path $StandardErrorPath -ErrorAction SilentlyContinue
        Remove-Item -Path $StandardErrorPath -Force -ErrorAction SilentlyContinue
    }

    # If there are any errors in the standard error log, display them
    if ($NetshErrors) {
        Write-Host -Object "[Error] An error has occurred when executing netsh."

        $NetshErrors | ForEach-Object {
            Write-Host -Object "[Error] $_"
        }

        $ExitCode = 1
    }

    # If the standard output log file exists, read and display its content
    if (Test-Path -Path $StandardOutputPath -ErrorAction SilentlyContinue) {
        $NetshOutput = Get-Content -Path $StandardOutputPath -ErrorAction SilentlyContinue
        Write-Host -Object $NetshOutput
        Remove-Item -Path $StandardOutputPath -Force -ErrorAction SilentlyContinue
    }

    exit $ExitCode
}
end {
    
    
    
}
