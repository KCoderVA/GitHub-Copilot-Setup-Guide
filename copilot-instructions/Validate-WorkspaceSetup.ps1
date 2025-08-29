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

# Validate-WorkspaceSetup.ps1
# VA Power Platform Workspace Validation Script
# Author: Kyle J. Coder - Edward Hines Jr. VA Hospital
# Purpose: Simple workspace validation for VA Power Platform projects

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$FixIssues,
    [string]$OutputPath = ''
)

# Simple validation script
$WorkspaceRoot = Split-Path $PSScriptRoot -Parent
$ErrorCount = 0
$WarningCount = 0
$PassCount = 0

# Collections for JSON report
$MissingDirs = @()
$MissingFiles = @()
$InvalidJsonFiles = @()
$WorkspaceFilesFound = @()
$ScriptSyntaxErrors = @()
$Dependencies = [ordered]@{ Git = $false; PAC = $false }

Write-Host "VA Power Platform Workspace Validation" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

# 1. Check Required Directories
Write-Host "`nChecking directory structure..." -ForegroundColor Yellow

$RequiredDirs = @(
    '.vscode', 'src', 'scripts', 'docs', 'templates',
    'sample-data', 'assets', 'logs'
)

foreach ($Dir in $RequiredDirs) {
    $DirPath = Join-Path $WorkspaceRoot $Dir
    if (Test-Path $DirPath) {
        Write-Host "   PASS: $Dir" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "   FAIL: $Dir (Missing)" -ForegroundColor Red
        $ErrorCount++
    $MissingDirs += $Dir

        if ($FixIssues) {
            try {
                New-Item -Path $DirPath -ItemType Directory -Force | Out-Null
                Write-Host "   FIXED: Created $Dir" -ForegroundColor Cyan
                $ErrorCount--
                $PassCount++
            } catch {
                Write-Host "   ERROR: Failed to create $Dir" -ForegroundColor Yellow
            }
        }
    }
}

# 2. Check Required Files
Write-Host "`nChecking required files..." -ForegroundColor Yellow

$RequiredFiles = @(
    'README.md',
    'copilot-instructions\Generate-ProductivityReport.ps1',
    'copilot-instructions\Clean-Workspace.ps1'
)

foreach ($File in $RequiredFiles) {
    $FilePath = Join-Path $WorkspaceRoot $File
    if (Test-Path $FilePath) {
        Write-Host "   PASS: $File" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "   FAIL: $File (Missing)" -ForegroundColor Red
        $ErrorCount++
    $MissingFiles += $File
    }
}

# 3. Check VS Code Configuration
Write-Host "`nChecking VS Code configuration..." -ForegroundColor Yellow

$VSCodeFiles = @(
    '.vscode\settings.json',
    '.vscode\tasks.json'
)

foreach ($File in $VSCodeFiles) {
    $FilePath = Join-Path $WorkspaceRoot $File
    if (Test-Path $FilePath) {
        try {
            $Content = Get-Content $FilePath -Raw
            $null = $Content | ConvertFrom-Json
            Write-Host "   PASS: $File (Valid JSON)" -ForegroundColor Green
            $PassCount++
        } catch {
            Write-Host "   WARN: $File (Invalid JSON)" -ForegroundColor Yellow
            $WarningCount++
            $InvalidJsonFiles += $File
        }
    } else {
        Write-Host "   FAIL: $File (Missing)" -ForegroundColor Red
        $ErrorCount++
        $MissingFiles += $File
    }
}

