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

# Clean-Workspace.ps1
# VA Power Platform Workspace Cleanup Script
# Author: Kyle J. Coder - Edward Hines Jr. VA Hospital
# Purpose: Safely cleans temporary files, logs, and outdated items from the workspace

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Quick', 'Standard', 'Deep', 'Archive')]
    [string]$CleanupLevel = 'Standard',

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Interactive,

    [Parameter(Mandatory = $false)]
    [int]$KeepLogsDays = 30,

    [Parameter(Mandatory = $false)]
    [int]$KeepBackupsDays = 7
)

# Error handling and logging
$ErrorActionPreference = 'Continue'
$LogPath = "$PSScriptRoot\..\logs\cleanup-operations.log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    if (!(Test-Path (Split-Path $LogPath))) {
        New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $LogEntry
}

function Get-CleanupTargets {
    param([string]$Level)

    $WorkspaceRoot = Split-Path $PSScriptRoot -Parent
    $Targets = @()

    # Common temporary files and patterns (all levels)
    $CommonPatterns = @(
        @{ Path = "$WorkspaceRoot\**"; Pattern = '*.tmp'; Description = 'Temporary files' },
        @{ Path = "$WorkspaceRoot\**"; Pattern = '*.cache'; Description = 'Cache files' },
        @{ Path = "$WorkspaceRoot\**"; Pattern = 'Thumbs.db'; Description = 'Windows thumbnail cache' },
        @{ Path = "$WorkspaceRoot\**"; Pattern = '.DS_Store'; Description = 'macOS metadata files' },
        @{ Path = "$WorkspaceRoot\**"; Pattern = 'desktop.ini'; Description = 'Windows folder config files' },
        @{ Path = "$WorkspaceRoot\src\**"; Pattern = '~*'; Description = 'Office temporary files' },
        @{ Path = "$WorkspaceRoot\src\**"; Pattern = 'TEMP_*'; Description = 'Temp prefixed files' }
    )

    $Targets += $CommonPatterns

    # Standard cleanup (includes Quick + more)
    if ($Level -in @('Standard', 'Deep', 'Archive')) {
        $StandardPatterns = @(
            @{ Path = "$WorkspaceRoot\logs"; Pattern = '*.log'; Description = 'Old log files'; DaysOld = $KeepLogsDays },
            @{ Path = "$WorkspaceRoot\archive\msapp-backups"; Pattern = '*.msapp'; Description = 'Old .msapp backups'; DaysOld = $KeepBackupsDays },
            @{ Path = "$WorkspaceRoot\archive\sql-exports"; Pattern = '*.sql'; Description = 'Old SQL exports'; DaysOld = $KeepBackupsDays },
            @{ Path = "$WorkspaceRoot\src\**"; Pattern = '*.bak'; Description = 'Backup files' },
            @{ Path = "$WorkspaceRoot\src\**"; Pattern = '*.orig'; Description = 'Original files from merges' }
        )
        $Targets += $StandardPatterns
    }

    # Deep cleanup (includes Standard + more aggressive)
    if ($Level -in @('Deep', 'Archive')) {
        $DeepPatterns = @(
            @{ Path = "$WorkspaceRoot\src\powerapps\**"; Pattern = '*.msapp.src'; Description = 'Intermediate unpack files' },
            @{ Path = "$WorkspaceRoot\.vscode"; Pattern = '*.log'; Description = 'VS Code logs' },
            @{ Path = "$WorkspaceRoot\scripts"; Pattern = '*.ps1.orig'; Description = 'Script backup files' },
            @{ Path = "$WorkspaceRoot\docs"; Pattern = '*.docx~*'; Description = 'Word auto-save files' }
        )
        $Targets += $DeepPatterns
    }

    # Archive cleanup (includes Deep + archival operations)
    if ($Level -eq 'Archive') {
        $ArchivePatterns = @(
            @{ Path = "$WorkspaceRoot\archive\cleanup"; Pattern = '*'; Description = 'Items marked for cleanup'; DaysOld = 0 },
            @{ Path = "$WorkspaceRoot\logs"; Pattern = 'productivity-log-*.md'; Description = 'Old productivity logs'; DaysOld = 90 }
        )
        $Targets += $ArchivePatterns
    }

    return $Targets
}

