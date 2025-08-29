#requires -Version 5.1
<#
Recursive-Directory-Analysis.ps1

Purpose:
  Recursively enumerate all items (files, folders, reparse points, shortcuts) under a user-specified root,
  print a concise summary to the terminal, and (unless -DryRun) analyze readable text files for lines and
  character counts and write a CSV report with a summary first row and a totals footer row.

Key behaviors:
  - Includes hidden and system items
  - Lists reparse points but does NOT traverse into them
  - Treats .lnk (shortcuts) as items themselves; does not resolve targets
  - Author is the NTFS owner; if unavailable, the literal string "null"
  - SizeBytes is the logical size for files; non-files get "null"
  - Timestamps in ISO 8601 local time
  - Text metrics include every character (including CR/LF/TAB/whitespace); line count covers all lines
  - Dry run performs enumeration + terminal summary only; no content analysis or CSV writing

Troubleshooting tips:
  - If you see access denied on certain paths, rerun with elevated permissions or exclude protected folders manually.
  - If the CSV doesn't open correctly in Excel, confirm it's saved with UTF-8 BOM (this script ensures that).
  - Very large directories may take time; be patient or target a narrower root path for testing.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Path,

    [switch]$DryRun,

    # Show progress by default; pass -NoProgress to disable
    [switch]$NoProgress
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host $msg }
function Write-Warn($msg) { Write-Warning $msg }
function Write-Err($msg)  { Write-Error $msg }

function Resolve-TargetPath {
    param([string]$InputPath)
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return $null
    }
    try {
        $full = [System.IO.Path]::GetFullPath($InputPath)
        return $full
    } catch {
        return $null
    }
}

function Read-RootPath {
    while ($true) {
        $inputPath = Read-Host -Prompt "Enter the target directory path to analyze"
        if ([string]::IsNullOrWhiteSpace($inputPath)) { continue }
        $full = Resolve-TargetPath -InputPath $inputPath
        if (-not $full) { Write-Warn "Unable to resolve path. Try again."; continue }
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { Write-Warn "Path is not a directory. Try again."; continue }
        return $full
    }
}

function Show-IntroMessage {
        $intro = @'
Recursive Directory Analysis (PowerShell)
------------------------------------------------------------
This tool recursively inventories ALL items (files, folders, shortcuts, and
reparse points) under a target directory. It includes hidden and system items.
It lists reparse points and linked folders as items but does NOT traverse into
their targets. Shortcut (.lnk) files are included as their own items; targets
are not resolved.

Run modes:
    - Default (no -DryRun): Full analysis of readable text files (lines and
        characters) and metadata for all items. Outputs a CSV report saved to
        the chosen root folder (UTF-8 with BOM).
    - Dry run (-DryRun): Performs the full recursive search and prints a concise
        summary only. No CSV is written and no per-file content is read.

Usage options:
    - Provide -Path <folder> when launching the script to skip this prompt.
    - Omit -Path to be prompted here.
    - Press Ctrl+C at any time to cancel.

Output artifacts:
    - CSV file named: RecursiveDirectoryAnalysis_YYYYMMDD_HHmmss.csv
        Location: the root folder you choose below.
        Includes: ItemType, Name, Extension, FullPath, SizeBytes, CreatedTime,
                            LastModifiedTime, Author, flags (Hidden/ReadOnly/System/Archive),
                            LinesOfText, CharacterCount, and a totals footer row.
------------------------------------------------------------
'@
        Write-Host $intro
}

# Read a line with timeout (returns default if user doesn't answer in time)
function Read-HostWithTimeout {
    param(
        [string]$Prompt,
        [int]$TimeoutSeconds = 30,
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
        # Fallback to default on any console issue
        $sw.Stop()
        return $Default
    }
    $sw.Stop()
    # Ensure we move to the next line after input or timeout for readability
    Write-Host ""
    $text = $sb.ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $Default }
    return $text
}

