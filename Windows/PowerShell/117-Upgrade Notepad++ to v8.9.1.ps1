# ==============================================================================
# Script Name: Upgrade Notepad++ to v8.9.1
# ==============================================================================
#
# Description:
#   Uninstalls any existing Notepad++ version and installs v8.9.1 (x64) silently.
#
# Metadata:
#   - NinjaOne Script ID: 117
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2026-02-03
#   - Last Updated By: Roland Penner
#   - Last Updated: 2026-02-03 20:23:18
#   - Active: True
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Uninstalls existing Notepad++ and installs v8.9.1 (x64) silently.
.DESCRIPTION
    Uninstalls any currently installed version of Notepad++ and then installs v8.9.1 (x64)
    downloaded from the official GitHub releases page. Uses BITS transfer when available,
    otherwise falls back to Invoke-WebRequest.
    Exit codes:
      0  = Success
      10 = Uninstall failed
      20 = Download failed
      30 = Install failed
.OUTPUTS
    Log messages are written to the console and to a log file in $env:ProgramData\NinjaOne\Logs\.
.NOTES
    2026-02-03: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/117-Upgrade%20Notepad%2B%2B%20to%20v8.9.1.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param ()

begin {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $InstallerUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.9.1/npp.8.9.1.Installer.x64.exe'
    $TempDir      = Join-Path $env:TEMP "NPP_Deploy"
    $Installer    = Join-Path $TempDir "npp.8.9.1.Installer.x64.exe"
    $LogDir       = Join-Path $env:ProgramData "NinjaOne\Logs"
    $LogFile      = Join-Path $LogDir "NotepadPP_Deploy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    # Ensure directories exist
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

    function Write-Log {
        param([string]$Message)
        $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $line  = "[$stamp] $Message"
        $line | Tee-Object -FilePath $LogFile -Append
    }

    function Get-NppUninstallEntries {
        $paths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $entries = foreach ($p in $paths) {
            try {
                Get-ItemProperty -Path $p -ErrorAction Stop | Where-Object {
                    $_.DisplayName -match '^Notepad(\+\+|plusplus)'
                }
            } catch { }
        }
        return $entries
    }

    function Stop-NppIfRunning {
        try {
            $procs = Get-Process -Name 'notepad++' -ErrorAction SilentlyContinue
            if ($procs) {
                Write-Log "Notepad++ process detected, attempting to stop."
                $procs | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
        } catch {
            Write-Log "Warning: Failed to stop Notepad++ process. $_"
        }
    }

    function Uninstall-NotepadPP {
        $entries = Get-NppUninstallEntries
        if (-not $entries) {
            Write-Log "No existing Notepad++ installation found."
            return $true
        }

        Stop-NppIfRunning

        $allOk = $true

        foreach ($e in $entries) {
            $displayName   = $e.DisplayName
            $uninstallStr  = $e.UninstallString
            Write-Log "Found installed: $displayName"
            if (-not $uninstallStr) {
                Write-Log "No UninstallString found for $displayName; skipping."
                continue
            }

            try {
                if ($uninstallStr -match 'msiexec\.exe') {
                    $cmd = $uninstallStr
                    if ($cmd -notmatch '/x' -and $cmd -notmatch '/X') {
                        if ($e.PSChildName -match '^\{.*\}$') {
                            $cmd = "msiexec.exe /x $($e.PSChildName) /qn /norestart"
                        } else {
                            $cmd = $cmd -replace '/i', '/x'
                            if ($cmd -notmatch '/x') { $cmd += ' /x' }
                            if ($cmd -notmatch '/qn') { $cmd += ' /qn' }
                            if ($cmd -notmatch '/norestart') { $cmd += ' /norestart' }
                        }
                    } else {
                        if ($cmd -notmatch '/qn') { $cmd += ' /qn' }
                        if ($cmd -notmatch '/norestart') { $cmd += ' /norestart' }
                    }
                    Write-Log "Uninstall (MSI): $cmd"
                    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $cmd" -Wait -PassThru -WindowStyle Hidden
                    if ($p.ExitCode -ne 0) {
                        Write-Log "MSI uninstall exit code: $($p.ExitCode)"
                        $allOk = $false
                    }
                } else {
                    $exe, $args = $null, $null

                    if ($uninstallStr.StartsWith('"')) {
                        $exe = $uninstallStr.Split('"')[1]
                        $args = $uninstallStr.Substring($uninstallStr.IndexOf('"', 1) + 1).Trim()
                    } else {
                        $parts = $uninstallStr.Split(' ', 2)
                        $exe   = $parts[0]
                        $args  = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                    }

                    if ([string]::IsNullOrWhiteSpace($args)) { $args = '/S' }
                    elseif ($args -notmatch '(^| )/S( |$)') { $args += ' /S' }

                    Write-Log "Uninstall (EXE): `"$exe`" $args"
                    $p = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
                    if ($p.ExitCode -ne 0) {
                        Write-Log "EXE uninstall exit code: $($p.ExitCode)"
                        $allOk = $false
                    }
                }
            } catch {
                Write-Log "Error uninstalling $displayName : $_"
                $allOk = $false
            }
        }

        $post = Get-NppUninstallEntries
        if ($post) {
            Write-Log "Notepad++ still detected after uninstall attempt."
            $allOk = $false
        } else {
            Write-Log "Notepad++ successfully uninstalled (or not present)."
        }

        return $allOk
    }

    function Get-NppInstaller {
        try {
            Write-Log "Downloading installer from $InstallerUrl to $Installer"
            if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
                Start-BitsTransfer -Source $InstallerUrl -Destination $Installer -ErrorAction Stop
            } else {
                Invoke-WebRequest -Uri $InstallerUrl -OutFile $Installer -UseBasicParsing -ErrorAction Stop
            }
            if (-not (Test-Path $Installer)) {
                throw "Download completed but file not found at $Installer"
            }
            $size = (Get-Item $Installer).Length
            if ($size -lt 1024kb) {
                throw "Downloaded file size too small ($size bytes) - possible network/content issue."
            }
            Write-Log "Download OK. Size: $([math]::Round($size/1MB,2)) MB"
            return $true
        } catch {
            Write-Log "Download failed: $_"
            return $false
        }
    }

    function Install-NotepadPP {
        try {
            if (-not (Test-Path $Installer)) {
                Write-Log "Installer not found at $Installer"
                return $false
            }

            $installArgs = '/S'

            Write-Log "Installing Notepad++ v8.9.1: `"$Installer`" $installArgs"
            $p = Start-Process -FilePath $Installer -ArgumentList $installArgs -Wait -PassThru -WindowStyle Hidden
            if ($p.ExitCode -ne 0) {
                Write-Log "Installer exit code: $($p.ExitCode)"
                return $false
            }

            $exePaths = @(
                "$env:ProgramFiles\Notepad++\notepad++.exe",
                "$env:ProgramFiles(x86)\Notepad++\notepad++.exe"
            )
            $installed = $exePaths | Where-Object { Test-Path $_ }
            if ($installed) {
                Write-Log "Install verification OK. Path(s): $($installed -join ', ')"
                return $true
            } else {
                Write-Log "Install verification failed: notepad++.exe not found."
                return $false
            }
        } catch {
            Write-Log "Install failed: $_"
            return $false
        }
    }
}
process {
    Write-Log "=== Notepad++ Deployment started ==="

    $uninstalled = Uninstall-NotepadPP
    if (-not $uninstalled) {
        Write-Log "Uninstall phase reported failure."
        Write-Log "=== Notepad++ Deployment finished with errors (uninstall) ==="
        exit 10
    }

    $downloaded = Get-NppInstaller
    if (-not $downloaded) {
        Write-Log "=== Notepad++ Deployment finished with errors (download) ==="
        exit 20
    }

    $installed = Install-NotepadPP
    if (-not $installed) {
        Write-Log "=== Notepad++ Deployment finished with errors (install) ==="
        exit 30
    }

    Write-Log "=== Notepad++ Deployment completed successfully ==="
    exit 0
}
end {
    # Cleanup temp files
    try {
        Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch { }
}
