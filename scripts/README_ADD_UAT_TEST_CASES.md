# Add UAT Test Cases Script - Setup Guide

## Problem Fixed

The script was refactored to use HTTP REST API directly via the `http` package, avoiding Flutter-specific dependencies that require compilation.

## Authentication Options

### Option 1: Service Account (Recommended for Automation)

1. **Create a Service Account:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Select project: `family-hub-71ff0`
   - Navigate to **IAM & Admin** → **Service Accounts**
   - Click **Create Service Account**
   - Name it: `uat-test-case-creator`
   - Grant role: **Cloud Firestore User** (for Firestore access)
     - In the role selector, search for "firestore" (not "cloud data")
     - Select "Cloud Firestore User" from the results
     - If "Cloud Firestore User" is not available, use **Cloud Datastore User** instead
     - Both roles provide Firestore access
   - Click **Done**

2. **Create and Download Key:**
   - Click on the service account you just created
   - Go to **Keys** tab
   - Click **Add Key** → **Create new key**
   - Choose **JSON** format
   - Download the JSON file
   - Save it as `scripts/firebase-service-account.json` (add to `.gitignore`!)

3. **Run the Script:**
   ```bash
   set GOOGLE_APPLICATION_CREDENTIALS=scripts/firebase-service-account.json
   dart scripts/add_uat_test_cases.dart dev
   ```

### Option 2: OAuth Access Token (For Manual Runs)

1. **Get Access Token:**
   ```bash
   # Install Firebase CLI if not already installed
   npm install -g firebase-tools
   
   # Login
   firebase login
   
   # Get CI token (note: this is deprecated but still works)
   firebase login:ci
   ```

2. **Note:** The CI token from `firebase login:ci` doesn't work for Firestore REST API. You need an OAuth access token instead.

3. **Get OAuth Token:**
   - Use Google OAuth Playground: https://developers.google.com/oauthplayground/
   - Select scope: `https://www.googleapis.com/auth/cloud-platform`
   - Authorize and get access token
   - Run: `dart scripts/add_uat_test_cases.dart dev YOUR_OAUTH_TOKEN`

### Option 3: Use Flutter (Temporary Workaround)

For now, you can use the original approach:

```bash
flutter run scripts/add_uat_test_cases.dart dev
```

But this requires Flutter compilation and may have issues.

## Recommended Solution

**Use Option 1 (Service Account)** - This is the proper way for automated scripts and doesn't require user interaction.

## Script Usage

```bash
# With service account (recommended)
set GOOGLE_APPLICATION_CREDENTIALS=scripts/firebase-service-account.json
dart scripts/add_uat_test_cases.dart dev

# With OAuth token
dart scripts/add_uat_test_cases.dart dev YOUR_OAUTH_TOKEN

# With environment variable
set FIREBASE_ACCESS_TOKEN=YOUR_TOKEN
dart scripts/add_uat_test_cases.dart dev
```

## What the Script Does

1. Creates a test round in the appropriate collection:
   - `dev_uat_test_rounds` for dev environment
   - `test_uat_test_rounds` for qa environment
   - `uat_test_rounds` for prod environment

2. Adds 6 test cases covering:
   - Data Isolation
   - Subscription Management
   - Feature Flags
   - IAP Integration
   - Feature Gating
   - Subscription UI

3. Adds sub-test cases for each test case (total: 24 sub-test cases)

## Next Steps

1. Create service account in Google Cloud Console
2. Download JSON key file
3. Save as `scripts/firebase-service-account.json`
4. Add to `.gitignore`
5. Run the script!

