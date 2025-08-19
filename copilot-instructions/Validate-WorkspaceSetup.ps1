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
    'scripts\Generate-ProductivityReport.ps1',
    'scripts\Clean-Workspace.ps1',
    'scripts\Unpack-PowerApp.ps1',
    'scripts\Pack-PowerApp.ps1'
)

foreach ($File in $RequiredFiles) {
    $FilePath = Join-Path $WorkspaceRoot $File
    if (Test-Path $FilePath) {
        Write-Host "   PASS: $File" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "   FAIL: $File (Missing)" -ForegroundColor Red
        $ErrorCount++
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
        }
    } else {
        Write-Host "   FAIL: $File (Missing)" -ForegroundColor Red
        $ErrorCount++
    }
}

# 4. Check Workspace File
Write-Host "`nChecking workspace file..." -ForegroundColor Yellow

$WorkspaceFiles = Get-ChildItem -Path $WorkspaceRoot -Filter "*.code-workspace" -ErrorAction SilentlyContinue
if ($WorkspaceFiles.Count -gt 0) {
    Write-Host "   PASS: Workspace file found" -ForegroundColor Green
    $PassCount++

    if ($WorkspaceFiles.Count -gt 1) {
        Write-Host "   WARN: Multiple workspace files found" -ForegroundColor Yellow
        $WarningCount++
    }
} else {
    Write-Host "   FAIL: No workspace file found" -ForegroundColor Red
    $ErrorCount++
}

# 5. Check External Dependencies
Write-Host "`nChecking external dependencies..." -ForegroundColor Yellow

# Check Git
try {
    $null = git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   PASS: Git installed" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "   WARN: Git not found" -ForegroundColor Yellow
        $WarningCount++
    }
} catch {
    Write-Host "   WARN: Git not found" -ForegroundColor Yellow
    $WarningCount++
}

# Check Power Platform CLI
try {
    $null = pac --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   PASS: Power Platform CLI installed" -ForegroundColor Green
        $PassCount++
    } else {
        Write-Host "   WARN: Power Platform CLI not found" -ForegroundColor Yellow
        $WarningCount++
    }
} catch {
    Write-Host "   WARN: Power Platform CLI not found" -ForegroundColor Yellow
    $WarningCount++
}

# 6. Check PowerShell Scripts Syntax
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

# Save report if requested
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
Generated by VA Power Platform Workspace Template
"@

    try {
        Set-Content -Path $OutputPath -Value $ReportContent -Encoding UTF8
        Write-Host "`nReport saved: $OutputPath" -ForegroundColor Cyan
    } catch {
        Write-Host "`nFailed to save report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nValidation complete!" -ForegroundColor Green

# Return appropriate exit code
if ($ErrorCount -gt 0) {
    exit 1
} else {
    exit 0
}
