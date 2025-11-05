# Azure Virtual Desktop - User Acceptance Testing Guide

## Overview

This guide outlines the User Acceptance Testing (UAT) process for your Azure Virtual Desktop (AVD) custom image. After your custom image has been built, you will be provided with access to a test environment where you can verify that all required applications and configurations are present and working correctly.

**Purpose of UAT:**
- Verify all applications required for your business operations are installed and functional
- Test the user experience and performance of the virtual desktop
- Identify any missing applications or configurations before the image is finalized
- Ensure the environment meets your business requirements

**Important:** This testing phase is critical. Any issues identified during UAT will be addressed before the image is captured and deployed to production. Please test thoroughly and provide detailed feedback.

---

## Prerequisites

Before beginning UAT, ensure you have:

1. **Access to Azure AD**: Your user account must be a member of the designated security group that provides access to the test host pool
2. **Windows Remote Desktop App**: Install the Remote Desktop app from the Microsoft Store, or use the built-in Windows Remote Desktop Connection
3. **Internet Connection**: Stable internet connection for accessing the virtual desktop
4. **Microsoft 365 Credentials**: Your Microsoft 365 account credentials for testing applications
5. **Test Data**: Sample files or documents you typically work with (optional, but recommended)

---

## Accessing the Test Environment

### Step 1: Receive Access Notification

You will receive an email notification when:
- The test host pool has been deployed
- Your user account has been added to the security group
- The test environment is ready for use

This typically takes 24-48 hours after the custom image build completes.

### Step 2: Connect Using Remote Desktop App

1. **Open the Remote Desktop app** (Windows Remote Desktop or Remote Desktop app from Microsoft Store)

2. **Sign in** with your Microsoft 365 credentials (the same credentials you use to access Office 365)

3. **Look for the new session option** - You should see a new desktop session available in your Remote Desktop app. It will typically be named after your organization or project.

4. **Click to connect** - Select the available session and click **Connect**

5. **Authenticate** - You may be prompted to sign in again. Use your Microsoft 365 credentials.

6. **Desktop loads** - The virtual desktop session will start, and you'll see a Windows 11 desktop environment.

> **Note:** If you don't see the session option, wait a few minutes and refresh the Remote Desktop app. If it still doesn't appear after 30 minutes, contact your IT administrator or the project team.

---

## Tester Selection Recommendations

We recommend selecting a diverse group of testers to ensure comprehensive coverage of your use cases. The number of testers should be proportional to your expected user base.

### Recommended Tester Count

| Expected Users | Recommended Testers | Rationale |
|----------------|---------------------|-----------|
| 1-10 users | 2 testers | Small team - representative sample |
| 11-25 users | 3-5 testers | Medium team - diverse role coverage |
| 26-50 users | 5-8 testers | Larger team - multiple departments |
| 51-100 users | 8-12 testers | Enterprise - cross-functional testing |
| 100+ users | 12-20 testers | Large organization - comprehensive coverage |

**General Rule:** Approximately 10-20% of expected users, with a minimum of 2 testers and a maximum of 20 testers.

### Tester Selection Criteria

When selecting testers, consider including:

- **Different roles and departments** - Finance, HR, IT, Operations, etc.
- **Varying technical proficiency** - Both technical and non-technical users
- **Different use cases** - Power users, occasional users, specific application users
- **Different locations** (if applicable) - Remote workers, office-based users
- **Key stakeholders** - Department heads, project sponsors, IT administrators

---

## Testing Procedures

### Phase 1: Initial Connection and Basic Functionality (15-20 minutes)

**Objective:** Verify you can connect to the environment and basic Windows functionality works.

#### Test Steps:

1. **Connection Test**
   - [ ] Successfully connect to the virtual desktop
   - [ ] Desktop loads without errors
   - [ ] No connection timeouts or disconnections
   - [ ] Login process is smooth

2. **Basic Windows Functionality**
   - [ ] Start menu opens and functions correctly
   - [ ] Taskbar is visible and responsive
   - [ ] Right-click context menus work
   - [ ] File Explorer opens and navigates correctly
   - [ ] System time and date are correct (should match your local timezone)
   - [ ] Windows search function works

3. **Performance Check**
   - [ ] Desktop is responsive (no significant lag)
   - [ ] Applications launch in reasonable time
   - [ ] Mouse and keyboard input are responsive
   - [ ] Screen resolution is appropriate

**Feedback:** Note any connection issues, performance problems, or unexpected behavior.

---

### Phase 2: Application Testing (30-45 minutes)

**Objective:** Verify all required applications are installed and functional.

Use the checklist below to test each application. For each application, verify:
- The application launches successfully
- You can open/create files
- Core functionality works as expected
- No error messages appear

