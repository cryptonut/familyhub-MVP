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

See `release_to_qa_testers.ps1` for full QA release automation.

## Production Release Process

1. Merge `release/qa` to `main`
2. Update version in `pubspec.yaml`
3. Build production APK
4. Deploy Firebase rules (use `deploy_firebase_rules_verified.ps1`)
5. Upload to Play Store
6. Update release notes
