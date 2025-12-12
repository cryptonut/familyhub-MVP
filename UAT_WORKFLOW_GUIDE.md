# UAT Workflow Guide
**Last Updated:** December 11, 2025

This guide outlines the standard workflow for managing User Acceptance Testing (UAT) in the Family Hub MVP application.

---

## Overview

The UAT system allows testers and administrators to:
- Create test rounds for different release cycles
- Add test cases and sub-test cases
- Execute tests and mark them as Pass/Fail
- Track testing progress and results
- View detailed test information

---

## Standard Workflow

### 1. Adding Test Cases (Initial Setup)

When a new release is ready for testing, test cases should be added using one of the following methods:

#### Option A: Using the Script (Recommended for Bulk Addition)

1. **Prepare Test Cases Document**
   - Review `UAT_TEST_CASES_ROADMAP_IMPLEMENTATION.md` or create your own test cases document
   - Ensure all test cases are documented with:
     - Number
     - Title
     - Description
     - Feature name
     - Test steps
     - Sub-test cases (if any)

2. **Run the Script**
   ```powershell
   # From project root
   .\scripts\add_uat_test_cases.ps1
   ```
   
   Or manually:
   ```bash
   flutter pub get
   dart run scripts/add_uat_test_cases.dart
   ```

3. **Verify in Firebase Console**
   - Open Firebase Console → Firestore Database
   - Navigate to `uat_test_rounds` collection
   - Verify the new test round and test cases were created

#### Option B: Using the UAT Screen (For Individual Addition)

1. **Access UAT Screen**
   - Open the app
   - Navigate to menu (three dots) → "User Acceptance Testing"
   - Ensure you have "tester" or "admin" role

2. **Create Test Round**
   - Tap the "+" icon in the AppBar (or "Add Test Round" button)
   - Enter round name and description
   - Tap "Create"

3. **Add Test Cases**
   - Select the test round from the dropdown
   - Tap the "+" icon (FAB or AppBar) to add a test case
   - Fill in:
     - Number (auto-filled based on existing cases)
     - Title (required)
     - Description
     - Feature (optional)
     - Test Steps (optional)
   - Tap "Add"

4. **Add Sub-Test Cases**
   - Expand a test case
   - Tap "Add Sub-Test" button
   - Fill in the sub-test case details
   - Tap "Add"

---

### 2. Executing Tests

1. **Access UAT Screen**
   - Navigate to menu → "User Acceptance Testing"
   - Ensure you have "tester" role

2. **Select Test Round**
   - Choose the test round from the dropdown

3. **Review Test Cases**
   - Test cases are listed with their status (pending, passed, failed)
   - Tap the info icon to view detailed test information
   - Expand test cases to see sub-test cases

4. **Execute Tests**
   - For each test case or sub-test case:
     - Review the description and test steps
     - Perform the test in the app
     - Mark as Pass (✓) or Fail (✗)
   - Once marked, the test is locked and shows the tester's name

---

### 3. Managing Test Cases (Tester/Admin Only)

Testers and admins can add test cases directly from the UAT screen:

- **Add Test Round**: Tap the "+" icon with circle outline in AppBar
- **Add Test Case**: Tap the "+" icon (FAB or AppBar) when a round is selected
- **Add Sub-Test Case**: Expand a test case and tap "Add Sub-Test"

---

## Roles and Permissions

- **Tester Role**: Can view and execute tests, add test cases
- **Admin Role**: Can view, execute, and manage all test cases
- **Regular Users**: Cannot access UAT features

To grant tester role:
1. Navigate to Admin Menu → Role Management
2. Select a user
3. Toggle "Tester" role

---

## Test Case Structure

### Test Round
- **Name**: Descriptive name (e.g., "Roadmap Phase 1.1 & 1.2 Implementation")
- **Description**: Overview of what's being tested
- **Created At**: Timestamp
- **Created By**: User ID who created it

### Test Case
- **Number**: Sequential number within the round
- **Title**: Brief title
- **Description**: Detailed description
- **Feature**: Feature being tested (optional)
- **Test**: Test steps (optional)
- **Status**: pending, passed, failed
- **Tested By**: Name of tester (after execution)
- **Tested At**: Timestamp (after execution)

### Sub-Test Case
- Same structure as test case
- Belongs to a parent test case
- Can be executed independently

---

## Best Practices

1. **Test Round Naming**
   - Use descriptive names: "Release v1.2.0", "Roadmap Phase 1.1", etc.
   - Include date or version number

2. **Test Case Organization**
   - Group related tests under the same test case
   - Use sub-test cases for detailed verification steps
   - Number test cases sequentially

3. **Test Execution**
   - Execute tests in order
   - Document any issues in the test description before marking as failed
   - Don't mark tests as passed until fully verified

4. **Regular Updates**
   - Add test cases as new features are developed
   - Update test cases when features change
   - Archive old test rounds (manually in Firebase Console)

---

## Troubleshooting

### Test Cases Not Appearing
- Verify you have "tester" role
- Check Firebase Console for test round existence
- Refresh the UAT screen

### Cannot Add Test Cases
- Verify you have "tester" or "admin" role
- Ensure a test round is selected
- Check Firebase permissions

### Script Fails
- Ensure Firebase is initialized correctly
- Check that you're authenticated (if script requires auth)
- Verify Firestore rules allow writes to `uat_test_rounds` collection

---

## Integration with Release Process

The UAT workflow should be integrated into the standard release process:

1. **Before Release**
   - Add test cases for new features
   - Review test cases with team
   - Assign testers

2. **During Testing**
   - Testers execute tests via UAT screen
   - Track progress and results
   - Address any failures

3. **After Testing**
   - Review test results
   - Fix any failed tests
   - Re-test if needed
   - Document results

---

## Future Enhancements

- Export test results to CSV/PDF
- Email notifications for test completion
- Test case templates
- Bulk import from CSV
- Test case versioning
- Test case dependencies
- Automated test execution (for regression tests)

---

*This workflow is part of the standard development process and should be followed for all releases.*

