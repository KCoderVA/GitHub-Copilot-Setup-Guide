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
Generates productivity reports with customizable time filtering.

.DESCRIPTION
This script creates productivity reports by filtering workspace activity based on the specified time period.
Each report type applies different date/time filters to show only relevant activity:

- DAILY: Shows activity for the current day only (00:00:00 to 23:59:59)
- WEEKLY: Shows activity for the current week (Sunday to Saturday)
- MONTHLY: Shows activity for the current month (1st to last day)
- CUSTOM: Shows activity for user-specified date range

Important: Each report is a SNAPSHOT of the specified time period, not cumulative history.
Running the same report type tomorrow will show ONLY tomorrow's activity (for Daily),
or the SAME week's activity including both days (for Weekly).

.PARAMETER ReportType
Determines the time filtering applied to the report:
- "Daily" = Today only (July 24, 2025)
- "Weekly" = Current week (July 20-26, 2025)
- "Monthly" = Current month (July 1-31, 2025)
- "Custom" = User-specified StartDate to EndDate

.EXAMPLE
.\Generate-ProductivityReport.ps1 -ReportType Daily
# Shows only today's activity

.EXAMPLE
.\Generate-ProductivityReport.ps1 -ReportType Weekly
# Shows this week's activity (accumulative from Sunday to today)

.EXAMPLE
.\Generate-ProductivityReport.ps1 -ReportType Custom -StartDate "2025-07-01" -EndDate "2025-07-15"
# Shows activity from July 1-15, 2025

.NOTES
WORK ESTIMATION MATHEMATICS EXPLAINED

This function estimates human work effort based on observable code changes and activity.
The estimation model combines industry-standard metrics with VA healthcare complexity factors.

NEW CODE CREATION (5 minutes per line):
- Industry studies show 10-15 lines per hour for quality, maintainable code
- Includes time for: design thinking, coding, testing, initial debugging
- PowerShell automation requires additional logic design and error handling
- VA environment adds compliance considerations during initial development

CODE MODIFICATION (3 minutes per line):
- Faster than new code because structure already exists
- Includes time for: understanding existing code, making changes, testing modifications
- Still requires careful consideration of side effects in healthcare environments

CODE REMOVAL (1.5 minutes per line):
- Fastest operation but still requires careful analysis
- Includes time for: understanding dependencies, ensuring safe removal, testing
- Critical in healthcare to ensure removed code doesn't break compliance or workflows

COMMIT OVERHEAD (15 minutes per commit):
- Time for: reviewing changes, writing meaningful commit messages, staging files
- Includes mental context switching between coding and version control
- VA environments require more detailed commit documentation for audit trails

COMPLEXITY MULTIPLIERS:

PowerShell Complexity Factor (1.2x):
- PowerShell automation requires additional error handling and edge case consideration
- Script robustness is critical in healthcare environments
- Integration with multiple systems adds complexity

Healthcare Compliance Factor (1.3x):
- HIPAA compliance considerations slow development
- VA security requirements add documentation and review overhead
- Integration with legacy VA systems requires additional testing and validation

CALCULATION EXAMPLE:
If you have made: 50 lines added, 20 lines modified, 10 lines removed, 3 commits
    Base Time = (50 × 5) + (20 × 3) + (10 × 1.5) + (3 × 15)
              = 250 + 60 + 15 + 45 = 370 minutes
    With Complexity = 370 × 1.2 × 1.3 = 577 minutes (9.6 hours)

IMPORTANT NOTES:
- These are ESTIMATES based on observable data, not precise time tracking
- Actual time varies based on developer experience, interruptions, and task complexity
- Use for relative comparison and trending, not absolute billing or performance metrics
- The model is intentionally conservative to avoid under-estimating effort
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Daily", "Weekly", "Monthly", "Custom")]
    [string]$ReportType = "Daily",

    [Parameter(Mandatory=$false)]
    [DateTime]$StartDate,

    [Parameter(Mandatory=$false)]
    [DateTime]$EndDate,

    [Parameter(Mandatory=$false)]
    [ValidateSet("Markdown", "HTML", "JSON", "CSV")]
    [string]$OutputFormat = "Markdown",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "",

    [Parameter(Mandatory=$false)]
    [switch]$OpenAfterGeneration,

    [Parameter(Mandatory=$false)]
    [switch]$IncludeDetailed = $false
)

