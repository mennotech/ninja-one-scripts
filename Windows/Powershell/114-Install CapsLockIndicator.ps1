# ==============================================================================
# Script Name: Install CapsLockIndicator
# ==============================================================================
#
# Description:
#   Installs and registers CapsLockIndicator from github.
#
# Metadata:
#   - NinjaOne Script ID: 114
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64
#   - Created By: Roland Penner
#   - Created On: 2025-12-22
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-12-22 17:09:23
#   - Active: True
# ==============================================================================

#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy or update CapsLockIndicator from GitHub for all users.
.DESCRIPTION
    Downloads the latest CapsLockIndicator release from GitHub, installs it to ProgramData,
    grants the Users group write permissions, registers it for all-users startup via the HKLM Run
    registry key, and optionally saves a configuration from a NinjaOne custom field.
.OUTPUTS
    None
.NOTES
    2025-12-22: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/Powershell/114-Install%20CapsLockIndicator.ps1
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

    # Configuration
$installPath = "$($env:ProgramData)\CapsLockIndicator"
$gitHubRepo = "jonaskohl/CapsLockIndicator"
$exeName = "CapsLockIndicator.exe"
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$registryName = "CapsLockIndicator"

# Get latest release info from GitHub API
try {
    $apiUrl = "https://api.github.com/repos/$gitHubRepo/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $latestVersion = $release.tag_name
    $downloadUrl = ($release.assets | Where-Object { $_.name -like "*.exe" }).browser_download_url
    
    if (-not $downloadUrl) {
        Write-Error "Failed to find executable asset in latest release"
        exit 1
    }
    
    Write-Output "Latest version available: $latestVersion"
} catch {
    Write-Error "Failed to fetch latest release info: $_"
    exit 1
}

# Check current installation
$currentVersion = $null
$needsInstall = $true
$exePath = Join-Path $installPath $exeName

if (Test-Path $exePath) {
    try {
        $versionInfo = (Get-Item $exePath).VersionInfo
        $currentVersion = $versionInfo.FileVersion
        Write-Output "Current version installed: $currentVersion"
        
        # Compare versions (simple string comparison)
        if ($currentVersion -eq $latestVersion.TrimStart('v')) {
            Write-Output "Already running latest version"
            $needsInstall = $false
        } else {
            Write-Output "Update available: $currentVersion -> $latestVersion"
        }
    } catch {
        Write-Warning "Could not determine current version: $_"
    }
}

# Download and install if needed
if ($needsInstall) {
    Write-Output "Installing CapsLockIndicator $latestVersion..."
    
    # Create install directory
    try {
        if (-not (Test-Path $installPath)) {
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        }
    } catch {
        Write-Error "Failed to create installation directory: $_"
        exit 1
    }
    
    # Download latest executable
    $tempFile = Join-Path $env:TEMP "CapsLockIndicator_temp.exe"
    try {
        Write-Output "Downloading from: $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
    } catch {
        Write-Error "Failed to download CapsLockIndicator: $_"
        exit 1
    }
    
    # Stop existing process if running
    Get-Process | Where-Object { $_.Path -eq $exePath } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Copy to install location
    try {
        Copy-Item -Path $tempFile -Destination $exePath -Force
        Remove-Item $tempFile -Force
        Write-Output "Installed to: $exePath"
    } catch {
        Write-Error "Failed to copy executable to installation directory: $_"
        exit 1
    }
}


# Set folder permissions for Users group to have write access
try {
    # Get Users group using SID (works across all language versions of Windows)
    $usersSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
    $usersGroup = $usersSID.Translate([System.Security.Principal.NTAccount])
    
    # Get current ACL
    $acl = Get-Acl -Path $installPath
    
    # Create new access rule: Users group with Modify rights (includes Write)
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $usersGroup,
        "Modify",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    
    # Add the rule and apply
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $installPath -AclObject $acl
    
    Write-Output "Granted write permissions to Users group on: $installPath"
} catch {
    Write-Error "Failed to set folder permissions: $_"
    exit 1
}


# Configure startup for all users
try {
    $registryValue = "`"$exePath`""
    Set-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -Type String -Force
    Write-Output "Registered for all users startup"
} catch {
    Write-Error "Failed to update registry for startup: $_"
    exit 1
}

# Download and save configuration from NinjaOne custom field
try {
    $configContent = Ninja-Property-Get capsLockIndicatorConfiguration
    
    if ($configContent) {
        # Normalize line endings to Windows format (CRLF)
        $configContent = $configContent -replace "`r`n", "`n"
        $configPath = Join-Path $installPath "usercfg"
        $configContent -split "`n" | Set-Content -Path $configPath -Encoding UTF8
        Write-Output "Configuration saved to: $configPath"
    } else {
        Write-Output "No configuration found in custom field 'capsLockIndicatorConfiguration'"
    }
} catch {
    Write-Error "Failed to write configuration file: $_"
    exit 1
}

Write-Output "CapsLockIndicator deployment completed successfully"
exit 0
}
end {
}
