# Quick Fixes for Critical Security Issues

This document provides step-by-step instructions to fix the most critical security issues identified in the audit.

## 1. Remove API Keys from Source Code (URGENT)

### Step 1: Create Environment Variable Files

Create `.env.dev`, `.env.qa`, `.env.prod` files (already in .gitignore):

```bash
# .env.dev
FIREBASE_API_KEY=your_dev_api_key_here
RECAPTCHA_SITE_KEY=your_recaptcha_key_here

# .env.qa  
FIREBASE_API_KEY=your_qa_api_key_here
RECAPTCHA_SITE_KEY=your_recaptcha_key_here

# .env.prod
FIREBASE_API_KEY=your_prod_api_key_here
RECAPTCHA_SITE_KEY=your_recaptcha_key_here
```

### Step 2: Update Config Files

**lib/config/dev_config.dart:**
```dart
@override
String get firebaseApiKey => const String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: '', // Will fail fast if not set
);
```

**lib/config/prod_config.dart:**
```dart
@override
String get firebaseApiKey => const String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: '',
);
```

**lib/config/qa_config.dart:**
```dart
@override
String get firebaseApiKey => const String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: '',
);
```

### Step 3: Update Build Commands

```bash
# Dev build
flutter run --dart-define=FIREBASE_API_KEY=your_key --dart-define=RECAPTCHA_SITE_KEY=your_key

# Release build
flutter build apk --dart-define=FIREBASE_API_KEY=your_key --dart-define=RECAPTCHA_SITE_KEY=your_key
```

### Step 4: Update CI/CD

Add secrets to your CI/CD platform and use:
```yaml
flutter build apk --dart-define=FIREBASE_API_KEY=${{ secrets.FIREBASE_API_KEY }}
```

---

## 2. Remove Google Services Files from Git (URGENT)

### Step 1: Add to .gitignore

Add to `.gitignore`:
```
# Firebase configuration files (contains sensitive data)
**/google-services.json
**/GoogleService-Info.plist
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

### Step 2: Remove from Git History

```bash
# Using git filter-branch (slow but works)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch android/app/src/*/google-services.json ios/Runner/GoogleService-Info.plist" \
  --prune-empty --tag-name-filter cat -- --all

# Or use BFG Repo-Cleaner (faster)
# Download from https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --delete-files google-services.json
java -jar bfg.jar --delete-files GoogleService-Info.plist
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

### Step 3: Document Setup Process

Create `docs/SETUP_FIREBASE_CONFIG.md` with instructions for developers.

---

## 3. Remove Print Statements (URGENT)

### Step 1: Find All Print Statements

```bash
grep -r "print(" lib/ --include="*.dart"
grep -r "debugPrint(" lib/ --include="*.dart"
```

### Step 2: Replace with Logger Service

**Before:**
```dart
print('DEBUG: Loaded ${items.length} items');
```

**After:**
```dart
if (kDebugMode) {
  Logger.debug('Loaded ${items.length} items', tag: 'BudgetDetailScreen');
}
```

### Step 3: Add Lint Rule

Add to `analysis_options.yaml`:
```yaml
linter:
  rules:
    - avoid_print  # Already present, ensure it's enabled
```

---

## 4. Change Package Name (URGENT)

### Step 1: Choose New Package Name

Example: `com.familyhub.app` or `io.familyhub.mobile`

### Step 2: Update Android

**android/app/build.gradle.kts:**
```kotlin
productFlavors {
    create("dev") {
        applicationId = "com.familyhub.app.dev"  // Changed
    }
    create("qa") {
        applicationId = "com.familyhub.app.test"  // Changed
    }
    create("prod") {
        applicationId = "com.familyhub.app"  // Changed
    }
}
```

### Step 3: Update iOS

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Update Bundle Identifier to `com.familyhub.app`
4. Update for each scheme (dev, qa, prod)

### Step 4: Update Firebase

1. Create new Firebase apps with new package names
2. Download new `google-services.json` files
3. Update `firebase_options.dart` with new app IDs

### Step 5: Update All References

```bash
# Find all references
grep -r "com.example.familyhub" . --exclude-dir=build --exclude-dir=.git
```

---

## 5. Fix Release Signing (URGENT)

### Step 1: Generate Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### Step 2: Create key.properties

Create `android/key.properties` (add to .gitignore):
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

### Step 3: Update build.gradle.kts

```kotlin
// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")  // Fixed
            minifyEnabled = true
            shrinkResources = true
        }
    }
}
```

---

## 6. Create Privacy Policy (URGENT)

### Template Structure

1. **Introduction**
   - What data you collect
   - Why you collect it

2. **Data Collection**
   - Personal information (name, email, birthday)
   - Location data
   - Photos
   - Calendar data
   - Chat messages
   - Usage data

3. **Data Usage**
   - How data is used
   - Who has access
   - Third-party services (Firebase, Agora, Google Maps)

4. **Data Sharing**
   - With family members
   - With third parties
   - Legal requirements

5. **Data Security**
   - Encryption measures
   - Access controls

6. **User Rights**
   - Access to data
   - Deletion requests
   - GDPR/CCPA rights

7. **Children's Privacy**
   - COPPA compliance
   - Age restrictions

8. **Contact Information**
   - Privacy contact email
   - Address

### Hosting

- Host on your website (e.g., `https://familyhub.app/privacy`)
- Must be publicly accessible
- Must be accessible without login

---

## 7. Fix Firestore Security Rules

### Issue: Overly Permissive User Reads

**Current (Line 102):**
```javascript
allow read: if isAuthenticated();  // Too permissive
```

**Fixed:**
```javascript
// Users can read their own document
allow read: if isAuthenticated() && request.auth.uid == userId;

// Users can read other users' documents only if they're in the same family
allow read: if isAuthenticated() && 
  belongsToFamily(resource.data.familyId);
```

### Issue: Chess Games Public Read

**Current (Line 1383):**
```javascript
allow read: if isAuthenticated();  // All authenticated users
```

**Fixed:**
```javascript
// Users can read games they're involved in or games in their family
allow read: if isAuthenticated() && (
  isGameParticipant() ||
  belongsToFamily(resource.data.familyId)
);
```

---

## 8. Implement Certificate Pinning

### Add Dependency

```yaml
dependencies:
  certificate_pinning: ^2.0.0
```

### Implement Pinning

```dart
import 'package:certificate_pinning/certificate_pinning.dart';

class SecureHttpClient {
  static Dio createSecureClient() {
    final dio = Dio();
    
    dio.httpClientAdapter = IOHttpClientAdapter()
      ..onHttpClientCreate = (client) {
        client.badCertificateCallback = 
          CertificatePinning.check(
            host: 'firebase.googleapis.com',
            fingerprints: [
              'SHA256:your_fingerprint_here',
            ],
          );
        return client;
      };
    
    return dio;
  }
}
```

---

## Verification Checklist

After implementing fixes, verify:

- [ ] No API keys in source code
- [ ] Google services files not in git
- [ ] No print() statements in code
- [ ] Package name changed from com.example
- [ ] Release builds signed properly
- [ ] Privacy Policy created and hosted
- [ ] Firestore rules tightened
- [ ] Certificate pinning implemented
- [ ] All builds succeed
- [ ] App runs correctly

---

## Next Steps

1. Complete all URGENT fixes
2. Test thoroughly
3. Review HIGH priority issues
4. Plan MEDIUM priority improvements
5. Schedule security review
