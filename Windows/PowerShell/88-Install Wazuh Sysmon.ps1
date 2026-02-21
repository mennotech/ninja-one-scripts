# ==============================================================================
# Script Name: Install Wazuh Sysmon
# ==============================================================================
#
# Description:
#   Downloads and installs Sysmon for Wazuh using SwiftOnSecurity's configuration.
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
    Downloads and installs Sysmon for use with Wazuh.
.DESCRIPTION
    Downloads Microsoft Sysmon and SwiftOnSecurity's recommended sysmon configuration,
    installs Sysmon with the configuration, and verifies the current configuration.
    If already installed (the Wazuh-Sysmon directory exists), the script exits without reinstalling.
.OUTPUTS
    Informational messages written to the host indicating each step of the installation process.
.NOTES
    2025-04-28: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/88-Install%20Wazuh%20Sysmon.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param ()

begin {
    $SysmonDir = "$env:ProgramData\Wazuh-Sysmon"
}
process {
    if (Test-Path $SysmonDir) {
        Write-Host "Already installed, cancelling."
    } else {
        New-Item -ItemType Directory -Path $SysmonDir -Force | Out-Null
        Set-Location $SysmonDir
        Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "Sysmon.zip"
        Expand-Archive -Path "Sysmon.zip" -DestinationPath "." -Force
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "sysmonconfig.xml"
        & ".\sysmon" -accepteula -i "sysmonconfig.xml"
        & ".\sysmon" -c
    }
}
end {
}
