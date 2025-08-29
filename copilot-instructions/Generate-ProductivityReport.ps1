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
- ALLTIME: Shows all entries from the beginning of time
- CUSTOM: Shows activity for user-specified date range

Important: Each report is a SNAPSHOT of the specified time period, not cumulative history.
Running the same report type tomorrow will show ONLY tomorrow's activity (for Daily),
or the SAME week's activity including both days (for Weekly).

.PARAMETER ReportType
Determines the time filtering applied to the report:
- "Daily" = Today only (July 24, 2025)
- "Weekly" = Current week (July 20-26, 2025)
- "Monthly" = Current month (July 1-31, 2025)
- "AllTime" = 1970-01-01 to Present
- "Custom" = User-specified StartDate to EndDate

.PARAMETER GitRepoPath
Path to a folder inside a Git repository to analyze. The script will resolve to the repository top-level automatically.

.PARAMETER OutputFormat
Single output format when -ExportFormats is not provided. One of: Markdown, HTML, JSON, CSV.

.PARAMETER ExportFormats
List of formats to export in one run (e.g., HTML,Markdown,JSON). Overrides -OutputFormat if specified.

.PARAMETER OutputDir
Directory for writing report files when -OutputPath is not specified. Defaults to /docs/reports under the workspace.

.PARAMETER FactorsConfig
Path to a JSON file defining the Alternative Effort Items. Shape: { "Items": [ { "Label": "...", "Factor": 0.25, "Links": ["..."], "Description": "<p>...</p>" } ] }

.PARAMETER GitRef
Git ref/branch/tag to analyze (default: HEAD). Use -AllBranches to include all branches.

.PARAMETER AllBranches
If set, analyze commits across all branches (adds --all to git log), still constrained by the date range.

.PARAMETER NonInteractive
Disable interactive prompts (useful for CI pipelines). The script uses provided parameters or defaults.

.PARAMETER Quiet
Reduce console output and suppress auto-open of the HTML report.

.PARAMETER MaxCommits
Maximum number of commits to list in the Recent Commits section (default: 10).

.PARAMETER BaselineJson
Path to a prior JSON export; if provided, the report computes deltas for key KPIs (Commits, Lines, Files, Estimated Work) and shows delta chips next to KPI values in HTML.

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
    [ValidateSet("Daily", "Weekly", "Monthly", "AllTime", "Custom")]
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
    ,
    [Parameter(Mandatory=$false)]
    [string]$GitRepoPath = "",

    # New optional features
    [Parameter(Mandatory=$false)]
    [string]$FactorsConfig = "",
    [Parameter(Mandatory=$false)]
    [string]$GitRef = "HEAD",
    [Parameter(Mandatory=$false)]
    [switch]$AllBranches,
    [Parameter(Mandatory=$false)]
    [string[]]$ExportFormats,
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "",
    [Parameter(Mandatory=$false)]
    [switch]$NonInteractive,
    [Parameter(Mandatory=$false)]
    [switch]$Quiet,
    [Parameter(Mandatory=$false)]
    [int]$MaxCommits = 99,
    [Parameter(Mandatory=$false)]
    [string]$BaselineJson = "",
    # Filesystem snapshot filter controls (opt-in to include normally-excluded areas)
    [Parameter(Mandatory=$false)]
    [switch]$FSIncludeGit,
    [Parameter(Mandatory=$false)]
    [switch]$FSIncludeCompressed,
    [Parameter(Mandatory=$false)]
    [switch]$FSIncludeArchiveTemp
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

# Conditional console writer (suppressed when -Quiet)
function Write-Info {
    param([string]$Text, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    if (-not $Quiet) { Write-Host $Text -ForegroundColor $Color }
}

# Read a line with timeout (returns default if user doesn't answer in time)
function Read-HostWithTimeout {
    param(
        [string]$Prompt,
        [int]$TimeoutSeconds = 15,
        [string]$Default = ''
    )
    Write-Host ("$Prompt (default after $TimeoutSeconds sec: $Default)")
    $sb = New-Object System.Text.StringBuilder
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            if ([System.Console]::KeyAvailable) {
                $key = [System.Console]::ReadKey($true)
                if ($key.Key -eq 'Enter') { break }
                elseif ($key.Key -eq 'Backspace') {
                    if ($sb.Length -gt 0) { $sb.Length = $sb.Length - 1; Write-Host "`b `b" -NoNewline }
                } else {
                    [void]$sb.Append($key.KeyChar)
                    Write-Host $key.KeyChar -NoNewline
                }
            } else {
                Start-Sleep -Milliseconds 50
            }
        }
    } catch {
        $sw.Stop()
        return $Default
    }
    $sw.Stop()
    $resultText = $sb.ToString().Trim()
    if ([string]::IsNullOrEmpty($resultText)) { return $Default } else { return $resultText }
}

function Show-IntroText {
    Write-Host ""
    Write-Host "What this tool does:" -ForegroundColor Cyan
    Write-Host "     Creates a decision-ready snapshot of development activity in this workspace for a selected period." -ForegroundColor Gray
    Write-Host "     It does this by analyzes Git commit history and code-change metrics and will also parse productivity logs in the /logs folder if present." -ForegroundColor Gray

    Write-Host ""; Write-Host "How the time window works:" -ForegroundColor Yellow
    Write-Host "    - Daily   : Today only (00:00–23:59)" -ForegroundColor Gray
    Write-Host "    - Weekly  : Current week (Sunday–Saturday)" -ForegroundColor Gray
    Write-Host "    - Monthly : Current month (1st–last day)" -ForegroundColor Gray
    Write-Host "    - AllTime : From 1970-01-01 to now" -ForegroundColor Gray
    Write-Host "    - Custom  : Exact Start and End dates you provide" -ForegroundColor Gray
    Write-Host "Note: Each run is a snapshot of the chosen period—not a running total or cumulative history." -ForegroundColor DarkGray

    Write-Host ""; Write-Host "What you’ll get as output:" -ForegroundColor Yellow
    Write-Host "    - A report file in your chosen format (Markdown / HTML / JSON / CSV)" -ForegroundColor Gray
    Write-Host "    - Code development statistics: commits, lines added/removed/modified, files changed" -ForegroundColor Gray
    Write-Host "    - An effort estimate derived from observable code changes" -ForegroundColor Gray
    Write-Host "    - Optional recent-commit details when Detailed mode is enabled" -ForegroundColor Gray

    Write-Host ""; Write-Host "Labor/manpower requirement calculations used in report formula:" -ForegroundColor Yellow
    Write-Host "    - New lines:       5.0 min/line" -ForegroundColor Gray
    Write-Host "    - Modified lines:  3.0 min/line" -ForegroundColor Gray
    Write-Host "    - Removed lines:   1.5 min/line" -ForegroundColor Gray
    Write-Host "    - Commit overhead: 15 min/commit for planning and documentation" -ForegroundColor Gray
    Write-Host "    - Multipliers:     1.2× PowerShell complexity, 1.3× healthcare compliance" -ForegroundColor Gray
    Write-Host "    - Minimum floor:   at least 30 minutes if any work occurred" -ForegroundColor Gray
    Write-Host "Use these estimates for relative comparison and trending—not precise time tracking or billing." -ForegroundColor DarkGray

    Write-Host ""; Write-Host "What happens next" -ForegroundColor Yellow
    Write-Host "    - You’ll be promped to choose a period of time, an report output format, and (optionally) identify a specific directory path containing a Git repository." -ForegroundColor Gray
    Write-Host "    - The script searches for the identified Git repository, analyzes the various activities in the repository and parent folder, and reads any productivity logs under /logs." -ForegroundColor Gray
    Write-Host "    - The script then generates the output details report and (if selected) automatically opens the output file." -ForegroundColor Gray

    Write-Host ""; Write-Host "Advanced options you can pass as parameters:" -ForegroundColor Yellow
    Write-Host "    - -FactorsConfig <path>     : Load productivity factors (Alternative Effort rows) from JSON instead of defaults" -ForegroundColor Gray
    Write-Host "    - -GitRef <ref>             : Analyze a specific branch/tag/ref (default: HEAD); use -AllBranches to scan all" -ForegroundColor Gray
    Write-Host "    - -ExportFormats <list>     : Export multiple formats in one run, e.g., -ExportFormats HTML,JSON" -ForegroundColor Gray
    Write-Host "    - -OutputDir <path>         : Choose output directory for reports (defaults to /docs/reports)" -ForegroundColor Gray
    Write-Host "    - -NonInteractive           : Disable prompts for CI/pipeline usage (uses provided parameters/defaults)" -ForegroundColor Gray
    Write-Host "    - -Quiet                    : Minimize console output and suppress auto-open" -ForegroundColor Gray
    Write-Host "    - -MaxCommits <n>           : Limit the Recent Commits section length (default: 10)" -ForegroundColor Gray
    Write-Host "    - -BaselineJson <path>      : Compare against prior JSON export; deltas shown next to KPIs" -ForegroundColor Gray
}

function New-Divider {
    param([string]$Char='-', [int]$Count=60)
    Write-Host ('' + ($Char * $Count)) -ForegroundColor DarkGray
}

function Show-Header {
    param([string]$Title)
    Write-Host ''
    New-Divider
    Write-Host $Title -ForegroundColor Cyan
    New-Divider
}

function Show-SubHeader {
    param([string]$Title)
    Write-Host $Title -ForegroundColor Yellow
}

function Show-ConfigSummary {
    param(
        [string]$ReportType,
    [Nullable[DateTime]]$StartDate,
    [Nullable[DateTime]]$EndDate,
        [string]$OutputFormat,
        [bool]$OpenAfterGeneration,
        [bool]$IncludeDetailed,
        [string]$GitRepoPath
    )
    Show-Header "Selected Options"
    Write-Host ("  Report Type  : {0}" -f $ReportType) -ForegroundColor Gray
    if ($ReportType -eq 'Custom') {
        Write-Host ("  Start Date   : {0}" -f $StartDate.ToString('yyyy-MM-dd')) -ForegroundColor Gray
        Write-Host ("  End Date     : {0}" -f $EndDate.ToString('yyyy-MM-dd')) -ForegroundColor Gray
    }
    Write-Host ("  Output Format: {0}" -f $OutputFormat) -ForegroundColor Gray
    Write-Host ("  Open File    : {0}" -f ($(if ($OpenAfterGeneration) { 'Yes' } else { 'No' }))) -ForegroundColor Gray
    Write-Host ("  Detailed Mode: {0}" -f ($(if ($IncludeDetailed) { 'Yes' } else { 'No' }))) -ForegroundColor Gray
    if ($GitRepoPath) { Write-Host ("  Git Repo Path: {0}" -f $GitRepoPath) -ForegroundColor Gray }
}

# Discover a default Git repository root starting from a given path
function Get-DefaultRepoPath {
    param([string]$StartPath)
    try {
        $dir = [System.IO.DirectoryInfo] (Resolve-Path -Path $StartPath -ErrorAction SilentlyContinue).Path
    } catch {
        $dir = [System.IO.DirectoryInfo] $StartPath
    }
    while ($null -ne $dir) {
        $gitPath = Join-Path $dir.FullName ".git"
        if (Test-Path $gitPath) { return $dir.FullName }
        $dir = $dir.Parent
    }
    return $StartPath # $StartPath or $gitPath
}

function Test-IsGitRepoPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    try {
        $full = (Resolve-Path -Path $Path -ErrorAction Stop).Path
        $git = Join-Path $full ".git"
        return (Test-Path $git)
    } catch { return $false }
}

function Get-GitTopLevelPath {
    param([string]$Path)
    try {
        $full = (Resolve-Path -Path $Path -ErrorAction Stop).Path
    } catch { $full = $Path }
    $top = (git -C "$full" rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and $top) { return $top.Trim() }
    return $null
}

function Get-ReportTypeInteractive {
    Write-Host "Select report period:" -ForegroundColor Cyan
    Write-Host "     1) Daily" -ForegroundColor Gray
    Write-Host "     2) Weekly" -ForegroundColor Gray
    Write-Host "     3) Monthly" -ForegroundColor Gray
    Write-Host "     4) All time (default)" -ForegroundColor Gray
    Write-Host "     5) Custom (enter start and end dates)" -ForegroundColor Gray
    $choice = Read-HostWithTimeout -Prompt "Enter choice [1-5]" -TimeoutSeconds 15 -Default "AllTime"

    switch -Regex ($choice.Trim()) {
        '^(1|daily)$'    { return @{ ReportType = 'Daily';   StartDate = $null; EndDate = $null } }
        '^(2|weekly)$'   { return @{ ReportType = 'Weekly';  StartDate = $null; EndDate = $null } }
        '^(3|monthly)$'  { return @{ ReportType = 'Monthly'; StartDate = $null; EndDate = $null } }
        '^(4|all\s*time|alltime)$' { return @{ ReportType = 'AllTime'; StartDate = $null; EndDate = $null } }
        '^(5|custom)$'   {
            $s = Read-HostWithTimeout -Prompt "Enter Start Date (YYYY-MM-DD)" -TimeoutSeconds 15 -Default ""
            $e = Read-HostWithTimeout -Prompt "Enter End Date (YYYY-MM-DD)"   -TimeoutSeconds 15 -Default ""
            try {
                if ([string]::IsNullOrWhiteSpace($s) -or [string]::IsNullOrWhiteSpace($e)) { throw 'Missing date(s)' }
                $sd = [DateTime]::Parse($s)
                $ed = [DateTime]::Parse($e)
                if ($ed -lt $sd) { $tmp = $sd; $sd = $ed; $ed = $tmp }
                return @{ ReportType = 'Custom'; StartDate = $sd; EndDate = $ed }
            } catch {
                Write-Host "Invalid or missing dates; defaulting to All time" -ForegroundColor Yellow
                return @{ ReportType = 'AllTime'; StartDate = $null; EndDate = $null }
            }
        }
        default { return @{ ReportType = 'AllTime'; StartDate = $null; EndDate = $null } }
    }
}