#### Application Testing Checklist

##### Microsoft 365 Apps

- [ ] **Microsoft Word**
  - [ ] Application launches
  - [ ] Can create a new document
  - [ ] Can open an existing document
  - [ ] Can save documents
  - [ ] Spell check works
  - [ ] Can print (if applicable)

- [ ] **Microsoft Excel**
  - [ ] Application launches
  - [ ] Can create a new spreadsheet
  - [ ] Can open an existing spreadsheet
  - [ ] Formulas calculate correctly
  - [ ] Can save spreadsheets
  - [ ] Charts and graphs work

- [ ] **Microsoft PowerPoint**
  - [ ] Application launches
  - [ ] Can create a new presentation
  - [ ] Can open an existing presentation
  - [ ] Can insert images and text
  - [ ] Can save presentations

- [ ] **Microsoft Outlook** (if installed)
  - [ ] Application launches
  - [ ] Can connect to your email account
  - [ ] Can send emails
  - [ ] Can receive emails
  - [ ] Calendar functions work
  - [ ] Contacts are accessible

- [ ] **Microsoft Teams** (if installed)
  - [ ] Application launches
  - [ ] Can sign in to Teams
  - [ ] Can join/create a meeting
  - [ ] Audio and video work (if applicable)
  - [ ] Screen sharing works
  - [ ] Chat functionality works

##### OneDrive

- [ ] **OneDrive**
  - [ ] OneDrive is installed
  - [ ] Can sign in to OneDrive
  - [ ] Files sync correctly
  - [ ] Can upload files
  - [ ] Can download files
  - [ ] File access is seamless

##### Web Browsers

- [ ] **Microsoft Edge**
  - [ ] Browser launches
  - [ ] Can navigate to websites
  - [ ] Can open multiple tabs
  - [ ] Can bookmark pages
  - [ ] Downloads work
  - [ ] Performance is acceptable

- [ ] **Google Chrome**
  - [ ] Browser launches
  - [ ] Can navigate to websites
  - [ ] Can open multiple tabs
  - [ ] Can bookmark pages
  - [ ] Downloads work
  - [ ] Performance is acceptable

##### PDF and Document Tools

- [ ] **Adobe Acrobat Reader**
  - [ ] Application launches
  - [ ] Can open PDF files
  - [ ] Can view PDFs correctly
  - [ ] Can print PDFs (if applicable)
  - [ ] Can annotate PDFs (if applicable)

##### Additional Applications

- [ ] **Snipping Tool** (or Windows Snipping Tool)
  - [ ] Can capture screenshots
  - [ ] Can save screenshots
  - [ ] Can annotate screenshots

- [ ] **Any custom applications** (specify in feedback)
  - [ ] Application launches
  - [ ] Core functionality works
  - [ ] Integrations work (if applicable)

---

### Phase 3: Configuration and Settings Testing (15-20 minutes)

**Objective:** Verify system configurations and optimizations are working correctly.

#### Test Steps:

1. **Language and Regional Settings**
   - [ ] System language is correct (English UK)
   - [ ] Date format is correct
   - [ ] Time format is correct
   - [ ] Currency format is correct (if applicable)

2. **Network and Performance**
   - [ ] Internet connectivity works
   - [ ] Can access internal resources (if applicable)
   - [ ] Network drives map correctly (if applicable)

3. **User Profile and Data Persistence**
   - [ ] Desktop shortcuts persist after logout/login
   - [ ] File associations are correct
   - [ ] User preferences are saved
   - [ ] Documents folder is accessible

4. **Security and Access**
   - [ ] Can access required shared folders (if applicable)
   - [ ] Printers are accessible (if applicable)
   - [ ] Permissions are correct for your role

---

### Phase 4: Real-World Workflow Testing (30-45 minutes)

**Objective:** Test your typical daily workflows to ensure everything works end-to-end.

#### Test Scenarios:

Choose 2-3 scenarios that represent your typical work:

**Example Scenario 1: Document Creation and Collaboration**
- [ ] Create a Word document
- [ ] Save it to OneDrive
- [ ] Share it with a colleague (if applicable)
- [ ] Open it in Teams and discuss
- [ ] Make edits and save changes

**Example Scenario 2: Data Analysis**
- [ ] Open Excel with sample data
- [ ] Create charts and pivot tables
- [ ] Export to PDF
- [ ] Email the PDF to yourself (if applicable)

**Your Custom Scenarios:**
- [ ] _________________________________________________
- [ ] _________________________________________________
- [ ] _________________________________________________

---

### Phase 5: Performance and Stability Testing (15-20 minutes)

**Objective:** Verify the environment performs well under normal use.

#### Test Steps:

