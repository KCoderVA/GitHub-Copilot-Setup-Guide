# Copyright 2025 Kyle J. Coder
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generate-ProductivityReport.ps1
# VA Power Platform Productivity Reporting Script
# Author: Kyle J. Coder - Edward Hines Jr. VA Hospital
# Purpose: Generates comprehensive productivity reports from workspace activity with enhanced Git statistics


<#
.SYNOPSIS
    Validates syntax for configuration files (YAML, JSON, XML, MSAPP)

.DESCRIPTION
    This script performs syntax validation on various file types commonly used
    in VA Power Platform development. It helps ensure configuration files are
    properly formatted before deployment and catches syntax errors early.

.PARAMETER FileTypes
    Comma-separated list of file types to validate (default: yaml,json,xml,msapp)

.PARAMETER Path
    Specific path to validate (default: entire workspace)

.PARAMETER FixSimpleErrors
    Attempt to fix simple formatting errors automatically

.EXAMPLE
    .\Validate-Syntax.ps1
    Validates all supported file types in the workspace

.EXAMPLE
    .\Validate-Syntax.ps1 -FileTypes "json,yaml" -Path "src"
    Validates only JSON and YAML files in the src folder

.NOTES
    Author: Kyle J. Coder
    Organization: Edward Hines Jr. VA Hospital (Hines VAMC)
    Team: Clinical Informatics & Advanced Analytics
    Email: Kyle.Coder@va.gov
    Created: July 24, 2025
    Version: 1.0.0

    VA Compliance:
    - No administrator privileges required
    - Compatible with VA security restrictions
    - Includes comprehensive error handling and logging
    - Follows VA professional standards and naming conventions

.LINK
    Validate-WorkspaceSetup.ps1 for workspace validation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="File types to validate")]
    [string]$FileTypes = "yaml,json,xml,msapp",

    [Parameter(Mandatory=$false, HelpMessage="Path to validate")]
    [string]$Path = "",

    [Parameter(Mandatory=$false, HelpMessage="Attempt to fix simple errors")]
    [switch]$FixSimpleErrors
)

# Script initialization
Set-StrictMode -Version Latest
$ScriptName = "Validate-Syntax"
$ScriptVersion = "1.0.0"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$WorkspacePath = Split-Path -Parent $ScriptPath
$LogPath = Join-Path $ScriptPath "..\logs"
$LogFile = Join-Path $LogPath "$ScriptName.log"

# Set validation path
if (-not $Path) {
    $Path = $WorkspacePath
}

function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"

    switch ($Level) {
        "INFO"    { Write-Host $LogEntry -ForegroundColor White }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
    }

    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    $LogEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Test-JsonSyntax {
    param([string]$FilePath)

    try {
        $Content = Get-Content -Path $FilePath -Raw -ErrorAction Stop

        # Try to parse JSON
        $ParsedJson = $Content | ConvertFrom-Json -ErrorAction Stop

        Write-LogMessage -Message "JSON syntax valid: $FilePath" -Level "SUCCESS"
        return @{ IsValid = $true; Error = $null }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-LogMessage -Message "JSON syntax error in $FilePath`: $ErrorMessage" -Level "ERROR"

        # Try to fix common issues if requested
        if ($FixSimpleErrors) {
            try {
                # Fix common JSON issues
                $FixedContent = $Content -replace ',(\s*[}\]])', '$1'  # Remove trailing commas
                $FixedContent = $FixedContent -replace '(["\w])\s*\n\s*(["\w])', '$1,$2'  # Add missing commas

                $ParsedFixed = $FixedContent | ConvertFrom-Json -ErrorAction Stop
                Set-Content -Path $FilePath -Value $FixedContent -Encoding UTF8
                Write-LogMessage -Message "Fixed JSON syntax errors in: $FilePath" -Level "SUCCESS"
                return @{ IsValid = $true; Error = $null; Fixed = $true }
            }
            catch {
                Write-LogMessage -Message "Could not auto-fix JSON errors in: $FilePath" -Level "WARNING"
            }
        }

        return @{ IsValid = $false; Error = $ErrorMessage }
    }
}

