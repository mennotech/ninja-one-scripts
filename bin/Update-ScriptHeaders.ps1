<#
.SYNOPSIS
    Updates headers for existing NinjaOne scripts based on metadata.
.DESCRIPTION
    Automatically discovers all script files under Windows, Linux, and macOS subdirectories
    and updates their metadata headers when the corresponding NinjaOne metadata has changed.
    Only processes files with actual content (skips stub files that still contain the TODO placeholder).

    Run Get-Scripts.ps1 first to ensure the metadata JSON is current before running this script.

.PARAMETER OutputPath
    The base directory containing the script repository folders (Windows, Linux, macOS) and the
    db/scripts-metadata.json file. Defaults to the current working directory.

.PARAMETER MetadataPath
    Full path to the scripts-metadata.json file. Defaults to <OutputPath>\db\scripts-metadata.json.

.OUTPUTS
    System.String
    Outputs status messages to the console and updates script file headers on disk.

.NOTES
    Version: 1.0.0
    Author: NinjaOne Scripts Project
    Created: 2026-02-20

    Version History:
    1.0.0 - 2026-02-20 - Initial release

.LINK
    https://github.com/mennotech/ninja-one-scripts

.LICENSE
    MIT License - See LICENSE file in repository root
#>
[CmdletBinding()]
param(
    [Parameter()]
    [String]$OutputPath = (Get-Location).Path,

    [Parameter()]
    [String]$MetadataPath = ""
)

begin {
    # Resolve metadata path
    if (-not $MetadataPath) {
        $MetadataPath = Join-Path -Path $OutputPath -ChildPath "db\scripts-metadata.json"
    }

    if (-not (Test-Path -Path $MetadataPath)) {
        Write-Error "Metadata file not found: $MetadataPath. Run Get-Scripts.ps1 first to generate it."
        exit 1
    }

    $metadata = Get-Content $MetadataPath -Raw | ConvertFrom-Json

    # Function to get script extension
    function Get-ScriptExtension {
        param([string]$Language)
        switch ($Language.ToLower()) {
            'powershell' { '.ps1' }
            { $_ -in 'batch', 'batchfile' } { '.bat' }
            { $_ -in 'bash', 'sh' } { '.sh' }
            'python' { '.py' }
            'javascript' { '.js' }
            'vbscript' { '.vbs' }
            default { '.txt' }
        }
    }

    # Function to extract existing metadata from header
    function Get-ExistingMetadata {
        param([string]$Content)

        $existing = @{}
        if ($Content -match 'NinjaOne Script ID:\s*(\d+)') { $existing.Id = [int]$matches[1] }
        if ($Content -match 'Last Updated:\s*([^\r\n]+)') { $existing.LastUpdated = $matches[1].Trim() }
        if ($Content -match 'Created On:\s*([^\r\n]+)') { $existing.CreatedOn = $matches[1].Trim() }
        if ($Content -match 'Description:\s*\r?\n#\s+(.+?)(?:\r?\n#\s*\r?\n|\r?\n# Metadata:)') {
            $existing.Description = $matches[1].Trim()
        }

        return $existing
    }
}