# Error handling and logging
$ErrorActionPreference = "Continue"
$LogPath = "$PSScriptRoot\..\logs\productivity-operations.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    if (!(Test-Path (Split-Path $LogPath))) {
        New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $LogEntry
}

function Get-ReportDateRange {
    param([string]$Type)

    $Today = Get-Date

    switch ($Type) {
        "Daily" {
            return @{
                Start = $Today.Date
                End = $Today.Date.AddDays(1).AddSeconds(-1)
                Title = $Today.ToString("MMMM dd, yyyy")
            }
        }
        "Weekly" {
            $StartOfWeek = $Today.AddDays(-[int]$Today.DayOfWeek)
            return @{
                Start = $StartOfWeek.Date
                End = $StartOfWeek.AddDays(7).AddSeconds(-1)
                Title = "Week of $($StartOfWeek.ToString("MMM dd, yyyy"))"
            }
        }
        "Monthly" {
            $StartOfMonth = New-Object DateTime($Today.Year, $Today.Month, 1)
            return @{
                Start = $StartOfMonth
                End = $StartOfMonth.AddMonths(1).AddSeconds(-1)
                Title = $Today.ToString("MMMM yyyy")
            }
        }
        "Custom" {
            return @{
                Start = $StartDate
                End = $EndDate
                Title = "$($StartDate.ToString("MMM dd")) - $($EndDate.ToString("MMM dd, yyyy"))"
            }
        }
    }
}

function Get-GitCodeStatistics {
    param($DateRange)

    $GitStats = @{
        CommitCount = 0
        LinesAdded = 0
        LinesRemoved = 0
        LinesModified = 0
        FilesChanged = 0
        Commits = @()
        EstimatedWorkMinutes = 0
    }

    try {
        # Check if we're in a Git repository
        $null = git status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Not in a Git repository or Git not available" "WARN"
            return $GitStats
        }

        # Format dates for Git log with proper timezone handling
        $GitStartDate = $DateRange.Start.ToString("yyyy-MM-dd")
        $GitEndDate = $DateRange.End.ToString("yyyy-MM-dd")

        Write-Log "Searching Git commits from $GitStartDate to $GitEndDate" "INFO"

        # Get commits in date range - use --after and --before for inclusive date range
        $GitLogOutput = git log --after="$GitStartDate 00:00:00" --before="$GitEndDate 23:59:59" --pretty=format:"%H|%ai|%s|%an" 2>$null

        if ($GitLogOutput) {
            $CommitHashes = @()
            foreach ($Line in $GitLogOutput) {
                if ($Line) {
                    $Parts = $Line -split '\|'
                    if ($Parts.Length -ge 4) {
                        $CommitHash = $Parts[0]
                        $CommitDate = [DateTime]::Parse($Parts[1])
                        $CommitMessage = $Parts[2]
                        $Author = $Parts[3]

                        $CommitHashes += $CommitHash
                        $GitStats.Commits += @{
                            Hash = $CommitHash
                            Date = $CommitDate
                            Message = $CommitMessage
                            Author = $Author
                        }
                    }
                }
            }

            $GitStats.CommitCount = $CommitHashes.Count
            Write-Log "Found $($GitStats.CommitCount) commits in date range" "INFO"

            # Get detailed stats for each commit
            if ($CommitHashes.Count -gt 0) {
                # Get cumulative diff stats for the date range - use same date filtering
                $DiffStatsOutput = git log --after="$GitStartDate 00:00:00" --before="$GitEndDate 23:59:59" --numstat --pretty=format:"" 2>$null

                if ($DiffStatsOutput) {
                    foreach ($Line in $DiffStatsOutput) {
                        if ($Line -and $Line -match '^\d+\s+\d+\s+') {
                            $Parts = $Line -split '\s+'
                            if ($Parts.Length -ge 3 -and $Parts[0] -ne '-' -and $Parts[1] -ne '-') {
                                $Added = [int]$Parts[0]
                                $Removed = [int]$Parts[1]

                                $GitStats.LinesAdded += $Added
                                $GitStats.LinesRemoved += $Removed
                                $GitStats.FilesChanged++
                            }
                        }
                    }
                }

                # Calculate modified lines (approximation: smaller of added/removed as modifications)
                $GitStats.LinesModified = [Math]::Min($GitStats.LinesAdded, $GitStats.LinesRemoved)

                # Adjust added/removed to account for modifications
                $GitStats.LinesAdded = $GitStats.LinesAdded - $GitStats.LinesModified
                $GitStats.LinesRemoved = $GitStats.LinesRemoved - $GitStats.LinesModified

                Write-Log "Git stats: +$($GitStats.LinesAdded) -$($GitStats.LinesRemoved) ~$($GitStats.LinesModified) across $($GitStats.FilesChanged) files" "INFO"
            }
        } else {
            Write-Log "No commits found in specified date range" "INFO"
        }

        # Estimate work effort
        $GitStats.EstimatedWorkMinutes = Get-WorkEstimate -GitStats $GitStats

    } catch {
        Write-Log "Error analyzing Git statistics: $($_.Exception.Message)" "WARN"
    }

    return $GitStats
}

