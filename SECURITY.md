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

# Security Policy

## Supported Content
This repository contains public instructional material. It should **not** contain production code, sensitive system details, or VA-restricted data.

## Do Not Submit
- PHI / PII / SPI or any veteran-identifiable information
- Internal VA network paths not already public
- Credentials, API keys, tokens, certificates
- Vulnerability exploit details targeting VA infrastructure

## Reporting a Vulnerability
If you believe you have identified a security concern related to the structure or scripts in this repository:
1. Do **not** post publicly.
2. Create a sanitized Issue (omit sensitive specifics) OR
3. Contact the maintainer directly via the email link in the guide.
4. For VA enterprise security matters, follow internal VA/ISSO escalation processes.

## Script Safety
PowerShell scripts are intentionally limited:
- No destructive file deletions outside intended workspace patterns
- Logging is local-only
- Review scripts before execution (`-WhatIf` or `-DryRun` flags where available)

## Dependency Integrity
Bundled `reveal.js` assets are vendor copies, not remotely loaded (offline friendly, reduces CDN risks). Verify integrity by comparing against official release `5.2.1` if needed.

## Responsible Use
Users are responsible for ensuring that outputs generated using the guide or prompt templates comply with HIPAA, FedRAMP, and VA policy.

---
If in doubt about security posture or data exposure risk, pause and consult your ISSO or supervisor.
