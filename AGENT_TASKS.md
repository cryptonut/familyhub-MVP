# Agent Executable Tasks

**Purpose:** Discrete tasks for Cursor agents to execute in sequence  
**Format:** Each task is self-contained with clear instructions and acceptance criteria

---

## Quick Reference

| Phase | Tasks | Status |
|-------|-------|--------|
| 1. Package Rename | 1.1-1.3 | ⬜ Not Started |
| 2. App Signing | 2.1-2.2 | ⬜ Not Started |
| 3. Legal Documents | 3.1-3.3 | ⬜ Not Started |
| 4. GDPR Compliance | 4.1-4.3 | ⬜ Not Started |
| 5. App Icons | 5.1 | ⬜ Not Started |
| 6. Metadata | 6.1-6.2 | ⬜ Not Started |
| 7. Register Screen Update | 7.1 | ⬜ Not Started |
| 8. Privacy Center Update | 8.1 | ⬜ Not Started |

---

## TASK 1.1: Rename Android Package

**Agent Prompt:**
```
Rename the Android package from com.example.familyhub_mvp to com.familyhub.app

Steps:
1. Update android/app/build.gradle.kts:
   - Change namespace from "com.example.familyhub_mvp" to "com.familyhub.app"
   - Update applicationId in dev flavor to "com.familyhub.app.dev"
   - Update applicationId in qa flavor to "com.familyhub.app.qa"  
   - Update applicationId in prod flavor to "com.familyhub.app"

2. Rename the Kotlin package directory structure:
   - Current: android/app/src/main/kotlin/com/example/familyhub_mvp/
   - Target: android/app/src/main/kotlin/com/familyhub/app/

3. Update package declarations in all Kotlin files to "package com.familyhub.app" (or appropriate subpackage)

4. Update AndroidManifest.xml widget references from com.example.familyhub_mvp to com.familyhub.app

5. Update the widget action name from com.example.familyhub_mvp.ACTION_WIDGET_TAP to com.familyhub.app.ACTION_WIDGET_TAP

Do NOT modify google-services.json files - those will be replaced separately.
```

