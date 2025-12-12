# Release Instructions for Agents

## Firebase Rules Deployment

### Automated Deployment (Recommended)

Use the verified deployment script:

```powershell
.\deploy_firebase_rules_verified.ps1
```

This script:
- Verifies local rules files (line count, key features)
- Deploys both Firestore and Storage rules
- Detects if deployment was skipped by CLI
- Provides verification steps and console URLs

**Important:** If the script reports "already up to date, skipping upload" but rules don't match in console, use manual deployment (see below).

### Manual Deployment (If Automated Fails)

**When to use:** If CLI says "already up to date" but console shows old rules (e.g., 38 lines instead of 610).

1. **Firestore Rules:**
   - Open `firestore.rules` in Notepad
   - Copy all (Ctrl+A, Ctrl+C)
   - Go to: https://console.firebase.google.com/project/family-hub-71ff0/firestore/rules
   - Delete all existing rules
   - Paste (Ctrl+V)
   - Click **Publish**
   - Verify "Last published" timestamp updates

2. **Storage Rules:**
   - Open `storage.rules` in Notepad
   - Copy all (Ctrl+A, Ctrl+C)
   - Go to: https://console.firebase.google.com/project/family-hub-71ff0/storage/rules
   - Delete all existing rules
   - Paste (Ctrl+V)
   - Click **Publish**

### Verification Checklist

After deployment, verify:
- [ ] Firestore Console shows "Last published" with recent timestamp
- [ ] Storage Console shows "Last published" with recent timestamp  
- [ ] Search for "openMatchmakingEnabled" in Firestore rules (should find 5 matches)
- [ ] Firestore rules show ~610 lines (not 38)
- [ ] Storage rules show ~37 lines

### Understanding Deployment Status

**Firestore Console:**
- "Last published" timestamp is at the top of the Rules tab
- Shows when rules were last deployed
- Updates immediately after manual publish

**Storage Console:**
- "Last published" timestamp should be at the top of the Rules tab
- If not visible, rules may not have been deployed recently
- Check deployment via CLI or deploy manually

## QA Release Process

### Automated QA Release (Recommended)

Use the automated release script:

```powershell
.\release_to_qa_testers.ps1
```

This script automatically:
- Checks out `release/qa` branch
- Merges `develop` into `release/qa`
- **Auto-increments build number** in `pubspec.yaml` (ensures unique version for each release)
- Commits and pushes version change
- Builds QA release APK
- Distributes to `qa-testers` group on Firebase App Distribution
- Generates release notes with commit history

**Important:** The script automatically increments the build number (e.g., `1.0.1+2` → `1.0.1+3`) to ensure each release has a unique version. This is critical because:
- Firebase App Distribution only sends email notifications for **new releases**, not updates to existing releases
- Each unique version triggers email notifications to testers
- The version increment is automatically committed to the repository

**Version Format:** `Major.Minor.Patch+Build`
- Example: `1.0.1+4` means version 1.0.1, build number 4
- The build number is automatically incremented on each release

### Manual QA Release (If Needed)

If you need to manually create a QA release:

1. **Checkout and merge:**
   ```powershell
   git checkout release/qa
   git merge develop
   ```

2. **Increment build number in `pubspec.yaml`:**
   ```yaml
   version: 1.0.1+4  # Increment the number after the +
   ```

3. **Commit version change:**
   ```powershell
   git add pubspec.yaml
   git commit -m "chore: Bump build number for QA release"
   git push origin release/qa
   ```

4. **Build and distribute:**
   ```powershell
   flutter build apk --release --flavor qa --dart-define=FLAVOR=qa
   firebase appdistribution:distribute build\app\outputs\flutter-apk\app-qa-release.apk --app YOUR_APP_ID --groups "qa-testers" --release-notes "QA Release Build"
   ```

## Production Release Process

1. Merge `release/qa` to `main`
2. Update version in `pubspec.yaml`
3. Build production APK
4. Deploy Firebase rules (use `deploy_firebase_rules_verified.ps1`)
5. Upload to Play Store
6. Update release notes
