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
  Generate a detailed HTML guidance file from a workspace validation JSON report.

.DESCRIPTION
  Reads a machine-readable validation report (JSON) emitted by Validate-WorkspaceSetup.ps1
  and creates a highly detailed, step-by-step HTML document that educates the user on how
  to resolve each error or warning. Optionally opens the HTML on completion and deletes
  the JSON report when finished.

.PARAMETER JsonReport
  Path to the JSON report created by Validate-WorkspaceSetup.ps1.

.PARAMETER OutputHtml
  Optional path for the generated HTML file. If omitted, will create a temp file.

.PARAMETER Open
  Opens the generated HTML in the default browser.

.PARAMETER DeleteJson
  Deletes the JsonReport file after the HTML is created.

.EXAMPLE
  pwsh -File Generate-WorkspaceGuidance.ps1 -JsonReport "$env:TEMP\workspace-validation-20250101-010101.json" -Open -DeleteJson
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string] $JsonReport,
  [string] $OutputHtml,
  [switch] $Open,
  [switch] $DeleteJson
)

Write-Host "Generate Workspace Guidance" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

if (-not (Test-Path -LiteralPath $JsonReport)) {
  throw "JsonReport not found: $JsonReport"
}

try {
  $data = Get-Content -LiteralPath $JsonReport -Raw | ConvertFrom-Json -Depth 10
} catch {
  throw "Failed to parse JSON report: $($_.Exception.Message)"
}

$root = $data.Root
if (-not $OutputHtml) {
  $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
  if ($root -and (Test-Path -LiteralPath $root)) {
    $OutputHtml = Join-Path $root "Workspace-Guidance-$ts.html"
  } else {
    $OutputHtml = Join-Path $env:TEMP "Workspace-Guidance-$ts.html"
  }
}

function _escHtml([string] $s) {
  if ($null -eq $s) { return '' }
  return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;')
}

# Normalize findings
$missingDirs  = @($data.Findings.MissingDirs)           | Where-Object { $_ }
$missingFiles = @($data.Findings.MissingFiles)          | Where-Object { $_ }
$invalidJson  = @($data.Findings.InvalidJsonFiles)      | Where-Object { $_ }
$deps         = $data.Findings.Dependencies
$scriptErrors = @($data.Findings.ScriptSyntaxErrors)    | Where-Object { $_ }
$ws           = $data.Findings.Workspace

# Dependency booleans (safe if null)
$depsGit = $false
$depsPac = $false
if ($deps -and $deps.PSObject.Properties['Git']) { $depsGit = [bool]$deps.Git }
if ($deps -and $deps.PSObject.Properties['PAC']) { $depsPac = [bool]$deps.PAC }

# Derived flags
$hasDepIssues         = (-not $depsGit) -or (-not $depsPac)
$hasInvalidJson       = $invalidJson.Count -gt 0
$hasMissingDirs       = $missingDirs.Count -gt 0
$hasMissingFiles      = $missingFiles.Count -gt 0
$hasMissingTasks      = ($missingFiles -contains ".vscode\tasks.json") -or ($invalidJson -contains ".vscode\tasks.json")
$hasMissingSettings   = ($missingFiles -contains ".vscode\settings.json") -or ($invalidJson -contains ".vscode\settings.json")
$hasMissingOpsScripts = ($missingFiles -contains "copilot-instructions\Generate-ProductivityReport.ps1") -or ($missingFiles -contains "copilot-instructions\Clean-Workspace.ps1")

# Guidance blocks
$howtoMissingDir = @'
<p><b>Why did this fail?</b> Your project is missing one or more standard folders (for example <code>.vscode</code>, <code>docs</code>, or <code>scripts</code>). The validator checks for these so everyone on your team has a consistent layout.
This consistency helps Copilot and coworkers find things quickly.</p>
<p><b>Benefits if you fix it:</b> Faster onboarding, easier automation (tasks know where files live), and fewer errors when sharing work. VS Code also recognizes <code>.vscode</code> settings per project, which improves your editing experience.</p>
<h4>Step-by-step: Create a folder</h4>
<ol>
  <li>Open File Explorer and go to your workspace folder. If you're unsure, it’s the folder you opened in VS Code (listed at the top of the Explorer).</li>
  <li>Right-click inside the folder background and choose <b>New &gt; Folder</b>.</li>
  <li>Type the folder name exactly as shown (for example <code>docs</code> or <code>.vscode</code>) and press Enter.</li>
  <li>If you’re on a VA network, prefer a local path like <code>C:\Users\&lt;YourName&gt;\Desktop\YourProject</code> to avoid slow network performance.</li>
  <li>Return to VS Code. The folder should appear in the Explorer. If not, click the Refresh icon or press F5.</li>
  <li>Re-run the validator to confirm the error is gone.</li>
