# ==============================================================================
# Script Name: User Profile Size Report
# ==============================================================================
#
# Description:
#   Generate a report of user profile sizes on the system.
#
# Metadata:
#   - NinjaOne Script ID: 95
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-18
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-18 22:36:42
#   - Active: True
# Script Variables (NinjaOne):
#   - minSizeMB (INTEGER, Optional): Minimum profile size in MB to include in the report. Default: 0
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Generates a report of user profile sizes on the system.
.DESCRIPTION
    This script scans user profiles on the system and reports their sizes.
    It can optionally filter profiles by minimum size.
    The script requires administrative privileges to run.

    The script can be run with the following parameters:
        -MinSizeMB: Minimum profile size in MB to include in the report. Default is 0.

.EXAMPLE
    User-Profile-Size-Report.ps1

    Scanning user profiles...
    Username          Profile Path                    Size
    --------          ------------                    ----
    john.doe          C:\Users\john.doe               15.23 GB
    jane.smith        C:\Users\jane.smith             8.45 GB
    Public            C:\Users\Public                 234.56 MB

.NOTES
    2025-06-18: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/95-User%20Profile%20Size%20Report.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [Int]$MinSizeMB = 0
)

begin {
    # If script form variables are used replace the command line parameters.
    if ($env:minSizeMB -and $env:minSizeMB -notlike "null") { $MinSizeMB = [int]$env:minSizeMB }

    function Format-ByteSize {
        param([long]$Bytes)
        if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
        if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
        if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
        if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
        return "$Bytes B"
    }

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

    $UsersPath = "$env:SystemDrive\Users"

    if (!(Test-Path -Path $UsersPath)) {
        Write-Host -Object "[Error] The users folder '$UsersPath' does not exist."
        exit 1
    }

    Write-Host -Object "Scanning user profiles..."

    $MinSizeBytes = $MinSizeMB * 1MB
    $ProfileResults = New-Object System.Collections.Generic.List[PSCustomObject]

    $UserFolders = Get-ChildItem -Path $UsersPath -Directory -ErrorAction SilentlyContinue

    foreach ($UserFolder in $UserFolders) {
        try {
            $Size = (Get-ChildItem -Path $UserFolder.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($null -eq $Size) { $Size = 0 }

            if ($Size -ge $MinSizeBytes) {
                $ProfileResults.Add([PSCustomObject]@{
                    Username    = $UserFolder.Name
                    ProfilePath = $UserFolder.FullName
                    SizeBytes   = $Size
                    Size        = Format-ByteSize -Bytes $Size
                })
            }
        }
        catch {
            Write-Host -Object "[Warning] Failed to scan profile '$($UserFolder.Name)': $($_.Exception.Message)"
        }
    }

    if (!$ProfileResults) {
        Write-Host -Object "No user profiles found matching the specified criteria."
        exit 0
    }

    $ProfileResults | Sort-Object -Property SizeBytes -Descending | Format-Table -Property Username, ProfilePath, Size -AutoSize | Out-String | Write-Host

    $TotalSize = ($ProfileResults | Measure-Object -Property SizeBytes -Sum).Sum
    Write-Host -Object "Total size of displayed profiles: $(Format-ByteSize -Bytes $TotalSize)"

    exit $ExitCode
}
end {
    
    
    
}
