@echo off
:: ----------------------------------------------------------------------------
:: Install-Copilot-Instructions.bat
:: ----------------------------------------------------------------------------
:: Purpose:
::   Ensure a workspace-level Copilot instructions file exists at
::     <repo-root>\.github\copilot-instructions.md by downloading your
::     public template or using a local fallback, then creating or updating
::     the target file.
::
:: What this script does (high level):
::   1) Finds its own folder and the one-level-up repo root ("grandDir").
::   2) Ensures a .github folder exists at the repo root.
::   3) Downloads the latest template from GitHub to a temp file.
::   4) If a target exists, prepends the template and pushes existing content
::      down by 385 lines; otherwise it creates the file.
::   5) Prints a success message and pauses so users can read output.
::
:: Requirements:
::   - Windows (batch + PowerShell available by default on Win 10/11)
::   - Write access to the repo root to create/modify .github
::   - Network access to raw.githubusercontent.com
::
:: Exit codes:
::   0 = Success; 1 = Error encountered
:: ----------------------------------------------------------------------------
setlocal EnableExtensions EnableDelayedExpansion
:: Track a single exit code for all branches; we jump to :done to pause.
set "EXITCODE=0"

rem ---------------------------------------------------------------------
rem Install/Update .github\copilot-instructions.md from repo template
rem ---------------------------------------------------------------------
echo.
echo [INFO] Starting Copilot instructions installer...
echo        Date/Time: %DATE% %TIME%
echo.
echo [INFO] Initializing environment... please wait if this is the first run.
echo        (PowerShell can take a few seconds to start on a cold machine.)
rem Warm up PowerShell so users see progress early and reduce cold-start lag later
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host '   [OK] PowerShell initialized'" 2>nul
echo.

rem 1) Identify this .bat file's directory (parent of the .bat)
rem    %~dp0 yields the drive+path of this script, with a trailing backslash.
set "batDir=%~dp0"
for %%I in ("%batDir%..") do set "grandDir=%%~fI"
set "parentDir=%batDir%"
echo [INFO] Script folder:     %parentDir%
echo [INFO] Candidate repo root (grandparent): %grandDir%

rem Normalize paths (remove trailing backslashes where needed)
if "%parentDir:~-1%"=="\" set "parentDir=%parentDir:~0,-1%"
if "%grandDir:~-1%"=="\" set "grandDir=%grandDir:~0,-1%"

rem 2) Discovery only: we now have parentDir and grandDir for later checks.
rem    No directory listings are printed; this keeps the script quiet.

rem 3) Check if the same folder as this .bat contains copilot-instructions.md
set "parentMd=%parentDir%\copilot-instructions.md"
if exist "%parentMd%" (
  set "HAS_PARENT_MD=1"
  echo [INFO] Found local template beside script: "%parentMd%"
) else (
  set "HAS_PARENT_MD=0"
  echo [INFO] No local template beside script.
)

rem 4) Check if the repo root (grandDir) contains a .github folder
set "ghDir=%grandDir%\.github"
if exist "%ghDir%" (
  set "HAS_GH_DIR=1"
  echo [INFO] .github folder exists at repo root: "%ghDir%"
) else (
  set "HAS_GH_DIR=0"
  echo [INFO] .github folder not found at repo root. Will create if required.
)

rem 5/6) Ensure .github folder exists when required
rem      Per requirements: if parent has MD and .github is missing, create it.
if "%HAS_GH_DIR%"=="0" (
  rem If parent has MD and .github is missing, create it (per requirement #6)
  if "%HAS_PARENT_MD%"=="1" (
  echo [ACTION] Creating missing .github folder at "%ghDir%"...
    mkdir "%ghDir%" 2>nul
    if errorlevel 1 (
      echo ERROR: Failed to create "%ghDir%".
      set "EXITCODE=1" & goto :done
    )
    set "HAS_GH_DIR=1"
  echo [OK] Created .github folder.
  )
)

rem 7) Fetch template from GitHub RAW (always fetch to ensure latest)
rem    We save to a precomputed temp path to avoid PowerShell $env syntax.
set "TEMPLATE_URL=https://raw.githubusercontent.com/KCoderVA/GitHub-Copilot-Setup-Guide/main/copilot-instructions/copilot-instructions.md"
set "TMP_TPL=%TEMP%\copilot_instructions_template.md"

rem PowerShell download with a quiet progress display and explicit out file
echo [ACTION] Downloading template from:
echo         %TEMPLATE_URL%
echo         to temp file: "%TMP_TPL%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '%TEMPLATE_URL%' -OutFile '%TMP_TPL%'; exit 0 } catch { Write-Host ('Download failed: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 (
  if "%HAS_PARENT_MD%"=="1" (
    echo [WARN] Download failed. Using local template beside script: "%parentMd%"
    copy /Y "%parentMd%" "%TMP_TPL%" >nul
    if errorlevel 1 (
      echo ERROR: Local fallback copy failed.
      set "EXITCODE=1" & goto :done
    )
  ) else (
    echo ERROR: Unable to download template from %TEMPLATE_URL% and no local fallback found.
    set "EXITCODE=1" & goto :done
  )
)
for %%A in ("%TMP_TPL%") do set "TPL_SIZE=%%~zA"
echo [OK] Template ready. Size: !TPL_SIZE! bytes

rem Ensure .github exists now (for creation path too)
if "%HAS_GH_DIR%"=="0" (
  mkdir "%ghDir%" 2>nul
  if errorlevel 1 (
  echo ERROR: Failed to create "%ghDir%".
  set "EXITCODE=1" & goto :done
  )
)

