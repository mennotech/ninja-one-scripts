# ==============================================================================
# Script Name: Install Wazuh Sysmon
# ==============================================================================
#
# Description:
#   Downloads and installs Sysmon with the SwiftOnSecurity configuration for Wazuh.
#
# Metadata:
#   - NinjaOne Script ID: 88
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-04-28
#   - Last Updated By: Roland Admin
#   - Last Updated: 2026-02-21 03:25:36
#   - Active: True
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Downloads and installs Sysmon with the SwiftOnSecurity configuration for use with Wazuh.
.DESCRIPTION
    Checks if Sysmon is already installed in C:\ProgramData\Wazuh-Sysmon. If not, creates the directory,
    downloads Sysmon from Sysinternals and the SwiftOnSecurity sysmon config from GitHub, then installs
    Sysmon with the downloaded configuration.
.OUTPUTS
    None
.NOTES
    2025-04-28: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/Powershell/88-Install%20Wazuh%20Sysmon.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param ()

begin {
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

    $InstallDir = "C:\ProgramData\Wazuh-Sysmon"

    if (Test-Path "$InstallDir") {
        Write-Host "Already installed, cancelling."
    } else {
        try {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            Set-Location -Path $InstallDir

            Write-Host "Downloading Sysmon..."
            Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$InstallDir\Sysmon.zip" -UseBasicParsing -ErrorAction Stop
            Expand-Archive -Path "$InstallDir\Sysmon.zip" -DestinationPath $InstallDir -Force
            Remove-Item -Path "$InstallDir\Sysmon.zip" -Force

            Write-Host "Downloading Sysmon configuration..."
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "$InstallDir\sysmonconfig.xml" -UseBasicParsing -ErrorAction Stop

            Write-Host "Installing Sysmon..."
            & "$InstallDir\sysmon.exe" -accepteula -i "$InstallDir\sysmonconfig.xml"
            & "$InstallDir\sysmon.exe" -c
        } catch {
            Write-Error "An error occurred during Sysmon installation: $_"
            exit 1
        }
    }
}
end {
}
