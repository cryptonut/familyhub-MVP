# Firebase Rules Sync Guide

## Problem: Manual Updates vs Automated Deployment

**Issue:** When rules are manually updated in Firebase Console, the local files become out of sync. Running automated deployment then overwrites the manual changes with the old local file.

## Solution: Two-Way Sync Process

### Scenario 1: Manual Update in Console → Need to Sync to Local

If you manually updated rules in Firebase Console and want to keep them:

1. **Run sync script:**
   ```powershell
   .\sync_rules_from_console.ps1
   ```

2. **Follow the prompts:**
   - Copy rules from Firebase Console
   - Paste into the opened Notepad file
   - Save and close

3. **Verify sync:**
   - Check line count matches console
   - Run deployment script to ensure they match

### Scenario 2: Local File Updated → Deploy to Console

If you updated the local file and want to deploy:

1. **Run deployment script:**
   ```powershell
   .\deploy_firebase_rules_verified.ps1
   ```

2. **Script will:**
   - Verify local file content
   - Deploy to Firebase
   - Warn if deployment was skipped
   - Provide manual steps if needed

## Best Practice Workflow

1. **Always update local files first** (not console)
2. **Then deploy using script** (ensures sync)
3. **If you must update console manually:**
   - Immediately run `sync_rules_from_console.ps1`
   - Commit the synced file to git
   - Document why manual update was needed

## Current Status

- **Local Firestore Rules:** 610 lines (includes openMatchmakingEnabled)
- **Local Storage Rules:** 37 lines
- **Deployed:** Check Firebase Console timestamps

## Verification

After any deployment:
- [ ] Check "Last published" timestamp in console
- [ ] Verify line count matches local file
- [ ] Search for key features (e.g., "openMatchmakingEnabled")
- [ ] Test functionality