# 4. Check .github instructions file
Write-Host "`nChecking Copilot instructions (.github) ..." -ForegroundColor Yellow
$GithubDir = Join-Path $WorkspaceRoot '.github'
$InstructionsPath = Join-Path $GithubDir 'copilot-instructions.md'
if (Test-Path $InstructionsPath) {
    Write-Host "   PASS: .github\\copilot-instructions.md present" -ForegroundColor Green
    $PassCount++
} else {
    Write-Host "   FAIL: .github\\copilot-instructions.md missing" -ForegroundColor Red
    $ErrorCount++
    $MissingFiles += ".github\\copilot-instructions.md"
    $InstallerBat = Join-Path $WorkspaceRoot 'copilot-instructions\Install-Copilot-Instructions.bat'
    if ($FixIssues -and (Test-Path $InstallerBat)) {
        Write-Host "   FIX: Running installer to create/update instructions..." -ForegroundColor Cyan
        try {
            $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', '"' + $InstallerBat + '"' -Wait -PassThru -WindowStyle Hidden
            if ($p.ExitCode -eq 0 -and (Test-Path $InstructionsPath)) {
                Write-Host "   FIXED: Instructions installed" -ForegroundColor Green
                $ErrorCount--
                $PassCount++
            } else {
                Write-Host "   WARN: Installer exited with code $($p.ExitCode)." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "   WARN: Failed to run installer: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        if (-not (Test-Path $InstallerBat)) {
            Write-Host "   HINT: Run copilot-instructions\\Install-Copilot-Instructions.bat to set this up." -ForegroundColor Gray
        }
    }
}

# 5. Check Workspace File
Write-Host "`nChecking workspace file..." -ForegroundColor Yellow

$WorkspaceFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.code-workspace" -ErrorAction SilentlyContinue
if ($WorkspaceFiles.Count -gt 0) {
    Write-Host "   PASS: Workspace file found" -ForegroundColor Green
    $PassCount++

    if ($WorkspaceFiles.Count -gt 1) {
        Write-Host "   WARN: Multiple workspace files found" -ForegroundColor Yellow
        $WarningCount++
    }
    $WorkspaceFilesFound = $WorkspaceFiles | ForEach-Object { $_.Name }
} else {
    Write-Host "   FAIL: No workspace file found" -ForegroundColor Red
    $ErrorCount++
}

# 6. Check External Dependencies
Write-Host "`nChecking external dependencies..." -ForegroundColor Yellow

# Check Git
try {
    $null = git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   PASS: Git installed" -ForegroundColor Green
        $PassCount++
        $Dependencies.Git = $true
    } else {
        Write-Host "   WARN: Git not found" -ForegroundColor Yellow
        $WarningCount++
        $Dependencies.Git = $false
    }
} catch {
    Write-Host "   WARN: Git not found" -ForegroundColor Yellow
    $WarningCount++
    $Dependencies.Git = $false
}

# Check Power Platform CLI
try {
    $null = pac --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   PASS: Power Platform CLI installed" -ForegroundColor Green
        $PassCount++
        $Dependencies.PAC = $true
    } else {
        Write-Host "   WARN: Power Platform CLI not found" -ForegroundColor Yellow
        $WarningCount++
        $Dependencies.PAC = $false
    }
} catch {
    Write-Host "   WARN: Power Platform CLI not found" -ForegroundColor Yellow
    $WarningCount++
    $Dependencies.PAC = $false
}

# 7. Check PowerShell Scripts Syntax
Write-Host "`nValidating script syntax..." -ForegroundColor Yellow

$ScriptFiles = Get-ChildItem -Path (Join-Path $WorkspaceRoot "scripts") -Filter "*.ps1" -ErrorAction SilentlyContinue

foreach ($Script in $ScriptFiles) {
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $Script.FullName -Raw), [ref]$null)
        Write-Host "   PASS: $($Script.Name)" -ForegroundColor Green
        $PassCount++
    } catch {
        Write-Host "   FAIL: $($Script.Name) (Syntax error)" -ForegroundColor Red
        $ErrorCount++
        if ($Detailed) {
            Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Gray
        }
    $ScriptSyntaxErrors += [ordered]@{ File = $Script.Name; Message = $_.Exception.Message }
    }
}

# Generate Summary
Write-Host "`nValidation Summary" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

$TotalChecks = $PassCount + $ErrorCount + $WarningCount

