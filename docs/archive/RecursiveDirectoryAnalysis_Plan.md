# Recursive Directory Analysis Script — Implementation Plan

This document outlines the end-to-end plan to build a portable PowerShell script that recursively inventories a target directory, summarizes results in the terminal, performs per-item analysis, and writes a CSV report with a summary row at the top and a totals footer row at the end.

## Decisions and Requirements (locked)
- Target shell: PowerShell (Windows PowerShell 5.1 and PowerShell 7+ compatible)
- Prompt user for target path if not provided via parameter
- Recurse all contents, including hidden files and folders
- Count all items of any type (files, folders, links/shortcuts, reparse points)
- Do NOT traverse into linked folders (reparse points); list the link item itself only
- Include .lnk shortcut files as their own items; do not resolve targets
- Author field: NTFS Owner; if unavailable, put literal "null"
- File size: logical size in bytes for files; folders get literal "null"
- Timestamps: ISO 8601 in local time (CreatedTime, LastModifiedTime)
- Binary/unreadable files: included as items with metadata; Lines/Characters set to literal "null"
- Text content metrics: count all characters (including spaces, tabs, newline characters CR/LF) and lines (include blank lines; 0 for empty file)
- Terminal summary: concise (overall totals + top extensions), full detail only in CSV
- CSV layout (Option A):
  - Row 1: a single-cell summary line
  - Row 2: column headers
  - Rows 3..N: data rows (one per item)
  - Final row: totals/footer
- CSV encoding: UTF-8 with BOM (Excel-friendly)
- Paths: include Full absolute path column only (no relative path)
- Dry run: perform full enumeration and terminal summary; do NOT perform per-item content analysis; do NOT write CSV; exit with a helpful prompt

## Output CSV Columns (proposed)
- ItemType (File | Folder | Shortcut | ReparsePoint)
- Name
- Extension (folders may be empty; use "null" where not applicable)
- FullPath (absolute path; unique per row)
- SizeBytes (files only; folders and non-file items: "null")
- CreatedTime (ISO 8601 local)
- LastModifiedTime (ISO 8601 local)
- Author (NTFS owner or "null")
- IsHidden (True/False)
- IsReadOnly (True/False)
- IsSystem (True/False)
- IsArchive (True/False)
- LinesOfText (text files only; otherwise "null")
- CharacterCount (text files only; otherwise "null")

Notes:
- Additional practical columns included per request: ItemType, LastModifiedTime, attribute flags
- No LinkTarget column (by decision)

## Architecture Overview
- Single script file in `copilot-instructions/` (portable, no repo-specific assumptions)
- Parameterized execution with interactive fallback
- Two-phase operation:
  1) Enumeration phase (always, includes dry run)
  2) Analysis + CSV output phase (skipped in dry run)
- Custom recursive traversal to avoid entering reparse points while still listing them
- Binary detection heuristic (fast, safe): initial byte sample check for NUL byte; otherwise treat as text
- Text metrics via streaming reader to handle large files; counts characters and lines accurately across CR/LF variants

## Phase 1a — Script Scaffolding
- Create script file `Recursive-Directory-Analysis.ps1`
- Param block:
  - `-Path <string>` (optional; prompt if missing)
  - `-DryRun` (switch)
  - `-Verbose` passthrough support
- Strict mode, error preferences, and helpful comments throughout

## Phase 1b — Input & Validation
- If `-Path` not provided, prompt user in terminal for a directory path
- Validate path exists and is a directory; friendly error if not
- Normalize to absolute path

## Phase 2a — Enumeration (all items)
- Include starting root folder itself as an item
- Depth-first traversal:
  - For each directory: list directory item
  - If directory is a reparse point: do not descend; continue
  - Otherwise enumerate children and push subdirectories
- Include hidden/system items
- Capture minimal metadata during enumeration to support terminal summary

## Phase 2b — Terminal Summary (concise)
- Compute totals: items, files, folders, shortcuts, reparse points
- Group files by extension; display top N extensions and counts (N=10)
- Print formatted one-line or short multi-line summary

## Phase 3 — Dry Run Exit Path
- If `-DryRun`: print clear completion message indicating a dry run
- Suggest rerun without `-DryRun` to produce CSV
- Exit 0

## Phase 4a — Content Analysis (text files)
- For each non-binary file:
  - Open a StreamReader with BOM detection
  - Stream through content in char buffers and tally:
    - CharacterCount: count every character including CR/LF/TAB/whitespace
    - LinesOfText: count occurrences of `\n` + add final line if last char isn’t `\n` and file non-empty
- For binary/unreadable: set LinesOfText/CharacterCount to literal `null`

## Phase 4b — Metadata Collection (all items)
- Build PSCustomObject per item with all columns
- Author via `Get-Acl` owner (catch and set `"null"` on failures)
- SizeBytes for files (Length); `"null"` for non-files
- Extension as lowercase; `"null"` for non-files
- Attributes to booleans (Hidden/ReadOnly/System/Archive)

## Phase 5 — CSV Generation (UTF-8 with BOM)
- Filename: `RecursiveDirectoryAnalysis_YYYYMMDD_HHmmss.csv` in the root path
- Row 1: single-cell summary text
- Row 2: column headers (exact order as defined)
- Rows 3..N: data rows
- Final row: totals/footer
  - Totals for numeric columns (SizeBytes sum over files, LinesOfText/CharacterCount sum over text files)
  - Counts for item types
- Implementation detail:
  - Use `ConvertTo-Csv` to produce header + rows; write header and rows manually to allow the custom first summary row; ensure `-Encoding utf8BOM`

## Phase 6 — Final Terminal Message
- Print completion message with totals and CSV file path
  - Include explicit dry/run indicator if applicable

## Phase 7 — Error Handling & Troubleshooting
- Try/catch around filesystem access; continue on per-item failures
- Permissions or locked files: log a warning; set fields to `"null"`
- Invalid path or non-directory: friendly error and exit 1
- Add inline comments with tips and a troubleshooting section in the script header

## Phase 8 — Validation
- Quick smoke tests on a small test tree (hidden items, .lnk, reparse point, text and binary)
- Verify:
  - Enumeration counts
  - Text metrics on known small files
  - CSV opens cleanly in Excel with BOM
  - Dry run skips CSV generation

## Phase 9 — Future Enhancements (deferred)
- Optional: progress indicator and rate-limited console updates
- Optional: parallel analysis with throttling for very large trees
- Optional: include hash checksums (MD5/SHA256) when requested
- Optional: additional encodings detection if needed beyond BOM

---

If approved, the next step is to implement `Recursive-Directory-Analysis.ps1` per the phases above and commit it under `copilot-instructions/`.