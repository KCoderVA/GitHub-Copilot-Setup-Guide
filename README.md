<!--
Copyright 2025 Kyle J. Coder

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# GitHub Copilot Enterprise Setup Guide (VA)

Interactive Reveal.js slide deck and printable guide to help VA employees (clinical, administrative, analytics, informatics) get started with GitHub Copilot Enterprise and Agent Mode.

## Project Contents

- `index.html` – Interactive slide deck (optimized for web & accessibility)
- `GitHub_Copilot_Setup_Guide_PRINTABLE.html` – Paginated printable version with dynamic TOC
- `GitHub Copilot Setup Guide (for VA Employees).pdf` – Distributed PDF version
- `copilot-instructions/` – PowerShell automation scripts, tasks, and Copilot instruction templates
- `prompts/` – Role and domain-specific prompt template collections (clinical, analytics, security, etc.)
- `dependencies/` – Bundled Reveal.js assets and Apache 2.0 license
- `archive/` – Prior HTML iterations / legacy versions

## Quick Start (GitHub Pages Hosting)

1. Fork or clone this repository.
2. Enable GitHub Pages in repository settings: Source = `main` (root).
3. Visit: `https://<your-username>.github.io/GitHub-Copilot-Setup-Guide/`.
4. Open `index.html` for the interactive version or the printable variant for generating a PDF.

## Printable Version

Use the "Printable Version" button in the top-right of `index.html` OR open `GitHub_Copilot_Setup_Guide_PRINTABLE.html` directly. Use your browser Print dialog (Landscape, margins = default) to export to PDF.

## PowerShell Automation Scripts
Located in `copilot-instructions/`:
- `Add-LicenseHeaders.ps1` – Injects standardized Apache 2.0 headers
- `Clean-Workspace.ps1` – Multi-level safe cleanup
- `Generate-ProductivityReport.ps1` – Summarizes effort & repository metrics
- `Validate-Syntax.ps1` – Basic syntax validation for config/script files
- `Validate-WorkspaceSetup.ps1` – Environment readiness & auto-fixes
- `tasks.json` – VS Code tasks to wire common actions

## Prompts & Instruction Files
Use the role-based prompt templates in `prompts/` to seed Copilot context. Place / adapt `copilot-instructions.md` and `COPILOT_BRIEFING.md` in active workspaces for persistent personalization.

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

## Author
Kyle J. Coder – Edward Hines Jr. VA Hospital / Clinical Informatics / Advanced Analytics

---
*If you build a derivative focused on another VA role or specialty, please contribute a link back or open a PR so others can benefit.*
