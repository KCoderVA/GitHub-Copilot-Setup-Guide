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

<#
.SYNOPSIS
    Automatically inserts license headers into source code files

.DESCRIPTION
    This script scans the workspace for source code files and automatically inserts
    VA-compliant license headers. Supports PowerShell, SQL, JavaScript, CSS, and HTML files.

    The script maintains consistency across all files and ensures proper attribution
    to Kyle J. Coder and Edward Hines Jr. VA Hospital.

.PARAMETER FileTypes
    Comma-separated list of file extensions to process (default: ps1,sql,js,css,html)

.PARAMETER SkipExisting
    Skip files that already have license headers

.PARAMETER DryRun
    Show what would be changed without making actual modifications

.EXAMPLE
    .\Add-LicenseHeaders.ps1
    Adds license headers to all supported file types

.EXAMPLE
    .\Add-LicenseHeaders.ps1 -FileTypes "ps1,sql" -DryRun
    Shows what PowerShell and SQL files would be updated

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
    LICENSE file for complete licensing terms
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'File extensions to process')]
    [string]$FileTypes = 'ps1,sql,js,css,html',

    [Parameter(Mandatory = $false, HelpMessage = 'Skip files that already have headers')]
    [switch]$SkipExisting,

    [Parameter(Mandatory = $false, HelpMessage = 'Show changes without applying them')]
    [switch]$DryRun
)

# Script initialization
Set-StrictMode -Version Latest
$ScriptName = 'Add-LicenseHeaders'
$ScriptVersion = '1.0.0'
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogPath = Join-Path $ScriptPath '..\logs'
$LogFile = Join-Path $LogPath "$ScriptName.log"

# Ensure log directory exists
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# License header templates
$LicenseHeaders = @{
    'ps1'  = @"
<#
 * VA Power Platform Development
 *
 * Author: Kyle J. Coder
 * Organization: Edward Hines Jr. VA Hospital (Hines VAMC)
 * Team: Clinical Informatics & Advanced Analytics
 * Email: Kyle.Coder@va.gov
 *
 * This file is part of the VA Power Platform workspace template.
 * Licensed under MIT License - see LICENSE file for details.
 *
 * VA Compliance: No PHI/ePHI, Internal Use Only
 * Created: $(Get-Date -Format 'yyyy-MM-dd')
 #>

"@

    'sql'  = @"
/*
 * VA Power Platform Development
 *
 * Author: Kyle J. Coder
 * Organization: Edward Hines Jr. VA Hospital (Hines VAMC)
 * Team: Clinical Informatics & Advanced Analytics
 * Email: Kyle.Coder@va.gov
 *
 * This file is part of the VA Power Platform workspace template.
 * Licensed under MIT License - see LICENSE file for details.
 *
 * VA Database: VhaCdwDwhSql33.vha.med.va.gov
 * Target Database: D03_VISN12Collab
 * Classification: Internal Use Only, No PHI/ePHI
 * Created: $(Get-Date -Format 'yyyy-MM-dd')
 */

"@

    'js'   = @"
/**
 * VA Power Platform Development
 *
 * @author Kyle J. Coder
 * @organization Edward Hines Jr. VA Hospital (Hines VAMC)
 * @team Clinical Informatics & Advanced Analytics
 * @email Kyle.Coder@va.gov
 *
 * This file is part of the VA Power Platform workspace template.
 * Licensed under MIT License - see LICENSE file for details.
 *
 * VA Compliance: Section 508 accessible, Internal Use Only
 * Created: $(Get-Date -Format 'yyyy-MM-dd')
 */

"@

    'css'  = @"
/*
 * VA Power Platform Development
 *
 * Author: Kyle J. Coder
 * Organization: Edward Hines Jr. VA Hospital (Hines VAMC)
 * Team: Clinical Informatics & Advanced Analytics
 * Email: Kyle.Coder@va.gov
 *
 * This file is part of the VA Power Platform workspace template.
 * Licensed under MIT License - see LICENSE file for details.
 *
 * VA Branding: Official colors and accessibility compliance
 * Created: $(Get-Date -Format 'yyyy-MM-dd')
 */

"@

    'html' = @"
<!--
 * VA Power Platform Development
 *
 * Author: Kyle J. Coder
 * Organization: Edward Hines Jr. VA Hospital (Hines VAMC)
 * Team: Clinical Informatics & Advanced Analytics
 * Email: Kyle.Coder@va.gov
 *
 * This file is part of the VA Power Platform workspace template.
 * Licensed under MIT License - see LICENSE file for details.
 *
 * VA Compliance: Section 508 accessible, Internal Use Only
 * Created: $(Get-Date -Format 'yyyy-MM-dd')
-->

"@
}

