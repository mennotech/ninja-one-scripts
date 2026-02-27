# ==============================================================================
# Script Name: Download and Install Wazuh Agent
# ==============================================================================
#
# Description:
#   Downloads and installs the Wazuh Agent with a specified server address.
#
# Metadata:
#   - NinjaOne Script ID: 89
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: NinjaOne
#   - Created On: 2025-03-31
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-04-29 00:52:49
#   - Active: True
# Script Variables (NinjaOne):
#   - wserver (TEXT, Required): The Wazuh Server URL or IP Address
#     Default: wazuh-agent.menno.tech
#
# ==============================================================================
#Requires -Version 2.0

<#
.SYNOPSIS
    Downloads and installs the Wazuh Agent.
.DESCRIPTION
    Downloads the Wazuh Agent MSI installer and installs it silently, pointing it at the
    specified Wazuh manager server. The server address must be provided via the 'wserver'
    script variable in NinjaOne or via the $env:wserver environment variable.
.OUTPUTS
    Informational messages written to the host indicating each step of the installation process.
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    2025-03-31: Initial version of the script.
    2025-04-29: Updated Wazuh Agent installer URL to v4.11.2.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/89-Download%20and%20Install%20Wazuh%20Agent.ps1
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

    function New-Shortcut {
        [CmdletBinding()]
        param(
            [Parameter()]
            [String]$Arguments,
            [Parameter()]
            [String]$IconPath,
            [Parameter(ValueFromPipeline = $True)]
            [String]$Path,
            [Parameter()]
            [String]$Target,
            [Parameter()]
            [String]$WorkingDir
        )
        process {
            Write-Host "Creating Shortcut at $Path"
            $ShellObject = New-Object -ComObject ("WScript.Shell")
            $Shortcut = $ShellObject.CreateShortcut($Path)
            $Shortcut.TargetPath = $Target
            if ($WorkingDir) { $Shortcut.WorkingDirectory = $WorkingDir }
            if ($Arguments) { $ShortCut.Arguments = $Arguments }
            if ($IconPath) { $Shortcut.IconLocation = $IconPath }
            $Shortcut.Save()

            if (!(Test-Path $Path -ErrorAction SilentlyContinue)) {
                Write-Error "Unable to create Shortcut at $Path"
                exit 1
            }
        }
    }
    # Utility function for downloading files.
    function Invoke-Download {
        param(
            [Parameter()]
            [String]$URL,
            [Parameter()]
            [String]$Path,
            [Parameter()]
            [int]$Attempts = 3,
            [Parameter()]
            [Switch]$SkipSleep
        )
        Write-Host "URL given, Downloading the file..."

        $SupportedTLSversions = [enum]::GetValues('Net.SecurityProtocolType')
        if ( ($SupportedTLSversions -contains 'Tls13') -and ($SupportedTLSversions -contains 'Tls12') ) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol::Tls13 -bor [System.Net.SecurityProtocolType]::Tls12
        }
        elseif ( $SupportedTLSversions -contains 'Tls12' ) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        else {
            # Not everything requires TLS 1.2, but we'll try anyway.
            Write-Warning "TLS 1.2 and or TLS 1.3 are not supported on this system. This download may fail!"
            if ($PSVersionTable.PSVersion.Major -lt 3) {
                Write-Warning "PowerShell 2 / .NET 2.0 doesn't support TLS 1.2."
            }
        }

        $i = 1
        While ($i -le $Attempts) {
            # Some cloud services have rate-limiting
            if (-not ($SkipSleep)) {
                $SleepTime = Get-Random -Minimum 3 -Maximum 15
                Write-Host "Waiting for $SleepTime seconds."
                Start-Sleep -Seconds $SleepTime
            }
        
            if ($i -ne 1) { Write-Host "" }
            Write-Host "Download Attempt $i"

            try {
                # Invoke-WebRequest is preferred because it supports links that redirect, e.g., https://t.ly
                if ($PSVersionTable.PSVersion.Major -lt 4) {
                    # Downloads the file
                    $WebClient = New-Object System.Net.WebClient
                    $WebClient.DownloadFile($URL, $Path)
                }
                else {
                    # Standard options
                    $WebRequestArgs = @{
                        Uri                = $URL
                        OutFile            = $Path
                        MaximumRedirection = 10
                        UseBasicParsing    = $true
                    }

                    # Downloads the file
                    Invoke-WebRequest @WebRequestArgs
                }

                $File = Test-Path -Path $Path -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "An error has occurred while downloading!"
                Write-Warning $_.Exception.Message

                if (Test-Path -Path $Path -ErrorAction SilentlyContinue) {
                    Remove-Item $Path -Force -Confirm:$false -ErrorAction SilentlyContinue
                }

                $File = $False
            }

            if ($File) {
                $i = $Attempts
            }
            else {
                Write-Warning "File failed to download."
                Write-Host ""
            }

            $i++
        }

        if (-not (Test-Path $Path)) {
            throw "Failed to download file!"
        }
        else {
            Write-Host "Download Successful!"
        }
    }

    function Install-WazuhAgent {
        [CmdletBinding()]
        param()
        
        $TargetDir = Join-Path -Path $env:ProgramData -ChildPath "WazuhAgent-Installer"

        # Tools to be downloaded
        $Tools = @(
            [PSCustomObject]@{
                Name     = "Wazuh Agent"
                FileName = "wazuh-agent.msi"
                URL      = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.11.2-1.msi"
            }
        )

        # Create Directory
        if (-not $(Test-Path $TargetDir -ErrorAction SilentlyContinue)) {
            Write-Host "Create Directory: $TargetDir"
            New-Item -ItemType Directory -Path $TargetDir -Force -ErrorAction SilentlyContinue
        }

        # Download tools to target directory
        try {
            foreach ($Tool in $Tools) {
                $FilePath = Join-Path $TargetDir $Tool.FileName
                if (-not $(Test-Path $FilePath)) {
                    Write-Host "Downloading $($Tool.Name) to $FilePath"
                    Invoke-Download -URL $Tool.URL -Path $FilePath
                } else {
                    Write-Host "$FilePath already exists. Skipping download."
                }
            }
        }
        catch {
            throw $_
        }
        
        # Run the Installer
        try {
            foreach ($Tool in $Tools) {
                $FilePath = Join-Path $TargetDir $Tool.FileName
                $InstallArgs = "/q WAZUH_MANAGER='$($env:wserver)'"
                Write-Host "Running $FilePath $InstallArgs"
                $Process = Start-Process $FilePath -ArgumentList $InstallArgs -PassThru -Wait
                Write-Host "Process result $($Process.ExitCode)"
            }
        }
        catch {
            throw $_
        }
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error -Message "Access Denied. Please run with Administrator privileges."
        exit 1
    }

    if (-not ($env:wserver)) {
        Write-Host "WSERVER is not set. Exiting"
        exit 1
    } else {
        Write-Host "Running installation with WSERVER = $($env:wserver)"
        
        try {
            Install-WazuhAgent
        }
        catch {
            Write-Error $_
            exit 1
        }
    }

    Write-Host "Successfully installed and set up Wazuh Agent with WSERVER = $($env:wserver)"
    exit 0
}
end {
    
    
    
}