set "ghFile=%ghDir%\copilot-instructions.md"
echo [INFO] Target file path: "%ghFile%"

rem 5,8,9) Create or inject content at top (with 385-line spacer when merging)
rem       - If the target exists: prepend the template, add 385 blank lines,
rem         then append the previous content. This preserves the existing file
rem         while surfacing the template at the top.
rem       - If the target doesn't exist: create it from the template.
if exist "%ghFile%" (
  rem Inject: [template] + 5 blank lines + existing content
  echo [ACTION] Existing target detected. Prepending template and pushing prior content down by 385 lines...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop'; " ^
    "$tpl = Get-Content -Raw '%TMP_TPL%'; " ^
    "$existing = Get-Content -Raw '%ghFile%' -ErrorAction SilentlyContinue; " ^
    "$nl = [Environment]::NewLine; " ^
    "$blanks = [string]::Concat((1..5 | ForEach-Object { $nl })); " ^
    "$out = $tpl + $blanks + $existing; " ^
    "$tmp = [System.IO.Path]::GetTempFileName(); " ^
    "$utf8NoBom = New-Object System.Text.UTF8Encoding($false); " ^
    "[System.IO.File]::WriteAllText($tmp, $out, $utf8NoBom); " ^
    "Move-Item -Force -LiteralPath $tmp -Destination '%ghFile%'"
  if errorlevel 1 (
  echo ERROR: Failed to inject into "%ghFile%".
  set "EXITCODE=1" & goto :done
  )
  echo [OK] Injection completed.
) else (
  rem Create new file from template
  echo [ACTION] Target doesn't exist. Creating new file from template...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop'; " ^
    "$src = '%TMP_TPL%'; " ^
    "$tmp = [System.IO.Path]::GetTempFileName(); " ^
    "Copy-Item -LiteralPath $src -Destination $tmp -Force; " ^
    "Move-Item -Force -LiteralPath $tmp -Destination '%ghFile%'"
  if errorlevel 1 (
    echo ERROR: Failed to create "%ghFile%".
    set "EXITCODE=1" & goto :done
  )
  echo [OK] Created new target file.
)

for %%A in ("%ghFile%") do set "GH_SIZE=%%~zA"
echo [INFO] Final target size: !GH_SIZE! bytes
echo.

rem 10) Success notification
rem     Friendly summary and next steps. We pause below so users can read it.
echo.
echo =====================================================================
echo SUCCESS: Copilot instructions have been installed/updated at:
echo    "%ghFile%"
echo.
echo Next steps:
echo  1) Restart VS Code to pick up the updated .github\copilot-instructions.md
echo  2) Open Copilot Chat and prompt your agent to identify and comply with
echo     the workspace instructions (pin the file for deterministic behavior)
echo  3) Optionally open the file now to review or customize local guidance
echo     (Path shown above). Consider committing it to source control.
echo  4) Share this installer with teammates who need the same setup.
echo =====================================================================
echo.

rem Attempt to open the target file directly in VS Code using the vscode:// protocol
echo [ACTION] Opening the instructions file in VS Code (if installed)...
set "VSC_URI="
for /f "usebackq delims=" %%U in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=[IO.Path]::GetFullPath('%ghFile%'); $u='vscode://file/'+($p -replace '\\','/'); Write-Output $u"`) do set "VSC_URI=%%U"
if not "%VSC_URI%"=="" (
  echo [INFO] VS Code URI: %VSC_URI%
  start "" "%VSC_URI%" >nul 2>nul
) else (
  echo [WARN] Could not construct VS Code URI.
)

rem If the 'code' CLI is available, also open the file via CLI as a fallback
where code >nul 2>nul && (
  echo [ACTION] Opening via 'code' CLI fallback...
  code "%ghFile%" >nul 2>nul
)

rem Try to open Copilot Chat view (may no-op if extension/commands not present)
echo [ACTION] Attempting to open Copilot Chat in VS Code...
start "" "vscode://command/github.copilot.openChat" >nul 2>nul
start "" "vscode://command/workbench.action.chat.open" >nul 2>nul
echo [INFO] If Copilot Chat did not open automatically, open it from the sidebar.

rem Provide a ready-to-use Copilot Chat prompt and copy it to clipboard
set "COPILOT_PROMPT=Use the workspace instructions at \"%ghFile%\" (.github\\copilot-instructions.md). Read it now, pin it in this chat, and comply with its rules for all tasks."
echo [ACTION] Copying a suggested Copilot Chat prompt to your clipboard...
echo %COPILOT_PROMPT% | clip
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=\"%COPILOT_PROMPT%\"; Set-Clipboard -Value $p" >nul 2>nul
)
echo [OK] Prompt copied. In Copilot Chat, press Ctrl+V to paste it.

rem Check if VS Code appears to be installed (CLI and/or URI handler). If not, guide the user.
set "HAS_CODE=0"
where code >nul 2>nul && set "HAS_CODE=1"
set "HAS_VSCODE_URI=0"
reg query "HKCR\vscode" >nul 2>nul && set "HAS_VSCODE_URI=1"
if "%HAS_CODE%"=="0" if "%HAS_VSCODE_URI%"=="0" (
  echo [WARN] Visual Studio Code does not appear to be installed on this machine.
  echo        You can download and install the latest version from:
  echo        https://code.visualstudio.com/download
  start "" "https://code.visualstudio.com/download" >nul 2>nul
)

:: Final pause and exit summary
:done
echo Press any key to close this window...
pause >nul

endlocal & exit /b %EXITCODE%
