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

# Project Documentation

This folder contains the documentation and release artifacts for the GitHub Copilot Enterprise Setup Guide.

- Canonical printable PDF: `GitHub Copilot Setup Guide (for VA Employees).pdf`
- Policy and contribution docs: `CHANGELOG.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `DISCLAIMER.md`, `RELEASE_NOTES.md`
- Legacy materials: `archive/`

For the interactive guide, open the repository root `index.html` or visit the GitHub Pages site.

## Workspace Automation (Summary)

- Use `copilot-instructions/Install-Copilot-Instructions.bat` to create or update `.github/copilot-instructions.md` in any active workspace. The installer opens VS Code/Copilot Chat and copies a ready prompt.
- Run automation via VS Code Tasks (Task: “Install/Update Copilot Instructions (.github)”, “Generate Productivity Report”, “Recursive Directory Analysis”, “Clean Workspace”).