function Get-WorkEstimate {
    param($GitStats)

    # Industry-standard estimates (adjusted for VA/healthcare complexity)
    $EstimatedMinutes = 0

    # Base coding time estimates (minutes per line)
    $NewCodeMinutesPerLine = 5.0      # ~12 lines per hour
    $ModifiedCodeMinutesPerLine = 3.0 # ~20 lines per hour
    $RemovedCodeMinutesPerLine = 1.5  # ~40 lines per hour (review/refactor time)

    # Calculate base time
    $EstimatedMinutes += $GitStats.LinesAdded * $NewCodeMinutesPerLine
    $EstimatedMinutes += $GitStats.LinesModified * $ModifiedCodeMinutesPerLine
    $EstimatedMinutes += $GitStats.LinesRemoved * $RemovedCodeMinutesPerLine

    # Add commit overhead (planning, committing, documentation)
    $CommitOverheadMinutes = 15 # 15 minutes per commit for planning/documentation
    $EstimatedMinutes += $GitStats.CommitCount * $CommitOverheadMinutes

    # Apply complexity multipliers
    $PowerShellComplexityFactor = 1.2  # PowerShell automation complexity
    $HealthcareComplianceFactor = 1.3  # VA compliance and documentation requirements

    $EstimatedMinutes = $EstimatedMinutes * $PowerShellComplexityFactor * $HealthcareComplianceFactor

    # Minimum time floor (at least 30 minutes if any work was done)
    if ($GitStats.CommitCount -gt 0 -and $EstimatedMinutes -lt 30) {
        $EstimatedMinutes = 30
    }

    return [Math]::Round($EstimatedMinutes, 0)
}

function Get-ProductivityData {
    param($DateRange)

    $WorkspaceRoot = Split-Path $PSScriptRoot -Parent
    $LogsPath = "$WorkspaceRoot\logs"

    $Data = @{
        PowerApps = @{
            Unpacked = @()
            Packed = @()
            Created = @()
        }
        SQL = @{
            QueriesRun = @()
            ExportsGenerated = @()
        }
        Workspace = @{
            CleanupsPerformed = @()
            ProjectsInitialized = @()
        }
        General = @{
            FilesCreated = @()
            FilesModified = @()
            TimeSpent = @{}
        }
        Git = @{
            CommitCount = 0
            LinesAdded = 0
            LinesRemoved = 0
            LinesModified = 0
            FilesChanged = 0
            Commits = @()
            EstimatedWorkMinutes = 0
        }
        Logs = @()
    }

    # Analyze Git repository activity
    try {
        Write-Log "Analyzing Git commit statistics for date range" "INFO"
        $GitStatistics = Get-GitCodeStatistics -DateRange $DateRange
        $Data.Git = $GitStatistics
    } catch {
        Write-Log "Error analyzing Git statistics: $($_.Exception.Message)" "WARN"
    }

    # Parse productivity logs (existing functionality)
    try {
        $ProductivityFiles = Get-ChildItem -Path $LogsPath -Filter "productivity-log-*.md" -ErrorAction SilentlyContinue

        foreach ($File in $ProductivityFiles) {
            $FileDate = [DateTime]::ParseExact($File.BaseName.Replace("productivity-log-", ""), "yyyy-MM-dd", $null)

            if ($FileDate -ge $DateRange.Start -and $FileDate -le $DateRange.End) {
                $Content = Get-Content -Path $File.FullName -Raw
                $Data.Logs += @{
                    Date = $FileDate
                    Content = $Content
                    File = $File.FullName
                }
            }
        }
    } catch {
        Write-Log "Error parsing productivity logs: $($_.Exception.Message)" "WARN"
    }

    return $Data
}

