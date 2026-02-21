# ==============================================================================
# Script Name: Deploy Blackpoint SNAP Agent
# ==============================================================================
#
# Description:
#   Downloads and installs the Blackpoint SNAP Agent using a URL from a NinjaOne custom field.
#
# Metadata:
#   - NinjaOne Script ID: 113
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64
#   - Created By: Roland Penner
#   - Created On: 2025-11-07
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-11-07 23:51:40
#   - Active: True
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Downloads and installs the Blackpoint SNAP Agent.
.DESCRIPTION
    Retrieves the Blackpoint SNAP installer URL from a NinjaOne custom field named 'blackpointInstallerUrl',
    downloads the installer, verifies .NET 4.6.1+ is present, and installs the SNAP agent silently.
    If the SNAP service is already running, the script exits without reinstalling.
.OUTPUTS
    Informational messages written to the host indicating each step of the installation process.
.NOTES
    2025-11-07: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/113-Deploy%20Blackpoint%20SNAP%20Agent.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param ()

begin {
    # Installer name
    $InstallerName = "snap_installer.exe"
    # Install location
    $InstallerPath = Join-Path $env:TEMP $InstallerName
    # Service name
    $SnapServiceName = "Snap"
    # Enable debug with 1
    $DebugMode = 0
    # Failure message
    $Failure = "Snap was not installed Successfully. Contact support@blackpointcyber.com if you need more help."

    function Test-IsElevated {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Get-NinjaProperty {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
            [String]$Name,
            [Parameter()]
            [String]$Type,
            [Parameter()]
            [String]$DocumentName
        )

        $DocumentationParams = @{}
        if ($DocumentName) { $DocumentationParams["DocumentName"] = $DocumentName }

        $NeedsOptions = "DropDown", "MultiSelect"

        if ($DocumentName) {
            if ($Type -Like "Secure") { throw [System.ArgumentOutOfRangeException]::New("$Type is an invalid type! Please check here for valid types. https://ninjarmm.zendesk.com/hc/en-us/articles/16973443979789-Command-Line-Interface-CLI-Supported-Fields-and-Functionality") }

            Write-Host "Retrieving value from Ninja Document..."
            $NinjaPropertyValue = Ninja-Property-Docs-Get -AttributeName $Name @DocumentationParams 2>&1

            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Docs-Options -AttributeName $Name @DocumentationParams 2>&1
            }
        } else {
            $NinjaPropertyValue = Ninja-Property-Get -Name $Name 2>&1

            if ($NeedsOptions -contains $Type) {
                $NinjaPropertyOptions = Ninja-Property-Options -Name $Name 2>&1
            }
        }

        if ($NinjaPropertyValue.Exception) { throw $NinjaPropertyValue }
        if ($NinjaPropertyOptions.Exception) { throw $NinjaPropertyOptions }

        if (-not $NinjaPropertyValue) {
            throw [System.NullReferenceException]::New("The Custom Field '$Name' is empty!")
        }

        switch ($Type) {
            "Attachment" { $NinjaPropertyValue | ConvertFrom-Json }
            "Checkbox" { [System.Convert]::ToBoolean([int]$NinjaPropertyValue) }
            "Date or Date Time" {
                $UnixTimeStamp = $NinjaPropertyValue
                $UTC = (Get-Date "1970-01-01 00:00:00").AddSeconds($UnixTimeStamp)
                $TimeZone = [TimeZoneInfo]::Local
                [TimeZoneInfo]::ConvertTimeFromUtc($UTC, $TimeZone)
            }
            "Decimal" { [double]$NinjaPropertyValue }
            "Device Dropdown" { $NinjaPropertyValue | ConvertFrom-Json }
            "Device MultiSelect" { $NinjaPropertyValue | ConvertFrom-Json }
            "Dropdown" {
                $Options = $NinjaPropertyOptions -replace '=', ',' | ConvertFrom-Csv -Header "GUID", "Name"
                $Options | Where-Object { $_.GUID -eq $NinjaPropertyValue } | Select-Object -ExpandProperty Name
            }
            "Integer" { [int]$NinjaPropertyValue }
            "MultiSelect" {
                $Options = $NinjaPropertyOptions -replace '=', ',' | ConvertFrom-Csv -Header "GUID", "Name"
                $Selection = ($NinjaPropertyValue -split ',').trim()
                foreach ($Item in $Selection) {
                    $Options | Where-Object { $_.GUID -eq $Item } | Select-Object -ExpandProperty Name
                }
            }
            "Organization Dropdown" { $NinjaPropertyValue | ConvertFrom-Json }
            "Organization Location Dropdown" { $NinjaPropertyValue | ConvertFrom-Json }
            "Organization Location MultiSelect" { $NinjaPropertyValue | ConvertFrom-Json }
            "Organization MultiSelect" { $NinjaPropertyValue | ConvertFrom-Json }
            "Time" {
                $Seconds = $NinjaPropertyValue
                $UTC = ([timespan]::fromseconds($Seconds)).ToString("hh\:mm\:ss")
                $TimeZone = [TimeZoneInfo]::Local
                $ConvertedTime = [TimeZoneInfo]::ConvertTimeFromUtc($UTC, $TimeZone)
                Get-Date $ConvertedTime -DisplayHint Time
            }
            default { $NinjaPropertyValue }
        }
    }

    function Get-TimeStamp {
        return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    }

    function Test-SnapInstalled {
        param([string]$service)
        if (Get-Service $service -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    }

    function Write-DebugMessage {
        param([string]$message)
        if ($DebugMode -eq 1) {
            Write-Host "$(Get-TimeStamp) [DEBUG] $message"
        }
    }

    function Test-DotNetVersion {
        Write-DebugMessage "Checking for .NET 4.6.1+..."
        if (-not (Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -gt 394254) {
            $NetError = "SNAP needs 4.6.1+ of .NET...EXITING"
            Write-Host "$(Get-TimeStamp) $NetError"
            exit 0
        }
        Write-DebugMessage "4.6.1+ Installed..."
    }

    function Get-SnapInstaller {
        Write-DebugMessage "Downloading from provided $DownloadURL..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Client = New-Object System.Net.Webclient
        try {
            $Client.DownloadFile($DownloadURL, $InstallerPath)
        } catch {
            $ErrorMsg = $_.Exception.Message
            Write-Host "$(Get-TimeStamp) $ErrorMsg"
        }
        if (-not (Test-Path $InstallerPath)) {
            $DownloadError = "Failed to download the SNAP Installation file from $DownloadURL"
            Write-Host "$(Get-TimeStamp) $DownloadError"
            throw $Failure
        }
        Write-DebugMessage "Installer Downloaded to $InstallerPath..."
    }

    function Install-SnapAgent {
        Write-DebugMessage "Verifying AV did not steal exe..."
        if (-not (Test-Path $InstallerPath)) {
            $AVError = "Something, or someone, deleted the file."
            Write-Host "$(Get-TimeStamp) $AVError"
            throw $Failure
        }
        Write-DebugMessage "Unpacking and Installing agent..."
        Start-Process -NoNewWindow -FilePath $InstallerPath -ArgumentList "-y"
    }

    function Invoke-SnapInstall {
        Write-DebugMessage "Starting..."
        Write-DebugMessage "Checking if SNAP is already installed..."
        if (Test-SnapInstalled($SnapServiceName)) {
            $ServiceError = "SNAP is Already Installed...Bye."
            Write-Host "$(Get-TimeStamp) $ServiceError"
            exit 0
        }
        Test-DotNetVersion
        Get-SnapInstaller
        Install-SnapAgent
        Write-Host "$(Get-TimeStamp) Snap Installed..."
    }
}
process {
    if (-not (Test-IsElevated)) {
        Write-Error "This script requires administrative privileges."
        exit 1
    }

    # Customer UID found in URL from Blackpoint Portal
    $blackpointInstallerUrl = Get-NinjaProperty -Name "blackpointInstallerUrl"

    if ($blackpointInstallerUrl) {
        Write-Host "Blackpoint Installation started. URL: $blackpointInstallerUrl"
    } else {
        Write-Host "No URL specified in field blackpointInstallerUrl"
        exit 1
    }

    # Snap URL
    $DownloadURL = $blackpointInstallerUrl

    try {
        Invoke-SnapInstall
    } catch {
        $ErrorMsg = $_.Exception.Message
        Write-Host "$(Get-TimeStamp) $ErrorMsg"
        exit 1
    }
}
end {
}
