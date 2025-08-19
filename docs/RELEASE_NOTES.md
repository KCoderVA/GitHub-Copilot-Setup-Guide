# Release 6.3.0 — GitHub Copilot Enterprise Setup Guide (VA)

Date: 2025-08-19
Tag: v6.3.0

## Highlights
- First public release of the interactive Reveal.js guide tailored for VA employees
- Canonical printable artifact: "GitHub Copilot Setup Guide (for VA Employees).pdf"
- Accessibility improvements and SEO metadata
- Bundled Reveal.js and plugins to work offline on GitHub Pages

## New
- index.html interactive guide with table of contents, navigation bar, keyboard access, and copy-to-clipboard for prompt blocks
- Printable PDF available via "Printable Version" button
- PowerShell scripts for productivity and compliance:
  - Add-LicenseHeaders.ps1
  - Clean-Workspace.ps1
  - Generate-ProductivityReport.ps1
  - Validate-Syntax.ps1
  - Validate-WorkspaceSetup.ps1
  - tasks.json (VS Code tasks)
- Prompt templates under prompts/ for VA roles and domains
- Documentation: README, CHANGELOG, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, DISCLAIMER

## Changes
- Robust Reveal.js initialization to avoid blank page during GitHub Pages load
- Correct canonical/og:url for project pages path
- All “Printable Version” links now target the repository PDF

## Fixed
- Duplicate TOC entry removed; various small content cleanups

## Compatibility
- Hosted via GitHub Pages (project site): https://kcoderva.github.io/GitHub-Copilot-Setup-Guide/
- All assets referenced using project-relative paths compatible with Pages

## Checks
- Lint/syntax: HTML validated; no build system required
- Accessibility: basic WCAG/508 considerations included; further audit planned

## How to use
- Open `index.html` for the interactive guide
- Click "Printable Version" to download the PDF for printing/distribution

## Acknowledgements
- Reveal.js (MIT) and highlight.js; see `docs/THIRD_PARTY_NOTICES.md` for license details.