1. **Multiple Applications**
   - [ ] Open 3-5 applications simultaneously
   - [ ] Switch between applications
   - [ ] All applications remain responsive
   - [ ] No crashes or freezes

2. **Extended Session**
   - [ ] Keep the session open for 30+ minutes
   - [ ] Continue working normally
   - [ ] No performance degradation
   - [ ] Session remains stable

3. **Disconnect and Reconnect**
   - [ ] Disconnect from the session (close Remote Desktop)
   - [ ] Wait 5 minutes
   - [ ] Reconnect to the session
   - [ ] All applications and work are preserved
   - [ ] Can continue where you left off

---

## Feedback Collection

### How to Provide Feedback

Please provide detailed feedback for each issue or concern. Use the following format:

**For Issues:**
- **Application/Feature:** [e.g., Microsoft Excel]
- **Issue Description:** [Clear description of what doesn't work]
- **Steps to Reproduce:** [Step-by-step instructions]
- **Expected Behavior:** [What should happen]
- **Actual Behavior:** [What actually happens]
- **Screenshots:** [If applicable, attach screenshots]
- **Priority:** [High/Medium/Low]

**For Missing Applications:**
- **Application Name:** [Exact name and version if known]
- **Use Case:** [Why you need this application]
- **Priority:** [High/Medium/Low]
- **Alternative:** [Is there an alternative that might work?]

**For Suggestions:**
- **Suggestion:** [Clear description]
- **Rationale:** [Why this would be helpful]
- **Priority:** [High/Medium/Low]

### Feedback Submission

Submit feedback via:
- **Email:** [Your project contact email]
- **Subject Line:** "AVD UAT Feedback - [Your Name] - [Date]"
- **Timeline:** Provide feedback within 48 hours of completing your testing

### Feedback Template

Use this template for structured feedback:

```
UAT Feedback Form

Tester Name: _________________________
Date: _________________________
Test Duration: _________________________

Issues Found:
1. [Issue description]
   Priority: [High/Medium/Low]
   Steps to reproduce: [Steps]

2. [Issue description]
   Priority: [High/Medium/Low]
   Steps to reproduce: [Steps]

Missing Applications:
1. [Application name]
   Priority: [High/Medium/Low]
   Use case: [Description]

2. [Application name]
   Priority: [High/Medium/Low]
   Use case: [Description]

Suggestions:
1. [Suggestion]
   Rationale: [Description]

Overall Assessment:
[ ] All requirements met - Ready for sign-off
[ ] Minor issues found - Need to be addressed
[ ] Major issues found - Significant changes required

Additional Comments:
[Your comments here]
```

---

## Sign-Off Process

### When to Sign Off

You should sign off on the UAT when:
- All critical applications are installed and working
- All high-priority issues have been resolved
- The environment meets your business requirements
- You are satisfied with the performance and user experience

### Sign-Off Checklist

Before signing off, confirm:

- [ ] All required applications are installed and functional
- [ ] All critical issues have been resolved
- [ ] Performance is acceptable for daily use
- [ ] User experience meets expectations
- [ ] Security and access controls are appropriate
- [ ] I have completed comprehensive testing
- [ ] I understand this image will be used for production deployment

### Sign-Off Form

```
AVD Custom Image UAT Sign-Off

Project: _________________________
Date: _________________________

Tester Information:
Name: _________________________
Title: _________________________
Department: _________________________
Email: _________________________

Testing Completed:
- [ ] Initial connection and basic functionality
- [ ] Application testing
- [ ] Configuration and settings
- [ ] Real-world workflow testing
- [ ] Performance and stability testing

Sign-Off Decision:
- [ ] APPROVED - Ready for production deployment
- [ ] APPROVED WITH NOTES - Minor issues documented but acceptable
- [ ] NOT APPROVED - Significant issues require resolution

Signature: _________________________
Date: _________________________

Additional Notes:
[Any additional comments or conditions]

Approval Authority:
[For IT/Project Manager]
Name: _________________________
Title: _________________________
Signature: _________________________
Date: _________________________
```

### Sign-Off Requirements

**Minimum Requirements for Approval:**
- At least 2 testers must provide sign-off
- All critical (High priority) issues must be resolved
- At least 80% of required applications must be functional
- Performance must be acceptable (no significant lag or crashes)

**For Large Deployments (50+ users):**
- At least 5 testers must provide sign-off
- Sign-off from at least 2 different departments
- IT administrator approval required

---

## Timeline and Expectations

### Typical UAT Timeline

| Phase | Duration | Responsibility |
|-------|----------|----------------|
| Environment Setup | 24-48 hours | Project Team |
| Tester Access Provisioning | 24 hours | Project Team |
| Testing Period | 5-7 business days | Testers |
| Feedback Review | 2-3 business days | Project Team |
| Issue Resolution | 3-5 business days | Project Team |
| Re-testing (if needed) | 2-3 business days | Testers |
| Final Sign-Off | 1 business day | Testers & Project Team |

**Total Estimated Time:** 2-3 weeks from environment deployment to final sign-off

### Expectations

**From Testers:**
- Complete testing within 5-7 business days
- Provide detailed, actionable feedback
- Respond promptly to follow-up questions
- Sign off when requirements are met

**From Project Team:**
- Address all critical issues within 3-5 business days
- Communicate status updates regularly
- Provide support during testing
- Ensure image is perfect before final capture

---

## Security Considerations

### Important Security Notes

1. **No Direct RDP Access**: Access to the test environment is provided through Azure Virtual Desktop only. Direct RDP access over the internet is not enabled for security reasons.

2. **Secure Connection**: All connections are encrypted and authenticated through Azure AD.

3. **Data Handling**: 
   - Do not store sensitive production data in the test environment
   - The test environment may be reset or recreated
   - Use test data only

4. **Access Control**: Access is managed through Azure AD security groups. Only authorized users can access the environment.

5. **Session Security**: Always disconnect from sessions when not in use. Sessions will automatically disconnect after a period of inactivity.

### Best Practices

- Use strong, unique passwords for your Microsoft 365 account
- Do not share your login credentials
- Report any security concerns immediately
- Follow your organization's data handling policies

---

## Troubleshooting

### Common Issues and Solutions

#### Cannot See Session in Remote Desktop App

**Symptoms:** Session doesn't appear in Remote Desktop app after being added to security group.

**Solutions:**
1. Wait 15-30 minutes after being added to the security group (propagation delay)
2. Sign out and sign back in to the Remote Desktop app
3. Close and reopen the Remote Desktop app
4. Clear app cache (if using Windows Remote Desktop app)
5. Contact your IT administrator if issue persists

#### Connection Issues

**Symptoms:** Cannot connect to the session, connection times out, or disconnects frequently.

**Solutions:**
1. Check your internet connection
2. Verify you're using a supported client (Windows Remote Desktop or Remote Desktop app)
3. Try connecting from a different network
4. Check firewall settings (ensure ports 443 and 3391 are open)
5. Contact support if issue persists

#### Application Not Working

**Symptoms:** Application crashes, won't launch, or functions incorrectly.

**Actions:**
1. Document the exact error message
2. Note the steps that led to the issue
3. Take screenshots if possible
4. Report through the feedback process
5. Try alternative applications if available (e.g., Edge vs Chrome)

#### Performance Issues

**Symptoms:** Slow response, lag, or freezing.

**Actions:**
1. Check your internet connection speed (should be at least 5 Mbps)
2. Close unnecessary applications
3. Note when performance issues occur (specific actions, times)
4. Report through the feedback process with details

#### Missing Application

**Symptoms:** Required application is not installed.

**Actions:**
1. Verify the application is on the required applications list
2. Check if an alternative application is available
3. Report through the feedback process with:
   - Application name and version
   - Use case and priority
   - Whether an alternative would work

---

## Support and Contact

### Getting Help

If you encounter issues during testing or have questions:

1. **Technical Issues**: Contact your IT administrator or project team
2. **Access Issues**: Contact the project team to verify security group membership
3. **Application Questions**: Refer to application documentation or contact support
4. **Feedback Submission**: Use the feedback process outlined above

### Project Contacts

- **Project Team Email:** [Your project contact email]
- **IT Support:** [Your IT support contact]
- **Project Manager:** [Project manager contact]

---

## Next Steps After UAT

Once UAT is complete and sign-off is received:

1. **Final Image Capture**: The project team will capture the approved image
2. **Production Deployment**: The image will be deployed to production host pools
3. **User Rollout**: Users will be onboarded to the production environment
4. **Training**: User training will be provided (if applicable)
5. **Support**: Ongoing support will be available

---

## Appendix: Quick Reference Checklist

### Pre-Testing Checklist
- [ ] Received access notification
- [ ] Remote Desktop app installed
- [ ] Microsoft 365 credentials ready
- [ ] Test data prepared (optional)

### Testing Checklist Summary
- [ ] Phase 1: Initial connection and basic functionality
- [ ] Phase 2: Application testing (all applications)
- [ ] Phase 3: Configuration and settings
- [ ] Phase 4: Real-world workflow testing
- [ ] Phase 5: Performance and stability

### Sign-Off Checklist
- [ ] All critical applications tested
- [ ] All high-priority issues resolved
- [ ] Performance acceptable
- [ ] Sign-off form completed
- [ ] Feedback submitted

---

**Document Version:** 1.0  
**Last Updated:** [Date]  
**For Questions:** Contact your project team