function Test-YamlSyntax {
    param([string]$FilePath)

    try {
        $Content = Get-Content -Path $FilePath -Raw -ErrorAction Stop

        # Basic YAML validation (PowerShell doesn't have native YAML parser)
        # Check for common YAML syntax issues
        $Lines = $Content -split "`n"
        $ErrorsFound = @()

        for ($i = 0; $i -lt $Lines.Count; $i++) {
            $Line = $Lines[$i]
            $LineNumber = $i + 1

            # Check for tab characters (YAML requires spaces)
            if ($Line -match "`t") {
                $ErrorsFound += "Line $LineNumber`: Tab character found (YAML requires spaces)"
            }

            # Check for basic indentation consistency
            if ($Line -match '^  [^ ]' -and $Line -notmatch '^  [-#]') {
                # This is a basic check for 2-space indentation
            }

            # Check for colon-space requirement
            if ($Line -match ':\w' -and $Line -notmatch '://') {
                $ErrorsFound += "Line $LineNumber`: Missing space after colon"
            }
        }

        if ($ErrorsFound.Count -eq 0) {
            Write-LogMessage -Message "YAML syntax valid: $FilePath" -Level "SUCCESS"
            return @{ IsValid = $true; Error = $null }
        } else {
            $ErrorMessage = $ErrorsFound -join "; "
            Write-LogMessage -Message "YAML syntax errors in $FilePath`: $ErrorMessage" -Level "ERROR"
            return @{ IsValid = $false; Error = $ErrorMessage }
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-LogMessage -Message "Error reading YAML file $FilePath`: $ErrorMessage" -Level "ERROR"
        return @{ IsValid = $false; Error = $ErrorMessage }
    }
}

function Test-XmlSyntax {
    param([string]$FilePath)

    try {
        $XmlDoc = New-Object System.Xml.XmlDocument
        $XmlDoc.Load($FilePath)

        Write-LogMessage -Message "XML syntax valid: $FilePath" -Level "SUCCESS"
        return @{ IsValid = $true; Error = $null }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-LogMessage -Message "XML syntax error in $FilePath`: $ErrorMessage" -Level "ERROR"
        return @{ IsValid = $false; Error = $ErrorMessage }
    }
}

function Test-MSAppSyntax {
    param([string]$FilePath)

    try {
        # PowerApps .msapp files are ZIP archives
        # Basic validation: check if it's a valid ZIP file
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $Archive = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        $RequiredFiles = @('Header.json', 'Properties.json', 'Entropy')
        $FoundFiles = $Archive.Entries | ForEach-Object { $_.Name }

        $MissingFiles = $RequiredFiles | Where-Object { $_ -notin $FoundFiles }

        if ($MissingFiles.Count -eq 0) {
            Write-LogMessage -Message "PowerApps file structure valid: $FilePath" -Level "SUCCESS"
            $Archive.Dispose()
            return @{ IsValid = $true; Error = $null }
        } else {
            $ErrorMessage = "Missing required files: $($MissingFiles -join ', ')"
            Write-LogMessage -Message "PowerApps file structure error in $FilePath`: $ErrorMessage" -Level "ERROR"
            $Archive.Dispose()
            return @{ IsValid = $false; Error = $ErrorMessage }
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-LogMessage -Message "PowerApps file validation error in $FilePath`: $ErrorMessage" -Level "ERROR"
        return @{ IsValid = $false; Error = $ErrorMessage }
    }
}

# Main execution
try {
    Write-LogMessage -Message "========================================" -Level "INFO"
    Write-LogMessage -Message "$ScriptName v$ScriptVersion" -Level "INFO"
    Write-LogMessage -Message "Author: Kyle J. Coder" -Level "INFO"
    Write-LogMessage -Message "Organization: Edward Hines Jr. VA Hospital" -Level "INFO"
    Write-LogMessage -Message "========================================" -Level "INFO"

    $Extensions = $FileTypes.Split(',').Trim()
    Write-LogMessage -Message "Validating file types: $($Extensions -join ', ')" -Level "INFO"
    Write-LogMessage -Message "Validation path: $Path" -Level "INFO"
    Write-LogMessage -Message "Auto-fix simple errors: $FixSimpleErrors" -Level "INFO"

    $TotalFiles = 0
    $ValidFiles = 0
    $InvalidFiles = 0
    $FixedFiles = 0
    $ValidationResults = @{}

    foreach ($Extension in $Extensions) {
        Write-LogMessage -Message "Processing .$Extension files..." -Level "INFO"

        $Files = Get-ChildItem -Path $Path -Filter "*.$Extension" -Recurse -File |
                 Where-Object { $_.FullName -notmatch '\\\.git\\|\\node_modules\\|\\logs\\' }

        Write-LogMessage -Message "Found $($Files.Count) .$Extension files" -Level "INFO"
        $TotalFiles += $Files.Count

        foreach ($File in $Files) {
            $Result = switch ($Extension.ToLower()) {
                'json' { Test-JsonSyntax -FilePath $File.FullName }
                'yaml' { Test-YamlSyntax -FilePath $File.FullName }
                'yml'  { Test-YamlSyntax -FilePath $File.FullName }
                'xml'  { Test-XmlSyntax -FilePath $File.FullName }
                'msapp' { Test-MSAppSyntax -FilePath $File.FullName }
                default {
                    Write-LogMessage -Message "Unknown file type: $Extension" -Level "WARNING"
                    @{ IsValid = $null; Error = "Unknown file type" }
                }
            }

            $ValidationResults[$File.FullName] = $Result

            if ($Result.IsValid) {
                $ValidFiles++
                if ($Result.Fixed) {
                    $FixedFiles++
                }
            } elseif ($Result.IsValid -eq $false) {
                $InvalidFiles++
            }
        }
    }

    Write-LogMessage -Message "========================================" -Level "INFO"
    Write-LogMessage -Message "Syntax validation completed!" -Level "SUCCESS"
    Write-LogMessage -Message "Total files checked: $TotalFiles" -Level "INFO"
    Write-LogMessage -Message "Valid files: $ValidFiles" -Level "SUCCESS"
    Write-LogMessage -Message "Invalid files: $InvalidFiles" -Level "ERROR"
    Write-LogMessage -Message "Files auto-fixed: $FixedFiles" -Level "SUCCESS"

    # Generate detailed report
    $ReportPath = Join-Path $LogPath "syntax-validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $ValidationResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-LogMessage -Message "Detailed report saved: $ReportPath" -Level "INFO"

    Write-LogMessage -Message "Log file: $LogFile" -Level "INFO"
    Write-LogMessage -Message "========================================" -Level "INFO"

    if ($InvalidFiles -gt 0) {
        exit 1
    }
}
catch {
    Write-LogMessage -Message "Fatal error: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
