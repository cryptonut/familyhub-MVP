# Google Play Store Release - Implementation Plan

**Document Type:** Agent Execution Plan  
**Created:** December 18, 2025  
**Target Completion:** 10-15 days  
**Status:** Ready for Execution

---

## Overview

This document provides step-by-step instructions for Cursor agents to prepare Family Hub for Google Play Store submission. Tasks are organized in dependency order with clear acceptance criteria.

---

## Phase 1: Package Name & Identity (Days 1-2)

### Task 1.1: Update Android Package Name
**Priority:** 🔴 CRITICAL - Blocks everything else  
**Estimated Time:** 2-4 hours  
**Dependencies:** None

**Instructions:**
1. Update `android/app/build.gradle.kts`:
   - Change `namespace` from `com.example.familyhub_mvp` to `com.familyhub.app`
   - Update all `applicationId` in product flavors:
     - `dev`: `com.familyhub.app.dev`
     - `qa`: `com.familyhub.app.qa`  
     - `prod`: `com.familyhub.app`

2. Rename Kotlin package directory:
   - Move `android/app/src/main/kotlin/com/example/familyhub_mvp/` 
   - To `android/app/src/main/kotlin/com/familyhub/app/`

3. Update all Kotlin files in that directory:
   - `MainActivity.kt` - change package declaration
   - `FamilyHubApplication.kt` - change package declaration
   - `widgets/FamilyHubWidgetProvider.kt` - change package declaration
   - `widgets/WidgetConfigurationActivity.kt` - change package declaration
   - `widgets/WidgetUpdateService.kt` - change package declaration

4. Update `android/app/src/main/AndroidManifest.xml`:
   - Update widget receiver `android:name` to new package path
   - Update widget configuration activity `android:name`
   - Update widget service `android:name`
   - Update widget action from `com.example.familyhub_mvp.ACTION_WIDGET_TAP` to `com.familyhub.app.ACTION_WIDGET_TAP`

5. Update `android/app/src/debug/AndroidManifest.xml` if needed

6. Update `android/app/src/profile/AndroidManifest.xml` if needed

**Acceptance Criteria:**
- [ ] `flutter build apk --flavor prod` completes without errors
- [ ] App launches successfully on device/emulator
- [ ] No references to `com.example` remain in Android files

---

### Task 1.2: Regenerate Firebase Configuration
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 1-2 hours  
**Dependencies:** Task 1.1 complete

**Instructions:**
1. Go to Firebase Console → Project Settings → Your apps
2. Add new Android apps with updated package names:
   - `com.familyhub.app` (production)
   - `com.familyhub.app.dev` (development)
   - `com.familyhub.app.qa` (QA/test)
3. Download new `google-services.json` files
4. Place in correct flavor directories:
   - `android/app/src/prod/google-services.json`
   - `android/app/src/dev/google-services.json`
   - `android/app/src/qa/google-services.json`
5. Update `lib/firebase_options.dart` with new app IDs

**Acceptance Criteria:**
- [ ] Firebase Auth works with new package name
- [ ] Firestore connections work
- [ ] FCM notifications work

---

### Task 1.3: Update iOS Bundle Identifier (If iOS release planned)
**Priority:** 🟡 MEDIUM  
**Estimated Time:** 1 hour  
**Dependencies:** Task 1.1 complete

**Instructions:**
1. Update `ios/Runner.xcodeproj/project.pbxproj`:
   - Change `PRODUCT_BUNDLE_IDENTIFIER` from `com.example.familyhubMvp` to `com.familyhub.app`
2. Update `ios/Runner/Info.plist` if needed
3. Regenerate iOS Firebase config in Firebase Console
4. Download and replace `ios/Runner/GoogleService-Info.plist`

**Acceptance Criteria:**
- [ ] iOS build completes successfully
- [ ] Firebase works on iOS

---

## Phase 2: App Signing Configuration (Day 2)

