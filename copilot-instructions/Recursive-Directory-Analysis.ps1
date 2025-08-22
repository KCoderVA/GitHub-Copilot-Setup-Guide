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

    [switch]$DryRun
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

function Prompt-ForRootPath {
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

function Get-AuthorOrNull {
    param([string]$FullPath)
    try {
        $acl = Get-Acl -LiteralPath $FullPath -ErrorAction Stop
        if ($acl -and $acl.Owner) { return $acl.Owner }
        else { return 'null' }
    } catch {
        return 'null'
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
    if (Test-ReparsePoint -Item $Item) { return 'ReparsePoint' }
    if ($Item.PSIsContainer) { return 'Folder' }
    $ext = ($Item.Extension | ForEach-Object { $_.ToLowerInvariant() })
    if ($ext -eq '.lnk') { return 'Shortcut' }
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
    param([string]$Root)

    $result = New-Object System.Collections.Generic.List[System.IO.FileSystemInfo]

    # Include root itself
    $rootDir = Get-Item -LiteralPath $Root -Force
    $result.Add($rootDir) | Out-Null

    # Stack-based DFS to avoid following reparse points
    $stack = New-Object System.Collections.Stack
    $stack.Push($rootDir)

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
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
    }

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

    $created = try { $Item.CreationTime.ToString("yyyy-MM-ddTHH:mm:ss.fffK") } catch { 'null' }
    $modified = try { $Item.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss.fffK") } catch { 'null' }

    $name = try { $Item.Name } catch { [System.IO.Path]::GetFileName($Item.FullName) }
    $full = try { $Item.FullName } catch { $null }

    $extVal = if ($ext) { $ext } else { 'null' }
    $sizeVal = if ($null -ne $SizeBytes) { [string]$SizeBytes } else { 'null' }
    $linesVal = if ($null -ne $Lines) { [string]$Lines } else { 'null' }
    $charsVal = if ($null -ne $Chars) { [string]$Chars } else { 'null' }

    $obj = [ordered]@{
        ItemType        = $ItemType
        Name            = $name
        Extension       = $extVal
        FullPath        = $full
        SizeBytes       = $sizeVal
        CreatedTime     = $created
        LastModifiedTime= $modified
        Author          = $Author
        IsHidden        = [string]$($attrs.IsHidden)
        IsReadOnly      = [string]$($attrs.IsReadOnly)
        IsSystem        = [string]$($attrs.IsSystem)
        IsArchive       = [string]$($attrs.IsArchive)
        LinesOfText     = $linesVal
        CharacterCount  = $charsVal
    }
    return [PSCustomObject]$obj
}

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
    return "Recursive Directory Analysis summary for '$Root' at $ts — Items=$TotalItems; Files=$TotalFiles; Folders=$TotalFolders; Shortcuts=$TotalShortcuts; ReparsePoints=$TotalReparse; SumLines=$SumLines; SumChars=$SumChars; SumSizeBytes=$SumSizeBytes"
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
        # Write the single-cell summary as the first line
        $sw.WriteLine($SummaryLine)
        foreach ($line in $csvLines) { $sw.WriteLine($line) }
    } finally { $sw.Dispose() }
}

# 1) Resolve input path
$rootPath = if ($PSBoundParameters.ContainsKey('Path') -and $Path) { Resolve-TargetPath -InputPath $Path } else { $null }
if (-not $rootPath) { Show-IntroMessage; $rootPath = Prompt-ForRootPath }

# Validate directory
if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
    Write-Err "The path '$rootPath' is not a directory or does not exist."
    exit 1
}

Write-Info "Scanning: $rootPath"

# 2) Enumerate all items (including root)
$allItems = Get-AllItems -Root $rootPath

# Compute terminal summary basics
$files   = @($allItems | Where-Object { -not $_.PSIsContainer -and -not (Test-ReparsePoint -Item $_) -and ($_.Extension.ToLowerInvariant() -ne '.lnk') })
$folders = @($allItems | Where-Object { $_.PSIsContainer -and -not (Test-ReparsePoint -Item $_) })
$shorts  = @($allItems | Where-Object { -not $_.PSIsContainer -and ($_.Extension.ToLowerInvariant() -eq '.lnk') })
$reparse = @($allItems | Where-Object { Test-ReparsePoint -Item $_ })

$totalItems = $allItems.Count
$totalFiles = $files.Count
$totalFolders = $folders.Count
$totalShortcuts = $shorts.Count
$totalReparse = $reparse.Count

# Extension summary (files only, excluding shortcuts treated separately)
$extSummary = $files | ForEach-Object { $_.Extension.ToLowerInvariant() } | Group-Object | Sort-Object Count -Descending
$topN = 10
$topExt = $extSummary | Select-Object -First $topN

Write-Info "Summary of '$rootPath':"
Write-Info "  Total items: $totalItems (Files=$totalFiles, Folders=$totalFolders, Shortcuts=$totalShortcuts, ReparsePoints=$totalReparse)"
if ($topExt) {
    Write-Info "  Top extensions:"
    foreach ($g in $topExt) {
        $extName = if ($g.Name) { $g.Name } else { '(no extension)' }
        Write-Info "    $extName : $($g.Count)"
    }
}

if ($DryRun) {
    Write-Info "DRY RUN: Enumeration complete. No content analysis performed and no CSV generated. Re-run without -DryRun to produce the CSV report."
    exit 0
}

# 4) Analysis and row building
$rows = New-Object System.Collections.Generic.List[object]

[int64]$sumLines = 0
[int64]$sumChars = 0
[int64]$sumSize  = 0

foreach ($item in $allItems) {
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
}

# 5) CSV Generation
$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$csvPath = Join-Path -Path $rootPath -ChildPath "RecursiveDirectoryAnalysis_$timestamp.csv"

$summaryLine = Build-CsvSummaryLine -TotalItems $totalItems -TotalFiles $totalFiles -TotalFolders $totalFolders -TotalShortcuts $totalShortcuts -TotalReparse $totalReparse -SumLines $sumLines -SumChars $sumChars -SumSizeBytes $sumSize -Root $rootPath

# Footer totals row (same columns)
$totalsRow = [ordered]@{
    ItemType         = 'TOTALS'
    Name             = "Items=$totalItems; Files=$totalFiles; Folders=$totalFolders; Shortcuts=$totalShortcuts; ReparsePoints=$totalReparse"
    Extension        = 'null'
    FullPath         = 'null'
    SizeBytes        = [string]$sumSize
    CreatedTime      = 'null'
    LastModifiedTime = 'null'
    Author           = 'null'
    IsHidden         = 'null'
    IsReadOnly       = 'null'
    IsSystem         = 'null'
    IsArchive        = 'null'
    LinesOfText      = [string]$sumLines
    CharacterCount   = [string]$sumChars
}
$rows.Add([PSCustomObject]$totalsRow) | Out-Null

Write-CsvWithBom -CsvPath $csvPath -SummaryLine $summaryLine -Rows $rows

# 6) Final message
Write-Info "Recursive Directory Analysis is now complete. This analysis found [$totalItems] total objects, which contain a combined [$sumLines] total lines of raw text & a combined [$sumChars] individual characters. Detailed results saved to: $csvPath"