</ol>
<p class="note">Tip: Workspace settings that live inside <code>.vscode</code> apply only to this project. See <a href="https://code.visualstudio.com/docs/getstarted/settings" target="_blank" rel="noopener">VS Code settings docs</a> for more.</p>
'@

$howtoMissingFile = @'
<p><b>Why did this fail?</b> A key file wasn’t found—common examples are <code>README.md</code>, <code>.vscode\settings.json</code>, or <code>.github\copilot-instructions.md</code>.
These files provide instructions for humans (README), project-specific editor behavior (settings), and personalized Copilot guidance (instructions).</p>
<p><b>Benefits if you fix it:</b> Colleagues understand your project, VS Code behaves consistently, and Copilot tailors help to your role and tasks.</p>
<h4>Step-by-step: Create a README.md</h4>
<ol>
  <li>In VS Code, right-click your workspace root folder in the Explorer &gt; <b>New File</b>.</li>
  <li>Name it <code>README.md</code> (all caps is traditional but not required).</li>
  <li>Paste a simple outline: What this project is, how to open it, how to run scripts (if any), and who to contact for help.</li>
  <li>Save. For ideas, see <a href="https://www.makeareadme.com/" target="_blank" rel="noopener">Make a README</a>.</li>
</ol>
<h4>Step-by-step: Create .vscode\settings.json</h4>
<ol>
  <li>In VS Code Explorer, right-click the root folder &gt; <b>New Folder</b> and name it <code>.vscode</code> (if it doesn’t exist).</li>
  <li>Right-click the new <code>.vscode</code> folder &gt; <b>New File</b> and name it <code>settings.json</code>.</li>
  <li>Add a starter:
  <pre><code>{
  "files.eol": "\r\n",
  "editor.tabSize": 2,
  "editor.wordWrap": "on"
}
  </code></pre>
  </li>
  <li>Save the file and re-run the validator.</li>
</ol>
'@

$howtoInvalidJson = @'
<p><b>Why did this fail?</b> One or more JSON files (often under <code>.vscode</code>) could not be parsed. Common causes are trailing commas, missing quotes, or comments inside JSON.</p>
<h4>Step-by-step: Fix JSON errors</h4>
<ol>
  <li>Open the file listed (for example <code>.vscode\tasks.json</code>).</li>
  <li>Look at the Problems panel in VS Code (bottom pane). It will show the exact line and character.</li>
  <li>Remove trailing commas, ensure all keys/strings use double quotes, and remove comments (<code>// like this</code>) which are not allowed in JSON.</li>
  <li>Save the file and re-run the validator.</li>
</ol>
'@

$howtoDeps = @'
<p><b>About dependencies:</b> Git is required for source control and updates; PAC (Power Platform CLI) is needed if your team uses Dataverse or Power Platform automation.</p>
<h4>Install Git (Windows)</h4>
<ol>
  <li>Visit <a href="https://git-scm.com/downloads/win" target="_blank" rel="noopener">git-scm.com/downloads/win</a> and run the installer.</li>
  <li>Accept defaults unless your team advises otherwise.</li>
  <li>Close and reopen VS Code, then run <code>git --version</code> in a terminal to confirm.</li>
</ol>
<h4>Install Power Platform CLI (PAC)</h4>
<ol>
  <li>See Microsoft’s guide: <a href="https://learn.microsoft.com/power-platform/developer/cli/introduction" target="_blank" rel="noopener">Install PAC CLI</a>.</li>
  <li>If winget is available, you can run <code>winget install Microsoft.PowerApps.CLI</code> in an elevated PowerShell.</li>
  <li>Reopen VS Code and run <code>pac --version</code> to verify.</li>
</ol>
'@

$howtoScriptSyntax = @'
<p><b>Why did this fail?</b> A PowerShell script in your <code>scripts</code> folder has a syntax error. This is like a grammar mistake that stops the script from running.</p>
<p><b>Benefits if you fix it:</b> Your automations and reports run reliably. You can schedule or re-run them without manual edits.</p>
<h4>Step-by-step: Fix script syntax</h4>
<ol>
  <li>Open the file shown in the error list (for example <code>scripts\MyReport.ps1</code>).</li>
  <li>Read the message in the Problems panel. If it mentions a missing <code>}</code> or quote, check the lines just above for balance.</li>
  <li>Use indentation to align blocks clearly, then save and re-run the validator.</li>
  <li>If stuck, ask Copilot Chat: paste the error and the function around the line number and request a fix.</li>