**Files to Modify:**
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/example/familyhub_mvp/MainActivity.kt` → move & update
- `android/app/src/main/kotlin/com/example/familyhub_mvp/FamilyHubApplication.kt` → move & update
- `android/app/src/main/kotlin/com/example/familyhub_mvp/widgets/*.kt` → move & update

**Verification:**
```bash
cd /workspace && flutter clean && flutter pub get && flutter build apk --flavor dev --debug
```

---

## TASK 2.1: Configure Release Signing

**Agent Prompt:**
```
Configure release signing in android/app/build.gradle.kts

1. Add keystore properties loading at the top of the file (after existing imports):

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

2. Add signingConfigs block inside android {} block (before buildTypes):

signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
        keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String? ?: ""
    }
}

3. Update buildTypes.release to use release signing when available, falling back to debug:

buildTypes {
    release {
        signingConfig = if (keystorePropertiesFile.exists()) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }
        // ... rest of release config
    }
}

4. Create android/key.properties.example file:
# Copy to key.properties and fill in your values
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=familyhub
storeFile=../familyhub-release.keystore

5. Add to android/.gitignore:
key.properties
*.keystore
*.jks
```

**Files to Modify:**
- `android/app/build.gradle.kts`

**Files to Create:**
- `android/key.properties.example`

**Files to Update:**
- `android/.gitignore`

---

## TASK 3.1: Create Privacy Policy Document

**Agent Prompt:**
```
Create a comprehensive privacy policy document at docs/legal/PRIVACY_POLICY.md

The document must cover:
1. Introduction - App name (Family Hub), purpose, contact info
2. Information collected:
   - Account info (email, name, profile picture)
   - Location data (when location sharing enabled)
   - Calendar data (when calendar sync enabled)
   - Photos and media (when using photo albums)
   - Audio recordings (voice messages)
   - Messages and chat content
   - Device info and crash reports
   - Usage analytics
3. How information is used
4. Information sharing (only with family members user connects with, Firebase services)
5. Data security measures
6. User rights (GDPR: access, correction, deletion, export, portability)
7. CCPA rights for California users
8. Children's privacy (COPPA - under 13 parental consent)
9. Data retention policy
10. Third-party services (Firebase, Google Cloud)
11. Changes to policy
12. Contact information

Use professional legal language but keep it readable.
Last updated date: December 2024
```

**Files to Create:**
- `docs/legal/PRIVACY_POLICY.md`

---

## TASK 3.2: Create Terms of Service Document

**Agent Prompt:**
```
Create a Terms of Service document at docs/legal/TERMS_OF_SERVICE.md

The document must cover:
1. Acceptance of Terms
2. Description of Service (family organization app)
3. User Accounts
   - Registration requirements
   - Account security responsibilities
   - Age requirements (13+, or parental consent)
4. User Conduct
   - Prohibited activities
   - Content guidelines
5. User-Generated Content
   - Ownership
   - License grant to app
   - Responsibility for content
6. Intellectual Property
   - App ownership
   - User content ownership
7. Premium Features and Subscriptions
   - Billing
   - Cancellation
   - Refunds (per app store policies)
8. Privacy (reference Privacy Policy)
9. Disclaimers
   - "As is" service
   - No warranty
10. Limitation of Liability
11. Indemnification
12. Termination
13. Governing Law
14. Dispute Resolution
15. Changes to Terms
16. Contact Information

Use professional legal language.
Effective date: December 2024
```

**Files to Create:**
- `docs/legal/TERMS_OF_SERVICE.md`

---

## TASK 3.3: Create Legal Screen

**Agent Prompt:**
```
Create a Legal screen at lib/screens/settings/legal_screen.dart that displays links to Privacy Policy, Terms of Service, and Open Source Licenses.

The screen should:
1. Have an AppBar with title "Legal"
2. Show a ListView with:
   - Privacy Policy tile (opens URL in browser)
   - Terms of Service tile (opens URL in browser)
   - Open Source Licenses tile (shows Flutter's built-in license page)
3. Use url_launcher to open external URLs
4. Use Icons: privacy_tip, description, info_outline
5. Each tile should have a trailing arrow/external link icon

Use placeholder URLs that can be updated later:
- Privacy: https://familyhub.app/privacy
- Terms: https://familyhub.app/terms

Import url_launcher package (already in pubspec.yaml).
```

**Files to Create:**
- `lib/screens/settings/legal_screen.dart`

---

## TASK 4.1: Create Data Export Service

**Agent Prompt:**
```
Create a data export service at lib/services/data_export_service.dart

The service should:
1. Export all user data as JSON
2. Include:
   - User profile from Firestore
   - User's tasks (created by them)
   - User's messages (sent by them)
   - User's events (created by them)
   - Export metadata (date, user ID)
3. Save to temporary file
4. Use share_plus to share/save the file
5. Handle errors gracefully

Use FirestorePathUtils for collection paths.
Use the existing Logger service for logging.
Include proper async error handling.
```

**Files to Create:**
- `lib/services/data_export_service.dart`

---

## TASK 4.2: Create Delete Account Screen

**Agent Prompt:**
```
Create a Delete Account screen at lib/screens/settings/delete_account_screen.dart

The screen should:
1. Show a warning icon and clear message about permanent deletion
2. List what will be deleted (account, messages, tasks, photos)
3. Require password re-entry for confirmation
4. Require checkbox confirmation that action is irreversible
5. Show confirmation dialog before final deletion
6. Call AuthService.deleteCurrentUserAccount(password: password)
7. Handle errors and show appropriate messages
8. Use red color scheme to indicate danger

Use existing AuthService which already has deleteCurrentUserAccount method.
Style consistently with app theme.
```

**Files to Create:**
- `lib/screens/settings/delete_account_screen.dart`

---

## TASK 4.3: Create Analytics Consent Service

**Agent Prompt:**
```
Create an analytics consent service at lib/services/analytics_consent_service.dart

The service should:
1. Store user preferences in SharedPreferences:
   - analytics_enabled (bool, default true)
   - crashlytics_enabled (bool, default true)
2. Provide methods:
   - isAnalyticsEnabled() -> Future<bool>
   - isCrashlyticsEnabled() -> Future<bool>
   - setAnalyticsEnabled(bool) -> Future<void>
   - setCrashlyticsEnabled(bool) -> Future<void>
3. When setting enabled/disabled, also call:
   - FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled)
   - FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled)

Add firebase_analytics to imports (may need to add to pubspec.yaml if not present).
```

**Files to Create:**
- `lib/services/analytics_consent_service.dart`

**Files to Possibly Modify:**
- `pubspec.yaml` (add firebase_analytics if missing)

---

## TASK 7.1: Update Register Screen with Terms Acceptance

**Agent Prompt:**
```
Update lib/screens/auth/register_screen.dart to require terms acceptance before registration.

Changes needed:
1. Add state variable: bool _acceptedTerms = false;
2. Add import for url_launcher and gesture_recognizer
3. Before the "Create Account" button, add a CheckboxListTile with RichText:
   - Checkbox bound to _acceptedTerms
   - Text: "I agree to the Terms of Service and Privacy Policy"
   - Make "Terms of Service" and "Privacy Policy" tappable links (blue, underlined)
   - Links should open in browser using url_launcher
4. Disable the Create Account button when _acceptedTerms is false
5. Use placeholder URLs:
   - Terms: https://familyhub.app/terms
   - Privacy: https://familyhub.app/privacy

Maintain existing functionality and styling.
Add TapGestureRecognizer for the links.
```

**Files to Modify:**
- `lib/screens/auth/register_screen.dart`

---

## TASK 8.1: Update Privacy Center Screen

**Agent Prompt:**
```
Update lib/screens/settings/privacy_center_screen.dart to add:

1. A new section "Your Data" with:
   - "Export My Data" button - calls DataExportService().exportUserData()
   - "Delete My Account" button - navigates to DeleteAccountScreen

2. A new section "Privacy Preferences" with:
   - Analytics toggle - uses AnalyticsConsentService
   - Crash Reporting toggle - uses AnalyticsConsentService

3. Load initial toggle states in initState using the consent service

Add imports for:
- DataExportService
- DeleteAccountScreen  
- AnalyticsConsentService

Handle loading states and errors appropriately.
Show snackbar on successful export.
```

**Files to Modify:**
- `lib/screens/settings/privacy_center_screen.dart`

---

## TASK 9.1: Add Legal Menu to Home Screen

**Agent Prompt:**
```
Update lib/screens/home_screen.dart to add a "Legal" option to the settings/profile menu.

Find the PopupMenuButton or similar menu in the app bar and add:
- A menu item with Icons.gavel or Icons.policy
- Label: "Legal"
- On tap: Navigate to LegalScreen

Import LegalScreen from '../settings/legal_screen.dart'

Place it near other settings options like "Privacy Center".
```

**Files to Modify:**
- `lib/screens/home_screen.dart`

---

## TASK 10.1: Create Adaptive Icons

**Agent Prompt:**
```
Create Android adaptive icon configuration files.

1. Create android/app/src/main/res/values/ic_launcher_background.xml:
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#2196F3</color>
</resources>

2. Create android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml:
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>

3. Create android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml:
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>

Note: The foreground drawable (ic_launcher_foreground) will need to be created manually 
using Android Studio's Image Asset tool or a design tool, as it requires a properly 
formatted vector/PNG with safe zone considerations. For now, create placeholder files 
that reference the existing ic_launcher as foreground.

Alternative approach: Add flutter_launcher_icons to dev_dependencies and configure in pubspec.yaml.
```

**Directories to Create:**
- `android/app/src/main/res/mipmap-anydpi-v26/`

**Files to Create:**
- `android/app/src/main/res/values/ic_launcher_background.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`

---

## TASK 11.1: Update Metadata Files

**Agent Prompt:**
```
Update app metadata across all configuration files for consistency.

1. Update pubspec.yaml:
   - name: familyhub (remove _mvp)
   - description: 'Family Hub - All-in-one family organizer for calendar, tasks, chat, photos, and location sharing'
   - Keep version as is for now

2. Update web/manifest.json:
   - name: "Family Hub"
   - short_name: "Family Hub"
   - description: "All-in-one family organizer for calendar, tasks, chat, photos, and location sharing"

3. Update web/index.html:
   - <title>Family Hub</title>
   - <meta name="description" content="Family Hub - All-in-one family organizer...">
   - Update apple-mobile-web-app-title to "Family Hub"

4. Verify android/app/src/main/res/values/strings.xml has:
   - <string name="app_name">Family Hub</string>
```

**Files to Modify:**
- `pubspec.yaml`
- `web/manifest.json`
- `web/index.html`
- `android/app/src/main/res/values/strings.xml` (verify)

---

## TASK 12.1: Create Store Listing Document

**Agent Prompt:**
```
Create a Play Store listing document at docs/store/PLAY_STORE_LISTING.md

Include:
1. App Title (30 chars max): "Family Hub"
2. Short Description (80 chars max): Write compelling 80-char description
3. Full Description (4000 chars max): 
   - Use emoji section headers
   - Cover all major features: Calendar, Tasks, Chat, Photos, Location, Shopping, Games, Wallet
   - Mention premium features
   - Include call to action
4. Keywords/Tags for ASO
5. Suggested Category: Lifestyle
6. Content Rating: Everyone
7. Contact Email placeholder
8. Privacy Policy URL placeholder

Make it compelling and keyword-optimized for app store search.
```

**Directories to Create:**
- `docs/store/`

**Files to Create:**
- `docs/store/PLAY_STORE_LISTING.md`

---

## Execution Order

**Phase 1 (Critical Path - Do First):**
1. TASK 1.1 - Package rename (blocks Firebase config)
2. TASK 2.1 - Signing config

**Phase 2 (Legal - Required for Submission):**
3. TASK 3.1 - Privacy Policy
4. TASK 3.2 - Terms of Service
5. TASK 3.3 - Legal Screen

**Phase 3 (GDPR - Required for EU):**
6. TASK 4.1 - Data Export Service
7. TASK 4.2 - Delete Account Screen
8. TASK 4.3 - Analytics Consent Service

**Phase 4 (Integration):**
9. TASK 7.1 - Register Screen Update
10. TASK 8.1 - Privacy Center Update
11. TASK 9.1 - Home Screen Menu Update

**Phase 5 (Assets & Metadata):**
12. TASK 10.1 - Adaptive Icons
13. TASK 11.1 - Metadata Update
14. TASK 12.1 - Store Listing

---

## Verification Commands

After each phase, run:
```bash
cd /workspace
flutter clean
flutter pub get
flutter analyze
flutter build apk --flavor dev --debug
```

For release verification:
```bash
flutter build appbundle --flavor prod --release
```

---

*Each task should be executed as a separate agent session for clean context.*
