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

# Copilot Briefing - VA Power Platform Template

**For:** Future GitHub Copilot Sessions
**Project:** VA Power Platform Workspace Template
**Developer:** Kyle J. Coder - Program Analyst
**Organization:** Edward Hines Jr. VA Hospital (Hines VAMC)
**Last Updated:** July 24, 2025

---

## 🎯 Quick Context

You are working with **Kyle J. Coder**, a Program Analyst in Clinical Informatics & Advanced Analytics at Edward Hines Jr. VA Hospital. This workspace template was specifically designed for VA Power Platform development with strict compliance and automation requirements.

## ⚡ Critical Information

### Developer Profile
- **Name:** Kyle J. Coder
- **Role:** Program Analyst
- **Department:** Clinical Informatics & Advanced Analytics
- **Facility:** Edward Hines Jr. VA Hospital (Hines VAMC)
- **Email:** Kyle.Coder@va.gov (internal), HINClinicalAnalytics@va.gov (external)
- **GitHub:** KCoderVA

### VA Environment Constraints
🚨 **CRITICAL:** No admin privileges, no premium connectors, no Dataverse, output SQL to .csv only
- **SQL Server:** VhaCdwDwhSql33.vha.med.va.gov
- **Database:** D03_VISN12Collab
- **Power Platform:** https://make.gov.powerapps.us/
- **SharePoint:** https://dvagov.sharepoint.com/sites/vhahin/svc/ci/

## 🛡️ Copilot Behavior Guidelines

### DO Always:
- ✅ Use official facility name: "Edward Hines Jr. VA Hospital" (not "Hines VA" or variants)
- ✅ Maintain VA professional standards and compliance
- ✅ Create focused, single-purpose solutions
- ✅ Use non-interactive scripts (no halting prompts)
- ✅ Include comprehensive error handling
- ✅ Add detailed logging and documentation
- ✅ Respect existing folder organization
- ✅ Use VA-approved naming conventions

### DON'T Ever:
- ❌ Create multiple solutions for simple problems
- ❌ Make overly complicated scripts
- ❌ Put files in root folder without organization
- ❌ Create interactive prompts that halt automation
- ❌ Suggest admin-level operations
- ❌ Trigger Public Code Filter warnings
- ❌ Use unofficial facility names or abbreviations

## 📁 Template Structure Understanding

This template follows a specific organization:
```
/src/           - Source code by technology type
/scripts/       - Automation and utility scripts
/docs/          - Documentation and templates
/logs/          - Version tracking and execution logs
/assets/        - Branding and reference materials
/archive/       - Backups and cleanup
/templates/     - Reusable file templates
/sample-data/   - Example datasets
```

## 🔧 Key Implemented Scripts

### Essential Automation
- **Initialize-VAProject.ps1:** Project setup with workspace renaming
- **Generate-ProductivityReport.ps1:** Supervisor reporting with Git analysis
- **Update-VersionAndCommit.ps1:** Automated versioning and commits
- **Clean-Workspace.ps1:** Multi-level cleanup operations
- **Validate-WorkspaceSetup.ps1:** Dynamic environment validation

### Power Platform Specific
- **Unpack-PowerApp.ps1:** Extract .msapp for source control
- **Pack-PowerApp.ps1:** Package PowerApps for deployment
- **Export-SQLQuery.ps1:** Database operations with .csv output

## 📋 15 Critical Workflow Requirements

When working on this template, always remember:
1. Automated GitHub operations
2. Documentation auto-updates
3. Supervisor metrics and logs
4. TEMP_ prefixes for temporary files
5. License header automation
6. Smart file organization
7. PowerApps source control
8. Syntax validation
9. Version tracking and revert
10. Archive cleanup automation
11. Non-interactive execution
12. No halting prompts
13. Single-purpose solutions
14. VA naming conventions
15. Public Code Filter avoidance

## 🎭 Phase-Specific Instructions

### Phase 1 Sessions (Template Building)
**Goal:** Complete all 20 recommendations systematically
**Approach:** Build incrementally, test frequently, document thoroughly
**Key Focus:** VA compliance, automation, professional standards

### Phase 3 Sessions (Wizard Creation)
**Goal:** Create project initialization wizard
**Required Files:** Initialize-NewProject.ps1, Customize-WorkspaceTemplate.ps1, Validate-ProjectSetup.ps1
**Key Focus:** Interactive setup, template customization, validation

### Phase 4 Sessions (Project Use)
**Goal:** Help with actual project development
**Approach:** Use template automation, maintain standards, track productivity
**Key Focus:** Efficiency, compliance, documentation

## 🔍 Context File Priorities

**Always read these first:**
1. `TEMPLATE_CREATION_CONTEXT.md` - Complete implementation history
2. `PHASE3_REQUIREMENTS.md` - Current phase specifications
3. `README.md` - Project overview and getting started

**Reference as needed:**
4. Archive documentation for implementation decisions
5. Script files for current automation capabilities
6. VS Code configuration files for environment setup

## 💡 Problem-Solving Approach

### For Script Issues:
1. Check existing implementations in `/scripts/`
2. Review error handling patterns
3. Ensure VA compliance (no admin operations)
4. Test with non-interactive execution
5. Add comprehensive logging

### For Structure Questions:
1. Reference the established folder organization
2. Maintain consistency with existing patterns
3. Follow VA professional standards
4. Document all decisions clearly

### For Automation Requests:
1. Build single-purpose, focused solutions
2. Avoid complex multi-step approaches
3. Include error recovery mechanisms
4. Test thoroughly in VA constraints

## 🎯 Success Metrics

**Kyle values:**
- **Efficiency:** Solutions that save time and reduce manual work
- **Transparency:** Clear, understandable, and maintainable code
- **Compliance:** Full adherence to VA security and professional standards
- **Productivity:** Quantifiable work output for supervisor reporting
- **Quality:** Robust, tested, and documented implementations

## 🔮 Future Considerations

**Template Evolution:**
- Maintain backward compatibility
- Enhance automation capabilities
- Expand Power Platform integrations
- Improve documentation systems
- Add new VA compliance features

**User Experience:**
- Reduce manual configuration steps
- Improve error messages and guidance
- Enhance productivity tracking
- Streamline project initialization
- Maintain professional appearance

---

## 🚀 Ready-to-Use Prompts

### For Phase 3 Implementation:
```
"Read and fully analyze the attached TEMPLATE_CREATION_CONTEXT.md file. This contains all the requirements, implementation details, and specifications from the previous session where we built a complete VS Code workspace template for VA Power Platform development. Take time to understand Kyle J. Coder's specific requirements, the 20 recommendations that were implemented, and the context for Phase 3."

"Now implement Phase 3 as specified in the PHASE3_REQUIREMENTS.md file. Create the project initialization wizard and meta-level setup system that will allow this workspace template to be quickly customized for new projects."
```

### For New Project Setup:
```
"I'm starting a new project using my VA Power Platform workspace template. Please run the project initialization wizard and help me customize this workspace for my new project."
```

### For Template Enhancement:
```
"I need to enhance the VA Power Platform template with [specific requirement]. Please review the existing implementation and provide a solution that maintains VA compliance and follows our established patterns."
```

---

**Remember:** Kyle J. Coder at Edward Hines Jr. VA Hospital needs professional, compliant, and efficient solutions that work within VA constraints. Always prioritize automation, documentation, and VA professional standards.

**Last Updated:** July 24, 2025
**Template Version:** Phase 1 Complete, Phase 3 Ready
