<!--
COPILOT AGENT INITIALIZATION AND MAINTENANCE INSTRUCTIONS:

1. INITIAL SETUP:
   Upon first loading this file, scan for ALL template fields marked with double curly brackets {{...}}.
   Begin a conversational Q&A session with the user to gather required information.
   Update this file by replacing {{...}} placeholders with user responses.

2. INCOMPLETE SESSIONS:
   If the Q&A session is interrupted or incomplete:
   - Track which fields remain unfilled (contain {{...}})
   - Every 3-5 interactions OR at workspace startup, politely prompt:
     "I noticed we haven't completed your profile setup. Would you like to continue 
     answering the remaining [X] questions to personalize your workspace?"
   - Allow user to defer, but periodically retry (max once per day)
   - Prioritize critical fields (PROJECT_NAME, FACILITY_NAME, USER_NAME) over preferences

3. PREFERENCE CONFLICT DETECTION:
   Monitor all user interactions for information that contradicts saved preferences:
   - When detecting a conflict, immediately ask for clarification:
     "I noticed you mentioned [new value] but your profile shows [saved value]. 
     Would you like me to update your profile with the new information?"
   - Examples of conflicts to watch for:
     * Facility/location changes
     * Tool preferences differing from saved choices
     * File naming conventions being used differently
     * Response style preferences changing
   - Upon confirmation, update the relevant field in this file
   - Log preference changes with timestamps in comments for audit trail

4. ADAPTIVE LEARNING:
   - Track patterns in user behavior that suggest preference changes
   - After detecting 3+ instances of consistent deviation from a saved preference, 
     proactively suggest updating the profile
   - Example: If user consistently uses snake_case despite having PascalCase saved,
     offer to update FILE_NAMING_PREF

5. SMART REMINDERS:
   - For time-sensitive fields (WORK_HOURS, CURRENT_DATE), periodically verify accuracy
   - Seasonal checks: Every 3 months, ask if any major preferences have changed
   - Project milestone checks: When detecting project phase changes, verify if 
     role or team information needs updating

6. USER CONTEXT AWARENESS:
   - Parse user prompts for contextual information that could fill missing fields
   - Example: If user says "As a developer on the Power Platform team...", 
     automatically suggest updating USER_ROLE and TEAM_NAME if different
   - Always confirm before making automatic updates based on context

REMEMBER: Be helpful but not intrusive. Allow users to skip or defer updates, 
but maintain gentle persistence for critical missing information.
-->

# Copilot Instructions - {{PROJECT_NAME}}

## 🎯 Project Overview

You are working on **{{PROJECT_NAME}}**, a {{PROJECT_TYPE}} project for {{VA_FACILITY}} built using the VA workspace template. This workspace provides a complete development environment with pre-built automation scripts, organized folder structure, and VA-compliant configurations.

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

## 👤 User Demographics

<!--
Examples: Jane Doe, Michael Smith, KCoderVA
-->
- **Your Name:** {{USER_NAME}}

<!--
Examples: Developer, Business Analyst, Tester, Project Manager
-->
- **Primary Role:** {{USER_ROLE}}

<!--
Examples: VA Power Platform Team, Data Integration Group, Facility Automation Squad
-->
- **Team Name:** {{TEAM_NAME}}

<!--
Examples: VA Salt Lake City, VA Pittsburgh, VA Los Angeles
-->
- **Facility Name:** {{FACILITY_NAME}}

<!--
Examples: 123, 456, 789
-->
- **Facility Number:** {{FACILITY_NUMBER}}

<!--
Examples: 8, 10, 23
-->
- **VA Network Number:** {{VA_NETWORK_NUMBER}}

<!--
Examples: Salt Lake City, MST; Pittsburgh, EST; Los Angeles, PST
-->
- **Location/Timezone:** {{USER_LOCATION}}

<!--
Examples: 8am–4pm EST; 9am–5pm PST; Flexible, core hours 10am–3pm
-->
- **Working Hours:** {{WORK_HOURS}}

<!--
Examples: High contrast mode; Screen reader support; Larger font sizes; None
-->
- **Accessibility Needs:** {{ACCESSIBILITY_NEEDS}}

## 👤 User Work Preferences

<!--
Examples: janedoe, michael-smith, kcoderva
-->
- **GitHub Username:** {{GITHUB_USERNAME}}

<!--
Examples: snake_case (e.g., my_file_name.txt); kebab-case (e.g., my-file-name.txt); PascalCase (e.g., MyFileName.txt); camelCase (e.g., myFileName.txt)
-->
- **File Naming Convention:** {{FILE_NAMING_PREF}}