function Format-MarkdownReport {
    param($Data, $DateRange)

    # Build report content
    $Report = "# VA Power Platform Productivity Report`n`n"
    $Report += "**Report Period:** $($DateRange.Start.ToString('MMMM dd, yyyy')) - $($DateRange.End.ToString('MMMM dd, yyyy'))`n"
    $Report += "**Report Generated:** $(Get-Date -Format 'MMMM dd, yyyy HH:mm:ss')`n"
    $Report += "**Author:** Kyle J. Coder`n"
    $Report += "**Team:** Clinical Informatics & Advanced Analytics`n"
    $Report += "**Facility:** Edward Hines Jr. VA Hospital`n`n"
    $Report += "---`n`n"

    # Executive Summary
    $Report += "## Executive Summary`n`n"

    # Code Development Statistics
    $Report += "### Code Development Statistics`n"
    $Report += "- **Git Commits:** $($Data.Git.CommitCount)`n"
    $Report += "- **Lines Added:** $($Data.Git.LinesAdded)`n"
    $Report += "- **Lines Removed:** $($Data.Git.LinesRemoved)`n"
    $Report += "- **Lines Modified:** $($Data.Git.LinesModified)`n"
    $Report += "- **Files Changed:** $($Data.Git.FilesChanged)`n"
    $WorkHours = [Math]::Round($Data.Git.EstimatedWorkMinutes / 60, 1)
    $Report += "- **Estimated Work Time:** $($Data.Git.EstimatedWorkMinutes) minutes ($WorkHours hours)`n`n"

    # Git commit details if available
    if ($Data.Git.CommitCount -gt 0) {
        $Report += "## Code Development Details`n`n"
        $Report += "### Git Commit Summary`n"
        $Report += "**Total Commits:** $($Data.Git.CommitCount)`n"
        $Report += "**Code Changes:**`n"
        $Report += "- Added: $($Data.Git.LinesAdded) lines`n"
        $Report += "- Removed: $($Data.Git.LinesRemoved) lines`n"
        $Report += "- Modified: $($Data.Git.LinesModified) lines`n"
        $Report += "- Files Affected: $($Data.Git.FilesChanged)`n`n"

        $Report += "### Work Effort Estimation`n"
        $Report += "**Estimated Time Investment:** $($Data.Git.EstimatedWorkMinutes) minutes ($WorkHours hours)`n`n"
        $Report += "*Estimation based on industry standards adjusted for VA/healthcare complexity*`n`n"

        # Recent commit details
        if ($IncludeDetailed -and $Data.Git.Commits.Count -gt 0) {
            $Report += "### Recent Commits`n"
            $RecentCommits = $Data.Git.Commits | Sort-Object Date -Descending | Select-Object -First 10

            foreach ($Commit in $RecentCommits) {
                $ShortHash = $Commit.Hash.Substring(0, 7)
                $Report += "- **$($Commit.Date.ToString('MM/dd HH:mm'))** [$ShortHash] $($Commit.Message)`n"
            }

            if ($Data.Git.Commits.Count -gt 10) {
                $Report += "- *...and $($Data.Git.Commits.Count - 10) more commits*`n"
            }
        }

        $Report += "`n---`n`n"
    }

    # Productivity Metrics
    $Report += "## Productivity Metrics`n`n"
    $Report += "### Development Activity`n"
    $Report += "- **Version Control Operations:** $($Data.Git.CommitCount) commits`n"
    $Report += "- **Code Quality:** Structured commit messages and version tagging`n"
    $Report += "- **Workspace Organization:** Proper Git workflow and documentation`n`n"

    $Report += "---`n`n"
    $Report += "*Generated by VA Power Platform Workspace Template*`n"
    $Report += "*Report ID: $(Get-Date -Format 'yyyyMMdd-HHmmss')*`n"

    return $Report
}