if ($ErrorCount -eq 0 -and $WarningCount -eq 0) {
    Write-Host "EXCELLENT - All validations passed!" -ForegroundColor Green
    Write-Host "Your workspace is ready for VA Power Platform development." -ForegroundColor Green
} elseif ($ErrorCount -eq 0) {
    Write-Host "GOOD - Some warnings found but workspace is functional" -ForegroundColor Yellow
    Write-Host "Consider addressing warnings for optimal experience." -ForegroundColor Yellow
} else {
    Write-Host "ISSUES FOUND - Errors need attention before proceeding" -ForegroundColor Red
    Write-Host "Please fix critical errors before using the workspace." -ForegroundColor Red
}

Write-Host "`nResults:" -ForegroundColor White
Write-Host "   Passed: $PassCount" -ForegroundColor Green
Write-Host "   Warnings: $WarningCount" -ForegroundColor Yellow
Write-Host "   Errors: $ErrorCount" -ForegroundColor Red
Write-Host "   Total Checks: $TotalChecks" -ForegroundColor Cyan

# Save report if requested (Markdown)
if ($OutputPath) {
    $ReportContent = @"
# VA Power Platform Workspace Validation Report

**Generated:** $(Get-Date -Format "MMMM dd, yyyy at HH:mm")
**Author:** Kyle J. Coder
**Facility:** Edward Hines Jr. VA Hospital

## Summary
- Passed: $PassCount
- Warnings: $WarningCount
- Errors: $ErrorCount
- Total: $TotalChecks

## Status
$(if ($ErrorCount -eq 0 -and $WarningCount -eq 0) { "EXCELLENT - All validations passed!" }
elseif ($ErrorCount -eq 0) { "GOOD - Minor warnings found" }
else { "ISSUES FOUND - Errors require attention" })

---
Generated by VA Power Platform Workspace Template (updated Aug 2025)
"@

    try {
        Set-Content -Path $OutputPath -Value $ReportContent -Encoding UTF8
        Write-Host "`nReport saved: $OutputPath" -ForegroundColor Cyan
    } catch {
        Write-Host "`nFailed to save report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Always produce a JSON report to a temp file if errors or warnings were found, then trigger guidance generator
if ($ErrorCount -gt 0 -or $WarningCount -gt 0) {
    try {
        $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $tempJson = Join-Path $env:TEMP "workspace-validation-$ts.json"
        $jsonReport = [ordered]@{
            GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
            Root         = $WorkspaceRoot
            Summary      = [ordered]@{ Passed = $PassCount; Warnings = $WarningCount; Errors = $ErrorCount; TotalChecks = $TotalChecks }
            Findings     = [ordered]@{
                MissingDirs       = $MissingDirs
                MissingFiles      = $MissingFiles
                InvalidJsonFiles  = $InvalidJsonFiles
                WorkspaceFiles    = $WorkspaceFilesFound
                Dependencies      = $Dependencies
                ScriptSyntaxErrors= $ScriptSyntaxErrors
                Workspace         = [ordered]@{
                    HasWorkspaceFile     = ($WorkspaceFilesFound.Count -gt 0)
                    MultipleWorkspaceFiles= ($WorkspaceFilesFound.Count -gt 1)
                }
            }
        }
        $jsonReport | ConvertTo-Json -Depth 8 | Set-Content -Path $tempJson -Encoding UTF8
        Write-Host "`nJSON report created: $tempJson" -ForegroundColor Cyan

    # Create the educational HTML in the workspace root (per requirements)
    $outHtml = Join-Path $WorkspaceRoot "Workspace-Guidance-$ts.html"

        $guidanceScript = Join-Path $PSScriptRoot 'Generate-WorkspaceGuidance.ps1'
        if (Test-Path $guidanceScript) {
            try {
                & $guidanceScript -JsonReport $tempJson -OutputHtml $outHtml -Open -DeleteJson
            } catch {
                Write-Host "WARN: Failed to generate guidance: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "HINT: Guidance script not found: $guidanceScript" -ForegroundColor Gray
        }
    } catch {
        Write-Host "WARN: Failed to create JSON report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nValidation complete!" -ForegroundColor Green

# Return appropriate exit code
if ($ErrorCount -gt 0) {
    exit 1
} else {
    exit 0
}
