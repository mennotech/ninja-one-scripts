# ==============================================================================
# Script Name: Get Folder Size
# ==============================================================================
#
# Description:
#   Scans a folder and reports the size of its contents.
#
# Metadata:
#   - NinjaOne Script ID: 94
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-18
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-18 22:36:42
#   - Active: True
# Script Variables (NinjaOne):
#   - folderPath (TEXT, Required): The path to the folder to scan.
#   - depth (INTEGER, Optional): The depth of subfolders to report. Default: 1
#   - minSizeMB (INTEGER, Optional): Minimum size in MB to include in the report. Default: 0
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Scans a folder and reports the sizes of its contents.
.DESCRIPTION
    This script scans a given folder and reports the sizes of its immediate subfolders
    and files. It can optionally filter by minimum size and control the depth of the scan.
    The script requires administrative privileges to run.

    The script can be run with the following parameters:
        -FolderPath: The path to the folder to scan.
        -Depth: The depth of subfolders to report. Default is 1.
        -MinSizeMB: Minimum size in MB to include in the report. Default is 0.

.EXAMPLE
    -FolderPath "C:\Users"

    Scanning folder: C:\Users
    Name                     Size
    ----                     ----
    Default                  1.23 MB
    Public                   45.67 MB
    username                 12.34 GB

.NOTES
    2025-06-18: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/94-Get%20Folder%20Size.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [String]$FolderPath,
    [Parameter()]
    [Int]$Depth = 1,
    [Parameter()]
    [Int]$MinSizeMB = 0
)

begin {
    # If script form variables are used replace the command line parameters.
    if ($env:folderPath -and $env:folderPath -notlike "null") { $FolderPath = $env:folderPath }
    if ($env:depth -and $env:depth -notlike "null") { $Depth = [int]$env:depth }
    if ($env:minSizeMB -and $env:minSizeMB -notlike "null") { $MinSizeMB = [int]$env:minSizeMB }

    function Format-ByteSize {
        param([long]$Bytes)
        if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
        if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
        if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
        if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
        return "$Bytes B"
    }

    function Invoke-FolderScan {
        param(
            [string]$Path,
            [int]$CurrentDepth,
            [int]$MaxDepth
        )

        $Items = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
        $Results = New-Object System.Collections.Generic.List[PSCustomObject]

        foreach ($Item in $Items) {
            if ($Item.PSIsContainer) {
                $Size = (Get-ChildItem -Path $Item.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if ($null -eq $Size) { $Size = 0 }
                $Results.Add([PSCustomObject]@{
                    Name = $Item.Name
                    Path = $Item.FullName
                    SizeBytes = $Size
                    SizeFormatted = Format-ByteSize -Bytes $Size
                    Type = "Folder"
                })
            }
            else {
                $Results.Add([PSCustomObject]@{
                    Name = $Item.Name
                    Path = $Item.FullName
                    SizeBytes = $Item.Length
                    SizeFormatted = Format-ByteSize -Bytes $Item.Length
                    Type = "File"
                })
            }
        }

        return $Results
    }

    function Get-FolderScanBlock {
        # Returns the script block used for parallel folder scanning jobs
        return {
            param($Path)
            $Size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($null -eq $Size) { $Size = 0 }
            return $Size
        }
    }

    function Write-FolderSizeTable {
        param(
            [System.Collections.Generic.List[PSCustomObject]]$Items,
            [int]$MinSizeMB
        )

        $MinSizeBytes = $MinSizeMB * 1MB
        $FilteredItems = $Items | Where-Object { $_.SizeBytes -ge $MinSizeBytes } | Sort-Object -Property SizeBytes -Descending

        if (!$FilteredItems) {
            Write-Host -Object "No items found matching the specified criteria."
            return
        }

        $FilteredItems | Format-Table -Property Name, SizeFormatted, Type -AutoSize | Out-String | Write-Host
    }

    function Invoke-FolderSizeReport {
        param(
            [string]$FolderPath,
            [int]$Depth,
            [int]$MinSizeMB
        )

        Write-Host -Object "Scanning folder: $FolderPath"

        if (!(Test-Path -Path $FolderPath)) {
            Write-Host -Object "[Error] The folder '$FolderPath' does not exist."
            exit 1
        }

        $ScanResults = Invoke-FolderScan -Path $FolderPath -CurrentDepth 1 -MaxDepth $Depth
        Write-FolderSizeTable -Items $ScanResults -MinSizeMB $MinSizeMB
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

    # If $FolderPath is not provided, display an error message and exit
    if (!$FolderPath) {
        Write-Host -Object "[Error] A folder path is required."
        exit 1
    }

    Invoke-FolderSizeReport -FolderPath $FolderPath -Depth $Depth -MinSizeMB $MinSizeMB

    exit $ExitCode
}
end {
    
    
    
}
