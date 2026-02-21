# ==============================================================================
# Script Name: Find Registry Keys
# ==============================================================================
#
# Description:
#   This script recursively retrieves and displays all registry keys and values from a specified registry path.
#   It can format the output as a registry file if the formatRegFile parameter is set to "true".
#
# Metadata:
#   - NinjaOne Script ID: 103
#   - Language: powershell
#   - OS Type: Windows
#   - Architecture: 64, 32
#   - Created By: Roland Penner
#   - Created On: 2025-06-18
#   - Last Updated By: Roland Penner
#   - Last Updated: 2025-06-18 22:07:17
#   - Active: True
# Script Variables (NinjaOne):
#   - regkeypath (TEXT, Required): 
#     Default: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
#   - depth (INTEGER, Required): The depth of child items to traverse
#     Default: 1
#   - filtervalue (TEXT, Optional): A comma separated list of Registry properties to filter by
#   - formatregfile (TEXT, Required): Enter true or false
#     Default: false
#
# ==============================================================================
#Requires -Version 5.1

<#
.SYNOPSIS
    Retrieves and displays all registry keys and values from a specified registry path.
.DESCRIPTION
    The script allows you to specify a registry key path and a depth level to explore subkeys.
    It can also filter the displayed values based on specified property names and format the output as a registry file.
    It can format the output as a registry file if the -FormatRegFile parameter is set to "true".
.PARAMETER RegKeyPath
    The registry key path to search. Defaults to HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall.
.PARAMETER Depth
    The depth of child items to traverse. Defaults to 2.
.PARAMETER FilterValue
    An optional array of Registry properties to filter by.
.PARAMETER FormatRegFile
    Set to "true" to format output as a Windows Registry Editor Version 5.00 file. Defaults to "false".
.OUTPUTS
    Displays the registry keys and values in the console, or formats them as a registry file if specified.
    If -FormatRegFile is set to "true", the output will be formatted as a Windows Registry Editor Version 5.00 file.
    If -FilterValue is specified, only those values will be displayed.
    If the specified registry key path does not exist, a warning will be displayed.
.NOTES
    2025-06-18: Initial version of the script.
.LINK
    https://github.com/mennotech/ninja-one-scripts/blob/main/Windows/PowerShell/103-Find%20Registry%20Keys.ps1
.LICENSE
    This script is released under the MIT License.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$RegKeyPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    [Parameter()]
    [int]$Depth = 2,
    [Parameter()]
    [array]$FilterValue = $null,
    [Parameter()]
    [string]$FormatRegFile = "false"
)

begin {
    if ($env:regKeyPath -and $env:regKeyPath -notlike "null") { $RegKeyPath = $env:regKeyPath }
    if ($env:depth -and $env:depth -notlike "null") { $Depth = [int]$env:depth }
    if ($env:filterValue -and $env:filterValue -notlike "null") {
        $FilterValue = $env:filterValue -split ',' | ForEach-Object { $_.Trim() }
    }
    if ($env:formatRegFile -and $env:formatRegFile -notlike "null") { $FormatRegFile = [string]$env:formatRegFile }
    $regFormat = $FormatRegFile -eq "true"

    # Function to recursively retrieve registry keys
    function Get-RegistryKeys {
        param (
            [string]$path,
            [int]$currentDepth,
            [int]$maxDepth
        )

        if ($currentDepth -gt $maxDepth) {
            return
        }

        try {
            # Write the current registry key path values
            Write-RegistryValues -path $path

            # Get all child keys at the current path
            $keys = Get-ChildItem -Path $path -ErrorAction Stop
            foreach ($key in $keys) {
                Write-Host "`n[$($key)]"
                # Recursively call this function for child values
                Get-RegistryKeys -path $key.PSPath -currentDepth ($currentDepth + 1) -maxDepth $maxDepth
            }
        } catch {
            Write-Warning "Error accessing registry key: $path"
        }
    }

    # Function to write all registry values to output
    function Write-RegistryValues {
        param (
            [string]$path
        )

        try {
            $key = Get-Item -Path $path -ErrorAction Stop
            $values = Get-ItemProperty -Path $path -ErrorAction Stop
            foreach ($value in $values.PSObject.Properties) {
                # Skip certain properties that are not relevant for display
                if ($value.Name -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
                    continue
                }
                # Check if the value is in the FilterValue array, if provided
                if ($FilterValue -and $value.Name -notin $FilterValue) {
                    continue
                }
                if ($regFormat) {
                    Format-RegFileOutput -key $key -value $value
                } else {
                    Write-Host "$($value.Name) = $($value.Value)"
                }
            }
        } catch {
            Write-Warning "Error accessing registry values at: $path"
            Write-Warning "Error details: $_"
        }
    }

    function Format-RegFileOutput {
        param(
            [object]$key,
            [object]$value
        )

        if ($value.Name -eq "(default)") {
            $propertyName = "@"
        } else {
            $propertyName = $value.Name
        }

        $type = $key.GetValueKind($value.Name)
        switch ($type) {
            "String" {
                Write-Host "`"$($propertyName)`"=`"$($value.Value)`""
            }
            "ExpandString" {
                $padded = $value.Value + "`0"
                $binaryValues = [BitConverter]::ToString([System.Text.Encoding]::Unicode.GetBytes($padded)) -replace '-', ','
                Write-Host "`"$($propertyName)`"=hex(2):$($binaryValues)"
            }
            "Binary" {
                $binaryValues = [BitConverter]::ToString($value.Value) -replace '-', ','
                Write-Host "`"$($propertyName)`"=hex:$($binaryValues)"
            }
            "DWord" {
                $valueHex = "{0:X8}" -f $value.Value
                Write-Host "`"$($propertyName)`"=dword:$($valueHex)"
            }
            "QWord" {
                $binaryValues = [BitConverter]::ToString([BitConverter]::GetBytes($value.Value)) -replace '-', ','
                Write-Host "`"$($propertyName)`"=hex(b):$($binaryValues)"
            }
            "MultiString" {
                $joined = ($value.Value -join "`0") + "`0" + "`0"
                $binaryValues = [BitConverter]::ToString([System.Text.Encoding]::Unicode.GetBytes($joined)) -replace '-', ','
                Write-Host "`"$($propertyName)`"=hex(7):$($binaryValues)"
            }
            default {
                Write-Warning "Unknown value type for property '$($propertyName)' in key '$($key.Name)': $type"
            }
        }
    }
}
process {
    try {
        # Ensure the registry key path exists
        if (-not (Test-Path -Path "Registry::$RegKeyPath")) {
            Write-Warning "Registry key does not exist: $RegKeyPath"
            exit 1
        }

        Write-Host "Searching registry key: $RegKeyPath with depth: $Depth"
        Write-Host "----------------------"

        if ($regFormat) {
            Write-Host "Windows Registry Editor Version 5.00"
        }

        $rootKey = Get-Item -Path "Registry::$RegKeyPath" -ErrorAction Stop
        Write-Host "`n[$($rootKey)]"

        Get-RegistryKeys -path "Registry::$RegKeyPath" -currentDepth 1 -maxDepth $Depth
        Write-Host "`n----------------------"

    } catch {
        Write-Warning "An error occurred: $_"
        exit 1
    }
}
end {
}