function Get-OutputFormatInteractive {
    Write-Host "Select output format:" -ForegroundColor Cyan
    Write-Host "     1) Markdown (.md)" -ForegroundColor Gray
    Write-Host "     2) HTML (.html) [default]" -ForegroundColor Gray
    Write-Host "     3) JSON (.json)" -ForegroundColor Gray
    Write-Host "     4) CSV (.csv)" -ForegroundColor Gray
    $choice = Read-HostWithTimeout -Prompt "Enter choice [1-4] or name (Markdown/HTML/JSON/CSV)" -TimeoutSeconds 15 -Default "HTML"

    switch -Regex ($choice.Trim()) {
        '^(1|markdown|md)$' { return 'Markdown' }
        '^(2|html|htm)$'    { return 'HTML' }
        '^(3|json)$'        { return 'JSON' }
        '^(4|csv)$'         { return 'CSV' }
        default             { return 'HTML' }
    }
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
        "AllTime" {
            $startAll = Get-Date '1970-01-01'
            return @{
                Start = $startAll
                End = Get-Date
                Title = "All Time"
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
    param($DateRange, [string]$RepoPath, [string]$GitRef = 'HEAD', [switch]$AllBranches)

    $GitStats = @{
        CommitCount = 0
    # Partitioned counts (derived) used for effort estimates
    LinesAdded = 0
    LinesRemoved = 0
        LinesModified = 0
        FilesChanged = 0
        Commits = @()
        EstimatedWorkMinutes = 0
    # Raw counts matching GitHub UI (additions/deletions)
    LinesAddedRaw = 0
    LinesRemovedRaw = 0
    }

    try {
        # Check if target path is a Git repository
        if (-not (Test-IsGitRepoPath -Path $RepoPath)) {
            Write-Log "Provided path is not a Git repository: $RepoPath" "WARN"
            return $GitStats
        }
        $null = git -C $RepoPath status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Not in a Git repository or Git not available" "WARN"
            return $GitStats
        }

        # Format dates for Git log with proper timezone handling
        $GitStartDate = $DateRange.Start.ToString("yyyy-MM-dd")
        $GitEndDate = $DateRange.End.ToString("yyyy-MM-dd")

        Write-Log "Searching Git commits from $GitStartDate to $GitEndDate" "INFO"

    # Get commits in date range - use --after and --before for inclusive date range
    $refArg = if ($AllBranches) { '--all' } else { $GitRef }
    $GitLogOutput = git -C $RepoPath log $refArg --after="$GitStartDate 00:00:00" --before="$GitEndDate 23:59:59" --pretty=format:"%H|%ai|%s|%an" 2>$null

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

            # Get detailed stats for each commit and aggregate per-day
            if ($CommitHashes.Count -gt 0) {
                # One pass with markers to split commits
                $DiffStatsOutput = git -C $RepoPath log $refArg --after="$GitStartDate 00:00:00" --before="$GitEndDate 23:59:59" --numstat --pretty=format:"@@%H|%ai" 2>$null

                $dailyMap = @{}
                $totalRawAdded = 0; $totalRawRemoved = 0; $totalFiles = 0
                $curAdded = 0; $curRemoved = 0; $curFiles = 0; $curDate = $null
                function Add-ToDaily([datetime]$d, [int]$a, [int]$r, [int]$f) {
                    if (-not $d) { return }
                    $day = $d.Date
                    if (-not $dailyMap.ContainsKey($day)) {
                        $dailyMap[$day] = [pscustomobject]@{ Date=$day; FilesChanged=0; LinesAdded=0; LinesRemoved=0; LinesModified=0 }
                    }
                    $obj = $dailyMap[$day]
                    $obj.FilesChanged += $f
                    $obj.LinesAdded += $a
                    $obj.LinesRemoved += $r
                    # We accumulate modifications after per-commit totals are known, but for simplicity add per-commit min here
                    $obj.LinesModified += [Math]::Min([int]$a, [int]$r)
                }

                if ($DiffStatsOutput) {
                    foreach ($Line in $DiffStatsOutput) {
                        if ($Line -and $Line.StartsWith('@@')) {
                            # finalize previous
                            if ($curDate) {
                                Add-ToDaily -d $curDate -a $curAdded -r $curRemoved -f $curFiles
                                $totalRawAdded += $curAdded; $totalRawRemoved += $curRemoved; $totalFiles += $curFiles
                            }
                            # reset for new commit header
                            $curAdded = 0; $curRemoved = 0; $curFiles = 0
                            $parts = $Line.Substring(2) -split '\|'
                            if ($parts.Length -ge 2) {
                                try { $curDate = [DateTime]::Parse($parts[1]) } catch { $curDate = $null }
                            } else { $curDate = $null }
                            continue
                        }
                        if ($Line -and $Line -match '^\d+\s+\d+\s+') {
                            $Parts = $Line -split '\s+'
                            if ($Parts.Length -ge 3 -and $Parts[0] -ne '-' -and $Parts[1] -ne '-') {
                                $a = [int]$Parts[0]
                                $r = [int]$Parts[1]
                                $curAdded += $a
                                $curRemoved += $r
                                $curFiles++
                            }
                        }
                    }
                    # finalize last commit
                    if ($curDate) {
                        Add-ToDaily -d $curDate -a $curAdded -r $curRemoved -f $curFiles
                        $totalRawAdded += $curAdded; $totalRawRemoved += $curRemoved; $totalFiles += $curFiles
                    }
                }

                # Build Daily array (sorted)
                if ($dailyMap.Count -gt 0) {
                    $GitStats.Daily = ($dailyMap.GetEnumerator() | ForEach-Object { $_.Value } | Sort-Object Date)
                } else { $GitStats.Daily = @() }

                # Preserve existing aggregate semantics: modifications = min(totalAdded, totalRemoved)
                # Store raw values (GitHub-style additions/deletions) for display
                $GitStats.FilesChanged = $totalFiles
                $GitStats.LinesAddedRaw = $totalRawAdded
                $GitStats.LinesRemovedRaw = $totalRawRemoved

                # Partitioned values (avoid double-counting for estimates)
                $GitStats.LinesModified = [Math]::Min($totalRawAdded, $totalRawRemoved)
                $GitStats.LinesAdded    = $totalRawAdded   - $GitStats.LinesModified
                $GitStats.LinesRemoved  = $totalRawRemoved - $GitStats.LinesModified

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

<#
    Filesystem snapshot helpers (lightweight port of Recursive-Directory-Analysis.ps1)
    - Non-interactive, no prompts, no CSV; returns aggregate counts for the repo root.
    - Excludes .git, common compressed archives, and archive/temp folders by default.
#>
function Test-FSReparsePoint {
    param([System.IO.FileSystemInfo]$Item)
    try { return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) } catch { return $false }
}

function Test-FSIsBinaryFile {
    param([string]$FullPath)
    try {
        $fs = [System.IO.File]::Open($FullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $buf = New-Object byte[] 8192
            $read = $fs.Read($buf, 0, $buf.Length)
            for ($i=0; $i -lt $read; $i++) { if ($buf[$i] -eq 0) { return $true } }
            return $false
        } finally { $fs.Dispose() }
    } catch { return $true }
}

function Measure-FSTextFile {
    param([string]$FullPath)
    $totalChars = 0; $totalLines = 0; $anyChars = $false; $lastWasCR = $false
    try {
        $fs = [System.IO.File]::Open($FullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $sr = New-Object System.IO.StreamReader($fs, $true)
            try {
                $buffer = New-Object char[] 4096
                while (($count = $sr.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    for ($i = 0; $i -lt $count; $i++) {
                        $c = $buffer[$i]; $anyChars = $true; $totalChars++
                        if ($c -eq "`n") { $totalLines++; $lastWasCR = $false }
                        elseif ($c -eq "`r") { $lastWasCR = $true }
                        else { if ($lastWasCR) { $totalLines++; $lastWasCR = $false } }
                    }
                }
                if ($lastWasCR) { $totalLines++ }
                if (-not $anyChars) { $totalLines = 0 }
                elseif ($totalLines -eq 0) { $totalLines = 1 }
            } finally { $sr.Dispose() }
        } finally { $fs.Dispose() }
    } catch { return @{ Lines = $null; Chars = $null } }
    return @{ Lines = $totalLines; Chars = $totalChars }
}

function Get-FilesystemSnapshot {
    param(
        [Parameter(Mandatory=$true)][string]$RootPath,
        [bool]$ExcludeGit = $true,
        [bool]$ExcludeCompressed = $true,
    [bool]$ExcludeArchiveOrTemp = $true
    )
    $snapshot = [ordered]@{
        Root = $RootPath
        TotalItems = 0
        TotalFiles = 0
        TotalFolders = 0
        TotalShortcuts = 0
        TotalReparse = 0
        SumLines = 0
        SumChars = 0
        SumSizeBytes = 0
        LastModified = $null
        TopExtensions = @()
    Files = @()
        Filters = [ordered]@{ ExcludeGit=$ExcludeGit; ExcludeCompressed=$ExcludeCompressed; ExcludeArchiveOrTemp=$ExcludeArchiveOrTemp }
    }

    try {
        if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) { return $snapshot }
    $root = Get-Item -LiteralPath $RootPath -Force
        $stack = New-Object System.Collections.Stack
        $items = New-Object System.Collections.Generic.List[System.IO.FileSystemInfo]
        $items.Add($root) | Out-Null
        $stack.Push($root)

    $scanCount = 0
    $scanProgressId = 42
    # spinner + throttle for smoother, visible updates
    $scanSpinChars = @('|','/','-','\')
    $scanSpinIdx = 0
    $scanThrottleMs = 150
    $lastScanTick = [Environment]::TickCount
    if (-not $Quiet) { try { Write-Progress -Id $scanProgressId -Activity "Scanning directories |" -Status "Starting..." -PercentComplete 0 } catch {} }
    while ($stack.Count -gt 0) {
            $dir = $stack.Pop()
            try { $children = Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction Stop } catch { continue }
            foreach ($child in $children) {
                # Apply path-based excludes
                $path = $null; try { $path = $child.FullName } catch {}
                $name = $null; try { $name = $child.Name } catch {}
                if ($ExcludeGit) {
                    if ($path -and ($path -match "(?i)(\\|/)\.git(\\/|$|\\)")) { continue }
                    if ($name -and ($name -match '^(?i)\.git$')) { continue }
                }
                if ($ExcludeArchiveOrTemp) {
                    if ($path -and ($path -match '(?i)(\\|/)(archive|archives|archived|temp|tmp)(\\|/)')) { continue }
                    if ($name -and ($name -match '(?i)^(archive|archives|archived|temp|tmp)$')) { continue }
                }
                $items.Add($child) | Out-Null
                $scanCount++
                if (-not $Quiet) {
                    $nowTick = [Environment]::TickCount
                    if ((($nowTick - $lastScanTick) -ge $scanThrottleMs) -or ($scanCount % 100 -eq 0)) {
                        $spin = $scanSpinChars[$scanSpinIdx % $scanSpinChars.Length]
                        $scanSpinIdx++
                        try { Write-Progress -Id $scanProgressId -Activity ("Scanning directories {0}" -f $spin) -Status ("Found {0} items..." -f $scanCount) -PercentComplete 10 } catch {}
                        $lastScanTick = $nowTick
                    }
                }
                if ($child.PSIsContainer) {
                    if (Test-FSReparsePoint -Item $child) { continue }
                    $stack.Push($child)
                }
            }
        }

        # Final filter set for reporting
        $reportItems = @()
        foreach ($it in $items) {
            $skip = $false
            try {
                if ($ExcludeGit) {
                    if ($it.FullName -match "(?i)(\\|/)\.git(\\/|$|\\)") { $skip = $true }
                    if ($it.Name -match '^(?i)\.git$') { $skip = $true }
                }
                if ($ExcludeArchiveOrTemp) {
                    if ($it.FullName -match '(?i)(\\|/)(archive|archives|archived|temp|tmp)(\\|/)') { $skip = $true }
                    if ($it.Name -match '(?i)^(archive|archives|archived|temp|tmp)$') { $skip = $true }
                }
                if (-not $skip -and $ExcludeCompressed -and -not $it.PSIsContainer) {
                    $ext = ''; try { $ext = $it.Extension.ToLowerInvariant() } catch {}
                    $compressedExts = @('.zip','.7z','.rar','.gz','.tar','.bz2','.xz','.zipx')
                    if ($compressedExts -contains $ext) { $skip = $true }
                }
            } catch {}
            if (-not $skip) { $reportItems += ,$it }
        }

    $snapshot.TotalItems = $reportItems.Count
    if (-not $Quiet) { try { Write-Progress -Id $scanProgressId -Activity "Scanning directories" -Status ("Enumerated {0} items" -f $snapshot.TotalItems) -PercentComplete 20 } catch {} }
    $files   = @($reportItems | Where-Object { -not $_.PSIsContainer -and -not (Test-FSReparsePoint -Item $_) -and ($_.Extension.ToLowerInvariant() -ne '.lnk') })
    $folders = @($reportItems | Where-Object { $_.PSIsContainer -and -not (Test-FSReparsePoint -Item $_) })
    $shorts  = @($reportItems | Where-Object { -not $_.PSIsContainer -and ($_.Extension.ToLowerInvariant() -eq '.lnk') })
    $reparse = @($reportItems | Where-Object { Test-FSReparsePoint -Item $_ })
        $snapshot.TotalFiles    = $files.Count
        $snapshot.TotalFolders  = $folders.Count
        $snapshot.TotalShortcuts= $shorts.Count
        $snapshot.TotalReparse  = $reparse.Count

        # Top extensions (files only)
        $extGroups = $files | ForEach-Object { $_.Extension.ToLowerInvariant() } | Group-Object | Sort-Object Count -Descending | Select-Object -First 8
        $topExt = @()
        foreach ($g in $extGroups) {
            $ename = if ($g.Name) { $g.Name } else { '(none)' }
            $topExt += [pscustomobject]@{ Extension=$ename; Count=$g.Count }
        }
        $snapshot.TopExtensions = $topExt

        # Size, lines, chars, last-modified
        [int64]$sumSize = 0; [int64]$sumChars = 0; [int64]$sumLines = 0
        $fileRows = New-Object System.Collections.Generic.List[object]
        $rootResolved = $RootPath
        try { $rootResolved = (Resolve-Path -LiteralPath $RootPath -ErrorAction Stop).Path } catch {}
        $lastMod = $null
    $processed = 0
    $totalFiles = [math]::Max(1, $files.Count)
    $procProgressId = 43
    # spinner + throttle for file processing progress
    $procSpinChars = @('|','/','-','\')
    $procSpinIdx = 0
    $procThrottleMs = 150
    $lastProcTick = [Environment]::TickCount
    if (-not $Quiet) { try { Write-Progress -Id $procProgressId -Activity "Analyzing files |" -Status "Measuring text files..." -PercentComplete 0 } catch {} }
    foreach ($f in $files) {
            try { $sumSize += [int64]$f.Length } catch {}
            try { if ($null -eq $lastMod -or $f.LastWriteTime -gt $lastMod) { $lastMod = $f.LastWriteTime } } catch {}
            # Text metrics for non-binary only
            $isBin = $false
            try { $isBin = Test-FSIsBinaryFile -FullPath $f.FullName } catch { $isBin = $true }
            if (-not $isBin) {
                $m = Measure-FSTextFile -FullPath $f.FullName
                if ($m -and $null -ne $m.Lines -and $null -ne $m.Chars) {
                    $sumLines += [int64]$m.Lines
                    $sumChars += [int64]$m.Chars
                    # Add per-file row for reporting
                    $rel = $f.FullName
                    try {
                        if ($rootResolved -and $f.FullName.StartsWith($rootResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
                            $rel = $f.FullName.Substring($rootResolved.Length).TrimStart('\\','/')
                        }
                    } catch {}
                    $fileRows.Add([pscustomobject]@{
                        Path = $f.FullName
                        RelativePath = $rel
                        Name = $f.Name
                        SizeBytes = [int64]$f.Length
                        Lines = [int64]$m.Lines
                        Chars = [int64]$m.Chars
                        LastWriteTime = $f.LastWriteTime
                    }) | Out-Null
                }
            }
            $processed++
            if (-not $Quiet) {
                $pct = [int][math]::Min(100, [math]::Round(($processed / $totalFiles) * 100))
                $nowTick = [Environment]::TickCount
                if ((($nowTick - $lastProcTick) -ge $procThrottleMs) -or ($processed -eq $totalFiles) -or ($processed % 20 -eq 0)) {
                    $spin = $procSpinChars[$procSpinIdx % $procSpinChars.Length]
                    $procSpinIdx++
                    try { Write-Progress -Id $procProgressId -Activity ("Analyzing files {0}" -f $spin) -Status ("Processed {0}/{1} files" -f $processed, $totalFiles) -PercentComplete $pct } catch {}
                    $lastProcTick = $nowTick
                }
            }
        }
        if (-not $Quiet) { try { Write-Progress -Id $procProgressId -Activity "Analyzing files" -Completed } catch {} }
        if (-not $Quiet) { try { Write-Progress -Id $scanProgressId -Activity "Scanning directories" -Completed } catch {} }
        $snapshot.SumSizeBytes = $sumSize
        $snapshot.SumChars = $sumChars
        $snapshot.SumLines = $sumLines
        $snapshot.LastModified = $lastMod
        $snapshot.Files = $fileRows
    } catch {
        Write-Log "Filesystem snapshot failed: $($_.Exception.Message)" "WARN"
    }

    return [pscustomobject]$snapshot
}
function Get-ProductivityData {
    param($DateRange, [string]$RepoPath, [string]$GitRef = 'HEAD', [switch]$AllBranches)

    $WorkspaceRoot = Split-Path $PSScriptRoot -Parent
    $LogsPath = "$WorkspaceRoot\logs"

    $Data = @{
        RepoPath = $RepoPath
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
    $GitStatistics = Get-GitCodeStatistics -DateRange $DateRange -RepoPath $RepoPath -GitRef $GitRef -AllBranches:$AllBranches
        $Data.Git = $GitStatistics

        # Build alternative effort estimate set (Educational/Benchmark-based)
        # Basis: (LinesAdded x 1) + (LinesModified x 0.5) - (LinesRemoved x 0.5)
        $linesBasisRaw = [double]$GitStatistics.LinesAdded + (0.5 * [double]$GitStatistics.LinesModified) - (0.5 * [double]$GitStatistics.LinesRemoved)
        if ($linesBasisRaw -lt 0) { $linesBasisRaw = 0 }
        $linesBasis = [int][Math]::Round($linesBasisRaw, 0)
        # Load optional external factors config
        $items = $null
        if ($FactorsConfig -and (Test-Path -LiteralPath $FactorsConfig)) {
            try {
                $cfg = Get-Content -LiteralPath $FactorsConfig -Raw | ConvertFrom-Json -ErrorAction Stop
                if ($cfg -and $cfg.Items) {
                    $valid = @()
                    foreach ($row in @($cfg.Items)) {
                        if ($row.Label -and $null -ne $row.Factor) {
                            $h = [double]([double]$linesBasis * [double]$row.Factor)
                            $valid += [pscustomobject]@{
                                Key = ($row.Key ? $row.Key : ([guid]::NewGuid().ToString()))
                                Label = [string]$row.Label
                                Factor = [double]$row.Factor
                                Hours = [Math]::Round($h,1)
                                Links = @($row.Links)
                                Description = $row.Description
                            }
                        }
                    }
                    if ($valid.Count -gt 0) { $items = $valid }
                }
            } catch { Write-Log "Failed to load factors config: $($_.Exception.Message)" "WARN" }
        }
        if (-not $items) { $items = @(
            [pscustomobject]@{
                Key='Federal_VA_PP_Dev'; Label='Federal Government VA Power Platform Developer'; Factor=0.5; Hours=[Math]::Round(($linesBasis * 0.5),1); Links=@('https://www.gao.gov/products/gao-23-104779','https://stackoverflow.com/questions/73713134/powerapps-gov-cloud-limitations');
                Description=@'
<div><strong>Definition:</strong> Developer working in U.S. Federal enterprise environments (e.g., VA), subject to strict compliance, security, and licensing restrictions.<br>
<strong>Sources:</strong> <a href="https://www.gao.gov/products/gao-23-104779" target="_blank" rel="noopener">GAO: VA Modernization</a>, <a href="https://stackoverflow.com/questions/73713134/powerapps-gov-cloud-limitations" target="_blank" rel="noopener">PowerApps Gov Cloud limitations</a>.<br>
<strong>Notes:</strong> Productivity lowered by restricted connectors, limited installs, tighter security, added compliance/auditing. True LOC/hr can be very low due to review and documentation overhead.</div>
'@
            },
            [pscustomobject]@{
                Key='Traditional_Dev'; Label='Traditional Developer (COCOMO)'; Factor=0.1; Hours=[Math]::Round(($linesBasis * 0.1),1); Links=@('https://en.wikipedia.org/wiki/COCOMO','http://csse.usc.edu/tools/COCOMO.htm','https://www.goodreads.com/book/show/4845.Code_Complete','https://stackoverflow.com/questions/258927/how-many-lines-of-code-per-day-is-reasonable-for-a-programmer');
                Description=@'
<div><strong>Definition:</strong> Programmers using general-purpose languages (Java, C#, Python, JS) on typical software projects.<br>
<strong>Source:</strong> The <a href="https://en.wikipedia.org/wiki/COCOMO" target="_blank" rel="noopener">COCOMO</a> model correlates KLOC to person-months. See <a href="http://csse.usc.edu/tools/COCOMO.htm" target="_blank" rel="noopener">USC COCOMO</a> and McConnell’s <a href="https://www.goodreads.com/book/show/4845.Code_Complete" target="_blank" rel="noopener">Code Complete</a>. Community data discusses <a href="https://stackoverflow.com/questions/258927/how-many-lines-of-code-per-day-is-reasonable-for-a-programmer" target="_blank" rel="noopener">reasonable LOC/day</a>.<br>
<strong>Notes:</strong> Includes design, testing, debugging, docs, meetings. Complex enterprise work trends toward 8 LOC/hr; simple CRUD may be higher.</div>
'@
            },
            [pscustomobject]@{
                Key='Regular_PP_Dev'; Label='Regular Power Platform Developer'; Factor=0.25; Hours=[Math]::Round(($linesBasis * 0.25),1); Links=@('https://learn.microsoft.com/en-us/power-platform/','https://www.linkedin.com/pulse/powerapps-low-code-high-impact-victor-ma/');
                Description=@'
<div><strong>Definition:</strong> Solo developer in a large organization building apps/flows in low-code tools.<br>
<strong>Sources:</strong> <a href="https://learn.microsoft.com/en-us/power-platform/" target="_blank" rel="noopener">Microsoft Power Platform docs</a>, community case studies.<br>
<strong>Notes:</strong> “Line” ≈ formula/property/control configuration. One formula can encapsulate significant logic; volume of lines is lower but effort per line is higher.</div>
'@
            },
            [pscustomobject]@{
                Key='Advanced_Low_Complexity_PP_Dev'; Label='Advanced Low Complexity Power Platform Developer'; Factor=0.15; Hours=[Math]::Round(($linesBasis * 0.15),1); Links=@('https://www.gartner.com/en/information-technology/glossary/low-code-application-platform-lcap','https://powerusers.microsoft.com/');
                Description=@'
<div><strong>Definition:</strong> Experienced Power Platform developer (certified), working solo on low-complexity solutions.<br>
<strong>Sources:</strong> <a href="https://www.gartner.com/en/information-technology/glossary/low-code-application-platform-lcap" target="_blank" rel="noopener">Gartner on low-code</a>, <a href="https://powerusers.microsoft.com/" target="_blank" rel="noopener">community forums</a>.<br>
<strong>Notes:</strong> Faster execution on familiar patterns; lower coordination overhead.</div>
'@
            },
            [pscustomobject]@{
                Key='Advanced_High_Complexity_PP_Dev'; Label='Advanced High Complexity Power Platform Developer'; Factor=0.33; Hours=[Math]::Round(($linesBasis * 0.33),1); Links=@('https://powerusers.microsoft.com/');
                Description=@'
<div><strong>Definition:</strong> Experienced developer handling sensitive domains, custom dependencies, and complex logic.<br>
<strong>Source:</strong> <a href="https://powerusers.microsoft.com/" target="_blank" rel="noopener">community experience</a>.<br>
<strong>Notes:</strong> Higher integration/testing burden; more design and documentation time per “line”.</div>
'@
            },
            [pscustomobject]@{
                Key='Vibe_Coder_Copilot'; Label='Vibe Coder Using Copilot Agent'; Factor=0.02; Hours=[Math]::Round(($linesBasis * 0.02),1); Links=@('https://github.blog/2023-03-15-the-impact-of-github-copilot-on-developer-productivity/','https://research.github.com/research/copilot-developer-productivity/','https://www.microsoft.com/en-us/research/publication/measuring-productivity-of-ai-assisted-software-development/');
                Description=@'
<div><strong>Definition:</strong> Developer leveraging AI assistants (e.g., GitHub Copilot) for code, scripts, and docs.<br>
<strong>Sources:</strong> <a href="https://github.blog/2023-03-15-the-impact-of-github-copilot-on-developer-productivity/" target="_blank" rel="noopener">GitHub Blog</a>, <a href="https://research.github.com/research/copilot-developer-productivity/" target="_blank" rel="noopener">research</a>, <a href="https://www.microsoft.com/en-us/research/publication/measuring-productivity-of-ai-assisted-software-development/" target="_blank" rel="noopener">Microsoft studies</a>.<br>
<strong>Notes:</strong> High generation speed but requires review/integration/testing; benefits strongest for boilerplate and patterns.</div>
'@
            },
            [pscustomobject]@{
                Key='Regular_Java_Python_Fed'; Label='Regular Java/Python Developer in Federal Environment'; Factor=0.2; Hours=[Math]::Round(($linesBasis * 0.2),1); Links=@('https://www.gao.gov/assets/gao-16-468.pdf');
                Description=@'
<div><strong>Definition:</strong> Traditional language developer operating under federal restrictions (no premium connectors/admin rights; heavy compliance).<br>
<strong>Source:</strong> <a href="https://www.gao.gov/assets/gao-16-468.pdf" target="_blank" rel="noopener">GAO: Federal software challenges</a>.<br>
<strong>Notes:</strong> Lower productivity from access limits, workarounds, and compliance overhead.</div>
'@
            },
            [pscustomobject]@{
                Key='PP_Hobbyist'; Label='Power Platform Hobbyist'; Factor=1.0; Hours=[Math]::Round(($linesBasis * 1.0),1); Links=@('https://powerusers.microsoft.com/','https://news.ycombinator.com/item?id=24008194');
                Description=@'
<div><strong>Definition:</strong> Non-programmer learning Power Platform ad hoc.<br>
<strong>Sources:</strong> <a href="https://powerusers.microsoft.com/" target="_blank" rel="noopener">community forums</a>, community anecdotes.<br>
<strong>Notes:</strong> Slow progress with trial-and-error; each “line” may take hours of discovery and testing.</div>
'@
            }
    ) }

        $Data.Git.AlternativeEffort = [ordered]@{
            LinesBasis = $linesBasis
            BasisLabel = 'Lines Added + 0.5 × Lines Modified − 0.5 × Lines Removed (selected period)'
            Items      = $items
        }
    } catch {
        Write-Log "Error analyzing Git statistics: $($_.Exception.Message)" "WARN"
    }

    # Filesystem snapshot (repo root)
    try {
        if ($RepoPath -and (Test-Path -LiteralPath $RepoPath -PathType Container)) {
            Write-Log "Analyzing filesystem snapshot for: $RepoPath" "INFO"
            $fs = Get-FilesystemSnapshot -RootPath $RepoPath -ExcludeGit:(!$FSIncludeGit) -ExcludeCompressed:(!$FSIncludeCompressed) -ExcludeArchiveOrTemp:(!$FSIncludeArchiveTemp)
            $Data.Filesystem = $fs
        }
    } catch {
        Write-Log "Filesystem snapshot failed: $($_.Exception.Message)" "WARN"
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
    $Report += "   **Report Period:** $($DateRange.Start.ToString('MMMM dd, yyyy')) - $($DateRange.End.ToString('MMMM dd, yyyy'))`n"
    $Report += "   **Report Generated:** $(Get-Date -Format 'MMMM dd, yyyy HH:mm:ss')`n"
    $Report += "   **Author:** Kyle J. Coder`n"
    $Report += "   **Team:** Clinical Informatics & Advanced Analytics`n"
    $Report += "   **Facility:** Edward Hines Jr. VA Hospital`n`n"
    $Report += "---`n`n"

    # Executive Summary
    $Report += "## Executive Summary`n`n"

    # Code Development Statistics
    $Report += " ### Code Development Statistics`n"
    $Report += "   - **Git Commits:** $($Data.Git.CommitCount)`n"
    # Display raw values to match GitHub commit UI; keep Modified as estimate
    $Report += "   - **Lines Added:** $($Data.Git.LinesAddedRaw)`n"
    $Report += "   - **Lines Removed:** $($Data.Git.LinesRemovedRaw)`n"
    $Report += "   - **Lines Modified (est.):** $($Data.Git.LinesModified)`n"
    $Report += "   - **Files Changed:** $($Data.Git.FilesChanged)`n"
    $WorkHours = [Math]::Round($Data.Git.EstimatedWorkMinutes / 60, 1)
    $Report += "   - **Estimated Work Time:** $($Data.Git.EstimatedWorkMinutes) minutes ($WorkHours hours)`n`n"

    # Git commit details if available
    if ($Data.Git.CommitCount -gt 0) {
        $Report += "## Code Development Details`n`n"
        $Report += " ### Git Commit Summary`n"
        $Report += "   **Total Commits:** $($Data.Git.CommitCount)`n"
    $Report += "   **Code Changes (raw):**`n"
    $Report += "      - Added: $($Data.Git.LinesAddedRaw) lines`n"
    $Report += "      - Removed: $($Data.Git.LinesRemovedRaw) lines`n"
    $Report += "      - Modified (est.): $($Data.Git.LinesModified) lines`n"
        $Report += "      - Files Affected: $($Data.Git.FilesChanged)`n`n"

        $Report += "### Work Effort Estimation`n"
        $Report += "   **Estimated Time Investment:** $($Data.Git.EstimatedWorkMinutes) minutes ($WorkHours hours)`n`n"
        $Report += "   *Estimation based on industry standards adjusted for VA/healthcare complexity*`n`n"

        # Recent commit details
        if ($IncludeDetailed -and $Data.Git.Commits.Count -gt 0) {
            $Report += "### Recent Commits`n"
            $RecentCommits = $Data.Git.Commits | Sort-Object Date -Descending | Select-Object -First $MaxCommits

            foreach ($Commit in $RecentCommits) {
                $ShortHash = $Commit.Hash.Substring(0, 7)
                $Report += "- **$($Commit.Date.ToString('MM/dd HH:mm'))** [$ShortHash] $($Commit.Message)`n"
            }

            if ($Data.Git.Commits.Count -gt $MaxCommits) {
                $Report += "- *...and $($Data.Git.Commits.Count - $MaxCommits) more commits*`n"
            }
        }

        $Report += "`n---`n`n"
    }

    # Productivity Metrics
    $Report += "## Productivity Metrics`n`n"
    $Report += "### Development Activity`n"
    $Report += "-    **Version Control Operations:** $($Data.Git.CommitCount) commits`n"
    $Report += "-    **Code Quality:** Structured commit messages and version tagging`n"
    $Report += "-    **Workspace Organization:** Proper Git workflow and documentation`n`n"

    # Filesystem Snapshot
    if ($null -ne $Data.Filesystem) {
        $fs = $Data.Filesystem
        $sizeMB = [Math]::Round(($fs.SumSizeBytes / 1MB), 2)
        $lm = if ($fs.LastModified) { $fs.LastModified.ToString('yyyy-MM-dd HH:mm:ss') } else { 'n/a' }
        $Report += "## Filesystem Snapshot`n`n"
        $Report += "-    **Root:** $($fs.Root)`n"
        $Report += "-    **Items:** $($fs.TotalItems) (Files=$($fs.TotalFiles), Folders=$($fs.TotalFolders), Shortcuts=$($fs.TotalShortcuts), ReparsePoints=$($fs.TotalReparse))`n"
        $Report += "-    **Text Lines (sum):** $($fs.SumLines)`n"
        $Report += "-    **Characters (sum):** $($fs.SumChars)`n"
        $Report += "-    **Size:** $sizeMB MB`n"
        $Report += "-    **Last Modified (latest file):** $lm`n"
    $Report += "-    **Filters:** ExcludeGit=$($fs.Filters.ExcludeGit), ExcludeCompressed=$($fs.Filters.ExcludeCompressed), ExcludeArchiveOrTemp=$($fs.Filters.ExcludeArchiveOrTemp)`n"
        if ($fs.TopExtensions -and $fs.TopExtensions.Count -gt 0) {
            $Report += "-    **Top Extensions:** `n"
            foreach ($e in $fs.TopExtensions) { $Report += "     - $($e.Extension): $($e.Count)`n" }
        }
        $Report += "`n"
    }

    $Report += "---`n`n"
    $Report += "   *Generated by VA Power Platform Workspace Template*`n"
    $Report += "   *Report ID: $(Get-Date -Format 'yyyyMMdd-HHmmss')*`n"

    return $Report
}

function Export-Report {
    param($Content, $Format, $OutputPath, $Data)

    switch ($Format) {
        "Markdown" {
            Set-Content -Path $OutputPath -Value $Content -Encoding UTF8
        }
        "HTML" {
                        # Build a rich, self-contained HTML report using $Data and metadata parsed from $Content
                        # Extract metadata from Markdown content for display
                        $period = ($Content | Select-String -SimpleMatch "**Report Period:**").ToString()
                        if ($period) { $period = $period -replace '\*\*Report Period:\*\*\s*', '' }
                        $generated = ($Content | Select-String -SimpleMatch "**Report Generated:**").ToString()
                        if ($generated) { $generated = $generated -replace '\*\*Report Generated:\*\*\s*', '' }
                        $author = ($Content | Select-String -SimpleMatch "**Author:**").ToString()
                        if ($author) { $author = $author -replace '\*\*Author:\*\*\s*', '' }
                        $team = ($Content | Select-String -SimpleMatch "**Team:**").ToString()
                        if ($team) { $team = $team -replace '\*\*Team:\*\*\s*', '' }
                        $facility = ($Content | Select-String -SimpleMatch "**Facility:**").ToString()
                        if ($facility) { $facility = $facility -replace '\*\*Facility:\*\*\s*', '' }

                        # Simple HTML encoding helper
                        $encode = {
                                param($s)
                                if ($null -eq $s) { return '' }
                                ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;')
                        }

            $workHours = [Math]::Round(($Data.Git.EstimatedWorkMinutes / 60), 1)
            $repoDisplay = if ($Data.RepoPath) { & $encode $Data.RepoPath } else { 'Current workspace' }
            # Build a clickable file link to open the actual repo root in Explorer
            $repoHref = $null
            if ($Data.RepoPath) {
                try {
                    $resolvedRepo = (Resolve-Path -LiteralPath $Data.RepoPath -ErrorAction Stop).Path
                    $repoHref = [System.Uri]::EscapeUriString(("file:///" + $resolvedRepo.Replace('\\','/')))
                } catch {}
            }
            if ($repoHref) {
                $repoAnchor = "<a href='{0}' target='_blank' rel='noopener'><code>{1}</code></a>" -f $repoHref, $repoDisplay
            } else {
                $repoAnchor = "<code>$repoDisplay</code>"
            }
                        $commitRows = ""
                        $recent = @()
            if ($Data.Git.Commits -and $Data.Git.Commits.Count -gt 0) {
                $recent = $Data.Git.Commits | Sort-Object Date -Descending | Select-Object -First $MaxCommits
                                foreach ($c in $recent) {
                                        $short = if ($c.Hash) { $c.Hash.Substring(0, [Math]::Min(7, $c.Hash.Length)) } else { '' }
                                        $msg = & $encode $c.Message
                                        $auth = & $encode $c.Author
                                        $date = if ($c.Date) { $c.Date.ToString('yyyy-MM-dd HH:mm') } else { '' }
                                        $commitRows += "<tr><td>$date</td><td><code>$short</code></td><td>$msg</td><td>$auth</td></tr>"
                                }
                        }

            # Delta chips if baseline provided
            $dc = $Data.Git.BaselineDelta
            function New-DeltaChip([int]$v) {
                if ($null -eq $v) { return '' }
                if ($v -gt 0) { return "<span class='delta-chip up'>▲ +$v</span>" }
                if ($v -lt 0) { return "<span class='delta-chip down'>▼ $v</span>" }
                return "<span class='delta-chip neutral'>= 0</span>"
            }
            $chipCommits = if ($dc) { New-DeltaChip $dc.CommitCount } else { '' }
            # Deltas for raw values when baseline present; fall back if missing
            $chipAdded = if ($dc -and $dc.PSObject.Properties.Match('LinesAddedRaw').Count -gt 0) { New-DeltaChip $dc.LinesAddedRaw } elseif ($dc) { New-DeltaChip $dc.LinesAdded } else { '' }
            $chipRemoved = if ($dc -and $dc.PSObject.Properties.Match('LinesRemovedRaw').Count -gt 0) { New-DeltaChip $dc.LinesRemovedRaw } elseif ($dc) { New-DeltaChip $dc.LinesRemoved } else { '' }
            $chipModified = if ($dc) { New-DeltaChip $dc.LinesModified } else { '' }
            $chipFiles = if ($dc) { New-DeltaChip $dc.FilesChanged } else { '' }
            $chipEffort = if ($dc) { New-DeltaChip ([int]$dc.EstimatedWorkMinutes) } else { '' }

        $kpiHtml = @"
                <div class="kpis">
                    <div class="kpi"><div class="kpi-label">Git Commits</div><div class="kpi-value">$($Data.Git.CommitCount) $chipCommits</div></div>
                    <div class="kpi"><div class="kpi-label">Lines Added (raw)</div><div class="kpi-value add">$($Data.Git.LinesAddedRaw) $chipAdded</div></div>
                    <div class="kpi"><div class="kpi-label">Lines Removed (raw)</div><div class="kpi-value remove">$($Data.Git.LinesRemovedRaw) $chipRemoved</div></div>
                    <div class="kpi"><div class="kpi-label">Lines Modified (est.)</div><div class="kpi-value mod">$($Data.Git.LinesModified) $chipModified</div></div>
                    <div class="kpi"><div class="kpi-label">Files Changed</div><div class="kpi-value">$($Data.Git.FilesChanged) $chipFiles</div></div>
                    <div class="kpi"><div class="kpi-label">Est. Work</div><div class="kpi-value">$($Data.Git.EstimatedWorkMinutes) min $chipEffort<br><span class="sub">($workHours h)</span></div></div>
                </div>

"@
            $fsSummaryHtml = ''
            if ($null -ne $Data.Filesystem) {
                $fs = $Data.Filesystem
                function _fmtBytes2([Nullable[int64]]$b) {
                    if ($null -eq $b) { return '0 B' }
                    $sizes = 'B','KB','MB','GB','TB'
                    $i=0; $val=[double]$b
                    while ($val -ge 1024 -and $i -lt $sizes.Length-1) { $val/=1024; $i++ }
                    return ('{0:N2} {1}' -f $val, $sizes[$i])
                }
                $sizeTxt2 = _fmtBytes2 $fs.SumSizeBytes
                $lmTxt2 = if ($fs.LastModified) { $fs.LastModified.ToString('yyyy-MM-dd HH:mm') } else { 'n/a' }
        $fsSummaryHtml = @"
                <div class="kpis" style="margin-top:8px;">
                    <div class="kpi"><div class="kpi-label">Root</div><div class="kpi-value" style="font-size:14px;">$repoAnchor</div></div>
                    <div class="kpi"><div class="kpi-label">Items</div><div class="kpi-value">$($fs.TotalItems)</div></div>
                    <div class="kpi"><div class="kpi-label">Text Lines (sum)</div><div class="kpi-value">$($fs.SumLines)</div></div>
                    <div class="kpi"><div class="kpi-label">Characters (sum)</div><div class="kpi-value">$($fs.SumChars)</div></div>
                    <div class="kpi"><div class="kpi-label">Total Size</div><div class="kpi-value">$sizeTxt2</div></div>
                    <div class="kpi"><div class="kpi-label">Last Modified</div><div class="kpi-value">$lmTxt2</div></div>
                </div>
"@

            } # end if ($null -ne $Data.Filesystem)

            $labels = New-Object System.Collections.Generic.List[string]
            $bars   = New-Object System.Collections.Generic.List[int]
            $trend  = New-Object System.Collections.Generic.List[int]
            $barLegend = 'Files changed'
            $tooltipBarLabel = 'Files changed'
            # Precompute a map of daily lines-basis for later alignment (used for commits-per-day fallback too)
        $dailyTrendMap = @{}
        $dailyTrendLabelMap = @{}
        if ($Data.Git.PSObject.Properties.Match('Daily').Count -gt 0 -and $Data.Git.Daily) {
                foreach ($d in $Data.Git.Daily) {
            $key = $d.Date.ToString('yyyy-MM-dd')
            # Balanced per-day basis to avoid over-cancellation
            $lbv = [int]([double]$d.LinesAdded + 0.5*[double]$d.LinesModified - 0.5*[double]$d.LinesRemoved)
                    if ($lbv -lt 0) { $lbv = 0 }
                    $dailyTrendMap[$key] = $lbv
            $dailyTrendLabelMap[$d.Date.ToString('MM/dd')] = $lbv
                }
            }
            if ($Data.Git.PSObject.Properties.Match('Daily').Count -gt 0 -and $Data.Git.Daily -and $Data.Git.Daily.Count -gt 0) {
                foreach ($d in $Data.Git.Daily) {
                    [void]$labels.Add($d.Date.ToString('MM/dd'))
                    [void]$bars.Add([int]$d.FilesChanged)
                    $lb = [int]([double]$d.LinesAdded + 0.5*[double]$d.LinesModified - 0.5*[double]$d.LinesRemoved)
                    if ($lb -lt 0) { $lb = 0 }
                    [void]$trend.Add($lb)
                }
                # If all daily bars are zero, treat as empty to trigger fallback below
                if ($bars.Count -gt 0 -and -not ($bars | Where-Object { $_ -gt 0 } | Select-Object -First 1)) {
                    $labels.Clear(); $bars.Clear(); $trend.Clear();
                }
            }
            # Fallback if no Daily bars: use commits-per-day so the chart never renders empty when commits exist
            if ($bars.Count -eq 0 -and $Data.Git.Commits -and $Data.Git.Commits.Count -gt 0) {
                $barLegend = 'Commits'
                $tooltipBarLabel = 'Commits'
                $grouped = $Data.Git.Commits | Group-Object { $_.Date.Date } | Sort-Object Name
                foreach ($g in $grouped) {
                    $d = [datetime]$g.Name
                    $labelStr = $d.ToString('MM/dd')
                    [void]$labels.Add($labelStr)
                    [void]$bars.Add([int]$g.Count)
                    # Prefer exact label match to avoid locale/timezone slippage
                    if ($dailyTrendLabelMap.ContainsKey($labelStr)) { [void]$trend.Add([int]$dailyTrendLabelMap[$labelStr]) }
                    else {
                        $k = $d.ToString('yyyy-MM-dd')
                        if ($dailyTrendMap.ContainsKey($k)) { [void]$trend.Add([int]$dailyTrendMap[$k]) } else { [void]$trend.Add(0) }
                    }
                }
                # If the trend is still all zeros but we have Daily data, try a label-based fill
                if (($trend | Where-Object { $_ -gt 0 } | Measure-Object).Count -eq 0 -and $Data.Git.Daily -and $Data.Git.Daily.Count -gt 0) {
                    $labelFill = @{}
                    foreach ($dly in $Data.Git.Daily) {
                        $ls = $dly.Date.ToString('MM/dd')
                        $lb2 = [int]([double]$dly.LinesAdded + 0.5*[double]$dly.LinesModified - 0.5*[double]$dly.LinesRemoved)
                        if ($lb2 -lt 0) { $lb2 = 0 }
                        $labelFill[$ls] = $lb2
                    }
                    for ($i=0; $i -lt $labels.Count; $i++) {
                        if ($trend[$i] -eq 0 -and $labelFill.ContainsKey($labels[$i])) { $trend[$i] = [int]$labelFill[$labels[$i]] }
                    }
                }
                # If trend is all zeros, it will auto-hide in JS
            }
            # Important: Convert generic Lists to arrays before JSON to ensure JSON arrays (not objects)
            $labelsJson = ($labels.ToArray() | ConvertTo-Json -Compress)
            $barsJson = ($bars.ToArray() | ConvertTo-Json -Compress)
            $trendJson = ($trend.ToArray() | ConvertTo-Json -Compress)
            # Safety: never allow empty JS initializers which cause syntax errors
            if ([string]::IsNullOrWhiteSpace($labelsJson)) { $labelsJson = '[]' }
            if ([string]::IsNullOrWhiteSpace($barsJson))   { $barsJson   = '[]' }
            if ([string]::IsNullOrWhiteSpace($trendJson))  { $trendJson  = '[]' }

            # Build filesystem activity arrays (daily): bars = files modified per day; trend = sum of lines for those files
            $fsLabelsJson = '[]'; $fsBarsJson = '[]'; $fsTrendJson = '[]'
            try {
                if ($Data.Filesystem -and $Data.Filesystem.Files -and $Data.Filesystem.Files.Count -gt 0) {
                    $fsGroups = $Data.Filesystem.Files |
                        Where-Object { $_.LastWriteTime } |
                        Group-Object { $_.LastWriteTime.Date } |
                        Sort-Object { try { [datetime]$_.Name } catch { Get-Date 0 } }
                    $fsLabels = New-Object System.Collections.Generic.List[string]
                    $fsBars = New-Object System.Collections.Generic.List[int]
                    $fsTrend = New-Object System.Collections.Generic.List[int]
                    foreach ($g in $fsGroups) {
                        try { $d = [datetime]$g.Name } catch { $d = $null }
                        $labelStr = if ($d) { $d.ToString('MM/dd') } else { '' }
                        if (-not [string]::IsNullOrWhiteSpace($labelStr)) { [void]$fsLabels.Add($labelStr) } else { [void]$fsLabels.Add('') }
                        [void]$fsBars.Add([int]$g.Count)
                        $sumLinesDay = 0
                        try { $sumLinesDay = [int]([long]((($g.Group | Measure-Object -Property Lines -Sum).Sum) -as [long])) } catch {}
                        if ($sumLinesDay -lt 0) { $sumLinesDay = 0 }
                        [void]$fsTrend.Add([int]$sumLinesDay)
                    }
                    $fsLabelsJson = ($fsLabels.ToArray() | ConvertTo-Json -Compress)
                    $fsBarsJson = ($fsBars.ToArray() | ConvertTo-Json -Compress)
                    $fsTrendJson = ($fsTrend.ToArray() | ConvertTo-Json -Compress)
                    if ([string]::IsNullOrWhiteSpace($fsLabelsJson)) { $fsLabelsJson = '[]' }
                    if ([string]::IsNullOrWhiteSpace($fsBarsJson))   { $fsBarsJson   = '[]' }
                    if ([string]::IsNullOrWhiteSpace($fsTrendJson))  { $fsTrendJson  = '[]' }
                }
            } catch {}

            $chartSection = @"
            <section data-view="git">
                <h2>Activity Trend</h2>
                <div class="chart-card">
                    <canvas id="trend" height="160" style="display:block; width:100%; min-height:160px;"></canvas>
                    <div class="chart-legend" style="display:flex;justify-content:space-between;align-items:center;margin-top:8px;gap:8px;flex-wrap:wrap;">
                        <div style="display:flex;gap:12px;align-items:center;">
                            <span class="legend-item" style="display:inline-flex;align-items:center;gap:6px;color:var(--muted);"><span class="swatch" style="width:10px;height:10px;border-radius:2px;background:linear-gradient(180deg, var(--accent), var(--brand2));display:inline-block;"></span> $barLegend</span>
                            <span id="legend-trend" class="legend-item" style="display:inline-flex;align-items:center;gap:6px;color:var(--muted);"><span class="swatch" style="width:16px;height:2px;background:#f59e0b;display:inline-block;"></span> Lines basis</span>
                        </div>
                        <div class="legend-metrics" style="display:flex;gap:10px;color:var(--muted);font-size:12px;">
                            <span id="metric-total"></span>
                            <span id="metric-avg"></span>
                            <span id="metric-max"></span>
                        </div>
                    </div>
                    <div class="muted" style="font-size:12px;margin-top:6px;">Hover bars to see period details</div>
                </div>
                <script>
                (function(){
                    var labels = $labelsJson;
                    var bars = $barsJson;
                    var trend = $trendJson;
                    var tooltipBarLabel = '$tooltipBarLabel';
                    // Coerce possible JSON strings to arrays
                    try { if (typeof labels === 'string') labels = JSON.parse(labels); } catch(e) {}
                    try { if (typeof bars === 'string') bars = JSON.parse(bars); } catch(e) {}
                    try { if (typeof trend === 'string') trend = JSON.parse(trend); } catch(e) {}
                    labels = Array.isArray(labels) ? labels : [];
                    bars = Array.isArray(bars) ? bars : [];
                    trend = Array.isArray(trend) ? trend : [];
                    var c = document.getElementById('trend');
                    var noData = !bars || bars.length===0;
                    if (!c) { return; }
                    var ctx = c.getContext('2d');

                    // Metrics (numeric)
                    var total = 0, max = 0, maxIdx = 0;
                    for (var i=0;i<(bars?bars.length:0);i++){
                        var v = Number(bars[i]) || 0;
                        total += v;
                        if (v > max){ max = v; maxIdx = i; }
                    }
                    var avg = (!noData && bars.length) ? (total / bars.length) : 0;
                    var elTotal = document.getElementById('metric-total'); if (elTotal) elTotal.textContent = noData ? 'No activity' : ('Total: ' + total);
                    var elAvg = document.getElementById('metric-avg'); if (elAvg) elAvg.textContent = noData ? '' : ('Avg: ' + (Math.round(avg*10)/10));
                    var elMax = document.getElementById('metric-max'); if (elMax) elMax.textContent = (!noData && bars.length) ? ('Max: ' + max + ' (' + labels[maxIdx] + ')') : '';
                    var hasTrend = Array.isArray(trend) && trend.length === bars.length && trend.some(function(v){ return v>0; });
                    if (!hasTrend) {
                        var lt = document.getElementById('legend-trend');
                        if (lt) lt.style.display = 'none';
                    }

                    var dpr = window.devicePixelRatio || 1;
                    var pad = 28;
                    var hoverIdx = -1;

                    function sizeCanvas(){
                        var parent = c.parentElement;
                        // Prefer parent container width to avoid 0px rect before layout
                        var cssW = (parent && parent.clientWidth ? parent.clientWidth : (c.clientWidth || 600));
                        var cssH = parseInt(getComputedStyle(c).height) || c.clientHeight || 140;
                        // ensure CSS size is set for proper clientWidth/clientHeight
                        c.style.width = '100%';
                        if (!c.style.height) { c.style.height = cssH + 'px'; }
                        // set backing store size to match computed CSS width
                        c.width = Math.max(1, Math.floor(cssW * dpr));
                        c.height = Math.max(1, Math.floor(cssH * dpr));
                        ctx.setTransform(dpr,0,0,dpr,0,0);
                    }

                    function barColor(value){
                        var t = max === 0 ? 0 : (value / max);
                        // Interpolate between brand2 and accent (simple mix)
                        var c1 = [45,114,163];  // #2d72a3
                        var c2 = [62,140,199];  // #3e8cc7
                        var r = Math.round(c1[0] + (c2[0]-c1[0])*t);
                        var g = Math.round(c1[1] + (c2[1]-c1[1])*t);
                        var b = Math.round(c1[2] + (c2[2]-c1[2])*t);
                        return 'rgb(' + r + ',' + g + ',' + b + ')';
                    }

                    function draw(){
                        sizeCanvas();
                        var w = (c.parentElement && c.parentElement.clientWidth) ? c.parentElement.clientWidth : (c.clientWidth || 600);
                        var h = (parseInt(getComputedStyle(c).height) || c.clientHeight || 160);
                        if (w < 20 || h < 20) {
                            // if layout not ready, retry shortly
                            setTimeout(function(){ try{ draw(); }catch(_){} }, 30);
                            return;
                        }
                        ctx.clearRect(0,0,w,h);
                        var innerW = w - pad*2, innerH = h - pad*2;
                        innerW = Math.max(1, innerW);
                        innerH = Math.max(1, innerH);
                        var step = noData ? 1 : (innerW / Math.max(1, bars.length));
                        var barW = noData ? 0 : Math.max(2, Math.min(18, step * 0.66));

                        // Gridlines / or empty placeholder
                        ctx.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue('--border') || '#e5e7eb';
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        for (var g=0; g<=4; g++) {
                            var gy = h - pad - (innerH * (g/4));
                            ctx.moveTo(pad, gy + 0.5);
                            ctx.lineTo(w - pad, gy + 0.5);
                        }
                        ctx.stroke();

                        if (noData) {
                            // Show friendly empty state
                            var msg = 'No activity in selected period';
                            ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--muted') || '#6b7280';
                            ctx.font = '14px Segoe UI, Arial, sans-serif';
                            ctx.textAlign = 'center';
                            ctx.fillText(msg, w/2, h/2);
                            return;
                        }

                        // Bars
                        for (var i=0;i<bars.length;i++){
                            var x = pad + i*step + (step - barW)/2;
                            var bv = Number(bars[i]) || 0;
                            var barH = max===0 ? 0 : (bv/max) * innerH;
                            var y = h - pad - barH;
                            var r = Math.min(6, barW/2); // rounded corners
                            ctx.fillStyle = barColor(bv);
                            if (i === hoverIdx) {
                                ctx.fillStyle = '#1f5582';
                            }
                            // Rounded rect draw
                            var rx = x, ry = y, rw = barW, rh = barH;
                            ctx.beginPath();
                            ctx.moveTo(rx, ry + r);
                            ctx.arcTo(rx, ry, rx + r, ry, r);
                            ctx.lineTo(rx + rw - r, ry);
                            ctx.arcTo(rx + rw, ry, rx + rw, ry + r, r);
                            ctx.lineTo(rx + rw, ry + rh);
                            ctx.lineTo(rx, ry + rh);
                            ctx.closePath();
                            ctx.fill();
                        }

                        // Trend line (lines basis)
                        if (hasTrend) {
                            ctx.strokeStyle = '#f59e0b';
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            var tmax = 0; for (var i=0;i<trend.length;i++){ if (trend[i]>tmax) tmax = trend[i]; }
                            for (var i=0;i<trend.length;i++){
                                var cx = pad + i*step + step/2;
                                var cy = h - pad - (tmax===0 ? 0 : (trend[i]/tmax) * innerH);
                                if (i===0) ctx.moveTo(cx, cy); else ctx.lineTo(cx, cy);
                            }
                            ctx.stroke();
                        }

                        // Range label
                        ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--muted') || '#6b7280';
                        ctx.font = '12px Segoe UI, Arial, sans-serif';
                        var rangeText = labels.length ? (labels[0] + ' – ' + labels[labels.length-1]) : '';
                        ctx.textAlign = 'right';
                        ctx.fillText(rangeText, w - 8, pad - 10);

                        // Tooltip on hover
                        if (hoverIdx >= 0) {
                            var cx = pad + hoverIdx*step + step/2;
                            var hv = Number(bars[hoverIdx]) || 0;
                            var cy = h - pad - (max===0 ? 0 : (hv/max) * innerH);
                            // Guide line
                            ctx.strokeStyle = 'rgba(31,85,130,0.4)';
                            ctx.lineWidth = 1;
                            ctx.beginPath();
                            ctx.moveTo(cx + 0.5, pad);
                            ctx.lineTo(cx + 0.5, h - pad);
                            ctx.stroke();

                            // Tooltip box
                            var text1 = labels[hoverIdx];
                            var text2 = tooltipBarLabel + ': ' + hv;
                            var text3 = hasTrend ? ('Lines basis: ' + (trend[hoverIdx] || 0)) : '';
                            ctx.font = '12px Segoe UI, Arial, sans-serif';
                            var tw = Math.max(ctx.measureText(text1).width, ctx.measureText(text2).width, hasTrend?ctx.measureText(text3).width:0) + 16;
                            var th = hasTrend ? 52 : 36;
                            var tx = Math.min(Math.max(8, cx - tw/2), w - tw - 8);
                            var ty = Math.max(pad + 8, cy - th - 8);
                            ctx.fillStyle = 'rgba(15,23,42,0.9)';
                            var isDark = matchMedia('(prefers-color-scheme: dark)').matches;
                            if (!isDark) ctx.fillStyle = 'rgba(255,255,255,0.95)';
                            // Shadow
                            ctx.save();
                            ctx.shadowColor = 'rgba(0,0,0,0.15)';
                            ctx.shadowBlur = 6; ctx.shadowOffsetY = 2;
                            ctx.fillRect(tx, ty, tw, th);
                            ctx.restore();
                            ctx.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue('--border') || '#e5e7eb';
                            ctx.strokeRect(tx + 0.5, ty + 0.5, tw - 1, th - 1);
                            ctx.fillStyle = isDark ? '#e5e7eb' : '#1f2937';
                            ctx.textAlign = 'left';
                            ctx.fillText(text1, tx + 8, ty + 14);
                            ctx.fillText(text2, tx + 8, ty + 28);
                            if (hasTrend) ctx.fillText(text3, tx + 8, ty + 42);
                        }
                    }

                    function locateIndex(evt){
                        var rect = c.getBoundingClientRect();
                        var x = (evt.clientX - rect.left);
                        var w = c.clientWidth || 600;
                        var innerW = w - pad*2;
                        var step = innerW / (noData ? 1 : bars.length);
                        var rel = Math.max(0, Math.min(innerW, x - pad));
                        var idx = noData ? -1 : Math.floor(rel / step);
                        if (!noData && (idx < 0 || idx >= bars.length)) idx = -1;
                        return idx;
                    }

                    c.addEventListener('mousemove', function(e){ hoverIdx = locateIndex(e); try{ draw(); }catch(_){} });
                    c.addEventListener('mouseleave', function(){ hoverIdx = -1; try{ draw(); }catch(_){} });
                    window.addEventListener('resize', function(){ try{ draw(); }catch(_){} });
                    // Redraw when the container resizes
                    try {
                        if (window.ResizeObserver) {
                            var ro = new ResizeObserver(function(){ try{ draw(); }catch(_e){} });
                            ro.observe(c.parentElement || c);
                        }
                    } catch(_){}
                    try { requestAnimationFrame(function(){ try{ draw(); }catch(_e){} }); } catch(_) { try { draw(); } catch(e) {
                        // show a small message if drawing fails for any reason
                        try {
                            ctx.setTransform(1,0,0,1,0,0);
                            ctx.fillStyle = '#ef4444';
                            ctx.font = '12px Segoe UI, Arial, sans-serif';
                            ctx.fillText('Chart render error: ' + (e && e.message ? e.message : e), 8, 18);
                        } catch {}
                    }}
                })();
                </script>
            </section>
"@

            # Filesystem Activity Trend chart
            $fsChartSection = @"
            <section data-view="fs">
                <h2>Filesystem Activity Trend</h2>
                <div class="chart-card">
                    <canvas id="trend-fs" height="160" style="display:block; width:100%; min-height:160px;"></canvas>
                    <div class="chart-legend" style="display:flex;justify-content:space-between;align-items:center;margin-top:8px;gap:8px;flex-wrap:wrap;">
                        <div style="display:flex;gap:12px;align-items:center;">
                            <span class="legend-item" style="display:inline-flex;align-items:center;gap:6px;color:var(--muted);"><span class="swatch" style="width:10px;height:10px;border-radius:2px;background:linear-gradient(180deg, var(--accent), var(--brand2));display:inline-block;"></span> Files modified</span>
                            <span id="legend-trend-fs" class="legend-item" style="display:inline-flex;align-items:center;gap:6px;color:var(--muted);"><span class="swatch" style="width:16px;height:2px;background:#f59e0b;display:inline-block;"></span> Lines (sum)</span>
                        </div>
                        <div class="legend-metrics" style="display:flex;gap:10px;color:var(--muted);font-size:12px;">
                            <span id="metric-total-fs"></span>
                            <span id="metric-avg-fs"></span>
                            <span id="metric-max-fs"></span>
                        </div>
                    </div>
                    <div class="muted" style="font-size:12px;margin-top:6px;">Hover bars to see period details</div>
                </div>
                <script>
                (function(){
                    var labels = $fsLabelsJson;
                    var bars = $fsBarsJson;
                    var trend = $fsTrendJson;
                    var tooltipBarLabel = 'Files modified';
                    try { if (typeof labels === 'string') labels = JSON.parse(labels); } catch(e) {}
                    try { if (typeof bars === 'string') bars = JSON.parse(bars); } catch(e) {}
                    try { if (typeof trend === 'string') trend = JSON.parse(trend); } catch(e) {}
                    labels = Array.isArray(labels) ? labels : [];
                    bars = Array.isArray(bars) ? bars : [];
                    trend = Array.isArray(trend) ? trend : [];
                    var c = document.getElementById('trend-fs');
                    var noData = !bars || bars.length===0;
                    if (!c) { return; }
                    var ctx = c.getContext('2d');
                    var total = 0, max = 0, maxIdx = 0;
                    for (var i=0;i<(bars?bars.length:0);i++){
                        var v = Number(bars[i]) || 0;
                        total += v;
                        if (v > max){ max = v; maxIdx = i; }
                    }
                    var avg = (!noData && bars.length) ? (total / bars.length) : 0;
                    var elTotal = document.getElementById('metric-total-fs'); if (elTotal) elTotal.textContent = noData ? 'No activity' : ('Total: ' + total);
                    var elAvg = document.getElementById('metric-avg-fs'); if (elAvg) elAvg.textContent = noData ? '' : ('Avg: ' + (Math.round(avg*10)/10));
                    var elMax = document.getElementById('metric-max-fs'); if (elMax) elMax.textContent = (!noData && bars.length) ? ('Max: ' + max + ' (' + labels[maxIdx] + ')') : '';
                    var hasTrend = Array.isArray(trend) && trend.length === bars.length && trend.some(function(v){ return v>0; });
                    if (!hasTrend) {
                        var lt = document.getElementById('legend-trend-fs');
                        if (lt) lt.style.display = 'none';
                    }
                    var dpr = window.devicePixelRatio || 1;
                    var pad = 28;
                    var hoverIdx = -1;
                    function sizeCanvas(){
                        var parent = c.parentElement;
                        var cssW = (parent && parent.clientWidth ? parent.clientWidth : (c.clientWidth || 600));
                        var cssH = parseInt(getComputedStyle(c).height) || c.clientHeight || 140;
                        c.style.width = '100%';
                        if (!c.style.height) { c.style.height = cssH + 'px'; }
                        c.width = Math.max(1, Math.floor(cssW * dpr));
                        c.height = Math.max(1, Math.floor(cssH * dpr));
                        ctx.setTransform(dpr,0,0,dpr,0,0);
                    }
                    function barColor(value){
                        var t = max === 0 ? 0 : (value / max);
                        var c1 = [45,114,163];
                        var c2 = [62,140,199];
                        var r = Math.round(c1[0] + (c2[0]-c1[0])*t);
                        var g = Math.round(c1[1] + (c2[1]-c1[1])*t);
                        var b = Math.round(c1[2] + (c2[2]-c1[2])*t);
                        return 'rgb(' + r + ',' + g + ',' + b + ')';
                    }
                    function draw(){
                        sizeCanvas();
                        var w = (c.parentElement && c.parentElement.clientWidth) ? c.parentElement.clientWidth : (c.clientWidth || 600);
                        var h = (parseInt(getComputedStyle(c).height) || c.clientHeight || 160);
                        if (w < 20 || h < 20) { setTimeout(function(){ try{ draw(); }catch(_){} }, 30); return; }
                        ctx.clearRect(0,0,w,h);
                        var innerW = w - pad*2, innerH = h - pad*2;
                        innerW = Math.max(1, innerW);
                        innerH = Math.max(1, innerH);
                        var step = noData ? 1 : (innerW / Math.max(1, bars.length));
                        var barW = noData ? 0 : Math.max(2, Math.min(18, step * 0.66));
                        ctx.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue('--border') || '#e5e7eb';
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        for (var g=0; g<=4; g++) {
                            var gy = h - pad - (innerH * (g/4));
                            ctx.moveTo(pad, gy + 0.5);
                            ctx.lineTo(w - pad, gy + 0.5);
                        }
                        ctx.stroke();
                        if (noData) {
                            var msg = 'No activity in selected period';
                            ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--muted') || '#6b7280';
                            ctx.font = '14px Segoe UI, Arial, sans-serif';
                            ctx.textAlign = 'center';
                            ctx.fillText(msg, w/2, h/2);
                            return;
                        }
                        for (var i=0;i<bars.length;i++){
                            var x = pad + i*step + (step - barW)/2;
                            var bv = Number(bars[i]) || 0;
                            var barH = max===0 ? 0 : (bv/max) * innerH;
                            var y = h - pad - barH;
                            var r = Math.min(6, barW/2);
                            ctx.fillStyle = barColor(bv);
                            if (i === hoverIdx) { ctx.fillStyle = '#1f5582'; }
                            ctx.beginPath();
                            ctx.moveTo(x, y + r);
                            ctx.arcTo(x, y, x + r, y, r);
                            ctx.lineTo(x + barW - r, y);
                            ctx.arcTo(x + barW, y, x + barW, y + r, r);
                            ctx.lineTo(x + barW, y + barH);
                            ctx.lineTo(x, y + barH);
                            ctx.closePath();
                            ctx.fill();
                        }
                        if (hasTrend) {
                            ctx.strokeStyle = '#f59e0b';
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            var tmax = 0; for (var i=0;i<trend.length;i++){ if (trend[i]>tmax) tmax = trend[i]; }
                            for (var i=0;i<trend.length;i++){
                                var cx = pad + i*step + step/2;
                                var cy = h - pad - (tmax===0 ? 0 : (trend[i]/tmax) * innerH);
                                if (i===0) ctx.moveTo(cx, cy); else ctx.lineTo(cx, cy);
                            }
                            ctx.stroke();
                        }
                        ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--muted') || '#6b7280';
                        ctx.font = '12px Segoe UI, Arial, sans-serif';
                        var rangeText = labels.length ? (labels[0] + ' – ' + labels[labels.length-1]) : '';
                        ctx.textAlign = 'right';
                        ctx.fillText(rangeText, w - 8, pad - 10);
                        if (hoverIdx >= 0) {
                            var cx = pad + hoverIdx*step + step/2;
                            var hv = Number(bars[hoverIdx]) || 0;
                            var cy = h - pad - (max===0 ? 0 : (hv/max) * innerH);
                            ctx.strokeStyle = 'rgba(31,85,130,0.4)';
                            ctx.lineWidth = 1;
                            ctx.beginPath(); ctx.moveTo(cx + 0.5, pad); ctx.lineTo(cx + 0.5, h - pad); ctx.stroke();
                            var text1 = labels[hoverIdx];
                            var text2 = tooltipBarLabel + ': ' + hv;
                            var text3 = hasTrend ? ('Lines (sum): ' + (trend[hoverIdx] || 0)) : '';
                            ctx.font = '12px Segoe UI, Arial, sans-serif';
                            var tw = Math.max(ctx.measureText(text1).width, ctx.measureText(text2).width, hasTrend?ctx.measureText(text3).width:0) + 16;
                            var th = hasTrend ? 52 : 36;
                            var tx = Math.min(Math.max(8, cx - tw/2), w - tw - 8);
                            var ty = Math.max(pad + 8, cy - th - 8);
                            ctx.fillStyle = 'rgba(15,23,42,0.9)'; var isDark = matchMedia('(prefers-color-scheme: dark)').matches; if (!isDark) ctx.fillStyle = 'rgba(255,255,255,0.95)';
                            ctx.save(); ctx.shadowColor = 'rgba(0,0,0,0.15)'; ctx.shadowBlur = 6; ctx.shadowOffsetY = 2; ctx.fillRect(tx, ty, tw, th); ctx.restore();
                            ctx.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue('--border') || '#e5e7eb';
                            ctx.strokeRect(tx + 0.5, ty + 0.5, tw - 1, th - 1);
                            ctx.fillStyle = isDark ? '#e5e7eb' : '#1f2937';
                            ctx.textAlign = 'left';
                            ctx.fillText(text1, tx + 8, ty + 14);
                            ctx.fillText(text2, tx + 8, ty + 28);
                            if (hasTrend) ctx.fillText(text3, tx + 8, ty + 42);
                        }
                    }
                    function locateIndex(evt){
                        var rect = c.getBoundingClientRect();
                        var x = (evt.clientX - rect.left);
                        var w = c.clientWidth || 600;
                        var innerW = w - pad*2;
                        var step = innerW / (noData ? 1 : bars.length);
                        var rel = Math.max(0, Math.min(innerW, x - pad));
                        var idx = noData ? -1 : Math.floor(rel / step);
                        if (!noData && (idx < 0 || idx >= bars.length)) idx = -1;
                        return idx;
                    }
                    c.addEventListener('mousemove', function(e){ hoverIdx = locateIndex(e); try{ draw(); }catch(_){} });
                    c.addEventListener('mouseleave', function(){ hoverIdx = -1; try{ draw(); }catch(_){} });
                    window.addEventListener('resize', function(){ try{ draw(); }catch(_){} });
                    try { if (window.ResizeObserver) { var ro = new ResizeObserver(function(){ try{ draw(); }catch(_e){} }); ro.observe(c.parentElement || c); } } catch(_){ }
                    try { requestAnimationFrame(function(){ try{ draw(); }catch(_e){} }); } catch(_) { try { draw(); } catch(e) { try { ctx.setTransform(1,0,0,1,0,0); ctx.fillStyle = '#ef4444'; ctx.font = '12px Segoe UI, Arial, sans-serif'; ctx.fillText('Chart render error: ' + (e && e.message ? e.message : e), 8, 18); } catch {} } }
                })();
                </script>
            </section>
"@

            $commitTable = if ($commitRows) {
                                @"
                                <h2>Recent Commits</h2>
                                <table class="table">
                                        <thead><tr><th>Date</th><th>Hash</th><th>Message</th><th>Author</th></tr></thead>
                                        <tbody>
                                                $commitRows
                                        </tbody>
                                </table>
                $(if ($Data.Git.Commits.Count -gt $MaxCommits) { '<div class="muted" style="font-size:12px;margin-top:6px;">…and ' + ($Data.Git.Commits.Count - $MaxCommits) + ' more</div>' } else { '' })
"@
                        } else {
                                '<p class="muted">No commits found in the selected period.</p>'
                        }

                        # Filesystem card (if present)
                        $fsCard = ''
                        try {
                            if ($null -ne $Data.Filesystem) {
                                $fs = $Data.Filesystem
                                function _fmtBytes([Nullable[int64]]$b) {
                                    if ($null -eq $b) { return '0 B' }
                                    $sizes = 'B','KB','MB','GB','TB'
                                    $i=0; $val=[double]$b
                                    while ($val -ge 1024 -and $i -lt $sizes.Length-1) { $val/=1024; $i++ }
                                    return ('{0:N2} {1}' -f $val, $sizes[$i])
                                }
                                $sizeTxt = _fmtBytes $fs.SumSizeBytes
                                $lmTxt = if ($fs.LastModified) { $fs.LastModified.ToString('yyyy-MM-dd HH:mm') } else { 'n/a' }
                                $extList = ''
                                if ($fs.TopExtensions -and $fs.TopExtensions.Count -gt 0) {
                                    $li = @()
                                    foreach ($e in $fs.TopExtensions) { $li += ('<li><code>' + (& $encode $e.Extension) + '</code>: ' + $e.Count + '</li>') }
                                    $extList = '<ul style="margin:6px 0 0 18px">' + ($li -join '') + '</ul>'
                                }
                                # Build file table rows (limited to first 500 for HTML size)
                                $fileRowsHtml = ''
                                try {
                                    $maxRows = 500
                                    $rows = @()
                                    # Sort by LastWriteTime (modified date) descending
                                    foreach ($row in @($fs.Files | Sort-Object -Property @{Expression='LastWriteTime'; Descending=$true}, @{Expression='RelativePath'; Descending=$false} | Select-Object -First $maxRows)) {
                                        $rp = & $encode $row.RelativePath
                                        $sz = _fmtBytes $row.SizeBytes
                                        $ln = $row.Lines
                                        $ch = $row.Chars
                                        $dt = if ($row.LastWriteTime) { $row.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } else { '' }
                                        $rows += "<tr><td><code>$rp</code></td><td style='text-align:right'>$sz</td><td style='text-align:right'>$ln</td><td style='text-align:right'>$ch</td><td>$dt</td></tr>"
                                    }
                                    if ($rows.Count -gt 0) { $fileRowsHtml = ($rows -join "") } else { $fileRowsHtml = "<tr><td colspan='5' class='muted'>No non-binary text files found.</td></tr>" }
                                } catch { $fileRowsHtml = "<tr><td colspan='5' class='muted'>Failed to render file list.</td></tr>" }
                                $fsCard = @"
        <section class="card" style="margin-top:16px;">
            <h2>Recursive Directory Analysis</h2>
            <div class="kpis" style="margin-bottom:10px;">
                <div class="kpi"><div class="kpi-label">Root</div><div class="kpi-value" style="font-size:14px;">$repoAnchor</div></div>
                <div class="kpi"><div class="kpi-label">Items</div><div class="kpi-value">$($fs.TotalItems)</div></div>
                <div class="kpi"><div class="kpi-label">Text Lines (sum)</div><div class="kpi-value">$($fs.SumLines)</div></div>
                <div class="kpi"><div class="kpi-label">Characters (sum)</div><div class="kpi-value">$($fs.SumChars)</div></div>
                <div class="kpi"><div class="kpi-label">Total Size</div><div class="kpi-value">$sizeTxt</div></div>
                <div class="kpi"><div class="kpi-label">Last Modified</div><div class="kpi-value">$lmTxt</div></div>
            </div>
            <div class="intro" style="margin-top:10px;">
                <p><strong>Top Extensions:</strong></p>
                $extList
            </div>
            <h3 style="margin-top:16px; color:var(--brand2);">Non-binary Text Files (first 500)</h3>
            <table class="table">
                <thead><tr><th>Path</th><th style="text-align:right">Size</th><th style="text-align:right">Lines</th><th style="text-align:right">Chars</th><th>Last Modified</th></tr></thead>
                <tbody>
                    $fileRowsHtml
                </tbody>
            </table>
    </section>
"@
                            }
                        } catch { $fsCard = '' }

                        # Prepare Alternative Effort dynamic rendering data
                        try {
                            $gitAltBasisVal = [int]$Data.Git.AlternativeEffort.LinesBasis
                            $gitAltBasisLabel = [string]$Data.Git.AlternativeEffort.BasisLabel
                        } catch {
                            $gitAltBasisVal = 0
                            $gitAltBasisLabel = 'Git lines basis'
                        }
                        try {
                            if ($Data.Filesystem) { $fsAltBasisVal = [int]$Data.Filesystem.SumLines } else { $fsAltBasisVal = 0 }
                            $fsAltBasisLabel = 'Text Lines (sum) across directory'
                        } catch { $fsAltBasisVal = 0; $fsAltBasisLabel = 'Text Lines (sum) across directory' }
                        try {
                            $altItemsJson = ($Data.Git.AlternativeEffort.Items | Select-Object Label,Factor,Links,Description | ConvertTo-Json -Depth 6 -Compress)
                        } catch { $altItemsJson = '[]' }
                        # JSON literals for safe JS embedding
                        $gitAltBasisValJson = ($gitAltBasisVal | ConvertTo-Json -Compress)
                        $gitAltBasisLabelJson = ($gitAltBasisLabel | ConvertTo-Json -Compress)
                        $fsAltBasisValJson = ($fsAltBasisVal | ConvertTo-Json -Compress)
                        $fsAltBasisLabelJson = ($fsAltBasisLabel | ConvertTo-Json -Compress)

                        # Alternative Effort rows are now client-rendered dynamically based on selected view

                        # Precompute header metadata strings to avoid complex subexpressions inside the here-string
                        $metaPeriodText = if ($period) { "Period: $period" } else { '' }
                        $metaGeneratedText = if ($generated) { "Generated: $generated" } else { "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
                        $metaAuthorText = if ($author) { "Author: $author" } else { '' }
                        $metaTeamText = if ($team) { "Team: $team" } else { '' }
                        $metaFacilityText = if ($facility) { "Facility: $facility" } else { '' }
                        $metaRepoText = "Repository: $repoDisplay"
                        # Build footer meta chips HTML (only render non-empty values)
                        $metaChips = New-Object System.Collections.Generic.List[string]
                        if ($metaRepoText)     { [void]$metaChips.Add("<span class='meta-chip'>$metaRepoText</span>") }
                        if ($metaPeriodText)   { [void]$metaChips.Add("<span class='meta-chip'>$metaPeriodText</span>") }
                        if ($metaAuthorText)   { [void]$metaChips.Add("<span class='meta-chip'>$metaAuthorText</span>") }
                        if ($metaTeamText)     { [void]$metaChips.Add("<span class='meta-chip'>$metaTeamText</span>") }
                        if ($metaFacilityText) { [void]$metaChips.Add("<span class='meta-chip'>$metaFacilityText</span>") }
                        if ($metaGeneratedText){ [void]$metaChips.Add("<span class='meta-chip'>$metaGeneratedText</span>") }
                        $metaChipsHtml = [string]::Join("`n                ", $metaChips)

                        $FullHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>VA Power Platform Productivity Report</title>
        <style>
                :root{
                        --bg:#ffffff; --fg:#1f2937; --muted:#6b7280; --brand:#1f5582; --brand2:#2d72a3; --accent:#3e8cc7;
                        --card:#f8fafc; --border:#e5e7eb; --add:#0e9f6e; --remove:#ef4444; --mod:#f59e0b;
                }
                @media (prefers-color-scheme: dark){
                        :root{ --bg:#0b0f14; --fg:#e5e7eb; --muted:#94a3b8; --card:#0f172a; --border:#233044; }
                }
                body{ margin:0; padding:32px; font-family:Segoe UI, Roboto, Arial, sans-serif; background:var(--bg); color:var(--fg); display:flex; min-height:100vh; flex-direction:column; }
                .container{ max-width:1100px; margin:0 auto; width:100%; flex:1; display:block; }
                header h1{ margin:0; font-size:26px; color:var(--brand); }
                header .meta{ color:var(--muted); margin-top:4px; }
                .cards{ display:grid; grid-template-columns:1fr 1fr; gap:16px; margin:24px 0; }
                .cards-single{ grid-template-columns:1fr; }
                .card{ background:var(--card); border:1px solid var(--border); border-radius:10px; padding:16px 18px; }
                .kpis{ display:grid; grid-template-columns:repeat(3, minmax(0,1fr)); gap:12px; margin-top:8px; }
                .kpi{ background:#fff0; border:1px dashed var(--border); border-radius:8px; padding:12px; text-align:center; }
                .kpi-label{ font-size:12px; color:var(--muted); }
                .kpi-value{ font-size:20px; font-weight:600; margin-top:4px; }
                .kpi-value .sub{ font-size:12px; color:var(--muted); font-weight:400; }
                .kpi-value.add{ color:var(--add); }
                .kpi-value.remove{ color:var(--remove); }
                .kpi-value.mod{ color:var(--mod); }
                .delta-chip{ display:inline-block; margin-left:6px; padding:2px 6px; border-radius:999px; font-size:11px; line-height:1; border:1px solid var(--border); vertical-align:middle; }
                .delta-chip.up{ color:var(--add); border-color:var(--add); }
                .delta-chip.down{ color:var(--remove); border-color:var(--remove); }
                .delta-chip.neutral{ color:var(--muted); }
                h2{ color:var(--brand2); margin:22px 0 10px; font-size:20px; }
                .table{ width:100%; border-collapse:collapse; border:1px solid var(--border); border-radius:8px; overflow:hidden; }
                .table thead{ background:var(--card); }
                .table th, .table td{ padding:10px 12px; border-bottom:1px solid var(--border); vertical-align:top; }
                .muted{ color:var(--muted); }
                footer{ margin-top:24px; color:var(--muted); font-size:12px; padding-top:8px; border-top:1px solid var(--border); }
                footer .meta-row{ margin-top:6px; }
                code{ background:var(--card); padding:2px 6px; border-radius:6px; }
                #trend{ width:100%; display:block; }
                .chart-card{ background:var(--card); border:1px solid var(--border); border-radius:10px; padding:16px 18px; margin-top:16px; }
                .chart-legend{ font-size:12px; color:var(--muted); }
                .meta-row{ display:flex; flex-wrap:wrap; gap:8px; margin-top:8px; }
                .meta-chip{ background:var(--card); border:1px solid var(--border); color:var(--muted); border-radius:999px; padding:4px 10px; font-size:12px; }
                .intro{ background:var(--card); border:1px solid var(--border); border-radius:10px; padding:14px 16px; margin-top:12px; }
                .intro p{ margin:6px 0; color:var(--muted); }
                .intro ul{ margin:6px 0 0 18px; color:var(--muted); }
                .toggle .toggle-btn{ transition: background-color .15s ease, color .15s ease; }
                .toggle-btn.active{ background:var(--brand); color:#fff !important; }
                .toggle.toggle--intro .toggle-btn{ font-size:18px; padding:14px 22px !important; font-weight:600; }
                .placeholder{ text-align:center; padding:48px 12px 24px 12px; }
                /* Accordions */
                details { border:1px solid var(--border); border-radius:8px; padding:8px 10px; background:#fff0; }
                details + details { margin-top:8px; }
                summary { cursor:pointer; user-select:none; color:var(--brand2); font-weight:600; }
                summary::-webkit-details-marker { display:none; }
                summary::before { content:'▸'; display:inline-block; margin-right:6px; transition: transform .15s ease; }
                details[open] summary::before { transform: rotate(90deg); }
                .details-content { margin-top:8px; color:var(--fg); }
                .details-content a { color:var(--brand2); text-decoration:underline; }
        </style>
        </head>
<body>
    <div class="container">
        <header>
            <h1>VA Power Platform Productivity Report</h1>
        </header>

        <section class="intro" aria-label="About this report">
            <p><strong>What this is:</strong> A decision-ready snapshot of development activity for the selected time window. It analyzes Git commits and code changes in the specified repository and optionally summarizes productivity logs.</p>
            <p><strong>Repository analyzed:</strong> $repoAnchor.</p>
            <ul>
                <li><strong>Key metrics:</strong> commits, lines added/removed/modified, files changed, and an effort estimate adjusted for PowerShell and healthcare-compliance complexity.</li>
                <li><strong>Time window:</strong> Reports are snapshots (Daily/Weekly/Monthly/All Time/Custom), not cumulative history.</li>
                <li><strong>Use:</strong> Status reporting and personal tracking; not a substitute for formal timekeeping.</li>
            </ul>
        </section>

        <div style="display:flex;justify-content:center;margin:10px 0 4px 0;">
            <div class="toggle toggle--intro" role="group" aria-label="View selector" style="display:inline-flex;border:1px solid var(--border);border-radius:999px;overflow:hidden;">
                <button id="btn-view-git" class="toggle-btn" style="padding:6px 12px;border:none;background:transparent;color:var(--brand2);cursor:pointer;">Repository Commit View</button>
                <button id="btn-view-fs" class="toggle-btn" style="padding:6px 12px;border:none;background:transparent;color:var(--brand2);cursor:pointer;">Recursive Directory View</button>
            </div>
        </div>

        <div id="view-placeholder" class="placeholder" aria-live="polite">
            <h2 style="margin:0 0 8px 0; color:var(--brand2);">Select a view to continue</h2>
            <p style="margin:0;">Use the toggle above to switch between repository commits and the recursive directory analysis.</p>
        </div>

        <section class="cards cards-single" data-view="git" style="display:none;">
            <div class="card">
                <h2>Commit Summary</h2>
                <p class="muted">Snapshot of development activity and estimated effort for the selected period that was committed to the Git repository.</p>
                $kpiHtml
            </div>
        </section>

        <section class="cards cards-single" data-view="fs" style="display:none;">
            <div class="card">
                <h2>Directory Summary</h2>
                <p class="muted">Snapshot of development activity and estimated effort for the entire directory tree.</p>
                $fsSummaryHtml
            </div>
        </section>

        <div data-view="git" style="display:none;">$chartSection</div>
        <div data-view="fs" style="display:none;">$fsChartSection</div>

        <div data-view="git" style="display:none;">$commitTable</div>
        <div data-view="fs" style="display:none;">$fsCard</div>

    <section class="card" data-view="alt" style="margin-top:16px; display:none;">
            <h2>Alternative Effort Comparison</h2>
            <p class="muted" style="margin-top:4px">Educational estimates based on lines of code and benchmarked productivity factors for different developer types and contexts. Formula: <code>Labor Hours = LinesOfText × Productivity Factor</code>. Basis here is <strong>Lines Added + 0.5 × Lines Modified − 0.5 × Lines Removed</strong> for the selected period.</p>
            <div class="intro" style="margin-top:10px;">
                <p><strong>Lines basis:</strong> <span id="alt-basis-value">$($Data.Git.AlternativeEffort.LinesBasis)</span> <span class="muted">(<span id="alt-basis-label">$($Data.Git.AlternativeEffort.BasisLabel)</span>)</span></p>
            </div>
            <table class="table" style="margin-top:10px;">
                <thead>
                    <tr><th>Developer Type</th><th>Factor (hrs/line)</th><th>Estimated Hours</th><th>References</th></tr>
                </thead>
                <tbody id="alt-rows"></tbody>
            </table>
            <div class="muted" style="font-size:12px;margin-top:8px;">
                Sources and references are provided for transparency. Adjust factors to match your org’s historical data if available.
            </div>
        </section>

        <script>
        (function(){
            var toggle = document.querySelector('.toggle');
            var btnGit = document.getElementById('btn-view-git');
            var btnFs = document.getElementById('btn-view-fs');
            var placeholder = document.getElementById('view-placeholder');
            var footer = document.querySelector('footer .meta-row');
            var altSection = document.querySelector('[data-view="alt"]');
            var altRows = document.getElementById('alt-rows');
            var basisValEl = document.getElementById('alt-basis-value');
            var basisLabelEl = document.getElementById('alt-basis-label');
            if (!btnGit || !btnFs) return;

            var altData = {
                git: { basisVal: $gitAltBasisValJson, basisLabel: $gitAltBasisLabelJson },
                fs:  { basisVal: $fsAltBasisValJson,  basisLabel: $fsAltBasisLabelJson  },
                items: $altItemsJson
            };

            function renderAlt(view){
                try {
                    if (!altSection || !altRows) return;
                    var d = altData[view];
                    if (!d) return;
                    var basisVal = Number(d.basisVal) || 0;
                    if (basisValEl) basisValEl.textContent = String(basisVal);
                    if (basisLabelEl) basisLabelEl.textContent = d.basisLabel || '';
                    var items = altData.items || [];
                    if (typeof items === 'string') { try { items = JSON.parse(items); } catch(e) { items = []; } }
                    var rows = [];
                    for (var i=0;i<items.length;i++){
                        var it = items[i]||{};
                        var label = it.Label || '';
                        var factor = Number(it.Factor) || 0;
                        var hours = Math.round((basisVal * factor) * 10) / 10;
                        var desc = it.Description || '';
                        var links = Array.isArray(it.Links) ? it.Links : [];
                        var linkHtml = '';
                        if (links.length){
                            var li = links.map(function(u){ var safe=String(u||''); return '<li><a href="'+safe+'" target="_blank" rel="noopener">'+safe+'</a></li>'; }).join('');
                            linkHtml = '<div style="margin-top:8px"><strong>Sources:</strong><ul style="margin:6px 0 0 18px">'+li+'</ul></div>';
                        }
                        var details = '<details><summary>Details'+(links.length?(' ('+links.length+' links)'):'')+'</summary><div class="details-content">'+desc+linkHtml+'</div></details>';
                        rows.push('<tr><td>'+label+'</td><td style="white-space:nowrap">'+factor.toFixed(2)+'</td><td style="white-space:nowrap">'+hours.toFixed(1)+'</td><td>'+details+'</td></tr>');
                    }
                    altRows.innerHTML = rows.length ? rows.join('') : '<tr><td colspan="4" class="muted">No data available for this period.</td></tr>';
                } catch(e) {}
            }

            function setView(view){
                var showGit = view === 'git';
                btnGit.classList.toggle('active', showGit);
                btnFs.classList.toggle('active', !showGit);
                document.querySelectorAll('[data-view="git"]').forEach(function(el){ el.style.display = showGit? '' : 'none'; });
                document.querySelectorAll('[data-view="fs"]').forEach(function(el){ el.style.display = showGit? 'none' : ''; });
                document.querySelectorAll('[data-view="alt"]').forEach(function(el){ el.style.display = ''; });
                if (placeholder) placeholder.style.display = 'none';
                if (toggle) toggle.classList.remove('toggle--intro');
                if (footer){
                    var chipId = 'active-view-chip';
                    var existing = document.getElementById(chipId);
                    var label = showGit ? 'View: Repository Commits' : 'View: Recursive Directory';
                    if (!existing){
                        var span = document.createElement('span');
                        span.className = 'meta-chip';
                        span.id = chipId;
                        span.textContent = label;
                        footer.appendChild(span);
                    } else {
                        existing.textContent = label;
                    }
                }
                renderAlt(showGit ? 'git' : 'fs');
            }

            btnGit.addEventListener('click', function(){ setView('git'); });
            btnFs.addEventListener('click', function(){ setView('fs'); });
            // Start with placeholder visible, no view selected
        })();
        </script>

        <footer>
            <span style="font-size:12px;">Generated by VA Power Platform Workspace Template · Report ID: $(Get-Date -Format 'yyyyMMdd-HHmmss')</span>
            <div class="meta-row" style="margin-bottom:6px; font-size:3px;">
                $metaChipsHtml
            </div>
        </footer>
    </div>
</body>
</html>
"@
                        Set-Content -Path $OutputPath -Value $FullHtml -Encoding UTF8
        }
        default {
            switch ($Format) {
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
Filesystem Root,$($Data.Filesystem.Root)
Filesystem Total Items,$($Data.Filesystem.TotalItems)
Filesystem Files,$($Data.Filesystem.TotalFiles)
Filesystem Folders,$($Data.Filesystem.TotalFolders)
Filesystem Shortcuts,$($Data.Filesystem.TotalShortcuts)
Filesystem Reparse Points,$($Data.Filesystem.TotalReparse)
Filesystem Text Lines (sum),$($Data.Filesystem.SumLines)
Filesystem Characters (sum),$($Data.Filesystem.SumChars)
Filesystem Size Bytes,$($Data.Filesystem.SumSizeBytes)
Filesystem Last Modified,$((if ($Data.Filesystem.LastModified) { $Data.Filesystem.LastModified.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }))
"@
                    Set-Content -Path $OutputPath -Value $CsvData -Encoding UTF8
                }
                default {
                    # Fallback: write the original content
                    Set-Content -Path $OutputPath -Value $Content -Encoding UTF8
                }
            }
        }
    }
}

try {
    Write-Log "Starting productivity report generation" "INFO"

    if (-not $Quiet) {
        Write-Host "VA Power Platform Productivity Report Generator" -ForegroundColor Green
        Write-Host "================================================" -ForegroundColor Green
        Show-IntroText
        New-Divider
    }

    # Ensure progress is visible in this session (will be restored later)
    $origProgressPreference = $ProgressPreference
    if (-not $Quiet) { $ProgressPreference = 'Continue' }

    $progressId = 1

    # Determine date range (interactive if no parameters provided)
    if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('ReportType') -and -not $PSBoundParameters.ContainsKey('StartDate') -and -not $PSBoundParameters.ContainsKey('EndDate')) {
        Show-Header "Report Setup"
    $selection = Get-ReportTypeInteractive
        $ReportType = $selection.ReportType
        if ($ReportType -eq 'Custom') { $StartDate = $selection.StartDate; $EndDate = $selection.EndDate }
    }

    if ($ReportType -eq "Custom" -and (!$StartDate -or !$EndDate)) {
        throw "Custom report type requires both StartDate and EndDate parameters"
    }

    $DateRange = Get-ReportDateRange -Type $ReportType
    if (-not $Quiet) { Write-Host "Report Period: $($DateRange.Title)" -ForegroundColor Yellow }

    # Select output format (interactive if not provided)
    if (-not $NonInteractive -and -not $PSBoundParameters.ContainsKey('OutputFormat') -and -not $ExportFormats) {
        $OutputFormat = Get-OutputFormatInteractive
    }
    if (-not $Quiet -and $OutputFormat) { Write-Host "Output Format: $OutputFormat" -ForegroundColor Yellow }

    # Normalize -ExportFormats: allow a single comma-separated string (e.g., "HTML,JSON") or spaces/semicolons
    if ($ExportFormats) {
        if ($ExportFormats.Count -eq 1 -and ($ExportFormats[0] -match ',' -or $ExportFormats[0] -match ';' -or $ExportFormats[0] -match '\s')) {
            $ExportFormats = @($ExportFormats[0] -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        # Canonicalize names (case-insensitive) to one of: Markdown, HTML, JSON, CSV
        $canon = New-Object System.Collections.Generic.List[string]
        foreach ($f in $ExportFormats) {
            $v = ($f.ToString()).Trim()
            switch -Regex ($v) {
                '^(?i)md|markdown$' { [void]$canon.Add('Markdown'); continue }
                '^(?i)htm|html$'    { [void]$canon.Add('HTML'); continue }
                '^(?i)json$'        { [void]$canon.Add('JSON'); continue }
                '^(?i)csv$'         { [void]$canon.Add('CSV'); continue }
                default              { if ($v) { [void]$canon.Add($v) } }
            }
        }
        $ExportFormats = @($canon.ToArray())
    }

    # Determine default repo path and prompt user for an override with 15s timeout
    $DefaultRepo = Get-DefaultRepoPath -StartPath $PSScriptRoot
    if (-not $NonInteractive -and (-not $PSBoundParameters.ContainsKey('GitRepoPath') -or [string]::IsNullOrWhiteSpace($GitRepoPath))) {
        $answer = Read-HostWithTimeout -Prompt "Enter Git repository folder to analyze (default: $DefaultRepo)" -TimeoutSeconds 15 -Default $DefaultRepo
        $GitRepoPath = $answer
    }
    # Normalize to the actual git top-level. If not inside a repo, fall back to default's top-level.
    $TopLevel = Get-GitTopLevelPath -Path $GitRepoPath
    if (-not $TopLevel) {
        Write-Host "Provided path is not inside a Git repository. Using default: $DefaultRepo" -ForegroundColor Yellow
        $TopLevel = Get-GitTopLevelPath -Path $DefaultRepo
    }
    if ($TopLevel) { $GitRepoPath = $TopLevel }

    if (-not $Quiet) { Show-ConfigSummary -ReportType $ReportType -StartDate $StartDate -EndDate $EndDate -OutputFormat $OutputFormat -OpenAfterGeneration:$OpenAfterGeneration -IncludeDetailed:$IncludeDetailed -GitRepoPath $GitRepoPath }

    # Now that user input is complete, show initial progress
    if (-not $Quiet) { Write-Progress -Id $progressId -Activity "Productivity Report" -Status "Preparing..." -PercentComplete 5 }

    if (-not $Quiet) { Write-Progress -Id $progressId -Activity "Productivity Report" -Status "Analyzing workspace activity..." -PercentComplete 35 }

    # Generate output path if not specified
    if ([string]::IsNullOrEmpty($OutputPath)) {
        $ReportsPath = if ($OutputDir) { $OutputDir } else { "$PSScriptRoot\..\docs\reports" }
        if (!(Test-Path $ReportsPath)) {
            New-Item -Path $ReportsPath -ItemType Directory -Force | Out-Null
        }

        if ($ExportFormats -and $ExportFormats.Count -gt 0) {
            # Build a base name; we'll export all formats below
            $OutputPath = Join-Path $ReportsPath ("productivity-report-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".placeholder")
        } else {
            $FileExtension = switch ($OutputFormat) {
                "Markdown" { "md" }
                "HTML" { "html" }
                "JSON" { "json" }
                "CSV" { "csv" }
            }
            $FileName = "productivity-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').$FileExtension"
            $OutputPath = Join-Path $ReportsPath $FileName
        }
    }

    if (-not $Quiet) { Show-Header "Analyzing Workspace Activity" }

    # Collect productivity data
    $ProductivityData = Get-ProductivityData -DateRange $DateRange -RepoPath $GitRepoPath -GitRef $GitRef -AllBranches:$AllBranches

    # Optional baseline comparison
    $Baseline = $null
    if ($BaselineJson -and (Test-Path -LiteralPath $BaselineJson)) {
        try {
            $Baseline = Get-Content -LiteralPath $BaselineJson -Raw | ConvertFrom-Json -ErrorAction Stop
        } catch { Write-Log "Failed to read baseline JSON: $($_.Exception.Message)" "WARN" }
    }
    $Delta = $null
    if ($Baseline -and $Baseline.Git) {
        $Delta = [ordered]@{
            CommitCount = ($ProductivityData.Git.CommitCount - $Baseline.Git.CommitCount)
            LinesAdded = ($ProductivityData.Git.LinesAdded - $Baseline.Git.LinesAdded)
            LinesRemoved = ($ProductivityData.Git.LinesRemoved - $Baseline.Git.LinesRemoved)
            LinesModified = ($ProductivityData.Git.LinesModified - $Baseline.Git.LinesModified)
            FilesChanged = ($ProductivityData.Git.FilesChanged - $Baseline.Git.FilesChanged)
            EstimatedWorkMinutes = ($ProductivityData.Git.EstimatedWorkMinutes - $Baseline.Git.EstimatedWorkMinutes)
        }
        $ProductivityData.Git.BaselineDelta = $Delta
    }

    if (-not $Quiet) { Write-Progress -Id $progressId -Activity "Productivity Report" -Status "Generating report..." -PercentComplete 70 }
    if (-not $Quiet) { Show-Header "Generating Report" }

    # Generate report content
    $ReportContent = Format-MarkdownReport -Data $ProductivityData -DateRange $DateRange

    if (-not $Quiet) { Write-Progress -Id $progressId -Activity "Productivity Report" -Status "Exporting report..." -PercentComplete 85 }
    # Export report(s)
    if ($ExportFormats -and $ExportFormats.Count -gt 0) {
        $ReportsPath = Split-Path -Parent $OutputPath
        foreach ($fmt in $ExportFormats) {
            $fmtName = ($fmt.ToString()).Trim()
            $ext = switch -Regex ($fmtName) {
                '^(?i)Markdown$' { 'md' }
                '^(?i)HTML$'     { 'html' }
                '^(?i)JSON$'     { 'json' }
                '^(?i)CSV$'      { 'csv' }
                default          { ($fmtName -replace '^\.+','') } # fall back to raw, strip leading dots
            }
            $outFile = Join-Path $ReportsPath ("productivity-report-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + "." + $ext)
            Export-Report -Content $ReportContent -Format $fmt -OutputPath $outFile -Data $ProductivityData
            $lastOut = $outFile
        }
        $OutputPath = $lastOut
    } else {
        Export-Report -Content $ReportContent -Format $OutputFormat -OutputPath $OutputPath -Data $ProductivityData
    }

    # Summary
    $FileSize = (Get-Item $OutputPath).Length

    if (-not $Quiet) { Write-Progress -Id $progressId -Activity "Productivity Report" -Completed }

    if (-not $Quiet) {
        Show-Header "Report Generated"
        Write-Host "Productivity report generated successfully!" -ForegroundColor Green
        Write-Host "Report file: $OutputPath" -ForegroundColor Cyan
        Write-Host "File size: $([math]::Round($FileSize / 1KB, 2)) KB" -ForegroundColor Yellow
    }

    if (-not $Quiet) {
        Show-SubHeader "Report Summary"
        Write-Host "   Git Commits: $($ProductivityData.Git.CommitCount)" -ForegroundColor Gray
        Write-Host "   Lines Changed: $($ProductivityData.Git.LinesAdded + $ProductivityData.Git.LinesRemoved + $ProductivityData.Git.LinesModified)" -ForegroundColor Gray
        Write-Host "   Estimated Work: $($ProductivityData.Git.EstimatedWorkMinutes) minutes" -ForegroundColor Gray
    }

    # Open file if requested
    $opened = $false
    if ($OpenAfterGeneration -and -not $Quiet) {
        Write-Host "`nOpening report..." -ForegroundColor Yellow
        Start-Process $OutputPath
        $opened = $true
    }

    # Additionally, automatically open the HTML report if not already opened
    try {
    if (-not $Quiet -and -not $opened -and (Test-Path -LiteralPath $OutputPath)) {
            $ext = [System.IO.Path]::GetExtension($OutputPath)
            if ($ext -and $ext.Equals('.html', 'InvariantCultureIgnoreCase')) {
                Write-Host "`nOpening HTML report..." -ForegroundColor Yellow
                Start-Process $OutputPath
                $opened = $true
            }
        }
    } catch {
        Write-Log "Failed to open report automatically: $($_.Exception.Message)" "WARN"
    }

    Write-Log "Productivity report generated successfully: $OutputPath" "SUCCESS"

    # Exit behavior: if the HTML report was opened successfully, don't prompt (allow window/process to close).
    # If it was not opened (error or non-HTML), keep the prompt so the user can read output/errors.
    $isHtml = $false
    try { $isHtml = ([System.IO.Path]::GetExtension($OutputPath)).Equals('.html', 'InvariantCultureIgnoreCase') } catch {}
    $shouldPrompt = $true
    if ($opened -and $isHtml) { $shouldPrompt = $false }
    if ($shouldPrompt -and -not $NonInteractive -and -not $Quiet) {
        try { [void](Read-Host -Prompt "Press Enter to exit") } catch {}
    }

    # Restore original progress preference
    if ($PSBoundParameters.ContainsKey('origProgressPreference') -or $null -ne $origProgressPreference) { $ProgressPreference = $origProgressPreference }

} catch {
    Write-Log "Error generating productivity report: $($_.Exception.Message)" "ERROR"
    Write-Host "Error generating report: $($_.Exception.Message)" -ForegroundColor Red
    # Pause on error as well so the user can read the message (if interactive)
    if (-not $NonInteractive -and -not $Quiet) { try { [void](Read-Host -Prompt "Press Enter to exit") } catch {} }
    # Restore original progress preference on error
    if ($PSBoundParameters.ContainsKey('origProgressPreference') -or $null -ne $origProgressPreference) { $ProgressPreference = $origProgressPreference }
    exit 1
}
