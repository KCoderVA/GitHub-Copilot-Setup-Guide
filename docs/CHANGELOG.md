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

# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and semantic versioning principles when practical.

## [6.3.0] - 2025-08-19 (Initial Public Release)
### Added
- Interactive `index.html` Reveal.js slide deck with VA-focused Copilot Enterprise onboarding content.
- Printable version: `GitHub Copilot Setup Guide (for VA Employees).pdf` (exported from the printable HTML during release).
- Accessibility enhancements (skip link, keyboard focus outlines, secured external links, reduced duplicate content).
- SEO & social meta tags (OpenGraph, Twitter) for improved sharing preview.
- PowerShell automation scripts in `copilot-instructions/`:
  - `Add-LicenseHeaders.ps1`
  - `Clean-Workspace.ps1`
  - `Generate-ProductivityReport.ps1`
  - `Validate-Syntax.ps1`
  - `Validate-WorkspaceSetup.ps1`
  - `tasks.json` (VS Code task automation)
- Prompt and role context files in `prompts/` (accessibility, security, analytics, enterprise dev, power platform, primary care nurse, etc.).
- Documentation set (in `docs/`): `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `DISCLAIMER.md`.
- Root `LICENSE` (Apache 2.0) plus bundled `dependencies/LICENSE.txt` (upstream license text).
- `.gitignore` with sensible defaults and exclusion of `archive/` directory.
- Copy-to-clipboard buttons with user feedback for embedded prompts.
- "Printable Version" quick-access button from interactive deck.

### Changed / Improved
- Converted absolute Windows file-system links to relative web paths for GitHub Pages compatibility.
- Removed duplicate TOC entry and redundant explanatory notes.
- Deferred script loading (performance) & added `<noscript>` fallback messaging.
- Standardized code block styling and improved readability for dark-on-light theme.

### Fixed
- Eliminated empty anchor in Phase 3 TOC subsection.
- Removed duplicated advisory text in Enterprise access success indicators.

### Notes
- Version number (6.3) derived from internal iteration; earlier local revisions consolidated into this initial public commit.
- Future versions will add: accessibility audit report, optional dark theme toggle, CI link checker, and minified distribution variant.

## [Unreleased]
### Planned
- Add screenshot thumbnail for sharing (update OpenGraph image).
- Introduce CHANGELOG automation script.
- Add Lighthouse/axe accessibility summary.
- Provide dark-mode theme toggle and high-contrast print stylesheet.
- Optional localization scaffolding.

---

[6.3.0]: https://github.com/KCoderVA/GitHub-Copilot-Setup-Guide/releases/tag/v6.3.0
