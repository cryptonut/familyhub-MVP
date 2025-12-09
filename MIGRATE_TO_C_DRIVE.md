# Project Migration to C: Drive - Comprehensive Plan

## Overview

This document outlines the complete plan to migrate `familyhub-MVP` from `D:\Users\Simon\Documents\familyhub-MVP` to `C:\Users\Simon\Documents\familyhub-MVP` safely and without breaking anything.

## Pre-Migration Checklist

### 1. Verify Requirements
- [x] C: drive has 180GB+ free (confirmed)
- [ ] Current project size verified (run `check_project_size.ps1`)
- [ ] All changes committed and pushed
- [ ] No active builds or processes
- [ ] Backup created (optional but recommended)

### 2. Current Location Analysis
- **Current:** `D:\Users\Simon\Documents\familyhub-MVP`
- **Target:** `C:\Users\Simon\Documents\familyhub-MVP`
- **Space needed:** ~5-10 GB (to be verified)

## What Needs to Be Updated

### ✅ Items That DON'T Need Updates (Relative Paths)
- Git repository (uses relative paths)
- Flutter project structure (relative paths)
- Most scripts (use `Get-Location` or relative paths)
- Gradle cache (`~/.gradle` - already on C:)
- Android SDK (typically already on C:)

### ⚠️ Items That MIGHT Need Updates
- IDE/Editor project paths (VS Code, Android Studio, etc.)
- Terminal/Shell working directories
- Any custom environment variables pointing to project
- Windows shortcuts/aliases

### ❌ Items That DON'T Need Changes
- Firebase configuration (no paths)
- GitHub remotes (URLs, not paths)
- Package dependencies (relative)
- Build configurations (relative)

## Migration Strategy

### Phase 1: Preparation
1. Check current size
2. Verify C: drive space
3. Commit all pending changes
4. Close IDEs/editors

### Phase 2: Safe Migration
1. Use `robocopy` for reliable file copy
2. Verify copy integrity
3. Update Git working directory
4. Test basic operations

### Phase 3: Verification
1. Run Flutter doctor
2. Test build
3. Verify Git operations
4. Check IDE access

### Phase 4: Cleanup
1. Verify everything works on C:
2. Backup old location (rename)
3. Update any shortcuts
4. Document completion

## Benefits of Moving to C:

1. **Faster Builds:** SSD on C: drive (if project currently on HDD)
2. **Better Performance:** Same drive as Gradle cache and Android SDK
3. **Simpler Paths:** Avoids cross-drive operations
4. **Standard Location:** Documents folder on C: is typical

## Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| Path references break | Use `robocopy` with verification, test immediately |
| Git issues | Git uses relative paths, should be fine |
| IDE won't find project | Document how to reopen in IDE |
| Build failures | Keep old location as backup initially |
| Permission issues | Run PowerShell as Administrator if needed |

## Rollback Plan

If anything breaks:
1. Rename `C:\Users\Simon\Documents\familyhub-MVP` to `familyhub-MVP.backup`
2. Rename `D:\Users\Simon\Documents\familyhub-MVP.backup` back to `familyhub-MVP`
3. Everything should work again

## Post-Migration Tasks

1. Update IDE workspace/project paths
2. Update any desktop shortcuts
3. Test full build
4. Test Git push/pull
5. Verify Firebase operations
6. Delete old backup after verification