function Get-FilesToClean {
    param($Target)

    $FilesToClean = @()

    try {
        if (Test-Path $Target.Path) {
            $SearchPath = Split-Path $Target.Path -Parent
            $SearchPattern = Split-Path $Target.Path -Leaf

            if ($SearchPattern -eq '**') {
                $Files = Get-ChildItem -Path $SearchPath -Filter $Target.Pattern -Recurse -File -ErrorAction SilentlyContinue
            }
            else {
                $Files = Get-ChildItem -Path $Target.Path -Filter $Target.Pattern -File -ErrorAction SilentlyContinue
            }

            foreach ($File in $Files) {
                $ShouldInclude = $true

                # Check age criteria if specified
                if ($Target.DaysOld -ne $null) {
                    $CutoffDate = (Get-Date).AddDays(-$Target.DaysOld)
                    if ($File.LastWriteTime -gt $CutoffDate) {
                        $ShouldInclude = $false
                    }
                }

                # Exclude protected files
                $ProtectedPatterns = @('*reference*', '*template*', '*sample*')
                foreach ($Pattern in $ProtectedPatterns) {
                    if ($File.Name -like $Pattern) {
                        $ShouldInclude = $false
                        break
                    }
                }

                if ($ShouldInclude) {
                    $FilesToClean += $File
                }
            }
        }
    }
    catch {
        Write-Log "Error scanning for files: $($_.Exception.Message)" 'WARN'
    }

    return $FilesToClean
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    elseif ($Bytes -lt 1MB) { return "$([math]::Round($Bytes / 1KB, 2)) KB" }
    elseif ($Bytes -lt 1GB) { return "$([math]::Round($Bytes / 1MB, 2)) MB" }
    else { return "$([math]::Round($Bytes / 1GB, 2)) GB" }
}

function Confirm-CleanupAction {
    param([array]$Files, [string]$Description)

    if ($Files.Count -eq 0) { return $false }

    $TotalSize = ($Files | Measure-Object -Property Length -Sum).Sum

    Write-Host "`n📋 $Description" -ForegroundColor Cyan
    Write-Host "   Files to clean: $($Files.Count)" -ForegroundColor Yellow
    Write-Host "   Total size: $(Format-FileSize $TotalSize)" -ForegroundColor Yellow

    if ($Interactive) {
        Write-Host '   Sample files:' -ForegroundColor Gray
        $Files | Select-Object -First 5 | ForEach-Object {
            Write-Host "     - $($_.Name) ($(Format-FileSize $_.Length))" -ForegroundColor Gray
        }
        if ($Files.Count -gt 5) {
            Write-Host "     ... and $($Files.Count - 5) more" -ForegroundColor Gray
        }

        $Response = Read-Host '   Clean these files? (y/N)'
        return ($Response -eq 'y' -or $Response -eq 'Y')
    }

    return $true
}

function Remove-Files {
    param([array]$Files, [string]$Description)

    $RemovedCount = 0
    $RemovedSize = 0
    $Errors = @()

    foreach ($File in $Files) {
        try {
            if (!$DryRun) {
                $Size = $File.Length
                Remove-Item -Path $File.FullName -Force
                $RemovedCount++
                $RemovedSize += $Size
            }
            else {
                Write-Host "   [DRY RUN] Would remove: $($File.FullName)" -ForegroundColor Gray
                $RemovedCount++
                $RemovedSize += $File.Length
            }
        }
        catch {
            $Errors += "Failed to remove $($File.FullName): $($_.Exception.Message)"
        }
    }

    return @{
        RemovedCount = $RemovedCount
        RemovedSize  = $RemovedSize
        Errors       = $Errors
    }
}