function Read-YesNoWithTimeout {
    param(
        [string]$Question,
        [int]$TimeoutSeconds = 30,
        [bool]$DefaultYes = $true
    )
    $defText = if ($DefaultYes) { 'YES' } else { 'NO' }
    $ans = Read-HostWithTimeout -Prompt "$Question [YES/NO]" -TimeoutSeconds $TimeoutSeconds -Default $defText
    if ($ans -match '^(?i)y(es)?$') { return $true }
    if ($ans -match '^(?i)n(o)?$') { return $false }
    # Unrecognized input -> default
    return $DefaultYes
}

# Simple UI helpers for clearer terminal output
function New-Divider { param([string]$Char='-',[int]$Count=60) Write-Host ("" + ($Char * $Count)) -ForegroundColor DarkGray }
function Show-Header   { param([string]$Title) Write-Host ""; New-Divider; Write-Host $Title -ForegroundColor Cyan; New-Divider }
function Show-SubHeader{ param([string]$Title) Write-Host $Title -ForegroundColor Yellow }
function Format-YesNo  { param([bool]$Val) if ($Val) { Write-Host 'YES' -ForegroundColor Green -NoNewline } else { Write-Host 'NO' -ForegroundColor Red -NoNewline } }
function Show-PreferencesSummary {
    param(
        [bool]$ExcludeGit,
        [bool]$ExcludeCompressed,
        [bool]$ExcludeArchiveOrTemp,
        [bool]$ExcludeFoldersRows
    )
    Show-SubHeader "Chosen scan preferences:"
    Write-Host "  1) Exclude .git repo items: " -NoNewline;  Format-YesNo -Val:$ExcludeGit;        Write-Host ""
    Write-Host "  2) Exclude compressed items: " -NoNewline;  Format-YesNo -Val:$ExcludeCompressed; Write-Host ""
    Write-Host "  3) Exclude archive/temp items: " -NoNewline;Format-YesNo -Val:$ExcludeArchiveOrTemp;Write-Host ""
    Write-Host "  4) Exclude folder rows: " -NoNewline;     Format-YesNo -Val:$ExcludeFoldersRows;  Write-Host ""
}

function Get-AuthorOrNull {
    param([string]$FullPath)
    try {
        $acl = Get-Acl -LiteralPath $FullPath -ErrorAction Stop
    if ($acl -and $acl.Owner) { return $acl.Owner }
    else { return '' }
    } catch {
    return ''
    }
}

function Test-ReparsePoint {
    param([System.IO.FileSystemInfo]$Item)
    try {
        return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    } catch {
        return $false
    }
}

function Get-ItemType {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.PSIsContainer) {
        if (Test-ReparsePoint -Item $Item) { return 'ReparsePoint' }
        return 'Folder'
    }
    $ext = ($Item.Extension | ForEach-Object { $_.ToLowerInvariant() })
    if ($ext -eq '.lnk') { return 'Shortcut' }
    # Treat non-container reparse files as normal files for analysis purposes
    return 'File'
}

function Test-IsBinaryFile {
    param([string]$FullPath)
    # Heuristic: if file contains NUL bytes in the first 8KB, treat as binary.
    try {
        $fs = [System.IO.File]::Open($FullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $buf = New-Object byte[] 8192
            $read = $fs.Read($buf, 0, $buf.Length)
            for ($i = 0; $i -lt $read; $i++) {
                if ($buf[$i] -eq 0) { return $true }
            }
            return $false
        } finally { $fs.Dispose() }
    } catch {
        # If cannot read, treat as unreadable/binary to skip text metrics later
        return $true
    }
}

