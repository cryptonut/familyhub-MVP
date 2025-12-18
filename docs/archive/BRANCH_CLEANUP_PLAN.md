# Branch Cleanup Plan

## Current Branch Analysis

### ✅ **Important Branches (KEEP)**
These are your main workflow branches:

1. **`main`** - Production branch (default)
2. **`develop`** - Development branch (active work)
3. **`release/qa`** - QA testing branch (merged from develop)

### ❓ **Potentially Old (CHECK BEFORE DELETING)**
1. **`merge-chess-to-qa`** - May be old merge branch, check if still needed

### ❌ **Old AI-Generated Branches (SAFE TO DELETE)**
These appear to be branches created by GitHub Copilot and Cursor AI for specific tasks that are now complete:

1. `copilot/publish-app-for-android-testing` - Old Copilot branch
2. `cursor/diagnose-android-login-and-data-retrieval-problems-bda8` - Old Cursor branch
3. `cursor/investigate-login-errors-using-logcat-claude-4.1-opus-thinking-192c` - Old Cursor branch
4. `cursor/investigate-login-errors-using-logcat-gpt-5.1-codex-high-7de6` - Old Cursor branch
5. `cursor/review-familyhub-android-login-issues-cf0a` - Old Cursor branch
6. `cursor/review-familyhub-mvp-for-enterprise-readiness-claude-4.5-opus-high-thinking-46af` - Old Cursor branch
7. `cursor/review-familyhub-mvp-for-enterprise-readiness-composer-1-0906` - Old Cursor branch
8. `cursor/review-familyhub-mvp-for-enterprise-readiness-gemini-3-pro-preview-7189` - Old Cursor branch
9. `cursor/review-familyhub-mvp-for-enterprise-readiness-gpt-5.1-codex-b890` - Old Cursor branch

## Why So Many Branches?

These branches were likely created by:
- **GitHub Copilot** - Auto-generated branches for tasks
- **Cursor AI** - AI assistant branches for code reviews and fixes
- **Feature branches** - Created for specific features/tasks

Many appear to be from earlier development phases (login fixes, enterprise readiness reviews) that are now complete.

## Recommended Action: Clean Up Old Branches

### Option 1: Delete Old Branches (Recommended)

**Delete old AI-generated branches:**
```bash
# Delete remote branches (one at a time for safety)
git push origin --delete copilot/publish-app-for-android-testing
git push origin --delete cursor/diagnose-android-login-and-data-retrieval-problems-bda8
git push origin --delete cursor/investigate-login-errors-using-logcat-claude-4.1-opus-thinking-192c
git push origin --delete cursor/investigate-login-errors-using-logcat-gpt-5.1-codex-high-7de6
git push origin --delete cursor/review-familyhub-android-login-issues-cf0a
git push origin --delete cursor/review-familyhub-mvp-for-enterprise-readiness-claude-4.5-opus-high-thinking-46af
git push origin --delete cursor/review-familyhub-mvp-for-enterprise-readiness-composer-1-0906
git push origin --delete cursor/review-familyhub-mvp-for-enterprise-readiness-gemini-3-pro-preview-7189
git push origin --delete cursor/review-familyhub-mvp-for-enterprise-readiness-gpt-5.1-codex-b890

# Check merge-chess-to-qa first, then delete if not needed
git push origin --delete merge-chess-to-qa
```

### Option 2: Keep But Archive (If Unsure)

If you're not sure, you can:
1. Keep them for now
2. Add a note in branch description that they're archived
3. Delete later when confident they're not needed

## Best Practice Going Forward

### Branch Naming Convention
Use clear, descriptive names:
- ✅ `feature/calendar-sync`
- ✅ `bugfix/login-timeout`
- ✅ `release/qa`
- ❌ `cursor/random-task-id` (AI-generated, unclear)

### Branch Lifecycle
1. **Create** branch for feature/fix
2. **Work** on branch
3. **Merge** to `develop` or `release/qa`
4. **Delete** branch after merge (GitHub can auto-delete)

### Prevent AI Branch Proliferation
- Configure GitHub/Cursor to not auto-create branches
- Or manually delete AI branches after tasks complete
- Use feature branches with clear naming

## Current Branch Strategy (Recommended)

```
main (production)
  ↑
release/qa (QA testing)
  ↑
develop (active development)
  ↑
feature/* (individual features - delete after merge)
```

## Summary

**Total Branches:** ~13  
**Keep:** 3-4 (main, develop, release/qa, maybe merge-chess-to-qa)  
**Delete:** ~9 (old AI-generated branches)

**Action:** Clean up old branches to keep repository organized and reduce confusion.