</ol>
'@

$howtoWorkspaceNone = @'
<p><b>Why did this fail?</b> No <code>.code-workspace</code> file was found. While optional, a workspace file lets you save window layout, tasks, and multi-folder setups under one file.</p>
<p><b>Benefits if you fix it:</b> One-click open for your entire project, shared tasks, and consistent settings for your team.</p>
<h4>Step-by-step: Create a workspace file</h4>
<ol>
  <li>In VS Code, go to <b>File &gt; Save Workspace As...</b>.</li>
  <li>Save it in your project root (for example <code>YourProject.code-workspace</code>).</li>
  <li>Next time, double-click this file to reopen the same project with your layout and tasks.</li>
</ol>
'@

$howtoWorkspaceMultiple = @'
<p><b>Why is this a warning?</b> More than one <code>.code-workspace</code> file was found. This can confuse teammates about which one to use.</p>
<p><b>What to do:</b> Pick a single “official” workspace file and remove or archive the others to an <code>archive</code> folder.</p>
'@

$howtoVscodeTasks = @'
<p><b>About tasks:</b> VS Code Tasks let you run repeatable actions (like “Validate Workspace”) with a single command or hotkey. They’re stored in <code>.vscode\tasks.json</code>.</p>
<h4>Step-by-step: Add tasks.json</h4>
<ol>
  <li>In VS Code, create the <code>.vscode</code> folder if it doesn’t exist.</li>
  <li>Inside <code>.vscode</code>, create a file named <code>tasks.json</code>.</li>
  <li>Paste a starter config:
  <pre><code>{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Validate Workspace",
      "type": "shell",
      "command": "pwsh",
      "args": ["-NoProfile","-ExecutionPolicy","Bypass","-File","copilot-instructions/Validate-WorkspaceSetup.ps1","-Detailed"],
      "problemMatcher": []
    }
  ]
}
  </code></pre>
  </li>
  <li>Run it via <b>Terminal &gt; Run Task...</b> and pick “Validate Workspace”.</li>
  <li>Learn more in <a href="https://code.visualstudio.com/docs/editor/tasks" target="_blank" rel="noopener">VS Code Tasks</a>.</li>
</ol>
'@

$howtoVscodeSettings = @'
<p><b>About project settings:</b> <code>.vscode\settings.json</code> stores project-specific editor preferences (wrapping, tabs, linters) so everyone gets the same experience.</p>
<h4>Step-by-step: Add settings.json</h4>
<ol>
  <li>Create <code>.vscode</code> if it doesn’t exist, then create <code>settings.json</code> inside it.</li>
  <li>Paste:
  <pre><code>{
  "files.eol": "\r\n",
  "editor.tabSize": 2,
  "editor.wordWrap": "on"
}
  </code></pre>
  </li>
  <li>Open <b>File &gt; Preferences &gt; Settings</b> to discover more helpful options.</li>
  <li>See <a href="https://code.visualstudio.com/docs/getstarted/settings" target="_blank" rel="noopener">User & Workspace Settings</a>.</li>
</ol>
'@