function Measure-TextFile {
    param([string]$FullPath)
    # Returns a hashtable with Lines and Chars
    $totalChars = 0
    $totalLines = 0
    $anyChars = $false
    $lastWasCR = $false

    try {
        $fs = [System.IO.File]::Open($FullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $sr = New-Object System.IO.StreamReader($fs, $true)
            try {
                $buffer = New-Object char[] 4096
                while (($count = $sr.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    for ($i = 0; $i -lt $count; $i++) {
                        $c = $buffer[$i]
                        $anyChars = $true
                        $totalChars++
                        if ($c -eq "`n") {
                            $totalLines++
                            $lastWasCR = $false
                        } elseif ($c -eq "`r") {
                            $lastWasCR = $true
                        } else {
                            if ($lastWasCR) { $totalLines++; $lastWasCR = $false }
                        }
                    }
                }
                if ($lastWasCR) { $totalLines++ }
                if (-not $anyChars) { $totalLines = 0 }
                elseif ($totalLines -eq 0) { $totalLines = 1 }
            } finally { $sr.Dispose() }
        } finally { $fs.Dispose() }
    } catch {
        return @{ Lines = $null; Chars = $null }
    }
    return @{ Lines = $totalLines; Chars = $totalChars }
}

function Get-ItemAttributesBooleans {
    param([System.IO.FileSystemInfo]$Item)
    $attrs = $Item.Attributes
    return @{
        IsHidden   = (($attrs -band [IO.FileAttributes]::Hidden)   -ne 0)
        IsReadOnly = (($attrs -band [IO.FileAttributes]::ReadOnly) -ne 0)
        IsSystem   = (($attrs -band [IO.FileAttributes]::System)   -ne 0)
        IsArchive  = (($attrs -band [IO.FileAttributes]::Archive)  -ne 0)
    }
}

function Get-AllItems {
    param(
        [string]$Root,
        [bool]$EnableProgress = $true
    )

    $result = New-Object System.Collections.Generic.List[System.IO.FileSystemInfo]

    # Include root itself
    $rootDir = Get-Item -LiteralPath $Root -Force
    $result.Add($rootDir) | Out-Null

    # Stack-based DFS to avoid following reparse points
    $stack = New-Object System.Collections.Stack
    $stack.Push($rootDir)

    $processedDirs = 0
    $lastUpdate = Get-Date
    $spin = '|/-\\'
    $spinIdx = 0
    $progressId = 1

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        $processedDirs++
        # List children of $dir
        try {
            $children = Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction Stop
        } catch {
            Write-Warn "Skipping inaccessible directory: $($dir.FullName) — $($_.Exception.Message)"
            continue
        }

        foreach ($child in $children) {
            $result.Add($child) | Out-Null
            if ($child.PSIsContainer) {
                if (Test-ReparsePoint -Item $child) {
                    # list but do not traverse
                    continue
                }
                # Normal directory, descend
                $stack.Push($child)
            }
        }

        if ($EnableProgress) {
            $now = Get-Date
            if (($now - $lastUpdate).TotalMilliseconds -ge 200) {
                $spinChar = $spin[$spinIdx % $spin.Length]
                $spinIdx++
                $status = "[$spinChar] Processed dirs: $processedDirs | Discovered items: $($result.Count)"
                Write-Progress -Id $progressId -Activity "Scanning (enumerating items)" -Status $status -PercentComplete -1
                $lastUpdate = $now
            }
        }
    }

    if ($EnableProgress) { Write-Progress -Id $progressId -Activity "Scanning (enumerating items)" -Completed }
    return $result
}

