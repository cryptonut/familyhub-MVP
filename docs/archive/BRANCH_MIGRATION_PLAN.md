# Branch Migration Plan - Move Work to Develop

## Current Situation
- **Current Branch:** `release/qa` ❌
- **Should Be On:** `develop` ✅
- **Uncommitted Changes:** Many modified files + new files

## Plan

### Step 1: Save Current Work
We have two options:

**Option A: Stash Changes (Recommended)**
- Saves all changes temporarily
- Can apply to develop branch
- Keeps working directory clean

**Option B: Commit to Current Branch**
- Creates a commit on release/qa
- Can cherry-pick to develop later
- Preserves history

### Step 2: Switch to Develop Branch
```bash
git checkout develop
```

### Step 3: Apply Changes to Develop
- If stashed: `git stash pop`
- If committed: `git cherry-pick <commit-hash>`

### Step 4: Verify and Test
- Ensure all changes are present
- Test that fixes work
- Commit to develop

## Recommended Approach

**Use Option A (Stash):**
1. Stash all changes (including new files)
2. Switch to develop
3. Apply stash
4. Test and commit

## Files to Migrate

### Modified Files:
- `android/app/src/main/kotlin/com/example/familyhub_mvp/MainActivity.kt` (removed workaround)
- `lib/main.dart` (CacheService initialization fix)
- `lib/services/cache_service.dart` (non-blocking with timeouts)
- Plus many other feature files

### New Files:
- All the new services, widgets, models we created
- Documentation files

## After Migration

1. Test authentication fix on develop branch
2. If working, commit to develop
3. Later, merge develop → release/qa when ready for testing