$howtoOpsScripts = @'
<p><b>About VA automation scripts:</b> The <code>copilot-instructions</code> folder often includes helpful scripts like <code>Generate-ProductivityReport.ps1</code> and <code>Clean-Workspace.ps1</code> used by teams for reporting and cleanup.</p>
<h4>Step-by-step: Acquire automation scripts</h4>
<ol>
  <li>Create a <code>copilot-instructions</code> folder in your workspace if it doesn’t exist.</li>
  <li>Copy the missing scripts from your team’s Copilot kit (the same place you got this validator), or request them from your team lead.</li>
  <li>After copying, right-click each <code>.ps1</code> in VS Code and select <b>Open</b> to review inline help comments.</li>
  <li>Re-run the validator to confirm the files are detected.</li>
</ol>
'@

# HTML output (double-quoted here-string for interpolation)
$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Workspace Setup Guidance</title>
  <style>
    body{font-family:'Segoe UI',Tahoma,Arial,sans-serif;margin:24px;line-height:1.55}
    h1,h2,h3{color:#003366}
    .note{background:#fff3cd;padding:10px;border-left:4px solid #ffc107;border-radius:4px}
    .bad{color:#b00020}
    code{background:#222;color:#ffd866;padding:2px 5px;border-radius:4px}
    .box{background:#f6f8fa;border:1px solid #e1e4e8;border-radius:6px;padding:12px}
    /* Collapsible sections */
    details{background:#fff;border:1px solid #e1e4e8;border-radius:6px;margin:12px 0}
    details>summary{cursor:pointer;padding:10px 12px;font-weight:600;list-style:none}
    details[open]>summary{border-bottom:1px solid #e1e4e8}
    details .box{border:0;background:transparent;padding:12px}
    .summary-badge{display:inline-block;font-size:.9rem;color:#444;margin-left:.5rem}
    .pill{display:inline-block;padding:2px 8px;border-radius:999px;background:#eef2ff;color:#3949ab;margin-left:.5rem;font-weight:500}
  </style>
</head>
<body>
  <h1>Workspace Setup Guidance</h1>
  <p><b>Workspace:</b> $(_escHtml $root)</p>
  <div class="note">This guide was generated from your workspace validation. It doesn’t change your files; it explains what was checked, why it matters for clinical work, and how to fix items with safe, beginner-friendly steps.</div>

  <h2>Before you start</h2>
  <p>Think of this as a checklist you can open any time. Each topic below is collapsible—expand only what you need. Fixes are designed for Windows and VS Code, and they avoid risky changes. If a step feels unfamiliar, open the link beside it to learn more, or ask a teammate to pair for a few minutes.</p>
  <p>Why this matters in a clinical environment:</p>
  <ul>
    <li>Consistency reduces rework: shared settings and tasks mean fewer surprises when exchanging files.</li>
    <li>Safety and traceability: clear folder structure and version control help you audit changes and roll back safely.</li>
    <li>Speed: once your environment is healthy, Copilot and VS Code can assist more effectively.</li>
  </ul>
  <p>If your device is on a secure network drive or has limited permissions, prefer working in a local folder under your user profile (e.g., <code>C:\Users\\YourName\\Documents\\Projects</code>) and copy outputs back to shared locations as needed.</p>

  <h2>Summary</h2>
  <ul>
    <li>Passed: $($data.Summary.Passed)</li>
    <li>Warnings: $($data.Summary.Warnings)</li>
    <li>Errors: $($data.Summary.Errors)</li>
    <li>Total Checks: $($data.Summary.TotalChecks)</li>
  </ul>

  <h2>Fixes</h2>
  $(if($hasMissingDirs){"<details><summary><span class='bad'>Missing directories</span><span class='pill'>" + $missingDirs.Count + "</span></summary><div class='box'><p><b>Detected:</b> $(_escHtml (($missingDirs -join ', ')))</p>$howtoMissingDir</div></details>"})

  $(if($hasMissingFiles){"<details><summary><span class='bad'>Missing files</span><span class='pill'>" + $missingFiles.Count + "</span></summary><div class='box'><p><b>Detected:</b> $(_escHtml (($missingFiles -join ', ')))</p>$howtoMissingFile</div></details>"})

  $(if($hasMissingTasks){"<details><summary>VS Code tasks configuration</summary><div class='box'>$howtoVscodeTasks</div></details>"})
  $(if($hasMissingSettings){"<details><summary>VS Code project settings</summary><div class='box'>$howtoVscodeSettings</div></details>"})
  $(if($hasMissingOpsScripts){"<details><summary>Automation scripts</summary><div class='box'>$howtoOpsScripts</div></details>"})

  $(if($hasInvalidJson){"<details><summary>Invalid JSON in VS Code files<span class='pill'>" + $invalidJson.Count + "</span></summary><div class='box'><p><b>Detected:</b> $(_escHtml (($invalidJson -join ', ')))</p>$howtoInvalidJson</div></details>"})

  $(if($hasDepIssues){"<details><summary>Dependency checks</summary><div class='box'><p><b>Git:</b> " + $(if($depsGit){'Installed'}else{'Not found'}) + " &nbsp; | &nbsp; <b>PAC:</b> " + $(if($depsPac){'Installed'}else{'Not found'}) + "</p>$howtoDeps</div></details>"})

  $(if($scriptErrors -and $scriptErrors.Count -gt 0){"<details><summary>PowerShell script syntax<span class='pill'>" + $scriptErrors.Count + "</span></summary><div class='box'><p><b>Detected:</b> $(_escHtml (($scriptErrors | ForEach-Object { \"$($_.File): $($_.Message)\" }) -join '; '))</p>$howtoScriptSyntax</div></details>"})

  $(if($ws -and -not $ws.HasWorkspaceFile){"<details><summary><span class='bad'>Workspace file missing</span></summary><div class='box'>$howtoWorkspaceNone</div></details>"})
  $(if($ws -and $ws.MultipleWorkspaceFiles){"<details><summary>Multiple workspace files detected</summary><div class='box'>$howtoWorkspaceMultiple</div></details>"})

  <hr/>
  <h2>More learning and help</h2>
  <p>Keep this handy library of references. Each link opens official documentation or a trusted guide:</p>
  <ul>
    <li>VS Code fundamentals: <a href="https://code.visualstudio.com/docs" target="_blank" rel="noopener">Documentation home</a></li>
    <li>Settings (project and user): <a href="https://code.visualstudio.com/docs/getstarted/settings" target="_blank" rel="noopener">User & Workspace Settings</a></li>
    <li>Tasks (automation): <a href="https://code.visualstudio.com/docs/editor/tasks" target="_blank" rel="noopener">VS Code Tasks</a></li>
    <li>Integrated terminal: <a href="https://code.visualstudio.com/docs/terminal/basics" target="_blank" rel="noopener">Terminal basics</a></li>
    <li>Markdown basics: <a href="https://www.markdownguide.org/basic-syntax/" target="_blank" rel="noopener">Markdown Guide</a></li>
    <li>Git for Windows: <a href="https://git-scm.com/downloads/win" target="_blank" rel="noopener">Download</a> · <a href="https://git-scm.com/docs" target="_blank" rel="noopener">Docs</a></li>
    <li>Power Platform CLI (PAC): <a href="https://learn.microsoft.com/power-platform/developer/cli/introduction" target="_blank" rel="noopener">Install & overview</a></li>
    <li>JSON validation tips: <a href="https://www.json.org/json-en.html" target="_blank" rel="noopener">Spec overview</a></li>
    <li>Accessibility & Section 508: <a href="prompts/va-accessibility-section508.md" target="_blank" rel="noopener">VA guidance (local)</a></li>
  </ul>
  <p>When you’ve made changes, re-run <code>copilot-instructions/Validate-WorkspaceSetup.ps1</code>. If everything’s green, consider committing your changes with Git so your team benefits too.</p>
</body>
</html>
"@

try {
  $dir = Split-Path -Parent $OutputHtml
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $html | Set-Content -Path $OutputHtml -Encoding UTF8
  Write-Host "Guidance written to: $OutputHtml" -ForegroundColor Cyan
} catch {
  throw "Failed to write HTML: $($_.Exception.Message)"
}

if ($Open) {
  try { Start-Process $OutputHtml | Out-Null } catch { Write-Host "WARN: Failed to open guidance: $($_.Exception.Message)" -ForegroundColor Yellow }
}

if ($DeleteJson) {
  try { Remove-Item -Path $JsonReport -Force -ErrorAction Stop } catch { Write-Host "WARN: Failed to delete JSON: $($_.Exception.Message)" -ForegroundColor Yellow }
}