### Task 2.1: Generate Production Keystore
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 30 minutes  
**Dependencies:** None (can run parallel to Phase 1)

**Instructions:**
1. Generate keystore using keytool (DO NOT commit to repo):
```bash
keytool -genkey -v -keystore familyhub-release.keystore -alias familyhub -keyalg RSA -keysize 2048 -validity 10000
```

2. Create `android/key.properties` file (add to .gitignore):
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=familyhub
storeFile=../familyhub-release.keystore
```

3. Add to `android/.gitignore`:
```
key.properties
*.keystore
*.jks
```

4. Store keystore backup in secure location (NOT in repo)

**Acceptance Criteria:**
- [ ] Keystore file exists outside repo
- [ ] `key.properties` created and gitignored
- [ ] Backup of keystore stored securely

---

### Task 2.2: Configure Release Signing
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 1 hour  
**Dependencies:** Task 2.1 complete

**Instructions:**
1. Update `android/app/build.gradle.kts`:

```kotlin
import java.util.Properties
import java.io.FileInputStream

// Add at top after existing imports
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

**Acceptance Criteria:**
- [ ] `flutter build appbundle --flavor prod --release` succeeds
- [ ] AAB is signed with release key (verify with `jarsigner -verify`)
- [ ] App installs and runs from release build

---

## Phase 3: Legal Documents (Days 2-3)

### Task 3.1: Create Privacy Policy
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 2-3 hours  
**Dependencies:** None

**Instructions:**
1. Create `docs/legal/PRIVACY_POLICY.md` with the following sections:
   - Introduction (app name, company, contact info)
   - Information We Collect:
     - Account information (email, name)
     - Location data (if enabled)
     - Calendar data (for sync feature)
     - Photos and media (for photo albums)
     - Audio recordings (for voice messages)
     - Device information (for crash reporting)
   - How We Use Information
   - Data Sharing (with family members only, Firebase services)
   - Data Retention
   - Children's Privacy (COPPA compliance - app is for families)
   - Your Rights (GDPR: access, correction, deletion, export)
   - Security Measures
   - Changes to Policy
   - Contact Information

2. Create HTML version at `docs/legal/privacy_policy.html` for web hosting

**Template structure:**
```markdown
# Privacy Policy for Family Hub

**Last Updated:** [DATE]
**Effective Date:** [DATE]

## 1. Introduction
Family Hub ("we", "our", "us") is committed to protecting your privacy...

## 2. Information We Collect
### 2.1 Information You Provide
- Email address and display name (for account creation)
- Profile information (birthday, relationship role)
- Photos you upload to family albums
- Voice messages you record
- Calendar events you create
- Tasks and shopping lists
- Chat messages within your family

### 2.2 Information Collected Automatically
- Device information (model, OS version)
- Crash reports and performance data (via Firebase Crashlytics)
- Usage analytics (via Firebase Analytics)
- Location data (only when you enable location sharing)

### 2.3 Information from Third Parties
- Calendar data (when you enable calendar sync)

## 3. How We Use Your Information
...

## 4. Information Sharing
We share information:
- With family members you've connected with in the app
- With service providers (Firebase/Google Cloud) for app operation
- As required by law

We do NOT sell your personal information.

## 5. Data Retention
...

## 6. Your Privacy Rights
### For EU/EEA Residents (GDPR)
- Right to access your data
- Right to correct your data
- Right to delete your data
- Right to data portability
- Right to withdraw consent

### For California Residents (CCPA)
...

## 7. Children's Privacy
...

## 8. Security
...

## 9. Changes to This Policy
...

## 10. Contact Us
...
```

**Acceptance Criteria:**
- [ ] Privacy policy document created
- [ ] Covers all data types collected by the app
- [ ] Includes GDPR rights section
- [ ] Includes contact information
- [ ] HTML version ready for web hosting

---

### Task 3.2: Create Terms of Service
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 2 hours  
**Dependencies:** None

