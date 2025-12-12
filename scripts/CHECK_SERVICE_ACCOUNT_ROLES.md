# Check Working Service Account Configuration

To find out what role the working service account has:

1. **Go to Google Cloud Console IAM:**
   https://console.cloud.google.com/iam-admin/iam?project=family-hub-71ff0

2. **Find the working service account** (the one that successfully writes to Firestore)

3. **Check its roles:**
   - Click the service account name
   - Look at the "Roles" column
   - Note which roles it has

4. **Compare with our new service account:**
   - Our service account: `uat-test-case-creator@family-hub-71ff0.iam.gserviceaccount.com`
   - Current role: "Cloud Datastore User"
   - If the working one has a different role, we need to add that role

## Common Roles for Firestore Access:

- **Cloud Datastore User** - Should work, but might not be sufficient for REST API
- **Cloud Datastore Owner** - Full access (more permissive)
- **Editor** - Project-level editor (very permissive)
- **Firebase Admin** - Firebase-specific admin role

## Next Steps:

Once you identify the working service account's role, we can:
1. Add the same role to our new service account
2. Or update the script to use the working service account
3. Or adjust the approach based on what works