try {
    Write-Log "Starting workspace cleanup - Level: $CleanupLevel" 'INFO'

    if ($DryRun) {
        Write-Host '🔍 DRY RUN MODE - No files will actually be deleted' -ForegroundColor Yellow
    }

    if ($Interactive) {
        Write-Host '🤝 INTERACTIVE MODE - You will be prompted before each cleanup action' -ForegroundColor Cyan
    }

    Write-Host "`n🧹 VA Power Platform Workspace Cleanup" -ForegroundColor Green
    Write-Host '=======================================' -ForegroundColor Green
    Write-Host "Cleanup Level: $CleanupLevel" -ForegroundColor White
    Write-Host "Keep Logs: $KeepLogsDays days" -ForegroundColor White
    Write-Host "Keep Backups: $KeepBackupsDays days" -ForegroundColor White

    $CleanupTargets = Get-CleanupTargets -Level $CleanupLevel
    $TotalRemovedCount = 0
    $TotalRemovedSize = 0
    $AllErrors = @()

    foreach ($Target in $CleanupTargets) {
        Write-Log "Processing cleanup target: $($Target.Description)" 'INFO'

        $FilesToClean = Get-FilesToClean -Target $Target

        if ($FilesToClean.Count -gt 0) {
            $ShouldClean = Confirm-CleanupAction -Files $FilesToClean -Description $Target.Description

            if ($ShouldClean) {
                $Result = Remove-Files -Files $FilesToClean -Description $Target.Description

                $TotalRemovedCount += $Result.RemovedCount
                $TotalRemovedSize += $Result.RemovedSize
                $AllErrors += $Result.Errors

                if ($Result.RemovedCount -gt 0) {
                    $Action = if ($DryRun) { 'Would clean' } else { 'Cleaned' }
                    Write-Host "   ✅ $Action $($Result.RemovedCount) files ($(Format-FileSize $Result.RemovedSize))" -ForegroundColor Green
                }

                if ($Result.Errors.Count -gt 0) {
                    Write-Host "   ⚠️  $($Result.Errors.Count) errors occurred" -ForegroundColor Yellow
                    foreach ($ErrorMessage in $Result.Errors) {
                        Write-Log $ErrorMessage 'ERROR'
                    }
                }
            }
            else {
                Write-Host '   ⏭️  Skipped' -ForegroundColor Gray
            }
        }
        else {
            Write-Host '   ✨ No files to clean' -ForegroundColor Gray
        }
    }

    # Summary
    Write-Host "`n📊 Cleanup Summary" -ForegroundColor Green
    Write-Host '==================' -ForegroundColor Green

    if ($TotalRemovedCount -gt 0) {
        $Action = if ($DryRun) { 'Would clean' } else { 'Cleaned' }
        Write-Host "✅ $Action $TotalRemovedCount files" -ForegroundColor Green
        Write-Host "💾 Space freed: $(Format-FileSize $TotalRemovedSize)" -ForegroundColor Green
    }
    else {
        Write-Host '✨ No files needed cleaning' -ForegroundColor Green
    }

    if ($AllErrors.Count -gt 0) {
        Write-Host "⚠️  $($AllErrors.Count) errors occurred" -ForegroundColor Yellow
        Write-Host "   Check the log for details: $LogPath" -ForegroundColor Gray
    }

    # Update productivity log
    if (!$DryRun -and $TotalRemovedCount -gt 0) {
        $ProductivityPath = "$PSScriptRoot\..\logs\productivity-log-$(Get-Date -Format 'yyyy-MM-dd').md"
        $ProductivityEntry = @"

## $(Get-Date -Format 'HH:mm') - Workspace Cleanup
**Level:** $CleanupLevel
**Files Cleaned:** $TotalRemovedCount
**Space Freed:** $(Format-FileSize $TotalRemovedSize)
**Errors:** $($AllErrors.Count)
**Status:** Success

"@

        if (!(Test-Path $ProductivityPath)) {
            $Header = "# Productivity Log - $(Get-Date -Format 'MMMM dd, yyyy')`n**Author:** Kyle J. Coder`n**Team:** Clinical Informatics & Advanced Analytics`n"
            Set-Content -Path $ProductivityPath -Value $Header -Encoding UTF8
        }

        Add-Content -Path $ProductivityPath -Value $ProductivityEntry -Encoding UTF8
    }

    Write-Host "`n🎯 Cleanup completed successfully!" -ForegroundColor Green

}
catch {
    Write-Log "Error during workspace cleanup: $($_.Exception.Message)" 'ERROR'
    Write-Host "❌ Error during cleanup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