**Instructions:**
1. Create `docs/legal/TERMS_OF_SERVICE.md` with sections:
   - Acceptance of Terms
   - Description of Service
   - User Accounts and Registration
   - User Conduct and Prohibited Activities
   - User-Generated Content
   - Intellectual Property
   - In-App Purchases and Subscriptions
   - Termination
   - Disclaimers and Limitation of Liability
   - Governing Law
   - Changes to Terms
   - Contact Information

**Acceptance Criteria:**
- [ ] Terms of Service document created
- [ ] Covers subscription/IAP terms
- [ ] Includes limitation of liability
- [ ] HTML version ready for web hosting

---

### Task 3.3: Add Legal Links to App
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 2 hours  
**Dependencies:** Tasks 3.1, 3.2 complete

**Instructions:**
1. Create new file `lib/screens/settings/legal_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});
  
  static const String privacyPolicyUrl = 'https://yourwebsite.com/privacy';
  static const String termsOfServiceUrl = 'https://yourwebsite.com/terms';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(Uri.parse(privacyPolicyUrl)),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(Uri.parse(termsOfServiceUrl)),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Open Source Licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Family Hub',
              applicationVersion: '1.0.1',
            ),
          ),
        ],
      ),
    );
  }
}
```

2. Add Legal option to Settings/Profile menu in `home_screen.dart`

3. Update `lib/screens/auth/register_screen.dart` to add consent checkbox:
```dart
// Add before Create Account button
CheckboxListTile(
  value: _acceptedTerms,
  onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
  title: RichText(
    text: TextSpan(
      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
      children: [
        const TextSpan(text: 'I agree to the '),
        TextSpan(
          text: 'Terms of Service',
          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(termsUrl)),
        ),
        const TextSpan(text: ' and '),
        TextSpan(
          text: 'Privacy Policy',
          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(privacyUrl)),
        ),
      ],
    ),
  ),
  controlAffinity: ListTileControlAffinity.leading,
),
```

4. Disable Create Account button until terms accepted

**Acceptance Criteria:**
- [ ] Legal screen accessible from app settings
- [ ] Privacy Policy and ToS links work
- [ ] Registration requires terms acceptance
- [ ] Open source licenses page accessible

---

## Phase 4: GDPR Compliance (Days 3-4)

### Task 4.1: Create Data Export Feature
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 3-4 hours  
**Dependencies:** None

**Instructions:**
1. Create `lib/services/data_export_service.dart`:
```dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DataExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> exportUserData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final exportData = <String, dynamic>{
      'exportDate': DateTime.now().toIso8601String(),
      'userId': user.uid,
      'email': user.email,
    };

    // Export user profile
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      exportData['profile'] = userDoc.data();
    }

    // Export user's family data
    final userData = userDoc.data();
    final familyId = userData?['familyId'] as String?;
    
    if (familyId != null) {
      // Export tasks
      final tasks = await _firestore
          .collection('families/$familyId/tasks')
          .where('createdBy', isEqualTo: user.uid)
          .get();
      exportData['tasks'] = tasks.docs.map((d) => d.data()).toList();

      // Export messages
      final messages = await _firestore
          .collection('families/$familyId/messages')
          .where('senderId', isEqualTo: user.uid)
          .get();
      exportData['messages'] = messages.docs.map((d) => d.data()).toList();

      // Export events created by user
      final events = await _firestore
          .collection('families/$familyId/events')
          .where('createdBy', isEqualTo: user.uid)
          .get();
      exportData['events'] = events.docs.map((d) => d.data()).toList();
    }

    // Save to file and share
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/familyhub_data_export.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Family Hub Data Export',
    );
  }
}
```

2. Add export button to Privacy Center screen

**Acceptance Criteria:**
- [ ] User can export their data as JSON
- [ ] Export includes profile, tasks, messages, events
- [ ] Export can be shared/saved

---

