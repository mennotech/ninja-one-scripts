# GitHub Copilot Instructions for NinjaOne Scripts

## Project Overview
This repository contains administrative scripts designed for NinjaOne RMM (Remote Monitoring and Management) platform. Scripts are primarily PowerShell-based and focus on Windows system management, monitoring, and automation.

## PowerShell Script Standards

### Script Header Requirements
All PowerShell scripts MUST include:
- Complete comment-based help block with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.OUTPUTS`, `.NOTES`, `.LINK`, and `.LICENSE` sections
- Version history in `.NOTES` with date and description (format: YYYY-MM-DD)
- MIT License reference in `.LICENSE` section
- GitHub repository link in `.LINK` section

### Code Structure
- Use `[CmdletBinding()]` for all scripts
- Define parameters with proper `[Parameter()]` attributes and type declarations
- Organize code into `begin`, `process`, and `end` blocks when appropriate
- Use `begin` block for initialization, validation, and prerequisite checks
- Use `process` block for main logic
- Use `end` block for cleanup and final output

### NinjaOne Integration
- Support RMM custom field parameters (prefix with "RMM" in parameter names)
- Check for environment variables that may override parameters (e.g., `$env:RMMFieldName`)
- Handle environment variable nulls with: `if ($env:VarName -and $env:VarName -notlike "null")`
- Provide clear output for RMM field population

### Administrative Privileges
- Include `Test-IsElevated` function when admin rights are required
- Exit with error code 1 if elevation is needed but not present
- Display clear error messages using `Write-Error`

### Error Handling
- Use `try`/`catch` blocks for external operations (web requests, file operations, scheduled tasks)
- Use `-ErrorAction SilentlyContinue` or `-ErrorAction Stop` explicitly
- Provide detailed error messages that indicate what failed and why
- Exit with appropriate error codes for scripting scenarios

### External Dependencies
- Download and install required utilities programmatically when not present
- Use `Test-Path` to verify installations before proceeding
- Store third-party utilities in `$env:PROGRAMFILES` or appropriate system locations
- Clean up temporary files after downloads

### Naming Conventions
- Script names: Use `Verb-Noun` format (e.g., `Get-OneDriveStatus.ps1`)
- Variables: Use PascalCase for major variables, camelCase for local/temporary ones
- Functions: Use approved PowerShell verbs (Get, Set, Test, New, Remove, etc.)
- Parameters: Use descriptive names with type hints

### Output and Logging
- Use `Write-Host` for informational messages
- Use `Write-Error` for errors
- Use `Write-Verbose` for detailed logging (respects `-Verbose` parameter)
- Return structured data when possible (objects, hashtables, JSON)
- Include status details for RMM consumption

### File Organization
- Place Windows PowerShell scripts in: `Windows/PowerShell/`
- Use descriptive filenames with spaces acceptable (e.g., `Get OneDrive Sync Status.ps1`)
- Group related scripts by OS platform in root folders

## Code Quality Standards

### Best Practices
- Always validate inputs and prerequisites before executing main logic
- Use consistent indentation (4 spaces)
- Include inline comments for complex logic
- Validate paths and files before operations
- Use `-Force` parameter judiciously and document its use

### Security Considerations
- Validate URLs before downloading external content
- Use HTTPS for all web requests
- Verify downloaded files before extraction
- Run scheduled tasks with least privilege when possible
- Sanitize user inputs and environment variables

### Performance
- Minimize WMI/CIM calls; cache results when possible
- Use efficient filtering in Where-Object clauses
- Avoid unnecessary loops; use pipeline where appropriate
- Include appropriate sleep/wait times for scheduled tasks and services

### Testing Approach
- Test with and without RMM environment variables
- Verify behavior with and without admin privileges
- Test on systems with and without required dependencies
- Include edge case handling (no users logged in, missing files, etc.)

## Documentation Requirements

### README Updates
When adding new scripts, update the main README.md with:
- Script name and brief description
- Key features or use cases
- Required permissions or prerequisites
- Link to the script file

### Inline Documentation
- Document WHY not just WHAT for complex logic
- Explain RMM-specific integration points
- Note any version-specific requirements
- Include examples in comment-based help when beneficial

## Platform-Specific Guidelines

### Windows/PowerShell Scripts
- Target PowerShell 5.1 for maximum compatibility
- Use .NET classes when PowerShell cmdlets aren't available
- Handle both Windows PowerShell and PowerShell Core scenarios when relevant
- Use Windows-specific paths with environment variables (`$env:PROGRAMFILES`, `$env:TEMP`)

### Scheduled Tasks
- Use XML definition for precise control
- Include appropriate triggers, principals, and settings
- Set execution time limits to prevent runaway tasks
- Document task purpose in registration info

## Common Patterns

### RMM Parameter Pattern
```powershell
[Parameter()]
[String]$RMMFieldName = ""

# In begin block:
if ($env:RMMFieldName -and $env:RMMFieldName -notlike "null") { 
    $RMMFieldName = $env:RMMFieldName 
}
```

### Elevation Check Pattern
```powershell
function Test-IsElevated { 
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsElevated)) {
    Write-Error "This script requires administrative privileges."
    exit 1
}
```

### Download and Install Pattern
```powershell
if (-not (Test-Path -Path $destinationPath)) {
    Write-Host "Module not installed. Installing..."
    $url = "https://..."
    $tempPath = "$env:TEMP\file.zip"
    Invoke-WebRequest -Uri $url -OutFile $tempPath
    Expand-Archive -Path $tempPath -DestinationPath $destinationPath -Force
    Remove-Item -Path $tempPath -Force
    
    if (-not (Test-Path -Path $destinationPath)) {
        Write-Error "Failed to install. Please check the installation path."
        exit 1
    }
}
```

## Version Control

### Commit Messages
- Use descriptive commit messages
- Start with verb: "Add", "Update", "Fix", "Remove"
- Reference issue numbers when applicable
- Example: "Add new script for monitoring disk space"

### Changelog Maintenance
- Update script `.NOTES` section with version history
- Include date and description of changes
- Use YYYY-MM-DD date format

## License
All scripts are released under the MIT License. Include license reference in every script file.