function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"

    switch ($Level) {
        'INFO' { Write-Host $LogEntry -ForegroundColor White }
        'WARNING' { Write-Host $LogEntry -ForegroundColor Yellow }
        'ERROR' { Write-Host $LogEntry -ForegroundColor Red }
        'SUCCESS' { Write-Host $LogEntry -ForegroundColor Green }
    }

    $LogEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Test-ExistingHeader {
    param([string]$FilePath)

    try {
        $Content = Get-Content -Path $FilePath -First 20 -ErrorAction Stop
        $ContentText = $Content -join "`n"

        # Check for existing license indicators
        return ($ContentText -match 'Kyle J\. Coder' -or
            $ContentText -match 'Edward Hines Jr\. VA Hospital' -or
            $ContentText -match 'MIT License' -or
            $ContentText -match 'VA Power Platform Development')
    }
    catch {
        Write-LogMessage -Message "Error reading file $FilePath`: $($_.Exception.Message)" -Level 'WARNING'
        return $false
    }
}

function Add-HeaderToFile {
    param(
        [string]$FilePath,
        [string]$Extension,
        [bool]$DryRunMode
    )

    try {
        if (-not $LicenseHeaders.ContainsKey($Extension)) {
            Write-LogMessage -Message "No header template for extension: $Extension" -Level 'WARNING'
            return $false
        }

        $Header = $LicenseHeaders[$Extension]
        $OriginalContent = Get-Content -Path $FilePath -Raw -ErrorAction Stop

        if ($DryRunMode) {
            Write-LogMessage -Message "DRY RUN: Would add header to $FilePath" -Level 'INFO'
            return $true
        }

        # Add header to beginning of file
        $NewContent = $Header + $OriginalContent
        Set-Content -Path $FilePath -Value $NewContent -Encoding UTF8 -ErrorAction Stop

        Write-LogMessage -Message "Added license header to: $FilePath" -Level 'SUCCESS'
        return $true
    }
    catch {
        Write-LogMessage -Message "Error processing file $FilePath`: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

# Main execution
try {
    Write-LogMessage -Message '========================================' -Level 'INFO'
    Write-LogMessage -Message "$ScriptName v$ScriptVersion" -Level 'INFO'
    Write-LogMessage -Message 'Author: Kyle J. Coder' -Level 'INFO'
    Write-LogMessage -Message 'Organization: Edward Hines Jr. VA Hospital' -Level 'INFO'
    Write-LogMessage -Message '========================================' -Level 'INFO'

    if ($DryRun) {
        Write-LogMessage -Message 'DRY RUN MODE: No files will be modified' -Level 'WARNING'
    }

    $Extensions = $FileTypes.Split(',').Trim()
    $WorkspacePath = Split-Path -Parent $ScriptPath
    $ProcessedCount = 0
    $SkippedCount = 0
    $ErrorCount = 0

    Write-LogMessage -Message "Processing file types: $($Extensions -join ', ')" -Level 'INFO'
    Write-LogMessage -Message "Workspace path: $WorkspacePath" -Level 'INFO'

    foreach ($Extension in $Extensions) {
        Write-LogMessage -Message "Processing .$Extension files..." -Level 'INFO'

        $SearchPattern = "*.$Extension"
        $Files = Get-ChildItem -Path $WorkspacePath -Filter $SearchPattern -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\\.git\\|\\node_modules\\|\\logs\\' }

        Write-LogMessage -Message "Found $($Files.Count) .$Extension files" -Level 'INFO'

        foreach ($File in $Files) {
            if ($SkipExisting -and (Test-ExistingHeader -FilePath $File.FullName)) {
                Write-LogMessage -Message "Skipping (header exists): $($File.FullName)" -Level 'INFO'
                $SkippedCount++
                continue
            }

            if (Add-HeaderToFile -FilePath $File.FullName -Extension $Extension -DryRunMode $DryRun) {
                $ProcessedCount++
            }
            else {
                $ErrorCount++
            }
        }
    }

    Write-LogMessage -Message '========================================' -Level 'INFO'
    Write-LogMessage -Message 'License header processing completed!' -Level 'SUCCESS'
    Write-LogMessage -Message "Files processed: $ProcessedCount" -Level 'SUCCESS'
    Write-LogMessage -Message "Files skipped: $SkippedCount" -Level 'INFO'
    Write-LogMessage -Message "Errors encountered: $ErrorCount" -Level 'INFO'

    if ($DryRun) {
        Write-LogMessage -Message 'This was a DRY RUN - no files were actually modified' -Level 'WARNING'
        Write-LogMessage -Message 'Run without -DryRun to apply changes' -Level 'INFO'
    }

    Write-LogMessage -Message "Log file: $LogFile" -Level 'INFO'
    Write-LogMessage -Message '========================================' -Level 'INFO'
}
catch {
    Write-LogMessage -Message "Fatal error: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}