### Task 4.2: Create Account Deletion UI
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 2-3 hours  
**Dependencies:** None (account deletion code exists in AuthService)

**Instructions:**
1. Create `lib/screens/settings/delete_account_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isDeleting = false;
  bool _confirmChecked = false;

  Future<void> _deleteAccount() async {
    if (!_confirmChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm you understand this action is irreversible')),
      );
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete:\n\n'
          '• Your account and profile\n'
          '• All your messages\n'
          '• All your tasks\n'
          '• All your photos\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _authService.deleteCurrentUserAccount(password: password);
      // User will be signed out automatically, auth wrapper will handle navigation
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        backgroundColor: Colors.red.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              'Delete Your Account',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'This action is permanent and cannot be undone. '
              'All your data will be permanently deleted.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password to confirm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _confirmChecked,
              onChanged: (v) => setState(() => _confirmChecked = v ?? false),
              title: const Text(
                'I understand this action is irreversible',
                style: TextStyle(fontSize: 14),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isDeleting ? null : _deleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isDeleting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Delete My Account'),
            ),
          ],
        ),
      ),
    );
  }
}
```

2. Add link to Delete Account screen from Privacy Center

**Acceptance Criteria:**
- [ ] Delete Account screen accessible from Privacy Center
- [ ] Requires password re-authentication
- [ ] Shows clear warning about data loss
- [ ] Account deletion works correctly

---

### Task 4.3: Add Analytics Consent Toggle
**Priority:** 🟡 IMPORTANT  
**Estimated Time:** 2 hours  
**Dependencies:** None

**Instructions:**
1. Add to `lib/services/analytics_consent_service.dart`:
```dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsConsentService {
  static const _analyticsKey = 'analytics_enabled';
  static const _crashlyticsKey = 'crashlytics_enabled';

  Future<bool> isAnalyticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_analyticsKey) ?? true; // Default enabled
  }

  Future<bool> isCrashlyticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_crashlyticsKey) ?? true;
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsKey, enabled);
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
  }

  Future<void> setCrashlyticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_crashlyticsKey, enabled);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  }
}
```

2. Add toggles to Privacy Center screen

**Acceptance Criteria:**
- [ ] User can disable analytics
- [ ] User can disable crash reporting
- [ ] Preferences persist across app restarts

---

## Phase 5: App Icons & Graphics (Days 4-5)

### Task 5.1: Create Adaptive App Icons
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 2-3 hours  
**Dependencies:** None

**Instructions:**
1. Create icon source files (or use existing assets):
   - Foreground icon (should be simple, 108x108dp safe zone in 72x72dp center)
   - Background color or image

2. Create `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

3. Create `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

4. Create `android/app/src/main/res/values/ic_launcher_background.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#2196F3</color>
</resources>
```

5. Create foreground drawable `android/app/src/main/res/drawable/ic_launcher_foreground.xml`
   - Or use PNG files in drawable-hdpi, drawable-mdpi, etc.

6. Generate all density versions using Android Studio's Image Asset tool or:
   - `flutter_launcher_icons` package

7. Alternative: Use `flutter_launcher_icons` package:
   - Add to `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1
   
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/icon/app_icon.png"
     adaptive_icon_background: "#2196F3"
     adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
   ```
   - Run: `flutter pub run flutter_launcher_icons`

**Acceptance Criteria:**
- [ ] Adaptive icons display correctly on Android 8+
- [ ] Round icons display correctly
- [ ] Legacy icons still work on older Android
- [ ] Icon looks good at all sizes

---

### Task 5.2: Create Play Store Graphics
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 4-6 hours (can be done outside Cursor)  
**Dependencies:** App must be runnable

**Instructions:**
1. Create Feature Graphic (1024 x 500 px):
   - App name prominently displayed
   - Key app features illustrated
   - Clean, professional design
   - Save as `assets/store/feature_graphic.png`