function Export-Report {
    param($Content, $Format, $OutputPath, $Data)

    switch ($Format) {
        "Markdown" {
            Set-Content -Path $OutputPath -Value $Content -Encoding UTF8
        }
        "HTML" {
            $HtmlContent = $Content -replace "`n", "<br>`n"
            $HtmlContent = $HtmlContent -replace "\*\*(.*?)\*\*", "<strong>$1</strong>"

            $FullHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>VA Power Platform Productivity Report</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #1f5582; }
        h2 { color: #2d72a3; }
        h3 { color: #3e8cc7; }
    </style>
</head>
<body>
$HtmlContent
</body>
</html>
"@
            Set-Content -Path $OutputPath -Value $FullHtml -Encoding UTF8
        }
        "JSON" {
            $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        }
        "CSV" {
            $CsvData = @"
Metric,Value
Report Generated,$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Git Commits,$($Data.Git.CommitCount)
Lines Added,$($Data.Git.LinesAdded)
Lines Removed,$($Data.Git.LinesRemoved)
Lines Modified,$($Data.Git.LinesModified)
Files Changed,$($Data.Git.FilesChanged)
Estimated Work Minutes,$($Data.Git.EstimatedWorkMinutes)
"@
            Set-Content -Path $OutputPath -Value $CsvData -Encoding UTF8
        }
    }
}

try {
    Write-Log "Starting productivity report generation" "INFO"

    Write-Host "VA Power Platform Productivity Report Generator" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green

    # Determine date range
    if ($ReportType -eq "Custom" -and (!$StartDate -or !$EndDate)) {
        throw "Custom report type requires both StartDate and EndDate parameters"
    }

    $DateRange = Get-ReportDateRange -Type $ReportType
    Write-Host "Report Period: $($DateRange.Title)" -ForegroundColor Yellow

    # Generate output path if not specified
    if ([string]::IsNullOrEmpty($OutputPath)) {
        $ReportsPath = "$PSScriptRoot\..\docs\reports"
        if (!(Test-Path $ReportsPath)) {
            New-Item -Path $ReportsPath -ItemType Directory -Force | Out-Null
        }

        $FileExtension = switch ($OutputFormat) {
            "Markdown" { "md" }
            "HTML" { "html" }
            "JSON" { "json" }
            "CSV" { "csv" }
        }

        $FileName = "productivity-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').$FileExtension"
        $OutputPath = Join-Path $ReportsPath $FileName
    }

    Write-Host "Analyzing workspace activity..." -ForegroundColor Yellow

    # Collect productivity data
    $ProductivityData = Get-ProductivityData -DateRange $DateRange

    Write-Host "Generating report..." -ForegroundColor Yellow

    # Generate report content
    $ReportContent = Format-MarkdownReport -Data $ProductivityData -DateRange $DateRange

    # Export report
    Export-Report -Content $ReportContent -Format $OutputFormat -OutputPath $OutputPath -Data $ProductivityData

    # Summary
    $FileSize = (Get-Item $OutputPath).Length

    Write-Host "`nProductivity report generated successfully!" -ForegroundColor Green
    Write-Host "Report file: $OutputPath" -ForegroundColor Cyan
    Write-Host "File size: $([math]::Round($FileSize / 1KB, 2)) KB" -ForegroundColor Yellow

    Write-Host "`nReport Summary:" -ForegroundColor White
    Write-Host "   Git Commits: $($ProductivityData.Git.CommitCount)" -ForegroundColor Gray
    Write-Host "   Lines Changed: $($ProductivityData.Git.LinesAdded + $ProductivityData.Git.LinesRemoved + $ProductivityData.Git.LinesModified)" -ForegroundColor Gray
    Write-Host "   Estimated Work: $($ProductivityData.Git.EstimatedWorkMinutes) minutes" -ForegroundColor Gray

    # Open file if requested
    if ($OpenAfterGeneration) {
        Write-Host "`nOpening report..." -ForegroundColor Yellow
        Start-Process $OutputPath
    }

    Write-Log "Productivity report generated successfully: $OutputPath" "SUCCESS"

} catch {
    Write-Log "Error generating productivity report: $($_.Exception.Message)" "ERROR"
    Write-Host "Error generating report: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
