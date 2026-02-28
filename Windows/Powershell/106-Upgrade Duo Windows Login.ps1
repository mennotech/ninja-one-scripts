#Requires -Version 5.1

<#
.SYNOPSIS
    Downloads the latest Duo Windows Logon MSI and installs it silently.
.DESCRIPTION
    Downloads the latest Duo Windows Logon installer zip from the official Duo Security URL,
    extracts the 64-bit MSI, and installs it silently. Temporary files are cleaned up after installation.
.OUTPUTS
    None
.NOTES
    2025-07-17: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/Powershell/106-Upgrade%20Duo%20Windows%20Login.ps1
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
        if (Test-Path "C:\duo-win-login-latest\") {
            Write-Host "Cleaning up zip folder"
            Remove-Item -Recurse -Force "C:\duo-win-login-latest\"
        }
        if (Test-Path "C:\duo-win-login-latest.zip") {
            Write-Host "Removing zip file"
            Remove-Item -Force "C:\duo-win-login-latest.zip"
        }
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error "This script requires administrative privileges."
        exit 1
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "Downloading Zip file"
    try {
        Invoke-WebRequest -Uri "https://dl.duosecurity.com/DuoWinLogon_MSIs_Policies_and_Documentation-latest.zip" -OutFile "C:\duo-win-login-latest.zip" -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Error "Download failed: $_"
        Remove-TemporaryFiles
        exit 1
    }

    if (Test-Path "C:\duo-win-login-latest.zip") {
        Write-Host "Expanding Archive"
        Expand-Archive "C:\duo-win-login-latest.zip" -DestinationPath C:\duo-win-login-latest -Force
    } else {
        Write-Host "Download failed"
        Remove-TemporaryFiles
        exit 1
    }

    if (Test-Path "C:\duo-win-login-latest\DuoWindowsLogon64.msi") {
        Write-Host "Running Installer"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /i C:\duo-win-login-latest\DuoWindowsLogon64.msi" -Wait -NoNewWindow
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