process {
    # Discover all script files under the OS subdirectories
    Write-Host "Scanning for script files..." -ForegroundColor Cyan
    $searchPaths = @("Windows", "Linux", "macOS") | ForEach-Object {
        Join-Path -Path $OutputPath -ChildPath $_
    } | Where-Object { Test-Path $_ }

    $allFiles = if ($searchPaths) {
        Get-ChildItem -Path $searchPaths -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.ps1', '.bat', '.sh', '.py', '.js', '.vbs', '.txt' }
    } else {
        @()
    }

    Write-Host "Found $($allFiles.Count) script file(s)" -ForegroundColor Gray
    Write-Host ""

    $processedCount = 0
    $skippedCount = 0
    $updatedCount = 0
    $renamedCount = 0
    $basePath = $OutputPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar)

    foreach ($file in $allFiles) {
        $fileName = $file.BaseName

        # Extract Script ID from filename (format: ID-ScriptName)
        $scriptId = $null
        if ($fileName -match '^(\d+)-') {
            $scriptId = [int]$matches[1]
        }

        # Find matching metadata by ID (preferred) or name (fallback for old files)
        if ($scriptId) {
            $scriptMeta = $metadata | Where-Object { $_.id -eq $scriptId }
        }
        else {
            $scriptMeta = $metadata | Where-Object { $_.name -eq $fileName }
        }

        if (-not $scriptMeta) {
            Write-Verbose "No metadata found for: $fileName"
            $skippedCount++
            continue
        }

        # Build expected filename with Script ID prefix
        $scriptName = $scriptMeta.name -replace '[<>:"/\\|?*]', '_'
        $expectedBaseName = "$($scriptMeta.id)-$scriptName"
        $expectedFileName = "$expectedBaseName$($file.Extension)"

        # Check if file needs to be renamed
        if ($file.Name -ne $expectedFileName) {
            $newPath = Join-Path -Path $file.DirectoryName -ChildPath $expectedFileName

            # Check if target already exists
            if (Test-Path $newPath) {
                Write-Warning "Cannot rename '$($file.Name)' to '$expectedFileName' - target already exists"
                $skippedCount++
                continue
            }

            try {
                Rename-Item -Path $file.FullName -NewName $expectedFileName -ErrorAction Stop
                $relativePath = $file.FullName.Substring($basePath.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
                Write-Host "  [RENAME] $relativePath → $expectedFileName" -ForegroundColor Cyan
                $renamedCount++
                # Update file reference for subsequent processing
                $file = Get-Item $newPath
            }
            catch {
                Write-Warning "Failed to rename $($file.Name): $_"
                $skippedCount++
                continue
            }
        }

        # Read current content
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue

        if (-not $content) {
            Write-Verbose "Empty file: $($file.FullName)"
            $skippedCount++
            continue
        }

        # Check if it's a stub file (contains TODO)
        if ($content -match 'TODO: Paste script content from NinjaOne GUI') {
            Write-Verbose "Stub file: $($file.FullName)"
            $skippedCount++
            continue
        }

        # Check existing metadata
        $existing = Get-ExistingMetadata -Content $content
        $updateDate = [DateTimeOffset]::FromUnixTimeSeconds($scriptMeta.updatedOn).DateTime.ToString("yyyy-MM-dd HH:mm:ss")
        $createDate = [DateTimeOffset]::FromUnixTimeSeconds($scriptMeta.createdOn).DateTime.ToString("yyyy-MM-dd")

        # Determine if update is needed
        $needsUpdate = $false
        $reason = ""

        if (-not $existing.Id) {
            $needsUpdate = $true
            $reason = "No header found"
        }
        elseif ($existing.Id -ne $scriptMeta.id) {
            $needsUpdate = $true
            $reason = "Script ID mismatch"
        }
        elseif ($existing.LastUpdated -ne $updateDate) {
            $needsUpdate = $true
            $reason = "Metadata updated in NinjaOne"
        }

        if (-not $needsUpdate) {
            $relativePath = $file.FullName.Substring($basePath.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
            Write-Host "  [SKIP] Up-to-date: $relativePath" -ForegroundColor Gray
            $skippedCount++
            continue
        }

        # Build metadata header
        $osType = $scriptMeta.operatingSystems[0]

        # Determine comment character based on language
        $commentChar = switch ($scriptMeta.language.ToLower()) {
            'powershell' { '#' }
            { $_ -in 'batch', 'batchfile' } { 'REM' }
            { $_ -in 'bash', 'sh' } { '#' }
            'python' { '#' }
            'javascript' { '//' }
            'vbscript' { "'" }
            default { '#' }
        }

        # Format description with proper comment markers for multi-line content
        $formattedDescription = if ($scriptMeta.description) {
            # Handle both literal \n and actual newlines
            $desc = $scriptMeta.description -replace '\\n', "`n"
            # Split by newlines, trim each line, filter empty lines, and join with proper comment prefix
            ($desc -split '[\r\n]+' | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }) -join "`n$commentChar   "
        } else {
            "No description provided"
        }

        $header = @"
$commentChar ==============================================================================
$commentChar Script Name: $($scriptMeta.name)
$commentChar ==============================================================================
$commentChar
$commentChar Description:
$commentChar   $formattedDescription
$commentChar
$commentChar Metadata:
$commentChar   - NinjaOne Script ID: $($scriptMeta.id)
$commentChar   - Language: $($scriptMeta.language)
$commentChar   - OS Type: $osType
$commentChar   - Architecture: $($scriptMeta.architecture -join ', ')
$commentChar   - Created By: $(if ($scriptMeta.createdBy) { $scriptMeta.createdBy } else { 'N/A' })
$commentChar   - Created On: $createDate
$commentChar   - Last Updated By: $(if ($scriptMeta.lastUpdatedBy) { $scriptMeta.lastUpdatedBy } else { 'N/A' })
$commentChar   - Last Updated: $updateDate
$commentChar   - Active: $($scriptMeta.active)

"@

        # Add script variables if present
        if ($scriptMeta.scriptVariables -and $scriptMeta.scriptVariables.Count -gt 0) {
            $header += "$commentChar Script Variables (NinjaOne):`n"
            foreach ($var in $scriptMeta.scriptVariables) {
                $required = if ($var.required) { "Required" } else { "Optional" }
                # Format description with proper comment markers for multi-line content
                $varDesc = if ($var.description) {
                    $desc = $var.description -replace '\\n', "`n"
                    ($desc -split '[\r\n]+' | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }) -join " "
                } else { "" }
                $header += "$commentChar   - $($var.id) ($($var.type), $required): $varDesc`n"
                if ($var.defaultValue) {
                    $header += "$commentChar     Default: $($var.defaultValue)`n"
                }
            }
            $header += "$commentChar`n"
        }

        $header += @"
$commentChar ==============================================================================

"@

        # Find where the actual code starts (first line that's not a comment or blank)
        $lines = $content -split "`r?`n"
        $codeStartIndex = 0
        # List of all possible comment markers to check
        $commentMarkers = @('#', 'REM', '//', "'")
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            $isComment = $false
            foreach ($marker in $commentMarkers) {
                if ($line.StartsWith($marker)) {
                    $isComment = $true
                    break
                }
            }
            if ($line -and -not $isComment) {
                $codeStartIndex = $i
                break
            }
        }

        # Get the actual code (everything from first non-comment line)
        $actualCode = $lines[$codeStartIndex..($lines.Count - 1)] -join "`n"

        # Combine new header with actual code
        $newContent = $header + $actualCode

        # Write back to file
        try {
            Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -NoNewline -ErrorAction Stop
            $relativePath = $file.FullName.Substring($basePath.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
            Write-Host "  [UPDATE] $relativePath ($reason)" -ForegroundColor Green
            $updatedCount++
            $processedCount++
        }
        catch {
            Write-Warning "Failed to update $($file.FullName): $_"
        }
    }
}

end {
    # Summary
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Total files found: $($allFiles.Count)" -ForegroundColor Gray
    Write-Host "  Renamed: $renamedCount" -ForegroundColor Cyan
    Write-Host "  Processed: $processedCount" -ForegroundColor Gray
    Write-Host "  Updated: $updatedCount" -ForegroundColor Green
    Write-Host "  Skipped: $skippedCount" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Header update complete!" -ForegroundColor Cyan
}