function New-RowObject {
    param(
        [string]$ItemType,
        [System.IO.FileSystemInfo]$Item,
        [Nullable[int64]]$SizeBytes,
        [string]$Author,
        [Nullable[int]]$Lines,
        [Nullable[int64]]$Chars)

    $ext = if (-not $Item.PSIsContainer) { ($Item.Extension.ToLowerInvariant()); } else { $null }
    $attrs = Get-ItemAttributesBooleans -Item $Item

    $created = try { $Item.CreationTime.ToString("yyyy-MM-ddTHH:mm:ss.fffK") } catch { '' }
    $modified = try { $Item.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss.fffK") } catch { '' }

    $name = try { $Item.Name } catch { [System.IO.Path]::GetFileName($Item.FullName) }
    $full = try { $Item.FullName } catch { $null }

    $extVal = if ($ext) { $ext } else { '' }
    $sizeVal = if ($null -ne $SizeBytes) { [string]$SizeBytes } else { '' }
    $linesVal = if ($null -ne $Lines) { [string]$Lines } else { '' }
    $charsVal = if ($null -ne $Chars) { [string]$Chars } else { '' }

    <#
    ----------------------------------------------------------------------
    Productivity & Labor Hour Estimation Benchmarks (Explanation Block)
    ----------------------------------------------------------------------
    The following factors are used to estimate "labor hours" for each file,
    based on its detected LinesOfText. These estimates reflect widely cited
    industry heuristics, government reports, and community experience.

    - LaborHours_FederalEnvironment(Dept of VA)PowerPlatformsDev: 0.5 hrs/line
        * US Government environment (VA, DoD, etc.): strict security, compliance,
          restricted connectors, slow workflows, heavy documentation.
        * Productivity is lower due to overhead, workarounds, and constraints.
        * GAO reports: https://www.gao.gov/products/gao-23-104779
        * StackOverflow: https://stackoverflow.com/questions/73713134/powerapps-gov-cloud-limitations

    - LaborHours_TraditionalDev: 0.1 hrs/line
        * Based on COCOMO model, industry surveys, "Code Complete" by Steve McConnell.

    - LaborHours_RegularPowerPlatformDev: 0.25 hrs/line
        * An average Power Platform developer in a regular large company, working solo.
        * Reference: Industry Power Platform averages.

    - LaborHours_AdvancedLowComplexityPowerPlatformDev: 0.15 hrs/line
        * Experienced developer with advanced training/certifications, working solo on low-complexity projects at a major tech company/university.

    - LaborHours_AdvancedHighComplexityPowerPlatformDev: 0.33 hrs/line
        * Experienced developer with advanced training/certifications, working solo on high-complexity projects, sensitive content, self-built dependencies.

    - LaborHours_VibeCoderCopilotAgent: 0.02 hrs/line
        * Average 'vibe coder' using VS Code Copilot agent or similar LLM in a regular large company.

    - LaborHours_RegularJavaPythonDev_FederalEnvironment: 0.2 hrs/line
        * Regular Java/Python developer under federal government restrictions (no premium connectors, no admin rights, heavy compliance).

    - LaborHours_PowerPlatformHobbyist: 1.0 hrs/line
        * Standard computer user with average computer literacy, no programming background,
          learning Power Platform tools as a hobby/extracurricular interest.
        * Anecdotal: Microsoft Power Platform forums.

    Sources and references for these estimates are included for transparency. Adjust factors as needed for your organization's historical data.
    ----------------------------------------------------------------------
    #>

    # Productivity estimation factors
    $factorFederalGovVA         = 0.5
    $factorTraditionalDev       = 0.1
    $factorRegularPPDev         = 0.25
    $factorAdvancedLowComplexPP = 0.15
    $factorAdvancedHighComplexPP= 0.33
    $factorVibeCoderCopilot     = 0.02
    $factorJavaPythonFed        = 0.2
    $factorPowerPlatformHobbyist= 1.0

    # Calculate labor hours for each benchmark (only if Lines is available)
    $laborFederalGovVA         = if ($null -ne $Lines) { [math]::Round($Lines * $factorFederalGovVA,2) } else { '' }
    $laborTraditionalDev       = if ($null -ne $Lines) { [math]::Round($Lines * $factorTraditionalDev,2) } else { '' }
    $laborRegularPPDev         = if ($null -ne $Lines) { [math]::Round($Lines * $factorRegularPPDev,2) } else { '' }
    $laborAdvancedLowComplexPP = if ($null -ne $Lines) { [math]::Round($Lines * $factorAdvancedLowComplexPP,2) } else { '' }
    $laborAdvancedHighComplexPP= if ($null -ne $Lines) { [math]::Round($Lines * $factorAdvancedHighComplexPP,2) } else { '' }
    $laborVibeCoderCopilot     = if ($null -ne $Lines) { [math]::Round($Lines * $factorVibeCoderCopilot,2) } else { '' }
    $laborJavaPythonFed        = if ($null -ne $Lines) { [math]::Round($Lines * $factorJavaPythonFed,2) } else { '' }
    $laborPowerPlatformHobbyist= if ($null -ne $Lines) { [math]::Round($Lines * $factorPowerPlatformHobbyist,2) } else { '' }

    # Build Excel HYPERLINK formula for the FullPath column
    $fullForLink = if ($full) { $full } else { '' }
    $containingFolder = try {
        if ($Item.PSIsContainer) {
            if ($Item.Parent) { $Item.Parent.FullName } else { $Item.FullName }
        } else {
            $Item.DirectoryName
        }
    } catch { $fullForLink }
    if ([string]::IsNullOrWhiteSpace($containingFolder)) { $containingFolder = $fullForLink }
    $dispText = $fullForLink -replace '"','""'
    $targetPath = $containingFolder -replace '"','""'
    $fullHyperlink = if ([string]::IsNullOrEmpty($fullForLink)) { '' } else { [string]::Format('=HYPERLINK("{0}","{1}")', $targetPath, $dispText) }

    $obj = [ordered]@{
        CreatedTime      = $created
        LastModifiedTime = $modified
        Author           = $Author
        IsReparsePoint   = [string](Test-ReparsePoint -Item $Item)
        IsHidden         = [string]$($attrs.IsHidden)
        IsReadOnly       = [string]$($attrs.IsReadOnly)
        IsSystem         = [string]$($attrs.IsSystem)
        IsArchive        = [string]$($attrs.IsArchive)
        FullPath         = $fullHyperlink
        Name             = $name
        ItemType         = $ItemType
        Extension        = $extVal
        SizeBytes        = $sizeVal
        LinesOfText      = $linesVal
        CharacterCount   = $charsVal
        LaborHours_FederalEnvironmentDeptVA_PowerPlatformsDev = $laborFederalGovVA
        LaborHours_TraditionalDev       = $laborTraditionalDev
        LaborHours_RegularPowerPlatformDev = $laborRegularPPDev
        LaborHours_AdvancedLowComplexityPowerPlatformDev = $laborAdvancedLowComplexPP
        LaborHours_AdvancedHighComplexityPowerPlatformDev = $laborAdvancedHighComplexPP
        LaborHours_VibeCoderCopilotAgent = $laborVibeCoderCopilot
        LaborHours_RegularJavaPythonDev_FederalEnvironment = $laborJavaPythonFed
        LaborHours_PowerPlatformHobbyist = $laborPowerPlatformHobbyist
    }
    return [PSCustomObject]$obj
}

    <#
    ---------------------------------------------------------------------
function New-RowObject {
    param(
        [string]$ItemType,
        [System.IO.FileSystemInfo]$Item,
        [Nullable[int64]]$SizeBytes,
        [string]$Author,
        [Nullable[int]]$Lines,
        [Nullable[int64]]$Chars)

    $ext = if (-not $Item.PSIsContainer) { ($Item.Extension.ToLowerInvariant()); } else { $null }
    $attrs = Get-ItemAttributesBooleans -Item $Item

    $created = try { $Item.CreationTime.ToString("yyyy-MM-ddTHH:mm:ss.fffK") } catch { '' }
    $modified = try { $Item.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss.fffK") } catch { '' }

    $name = try { $Item.Name } catch { [System.IO.Path]::GetFileName($Item.FullName) }
    $full = try { $Item.FullName } catch { $null }

    $extVal = if ($ext) { $ext } else { '' }
    $sizeVal = if ($null -ne $SizeBytes) { [string]$SizeBytes } else { '' }
    $linesVal = if ($null -ne $Lines) { [string]$Lines } else { '' }
    $charsVal = if ($null -ne $Chars) { [string]$Chars } else { '' }

    # Build Excel HYPERLINK formula for the FullPath column
    # Requirement: clicking opens the containing folder/location, not the item itself.
    $fullForLink = if ($full) { $full } else { '' }
    $containingFolder = try {
        if ($Item.PSIsContainer) {
            if ($Item.Parent) { $Item.Parent.FullName } else { $Item.FullName }
        } else {
            $Item.DirectoryName
        }
    } catch { $fullForLink }
    if ([string]::IsNullOrWhiteSpace($containingFolder)) { $containingFolder = $fullForLink }
    # Escape double quotes for CSV/formula safety (Excel uses doubled quotes inside formulas)
    $dispText = $fullForLink -replace '"','""'
    $targetPath = $containingFolder -replace '"','""'
    $fullHyperlink = if ([string]::IsNullOrEmpty($fullForLink)) { '' } else { [string]::Format('=HYPERLINK("{0}","{1}")', $targetPath, $dispText) }

    # Reordered columns:
    # Far left: CreatedTime, LastModifiedTime, Author, IsReparsePoint, IsHidden, IsReadOnly, IsSystem, IsArchive
    # Then FullPath (as hyperlink), Name, and remaining columns
    $obj = [ordered]@{
        CreatedTime      = $created
        LastModifiedTime = $modified
        Author           = $Author
        IsReparsePoint   = [string](Test-ReparsePoint -Item $Item)
        IsHidden         = [string]$($attrs.IsHidden)
        IsReadOnly       = [string]$($attrs.IsReadOnly)
        IsSystem         = [string]$($attrs.IsSystem)
        IsArchive        = [string]$($attrs.IsArchive)
        FullPath         = $fullHyperlink
        Name             = $name
        ItemType         = $ItemType
        Extension        = $extVal
        SizeBytes        = $sizeVal
        LinesOfText      = $linesVal
        CharacterCount   = $charsVal
    }
    return [PSCustomObject]$obj
}

    ----------------------------------------------------------------------
    #>

function Build-CsvSummaryLine {
    param(
        [int]$TotalItems,
        [int]$TotalFiles,
        [int]$TotalFolders,
        [int]$TotalShortcuts,
        [int]$TotalReparse,
        [int64]$SumLines,
        [int64]$SumChars,
        [int64]$SumSizeBytes,
        [string]$Root
    )
    $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    return "Recursive Directory Analysis summary for '$Root' at $ts — Items=$TotalItems; Files=$TotalFiles; Folders=$TotalFolders; Shortcuts=$TotalShortcuts; ReparsePoints=$TotalReparse; SumLines=$SumLines; SumChars=$SumChars; SumSizeBytes=$SumSizeBytes (filters may apply)"
}

function Write-CsvWithBom {
    param(
        [string]$CsvPath,
        [string]$SummaryLine,
        [System.Collections.IEnumerable]$Rows
    )
    # Convert rows to CSV text (including header as first line)
    $csvLines = $Rows | ConvertTo-Csv -NoTypeInformation

    $dir = Split-Path -Parent $CsvPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $encoding = New-Object System.Text.UTF8Encoding($true) # with BOM
    $sw = New-Object System.IO.StreamWriter($CsvPath, $false, $encoding)
    try {
        # Write header + rows first
        foreach ($line in $csvLines) { $sw.WriteLine($line) }
        # Append the single-cell summary as the last line, under the data (including TOTALS)
        $sw.WriteLine($SummaryLine)
    } finally { $sw.Dispose() }
}

# 1) Resolve input path
$rootPath = if ($PSBoundParameters.ContainsKey('Path') -and $Path) { Resolve-TargetPath -InputPath $Path } else { $null }
if (-not $rootPath) { Show-IntroMessage; $rootPath = Read-RootPath }

# Validate directory
if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
    Write-Err "The path '$rootPath' is not a directory or does not exist."
    exit 1
}

Write-Info "Scanning: $rootPath"

# Ask preference questions (30s timeout each, default YES)
$banner = "Answer YES or NO for each preference. If no response within 30 seconds, YES will be selected."
Show-Header "Scan Preferences"
Write-Host $banner -ForegroundColor Gray
$ExcludeGit           = Read-YesNoWithTimeout -Question "Exclude any .git repository system files, objects, or folders?" -TimeoutSeconds 30 -DefaultYes $true
$ExcludeCompressed    = Read-YesNoWithTimeout -Question "Exclude any compressed items or .zip files, objects, or folders?" -TimeoutSeconds 30 -DefaultYes $true
$ExcludeArchiveOrTemp = Read-YesNoWithTimeout -Question "Exclude any obvious archive or temp files, objects, or folders?" -TimeoutSeconds 30 -DefaultYes $true
$ExcludeFoldersRows   = Read-YesNoWithTimeout -Question "Exclude all folder objects from final analysis report as their own rows? (folder contents still analyzed)" -TimeoutSeconds 30 -DefaultYes $true

Show-PreferencesSummary -ExcludeGit:$ExcludeGit -ExcludeCompressed:$ExcludeCompressed -ExcludeArchiveOrTemp:$ExcludeArchiveOrTemp -ExcludeFoldersRows:$ExcludeFoldersRows
New-Divider
Write-Host "Starting recursive scan for: $rootPath" -ForegroundColor Cyan
New-Divider

# Define filter predicates (apply to reporting/analysis only; enumeration remains complete)
function Test-ExcludeItem {
    param([System.IO.FileSystemInfo]$Item)
    $path = $null; try { $path = $Item.FullName } catch {}
    $name = $null; try { $name = $Item.Name } catch {}

    # 1) .git repo
    if ($ExcludeGit) {
        if ($path -and ($path -match "(?i)(\\|/)\.git(\\|/|$)")) { return $true }
        if ($name -and ($name -match '^(?i)\.git$')) { return $true }
    }

    # 2) compressed (common extensions)
    if ($ExcludeCompressed -and -not $Item.PSIsContainer) {
        $ext = ''
        try { $ext = $Item.Extension.ToLowerInvariant() } catch {}
        $compressedExts = @('.zip','.7z','.rar','.gz','.tar','.bz2','.xz','.zipx')
        if ($compressedExts -contains $ext) { return $true }
    }

    # 3) archive/temp paths or names
    if ($ExcludeArchiveOrTemp) {
        if ($path -and ($path -match '(?i)(\\|/)(archive|archives|archived|temp|tmp)(\\|/)')) { return $true }
        if ($name -and ($name -match '(?i)^(archive|archives|archived|temp|tmp)$')) { return $true }
    }

    # 4) exclude folders as rows
    if ($ExcludeFoldersRows -and $Item.PSIsContainer) { return $true }

    return $false
}

# 2) Enumerate all items (including root)
$showProgress = -not $NoProgress
$allItems = Get-AllItems -Root $rootPath -EnableProgress:$showProgress

# Apply reporting/analysis filters per user preferences
$reportItems = @($allItems | Where-Object { -not (Test-ExcludeItem -Item $_) })

# Compute terminal summary basics from filtered items
$files   = @($reportItems | Where-Object { -not $_.PSIsContainer -and -not (Test-ReparsePoint -Item $_) -and ($_.Extension.ToLowerInvariant() -ne '.lnk') })
$folders = @($reportItems | Where-Object { $_.PSIsContainer -and -not (Test-ReparsePoint -Item $_) })
$shorts  = @($reportItems | Where-Object { -not $_.PSIsContainer -and ($_.Extension.ToLowerInvariant() -eq '.lnk') })
$reparse = @($reportItems | Where-Object { Test-ReparsePoint -Item $_ })

$totalItems = $reportItems.Count
$totalFiles = $files.Count
$totalFolders = $folders.Count
$totalShortcuts = $shorts.Count
$totalReparse = $reparse.Count

# Extension summary (files only, excluding shortcuts treated separately)
$extSummary = $files | ForEach-Object { $_.Extension.ToLowerInvariant() } | Group-Object | Sort-Object Count -Descending
$topN = 10
$topExt = $extSummary | Select-Object -First $topN

Show-Header "Summary of '$rootPath'"
Write-Info "  Total items: $totalItems (Files=$totalFiles, Folders=$totalFolders, Shortcuts=$totalShortcuts, ReparsePoints=$totalReparse)"
if ($topExt) {
    Write-Host "  Top extensions:" -ForegroundColor Yellow
    foreach ($g in $topExt) {
        $extName = if ($g.Name) { $g.Name } else { '(no extension)' }
        Write-Info "    $extName : $($g.Count)"
    }
}

if ($DryRun) {
    Write-Info "DRY RUN: Enumeration complete. No content analysis performed and no CSV generated. Re-run without -DryRun to produce the CSV report."
    # Keep the window open for readability
    try { [void](Read-Host -Prompt "Press Enter to exit") } catch {}
    exit 0
}

# 4) Analysis and row building
$rows = New-Object System.Collections.Generic.List[object]

[int64]$sumLines = 0
[int64]$sumChars = 0
[int64]$sumSize  = 0

$totalToAnalyze = $reportItems.Count
$progressAnalysisId = 2
$processedItems = 0
$lastAnalysisUpdate = Get-Date
foreach ($item in $reportItems) {
    $type = Get-ItemType -Item $item

    # SizeBytes
    [Nullable[int64]]$sizeBytes = $null
    if ($type -eq 'File' -or $type -eq 'Shortcut') {
        try { $sizeBytes = [int64]$item.Length; $sumSize += ($sizeBytes -as [int64]) } catch { $sizeBytes = $null }
    }

    # Author
    $author = Get-AuthorOrNull -FullPath $item.FullName

    # Text metrics for non-binary files only
    [Nullable[int]]$lines = $null
    [Nullable[int64]]$chars = $null

    if ($type -eq 'File' -or $type -eq 'Shortcut') {
        $isBinary = Test-IsBinaryFile -FullPath $item.FullName
        if (-not $isBinary) {
            $m = Measure-TextFile -FullPath $item.FullName
            if ($m -and $null -ne $m.Lines -and $null -ne $m.Chars) {
                $lines = [int]$m.Lines
                $chars = [int64]$m.Chars
                $sumLines += $lines
                $sumChars += $chars
            }
        }
    }

    $row = New-RowObject -ItemType $type -Item $item -SizeBytes $sizeBytes -Author $author -Lines $lines -Chars $chars
    $rows.Add($row) | Out-Null

    # Analysis progress
    $processedItems++
    if ($showProgress -and $totalToAnalyze -gt 0) {
        $now = Get-Date
        if (($now - $lastAnalysisUpdate).TotalMilliseconds -ge 200 -or $processedItems -eq $totalToAnalyze) {
            $pct = [int](($processedItems * 100.0) / $totalToAnalyze)
            $status = "Analyzing item $processedItems of $totalToAnalyze"
            Write-Progress -Id $progressAnalysisId -Activity "Analyzing items" -Status $status -PercentComplete $pct
            $lastAnalysisUpdate = $now
        }
    }
}

if ($showProgress) { Write-Progress -Id $progressAnalysisId -Activity "Analyzing items" -Completed }

# 5) CSV Generation
$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$csvPath = Join-Path -Path $rootPath -ChildPath "RecursiveDirectoryAnalysis_$timestamp.csv"

$summaryLine = Build-CsvSummaryLine -TotalItems $totalItems -TotalFiles $totalFiles -TotalFolders $totalFolders -TotalShortcuts $totalShortcuts -TotalReparse $totalReparse -SumLines $sumLines -SumChars $sumChars -SumSizeBytes $sumSize -Root $rootPath

# Footer totals row (same columns)
$totalsRow = [ordered]@{
    CreatedTime      = ''
    LastModifiedTime = ''
    Author           = ''
    IsReparsePoint   = ''
    IsHidden         = ''
    IsReadOnly       = ''
    IsSystem         = ''
    IsArchive        = ''
    FullPath         = ''
    Name             = "Items=$totalItems; Files=$totalFiles; Folders=$totalFolders; Shortcuts=$totalShortcuts; ReparsePoints=$totalReparse"
    ItemType         = 'TOTALS'
    Extension        = ''
    SizeBytes        = [string]$sumSize
    LinesOfText      = [string]$sumLines
    CharacterCount   = [string]$sumChars
}
$rows.Add([PSCustomObject]$totalsRow) | Out-Null

Write-CsvWithBom -CsvPath $csvPath -SummaryLine $summaryLine -Rows $rows

# 6) Final message
Show-Header "Analysis Complete"
Write-Info "This analysis found [$totalItems] total objects, which contain a combined [$sumLines] total lines of raw text & a combined [$sumChars] individual characters."
Write-Host "Detailed results saved to:" -NoNewline; Write-Host " $csvPath" -ForegroundColor Green

# Attempt to open the CSV report automatically
try {
    Start-Process -FilePath $csvPath -ErrorAction Stop | Out-Null
} catch {
    Write-Warn "Could not automatically open the CSV: $($_.Exception.Message)"
}

# Keep the window open for readability
try { [void](Read-Host -Prompt "Press Enter to exit") } catch {}
