# ==============================================================================
# Script Name: Upgrade Duo Windows Login
# ==============================================================================
#
# Description:
#   Downloads the latest Duo Windows Logon installer, extracts it, and installs it silently.
#
# Metadata:
#   - NinjaOne Script ID: 106
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64
#   - Created By: Roland Penner
#   - Created On: 2025-07-17
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-07-17 21:26:59
#   - Active: True
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Downloads the latest Duo Windows Logon installer, extracts it, and installs it silently.
.DESCRIPTION
    Downloads the latest Duo Windows Logon MSI installer package from the Duo Security website,
    extracts the archive, and runs the 64-bit MSI installer silently.
    Temporary files are cleaned up after installation.
.OUTPUTS
    Informational messages are written to the host indicating each step of the process.
.NOTES
    2025-07-17: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/106-Upgrade%20Duo%20Windows%20Login.ps1
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

    function Remove-TemporaryFiles {
        $tempFolder = Join-Path $env:TEMP "duo-win-login-latest"
        $tempZip = Join-Path $env:TEMP "duo-win-login-latest.zip"
        if (Test-Path $tempFolder) {
            Write-Host "Cleaning up zip folder"
            Remove-Item -Recurse -Force $tempFolder
        }
        if (Test-Path $tempZip) {
            Write-Host "Removing zip file"
            Remove-Item -Force $tempZip
        }
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error "This script requires administrative privileges."
        exit 1
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $tempZip = Join-Path $env:TEMP "duo-win-login-latest.zip"
    $tempFolder = Join-Path $env:TEMP "duo-win-login-latest"

    Write-Host "Downloading Zip file"
    try {
        Invoke-WebRequest -Uri "https://dl.duosecurity.com/DuoWinLogon_MSIs_Policies_and_Documentation-latest.zip" -OutFile $tempZip -UseBasicParsing
    } catch {
        Write-Error "Download failed: $_"
        Remove-TemporaryFiles
        exit 1
    }

    if (Test-Path $tempZip) {
        Write-Host "Expanding Archive"
        Expand-Archive $tempZip -DestinationPath $tempFolder -Force
    } else {
        Write-Host "Download failed"
        Remove-TemporaryFiles
        exit 1
    }

    $installerPath = Join-Path $tempFolder "DuoWindowsLogon64.msi"
    if (Test-Path $installerPath) {
        Write-Host "Running Installer"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "-qn /i `"$installerPath`"" -Wait -NoNewWindow
    } else {
        Write-Host "Installer not found."
        Remove-TemporaryFiles
        exit 2
    }

    Write-Host "Installation complete. Cleaning up temporary files."
    Remove-TemporaryFiles
}
end {
}