2. Capture Phone Screenshots (1080 x 1920 or 1440 x 2560):
   - Minimum 2, recommend 8
   - Show key features:
     1. Dashboard/Home screen
     2. Calendar view
     3. Family chat
     4. Task list
     5. Photo albums
     6. Location sharing
     7. Shopping lists
     8. Settings/Profile
   - Save in `assets/store/screenshots/phone/`

3. Capture Tablet Screenshots (if supporting tablets):
   - 7-inch: 1200 x 1920
   - 10-inch: 1600 x 2560
   - Save in `assets/store/screenshots/tablet/`

4. Create High-res Icon (512 x 512 px):
   - PNG format, no transparency at edges
   - Save as `assets/store/icon_512.png`

**Acceptance Criteria:**
- [ ] Feature graphic created (1024x500)
- [ ] 8 phone screenshots captured
- [ ] Screenshots show key app features
- [ ] 512x512 icon for Play Store

---

## Phase 6: Play Store Metadata (Days 5-6)

### Task 6.1: Update App Metadata
**Priority:** 🟡 IMPORTANT  
**Estimated Time:** 1 hour  
**Dependencies:** None

**Instructions:**
1. Update `pubspec.yaml`:
```yaml
name: familyhub
description: 'Family Hub - All-in-one family organizer for calendar, tasks, chat, photos, and location sharing'
version: 1.0.0+1  # Reset for store release
```

2. Update `web/manifest.json`:
```json
{
    "name": "Family Hub",
    "short_name": "Family Hub",
    "description": "All-in-one family organizer for calendar, tasks, chat, photos, and location sharing",
    ...
}
```

3. Update `web/index.html`:
```html
<meta name="description" content="Family Hub - All-in-one family organizer for calendar, tasks, chat, photos, and location sharing">
<title>Family Hub</title>
```

4. Update `android/app/src/main/res/values/strings.xml`:
```xml
<resources>
    <string name="app_name">Family Hub</string>
</resources>
```

**Acceptance Criteria:**
- [ ] App name consistent across all files
- [ ] Description updated everywhere
- [ ] Version reset for store release

---

### Task 6.2: Create Store Listing Content
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 2-3 hours  
**Dependencies:** None

**Instructions:**
1. Create `docs/store/PLAY_STORE_LISTING.md`:

```markdown
# Play Store Listing Content

## App Name (30 chars max)
Family Hub

## Short Description (80 chars max)
All-in-one family organizer: Calendar, Tasks, Chat, Photos & Location sharing

## Full Description (4000 chars max)
Family Hub brings your family together in one beautifully designed app. Stay organized, connected, and in sync with the people who matter most.

📅 SHARED CALENDAR
• Create and share family events
• Sync with Google Calendar and device calendars
• Set reminders and recurring events
• RSVP tracking for family gatherings

✅ TASK MANAGEMENT
• Create shared to-do lists
• Assign tasks to family members
• Track completion and earn rewards
• Set due dates and priorities

💬 FAMILY CHAT
• Private family messaging
• Share photos and voice messages
• React to messages with emojis
• Keep conversations organized

📸 PHOTO ALBUMS
• Create shared family albums
• Upload and organize photos
• Comment and react to memories
• Cloud-synced across all devices

📍 LOCATION SHARING
• See where family members are
• Get arrival notifications
• Privacy controls for each member
• Peace of mind for parents

🛒 SHOPPING LISTS
• Create collaborative shopping lists
• Check off items in real-time
• Organize by store or category
• Never forget essentials again

🎮 FAMILY GAMES
• Play chess with family members
• Puzzle games for all ages
• Track scores and achievements
• Quality time together, anywhere

💰 FAMILY WALLET (Premium)
• Track allowances and chores
• Teach kids about money
• Set savings goals together

PREMIUM FEATURES:
• Extended Family Hubs - Connect with grandparents, aunts, uncles
• Homeschooling Hub - Manage curriculum and track progress
• Co-Parenting Hub - Coordinate schedules across households
• Encrypted Chat - End-to-end encrypted messaging

Family Hub is designed with privacy and security in mind. Your data belongs to your family.

Download now and bring your family closer together! 👨‍👩‍👧‍👦

## Keywords/Tags
family, organizer, calendar, shared calendar, family app, parenting, task manager, family chat, location sharing, shopping list, co-parenting

## Category
Lifestyle (Primary) / Productivity (Secondary)

## Content Rating
Everyone

## Contact Email
support@familyhub.app

## Privacy Policy URL
https://familyhub.app/privacy

## Target Audience
Families with children, parents, extended families
```

