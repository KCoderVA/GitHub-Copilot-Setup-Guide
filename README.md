
# GitHub Copilot Enterprise Setup Guide (VA)

Interactive Reveal.js slide deck and printable guide to help VA employees (clinical, administrative, analytics, informatics) get started with GitHub Copilot Enterprise and Agent Mode.

## Project Contents (clean root)

- `index.html` – Interactive slide deck (optimized for web & accessibility)
- `docs/` – Documentation and artifacts:
	- `GitHub Copilot Setup Guide (for VA Employees).pdf` – Canonical printable version
	- `CHANGELOG.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `DISCLAIMER.md`, `RELEASE_NOTES.md`
	- `archive/` – Prior HTML iterations / legacy files
- `copilot-instructions/` – PowerShell automation scripts, tasks, and Copilot instruction templates
- `prompts/` – Role and domain-specific prompt template collections (clinical, analytics, security, etc.)
- `dependencies/` – Bundled Reveal.js assets and Apache 2.0 license

## Quick Start

### Open [`index.html`](https://kcoderva.github.io/GitHub-Copilot-Setup-Guide/) for the interactive guide. OR, open [`docs/GitHub Copilot Setup Guide (for VA Employees).pdf`](https://github.com/KCoderVA/GitHub-Copilot-Setup-Guide/blob/main/docs/GitHub%20Copilot%20Setup%20Guide%20(for%20VA%20Employees).pdf)for a printable/distributable guide.

## Local Workspace Setup (High Recommendation)

Run these steps in the workspace where you actually do your work so Copilot follows your local rules.
1) Download or clone this repository.
2) Open your own active VS Code workspace (the project you want Copilot to obey).
3) Run `copilot-instructions/Install-Copilot-Instructions.bat` from this repo in that workspace.
	- Installs/updates `.github/copilot-instructions.md` in your workspace
	- Opens VS Code (deep link) and Copilot Chat
	- Copies a ready-to-paste chat prompt to your clipboard
4) Run `copilot-instructions/Validate-WorkspaceSetup.ps1` to check for standard folders/files and common tooling.
	- Use `-Detailed` for extra checks; `-FixIssues` can create missing directories safely
	- The validator emits a JSON report and generates a collapsible `Workspace-Guidance-<timestamp>.html` in your workspace root with step-by-step fixes
	- Add `-Open` to launch the guidance in your browser and `-DeleteJson` to remove the JSON after generating the HTML
5) (Recommended) Bring over the rest of the automation:
	- Copy the entire `copilot-instructions/` folder into your workspace root, or copy specific scripts you need
	- Copy the `prompts/` folder for role/domain starter prompts
	- Copy any templates from `docs/` you want to standardize locally
6) (Optional) Import tasks for one-click usage: copy `copilot-instructions/tasks.json` into `.vscode/tasks.json` in your workspace.

Why this matters:
- Ensures deterministic Copilot behavior by giving it a single, discoverable rules file in `.github`
- Reduces setup time for teammates; gives everyone the same guardrails and shortcuts
- Validates a healthy workspace structure quickly and non-destructively

## Automation & Scripts
All automation lives under `copilot-instructions/`.

Key scripts:
- `Install-Copilot-Instructions.bat` – Creates/updates `.github/copilot-instructions.md`, opens VS Code/Copilot Chat, and copies a ready-to-paste prompt
- `Generate-ProductivityReport.ps1` – Summarizes effort & repository metrics (HTML/MD/CSV/JSON)
- `Recursive-Directory-Analysis.ps1` – Inventories a directory tree and exports a CSV summary
- `Clean-Workspace.ps1` – Multi-level safe cleanup
- `Validate-Syntax.ps1` – Basic syntax validation for config/script files
- `Validate-WorkspaceSetup.ps1` – Environment readiness & optional auto-fixes
- `Generate-WorkspaceGuidance.ps1` – Reads the validator's JSON report and produces a collapsible, beginner‑friendly HTML with expanded intro/footer, resource links, and only the relevant fix blocks; can auto‑open and optionally delete the JSON
- `tasks.json` – VS Code tasks for common actions

## Prompts & Instruction Files
Use the role-based prompt templates in `prompts/` to seed Copilot context. The workspace-level instructions file should live at `.github/copilot-instructions.md`.

Install/update steps:
- Double‑click `copilot-instructions/Install-Copilot-Instructions.bat` (or run the VS Code task)
- Then run `copilot-instructions/Validate-WorkspaceSetup.ps1` to verify structure and dependencies

Next, copy the `prompts/` folder and any templates you want into your workspace so your team has them locally.

## Development / Contribution
Pull requests welcome for:
- New role-specific prompt sets
- Additional VA-compliant automation scripts
- Accessibility improvements (WCAG / Section 508 testing feedback)
- Localization or alternate print layouts

To contribute:
1. Create a new branch
2. Add/update content (keep licensing headers in scripts)
3. Open a PR with a concise summary of changes

## Accessibility Notes
- Skip link included for keyboard users
- Focus outlines restored
- External links open in new tab with `rel="noopener noreferrer"`
- Color palette maintains contrast against white theme

## License
Apache 2.0 – see `LICENSE`. Attribution required in derivatives. Embedded Reveal.js assets are MIT (see upstream project for details).

## Security & Compliance Reminder
No PHI/PII or sensitive VA data should be placed in this repository. All examples are generic. Follow local ISSO guidance before operationalizing any automation.

---
*If you build a derivative focused on another VA role or specialty, please contribute a link back or open a PR so others can benefit.*
