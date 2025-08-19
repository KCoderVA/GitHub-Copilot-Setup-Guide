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

# Copilot Instructions - {{PROJECT_NAME}}

## 🎯 Project Overview

You are working with **{{PROJECT_NAME}}**, a {{PROJECT_TYPE}} project for {{VA_FACILITY}} built using the VA Power Platform workspace template. This workspace provides a complete development environment with pre-built automation scripts, organized folder structure, and VA-compliant configurations.

## 🏥 VA Environment Understanding

**Critical VA Constraints:**
- No admin privileges required - All automation works with standard user permissions
- Power Platform Government Cloud environment (make.gov.powerapps.us)
- SQL output to .csv files only - No direct database modifications
- VA professional standards and naming conventions apply
- Security and compliance requirements built into all automation

**Project-Specific Information:**
- **Facility:** {{VA_FACILITY}}
- **Department:** {{DEPARTMENT}}
- **Project Type:** {{PROJECT_TYPE}}
- **Created:** {{CURRENT_DATE}}

## 📁 Workspace Structure

This project follows a professional organization pattern:
```
/src/           - Source code organized by technology type
/scripts/       - Automation and utility scripts
/docs/          - Documentation and references
/assets/        - Branding and reference materials
/templates/     - Reusable file templates
/sample-data/   - Example datasets for testing
/.vscode/       - VS Code configuration and integration
```

## 🔧 Available Automation Scripts

**Project Management:**
- Generate-ProductivityReport.ps1 - Create supervisor reports with work metrics
- Update-VersionAndCommit.ps1 - Automated versioning and Git operations
- Clean-Workspace.ps1 - Multi-level cleanup and maintenance

**File Operations:**
- Add-LicenseHeaders.ps1 - Automatic license header management
- Organize-Files.ps1 - Smart file organization by type and date
- Track-FileVersions.ps1 - Version tracking with backup and revert
- Validate-Syntax.ps1 - Multi-language syntax validation

**Power Platform Integration:**
- Unpack-PowerApp.ps1 - Extract PowerApps for source control
- Pack-PowerApp.ps1 - Package PowerApps for deployment
- Export-SQLQuery.ps1 - Database operations with .csv output

## 🛡️ Behavior Guidelines

**Always maintain:**
- VA professional standards and compliance
- Non-interactive script execution (no halting prompts)
- Comprehensive error handling and logging
- Single-purpose, focused solutions
- Proper folder organization and file naming
- Security and privacy considerations

**Key principles:**
- Use established folder structure consistently
- Follow VA naming conventions for all files
- Include proper documentation for all code
- Test thoroughly before deployment
- Maintain version control and backup practices
- Respect government security requirements

## 💡 Getting Started

1. **Review Documentation:** Start with README.md and QUICK-START.md
2. **Use VS Code Tasks:** Access automation via Ctrl+Shift+P → "Tasks: Run Task"
3. **Configure Environment:** Leverage pre-configured VS Code settings
4. **Start Development:** Use the organized folder structure for your work

## 🎯 Best Practices

**For Development:**
- Use VS Code tasks for script execution
- Leverage code snippets for common patterns (type "va-" and press Tab)
- Follow established error handling patterns
- Document all customizations and changes
- Regular cleanup and version control commits

**For Collaboration:**
- Use Generate-ProductivityReport.ps1 for status updates
- Maintain clean folder organization
- Document decisions in appropriate README files
- Use version tracking for important file changes
- Follow government collaboration standards

## 📋 Support and Documentation

**Key Reference Files:**
- README.md - Project overview and automation guide
- QUICK-START.md - Rapid setup instructions
- Individual folder README.md files for specific guidance

**For Advanced Usage:**
- Review script source code for customization options
- Check .vscode/ folder for development environment setup
- Use templates/ folder for consistent file creation
- Reference docs/ folder for detailed documentation

---

**Remember:** This workspace prioritizes VA compliance, professional standards, and automated efficiency. All scripts are designed for government environments with appropriate security and operational constraints.

**Last Updated:** {{CURRENT_DATE}}
**Project:** {{PROJECT_NAME}}
**Template Version:** 1.0.0