**Acceptance Criteria:**
- [ ] All store listing content written
- [ ] Character limits respected
- [ ] Keywords identified
- [ ] Contact info prepared

---

## Phase 7: Play Console Configuration (Days 6-7)

### Task 7.1: Configure In-App Purchases
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 2 hours  
**Dependencies:** App must be uploaded to Play Console first

**Instructions:**
1. In Google Play Console → Monetization → Products → Subscriptions:
   - Create `premium_monthly`:
     - Name: "Premium Monthly"
     - Description: "Access all premium features"
     - Price: $4.99/month
     - Grace period: 7 days
     - Free trial: 7 days
   
   - Create `premium_yearly`:
     - Name: "Premium Yearly"
     - Description: "Access all premium features - Best Value!"
     - Price: $47.99/year (20% savings)
     - Grace period: 14 days
     - Free trial: 14 days

2. Update `lib/services/subscription_service.dart` with correct product IDs

3. Add license testers for testing purchases:
   - Settings → License testing → Add tester emails

**Acceptance Criteria:**
- [ ] Monthly subscription created
- [ ] Yearly subscription created
- [ ] Test accounts configured
- [ ] IAP purchase flow works in testing

---

### Task 7.2: Complete Data Safety Form
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 1-2 hours  
**Dependencies:** Privacy Policy complete

**Instructions:**
Fill out Data Safety form in Play Console with:

| Data Type | Collected | Shared | Required | Purpose |
|-----------|-----------|--------|----------|---------|
| Email | Yes | No | Yes | Account management |
| Name | Yes | Yes (family) | Yes | App functionality |
| User IDs | Yes | No | Yes | Account management |
| Location | Yes | Yes (family) | No | Location sharing feature |
| Photos | Yes | Yes (family) | No | Photo albums feature |
| Audio | Yes | Yes (family) | No | Voice messages |
| Calendar | Yes | Yes (family) | No | Calendar sync |
| Purchases | Yes | No | No | Premium features |
| Crash logs | Yes | Yes (Firebase) | Yes | App stability |
| Usage data | Yes | Yes (Firebase) | No | Analytics |

Security practices:
- [x] Data encrypted in transit
- [x] User can request data deletion

**Acceptance Criteria:**
- [ ] All data types declared
- [ ] Sharing purposes explained
- [ ] Security practices selected
- [ ] Form submitted

---

### Task 7.3: Complete Content Rating
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 30 minutes  
**Dependencies:** None

**Instructions:**
1. Complete IARC questionnaire in Play Console
2. Answer honestly about:
   - User-generated content: Yes (chat, photos)
   - Location sharing: Yes
   - Purchases: Yes
   - Violence: No
   - Sexual content: No
   - Profanity: No
   - Gambling: No

Expected rating: **Everyone** or **Everyone 10+**

**Acceptance Criteria:**
- [ ] IARC questionnaire completed
- [ ] Content rating assigned
- [ ] No unexpected restrictions

---

## Phase 8: Final Testing & Submission (Days 7-10)

### Task 8.1: Release Build Testing
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 4-6 hours  
**Dependencies:** All previous phases

**Instructions:**
1. Build release AAB:
```bash
flutter build appbundle --flavor prod --release
```

2. Test on multiple devices:
   - Low-end Android device (Android 6.0+)
   - Mid-range Android device
   - High-end Android device
   - Android tablet (if supporting)

