# ==============================================================================
# Script Name: Remove Dell Support Assist
# ==============================================================================
#
# Description:
#   Remove Dell SupportAssist and related components from the system.
#
# Metadata:
#   - NinjaOne Script ID: 96
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-18
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-18 22:36:42
#   - Active: True
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Removes Dell SupportAssist and related components from the system.
.DESCRIPTION
    This script removes Dell SupportAssist and related software components from the system.
    It searches for Dell SupportAssist in the Windows registry and runs the uninstallers found.
    The script requires administrative privileges to run.

.EXAMPLE
    Remove-DellSupportAssist.ps1

    Searching for Dell SupportAssist installations...
    Found: Dell SupportAssist v3.12.0.0
    Uninstalling Dell SupportAssist...
    Successfully uninstalled Dell SupportAssist.

.NOTES
    2025-06-18: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/96-Remove%20Dell%20Support%20Assist.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param ()

begin {
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

    Write-Host -Object "Searching for Dell SupportAssist installations..."

    # Registry paths to search for installed software
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $DellSupportAssistEntries = @()

    foreach ($RegPath in $RegistryPaths) {
        if (Test-Path -Path $RegPath) {
            $DellSupportAssistEntries += Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue |
                Get-ItemProperty -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "*Dell*SupportAssist*" -or $_.DisplayName -like "*SupportAssist*" }
        }
    }

    if (!$DellSupportAssistEntries) {
        Write-Host -Object "No Dell SupportAssist installations found."
        exit 0
    }

    foreach ($Entry in $DellSupportAssistEntries) {
        Write-Host -Object "Found: $($Entry.DisplayName) v$($Entry.DisplayVersion)"

        if ($Entry.UninstallString) {
            Write-Host -Object "Uninstalling $($Entry.DisplayName)..."

            try {
                # Parse the uninstall string
                $UninstallString = $Entry.UninstallString

                # Handle MSI uninstallers
                if ($UninstallString -match "msiexec") {
                    $ProductCode = $UninstallString -replace '.*?(\{[A-F0-9\-]+\}).*', '$1'
                    if ($ProductCode -match '^\{') {
                        $Arguments = @("/x", $ProductCode, "/quiet", "/norestart")
                        $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow -ErrorAction Stop
                    }
                    else {
                        Write-Host -Object "[Warning] Could not parse MSI product code from: $UninstallString"
                        continue
                    }
                }
                else {
                    # Handle EXE uninstallers - add silent flags
                    $ExePath = $UninstallString -replace '"', '' -replace ' .*', ''
                    $Process = Start-Process -FilePath $ExePath -ArgumentList @("/quiet", "/norestart") -Wait -PassThru -NoNewWindow -ErrorAction Stop
                }

                if ($Process.ExitCode -eq 0) {
                    Write-Host -Object "Successfully uninstalled $($Entry.DisplayName)."
                }
                else {
                    Write-Host -Object "[Warning] Uninstall of '$($Entry.DisplayName)' exited with code $($Process.ExitCode)."
                    $ExitCode = 1
                }
            }
            catch {
                Write-Host -Object "[Error] Failed to uninstall '$($Entry.DisplayName)': $($_.Exception.Message)"
                $ExitCode = 1
            }
        }
        else {
            Write-Host -Object "[Warning] No uninstall string found for '$($Entry.DisplayName)'. Skipping."
        }
    }

    exit $ExitCode
}
end {
    
    
    
}
