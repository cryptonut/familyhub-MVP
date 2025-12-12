# How to Check Service Account IAM Role

## Method 1: Google Cloud Console (Easiest)

1. **Go to IAM & Admin:**
   https://console.cloud.google.com/iam-admin/iam?project=family-hub-71ff0

2. **Find your service account:**
   - Look for: `uat-test-case-creator@family-hub-71ff0.iam.gserviceaccount.com`
   - Or search for "uat-test-case-creator"

3. **Check the "Roles" column:**
   - You should see the role(s) assigned to this service account
   - Should show: **Editor** (if it was assigned correctly)

4. **If you don't see Editor:**
   - Click the **pencil icon** (Edit) next to the service account
   - Click **"ADD ANOTHER ROLE"**
   - Search for and select **"Editor"**
   - Click **"SAVE"**
   - Wait 1-2 minutes for changes to propagate

## Method 2: Using gcloud CLI

If you have gcloud CLI installed:

```powershell
gcloud projects get-iam-policy family-hub-71ff0 --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:uat-test-case-creator@family-hub-71ff0.iam.gserviceaccount.com"
```

## Method 3: Check Service Account Details

1. **Go to Service Accounts:**
   https://console.cloud.google.com/iam-admin/serviceaccounts?project=family-hub-71ff0

2. **Click on:** `uat-test-case-creator`

3. **Go to "PERMISSIONS" tab:**
   - This shows all roles assigned to this service account
   - Should list: **Editor**

## Common Issues

- **Role not showing:** Wait 1-2 minutes after assignment for propagation
- **Wrong service account:** Make sure you're checking the correct email
- **Role assigned at wrong level:** Make sure it's assigned at the **project level**, not folder/org level

## What to Look For

The service account should have:
- ✅ **Editor** role (project-level)
- OR **Cloud Datastore User** + **Cloud Firestore User** roles

If it only has "Cloud Datastore User", that might not be sufficient for REST API access.