<!--
Examples: Microsoft Teams; Slack; Email; Zoom
-->
- **Preferred Collaboration Tool:** {{COLLAB_TOOLS}}

<!--
Examples: Peer review required for all merges; Automated checks only; Weekly review meetings; Informal, ad hoc reviews
-->
- **Code Review Preferences:** {{CODE_REVIEW_PREFS}}

<!--
Examples: Markdown (.md); HTML (.html); PDF (.pdf)
-->
- **Preferred Output Format:** {{OUTPUT_FORMAT}}

<!--
Examples: Prettier, GitLens, Copilot; ESLint, Docker, Markdown All in One; None
-->
- **VS Code Extensions:** {{PREFERRED_VSCODE_EXTENSIONS}}

<!--
Examples: Jira, Notion, Figma; Power BI, Trello, Chrome; Excel, Outlook, GitHub Desktop
-->
- **Software Tools Used:** {{SOFTWARE_TOOLS}}

<!--
Examples: Fira Code; Consolas; Source Code Pro; Default
-->
- **Font:** {{FONT_PREF}}

<!--
Examples: 12pt; 14pt; 16px
-->
- **Font Size:** {{FONT_SIZE_PREF}}

<!--
Examples: Dark; Light; Solarized Dark; VA Blue
-->
- **Color Scheme / Theme:** {{COLOR_SCHEME_PREF}}

<!--
Examples: Sidebar on left; Tabs on top; Minimal UI
-->
- **UI Layout Preferences:** {{UI_PREFS}}

<!--
Examples: Bullet points; Concise sentences; Long, descriptive paragraphs
-->
- **Copilot Response Style:** {{COPILOT_RESPONSE_STYLE}}

<!--
Examples: Brief, just the essentials; Moderately detailed; Exhaustive, every step explained
-->
- **Documentation Detail Level:** {{DOC_DETAIL_LEVEL}}

<!--
Examples: Pop-up notifications; Email alerts; Log file only; No notifications
-->
- **Automation Notification Preference:** {{AUTOMATION_NOTIFY_PREF}}

<!--
Examples: Python; JavaScript; PowerShell
-->
- **Default Project Language:** {{DEFAULT_PROJECT_LANGUAGE}}

<!--
Examples: Synchronous/live editing; Asynchronous comments/reviews; Hybrid (mix of both)
-->
- **Collaboration Style:** {{COLLAB_STYLE}}

<!--
Examples: GitHub Issues; Jira; Trello; Excel
-->
- **Task Tracking Tool:** {{TASK_TRACKING_TOOL}}

<!--
Examples: Pytest; Jest; MSTest; None
-->
- **Preferred Testing Frameworks:** {{TEST_FRAMEWORKS}}

<!--
Examples: High contrast colors; Larger icons; Screen reader compatibility; No additional settings
-->
- **Accessibility Settings:** {{ACCESSIBILITY_PREFS}}

<!--
Examples: Custom: Ctrl+Alt+T for terminal; Default; VS Code Vim plugin
-->
- **Keyboard Shortcuts:** {{KEYBOARD_SHORTCUTS_PREF}}

<!--
Examples: Run Clean-Workspace.ps1; Open README.md; Launch Power BI dashboard
-->
- **Workspace Start-up Tasks:** {{STARTUP_TASKS}}

<!--
Examples: Conventional Commits (feat:, fix:, etc.); Simple, descriptive; Reference ticket numbers (e.g., JIRA-123)
-->
- **Preferred Commit Message Style:** {{COMMIT_MESSAGE_STYLE}}

<!--
Examples: Email only; In-app notifications; None
-->
- **Notification Preferences:** {{NOTIFICATION_PREFS}}

<!--
Examples: feature/username-description; bugfix/issue-number; release/v1.2.3
-->
- **Branch Naming Convention:** {{BRANCH_NAMING_PREF}}

<!--
Examples: English; Spanish; Bilingual (English/Spanish)
-->
- **Project Documentation Language:** {{DOC_LANGUAGE}}

<!--
Examples: Bug report; Feature request; Task
-->
- **Preferred Issue Template:** {{ISSUE_TEMPLATE_PREF}}

<!--
Examples: Novice; Intermediate; Expert
-->
- **Learning Mode:** {{LEARNING_MODE}}

<!--
Examples: Pomodoro Timer; Notion; Trello
-->
- **Favorite Productivity Tools:** {{PRODUCTIVITY_TOOLS}}

<!--
Examples: Object-Oriented; Functional; Procedural
-->
- **Programming Paradigm:** {{PROGRAMMING_PARADIGM}}

<!--
Examples: ESLint; Prettier; Black
-->
- **Linter/Formatter:** {{LINTER_FORMATTER}}

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

**Template Version:** 1.0.0