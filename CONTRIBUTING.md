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

# Contributing

Thanks for your interest in improving the GitHub Copilot Enterprise Setup Guide for VA users!

## Ways to Contribute
- Add or refine prompt templates (clinical, analytics, admin, research, security)
- Improve accessibility (semantic structure, ARIA hints, contrast audits)
- Add new automation scripts (PowerShell / VS Code tasks)
- Optimize print styling or pagination logic
- Provide localization / alternative language support
- Report bugs or inconsistencies

## Getting Started
1. Fork the repo and clone locally.
2. Create a feature branch: `git checkout -b feature/<short-name>`
3. Make changes (ensure scripts include Apache 2.0 header).
4. Run a quick validation:
   - Load `index.html` in a browser (check navigation & copy buttons)
   - Verify the PDF `GitHub Copilot Setup Guide (for VA Employees).pdf` opens from the "Printable Version" button
5. Commit with a conventional prefix (e.g., `feat:`, `fix:`, `docs:`).
6. Push and open a Pull Request.

## Coding & Content Guidelines
- Maintain consistent tone: instructive, VA-focused, vendor-neutral.
- No PHI/PII, internal VA system details, or sensitive architecture.
- Keep HTML lean—avoid heavy external CDNs (offline-friendly preferred).
- For JavaScript: prefer progressive enhancement and defensive DOM checks.
- Accessibility: ensure all interactive elements are keyboard reachable.

## Adding Prompt Sets
Place new files in `prompts/` using a clear, hyphenated naming pattern:
`va-<domain>-<topic>.md` (example: `va-clinical-nursing.md`).

## Adding Scripts
Place PowerShell scripts in `copilot-instructions/` with:
```
# Apache 2.0 header
# Short purpose description
# Usage examples (commented)
```

## Issues & Discussions
Open an Issue for bugs or content gaps. For broader ideas, open a Discussion (if enabled) or draft a PR.

## License
All contributions are under Apache 2.0. By submitting a PR you agree your work is licensed accordingly.

---
Thank you for helping make this resource more useful to the VA community.
