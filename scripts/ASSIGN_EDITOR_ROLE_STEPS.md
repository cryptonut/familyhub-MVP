# Assign Editor Role to Service Account

## Current Status
❌ **No roles assigned** - This is why we're getting 403 errors!

## Steps to Assign Editor Role

### Option 1: From Service Account Permissions Page (Current Page)

1. **Click the blue "Manage access" button** (visible on the Permissions tab)
2. In the dialog that opens:
   - Click **"ADD ANOTHER ROLE"**
   - Search for **"Editor"**
   - Select **"Editor"** from the dropdown
   - Click **"SAVE"**

### Option 2: From IAM Page

1. **Go to IAM page:**
   https://console.cloud.google.com/iam-admin/iam?project=family-hub-71ff0

2. **Find the service account:**
   - Look for: `uat-test-case-creator@family-hub-71ff0.iam.gserviceaccount.com`
   - Or search for "uat-test-case-creator"

3. **Edit the service account:**
   - Click the **pencil icon** (Edit) in the row
   - Click **"ADD ANOTHER ROLE"**
   - Search for **"Editor"**
   - Select **"Editor"**
   - Click **"SAVE"**

## After Assignment

1. **Wait 1-2 minutes** for IAM changes to propagate
2. **Verify the role appears:**
   - Refresh the Permissions page
   - You should see "Editor" in the roles list
3. **Run the script:**
   ```bash
   dart scripts/add_uat_test_cases.dart dev
   ```

## What Editor Role Provides

The Editor role grants:
- Full read/write access to all project resources
- Access to Firestore/Datastore
- Access to all Google Cloud services in the project

This is the same role that the working service account likely has.