3. Verify all features work:
   - [ ] Registration flow
   - [ ] Login flow
   - [ ] Family creation
   - [ ] Family invitation
   - [ ] Calendar sync
   - [ ] Chat messaging
   - [ ] Photo upload
   - [ ] Location sharing
   - [ ] Task creation
   - [ ] Shopping lists
   - [ ] Games
   - [ ] Premium features (test IAP)
   - [ ] Push notifications
   - [ ] Deep links
   - [ ] Widgets

4. Run static analysis:
```bash
flutter analyze
```

5. Fix any issues found

**Acceptance Criteria:**
- [ ] Release build runs on all test devices
- [ ] All features work correctly
- [ ] No crashes or ANRs
- [ ] `flutter analyze` passes
- [ ] Performance is acceptable

---

### Task 8.2: Pre-Launch Report
**Priority:** 🟡 IMPORTANT  
**Estimated Time:** 2-4 hours  
**Dependencies:** AAB uploaded to Play Console

**Instructions:**
1. Upload AAB to Play Console (internal testing track)
2. Wait for Pre-Launch Report to generate
3. Review and fix any issues:
   - Security vulnerabilities
   - Crashes
   - Performance issues
   - Accessibility warnings
   - Screenshot verification

**Acceptance Criteria:**
- [ ] No critical issues in pre-launch report
- [ ] Security scan passes
- [ ] Accessibility basics covered

---

### Task 8.3: Submit for Review
**Priority:** 🔴 CRITICAL  
**Estimated Time:** 1 hour  
**Dependencies:** All tasks complete

**Instructions:**
1. Create production release in Play Console
2. Upload signed AAB
3. Complete all store listing fields
4. Upload all graphics
5. Submit for review
6. Expected review time: 1-7 days

**Acceptance Criteria:**
- [ ] App submitted for review
- [ ] No policy violations flagged
- [ ] All required fields completed

---

## Appendix A: File Changes Summary

### Files to Create
- `docs/legal/PRIVACY_POLICY.md`
- `docs/legal/TERMS_OF_SERVICE.md`
- `lib/screens/settings/legal_screen.dart`
- `lib/screens/settings/delete_account_screen.dart`
- `lib/services/data_export_service.dart`
- `lib/services/analytics_consent_service.dart`
- `android/key.properties` (gitignored)
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`
- `android/app/src/main/res/values/ic_launcher_background.xml`
- `docs/store/PLAY_STORE_LISTING.md`
- `assets/store/` directory with graphics

### Files to Modify
- `android/app/build.gradle.kts` - package name, signing config
- `android/app/src/main/AndroidManifest.xml` - package references
- `android/app/src/main/kotlin/...` - all Kotlin files (package declaration)
- `lib/firebase_options.dart` - new app IDs
- `lib/screens/auth/register_screen.dart` - terms acceptance
- `lib/screens/home_screen.dart` - add legal menu option
- `lib/screens/settings/privacy_center_screen.dart` - add data controls
- `pubspec.yaml` - description, version
- `web/manifest.json` - metadata
- `web/index.html` - metadata
- All flavor `google-services.json` files

### Files to Add to .gitignore
- `android/key.properties`
- `*.keystore`
- `*.jks`

---

## Appendix B: Rollback Plan

If issues are discovered after submission:

1. **Before approval:** Cancel submission in Play Console
2. **After approval:** 
   - Use staged rollout (start at 5%)
   - Monitor crash reports
   - Halt rollout if issues found
   - Submit hotfix update

---

## Appendix C: Post-Launch Checklist

- [ ] Monitor crash reports in Firebase Crashlytics
- [ ] Respond to user reviews
- [ ] Set up Play Console alerts
- [ ] Plan first update with bug fixes
- [ ] Monitor subscription conversion rates
- [ ] Set up A/B testing for store listing

---

*End of Implementation Plan*
