# Dev/QA/Prod Workflow Guide

## ✅ Current Setup: Git Flow with Flavors

**Branches:**
- `develop` = Development code (may be unstable)
- `release/qa` = QA-ready code (stable, tested)
- `main` = Production-ready code (most stable, tested)

**Flavors:**
- **dev flavor** = Build from `develop` branch
- **qa flavor** = Build from `release/qa` branch
- **prod flavor** = Build from `main` branch

## 🎯 The Workflow (Git Flow)

```
develop branch → Build dev flavor
    ↓ (merge when stable)
release/qa branch → Build qa flavor
    ↓ (merge when tested)
main branch → Build prod flavor
```

**Why this works:**
- ✅ **Prod stays stable** - `main` only has tested, production-ready code
- ✅ **Dev can be messy** - `develop` is where you experiment
- ✅ **QA tests stable code** - `release/qa` has features ready for testing
- ✅ **Clear separation** - Each environment has its own code version

## 📋 Step-by-Step Workflow

### 1. Daily Development (on `develop`)

```powershell
# Start your day
git checkout develop
git pull origin develop

# Make your changes
# ... edit code ...

# Test locally with dev flavor
flutter run --release --flavor dev --dart-define=FLAVOR=dev

# Commit and push
git add .
git commit -m "Add new feature X"
git push origin develop

# Build and distribute dev build
.\build_and_distribute.ps1 dev firebase-manual
```

### 2. When Feature is Stable → Move to QA

```powershell
# Switch to QA branch
git checkout release/qa
git pull origin release/qa

# Merge develop into QA
git merge develop

# Test the merge
flutter run --release --flavor qa --dart-define=FLAVOR=qa

# Push QA branch
git push origin release/qa

# Build and distribute QA build
.\build_and_distribute.ps1 qa firebase-manual
```

### 3. When QA is Tested → Release to Prod

```powershell
# Switch to main (production)
git checkout main
git pull origin main

# Merge QA into main
git merge release/qa

# Create a release tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin main
git push origin v1.0.0

# Build and distribute prod build
.\build_and_distribute.ps1 prod firebase-manual
```

## 🚨 Important Rules

### ✅ DO:
- **Always develop on `develop`** - Never commit directly to `main`
- **Build dev flavor from `develop`** - This is your testing environment
- **Build qa flavor from `release/qa`** - Only merge stable code here
- **Build prod flavor from `main`** - Only merge tested code here
- **Tag releases on `main`** - Use version tags (v1.0.0, v1.1.0, etc.)

### ❌ DON'T:
- **Don't commit directly to `main`** - Always go through develop → qa → main
- **Don't build prod from `develop`** - Prod must come from `main`
- **Don't skip QA** - Always test in QA before prod
- **Don't merge broken code to `release/qa`** - Only stable features

## 🔄 Quick Reference

### Start New Feature
```powershell
git checkout develop
git pull origin develop
# ... make changes ...
```

### Test Dev Build
```powershell
git checkout develop
.\build_and_distribute.ps1 dev firebase-manual
```

### Promote to QA
```powershell
git checkout release/qa
git merge develop
git push origin release/qa
.\build_and_distribute.ps1 qa firebase-manual
```

### Release to Prod
```powershell
git checkout main
git merge release/qa
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin main --tags
.\build_and_distribute.ps1 prod firebase-manual
```

## 🎯 Branch Protection (Recommended)

Set up branch protection on GitHub:
1. Go to Settings → Branches
2. Add rule for `main`:
   - ✅ Require pull request reviews
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date
3. Add rule for `release/qa`:
   - ✅ Require pull request reviews (optional, but recommended)

This prevents accidental commits to `main` and ensures code review.

## 🔧 Emergency Hotfix (Prod Bug Fix)

If you need to fix a critical bug in production:

```powershell
# Create hotfix branch from main
git checkout main
git checkout -b hotfix/critical-bug-fix

# Fix the bug
# ... make changes ...

# Test the fix
flutter run --release --flavor prod --dart-define=FLAVOR=prod

# Merge to main and release
git checkout main
git merge hotfix/critical-bug-fix
git tag -a v1.0.1 -m "Hotfix: Critical bug fix"
git push origin main --tags

# Also merge back to develop
git checkout develop
git merge hotfix/critical-bug-fix
git push origin develop

# Build and distribute
.\build_and_distribute.ps1 prod firebase-manual

# Delete hotfix branch
git branch -d hotfix/critical-bug-fix
```

## 🎓 Key Concepts

1. **Flavors ≠ Branches**
   - **Flavors** = Build configurations (dev, qa, prod)
   - **Branches** = Code versions (develop, release/qa, main)

2. **Flavors control:**
   - Package name (`com.example.familyhub_mvp.dev`, etc.)
   - App name ("FamilyHub Dev", "FamilyHub Test", "FamilyHub")
   - Firebase app (separate apps for each environment)
   - Environment config (logging, API endpoints, etc.)

3. **Branches control:**
   - Which code version
   - What features are included
   - Code stability

4. **The Rule:**
   - **dev flavor** → Always build from `develop` branch
   - **qa flavor** → Always build from `release/qa` branch
   - **prod flavor** → Always build from `main` branch

   This ensures prod is always stable!

## 🤔 Common Questions

### "Can I work on dev and test at the same time?"

**Answer:** You work in ONE codebase, but you switch branches:
- **For development:** Work in `develop` branch, build `dev` flavor
- **For testing:** Merge `develop` → `release/qa`, then build `qa` flavor
- **For production:** Merge `release/qa` → `main`, then build `prod` flavor

**You don't make changes directly in `release/qa`** - always develop in `develop`, then merge when ready.

### "How do changes stay separate?"

**Answer:** Git branches keep them separate:
- `develop` branch = Your working code (can be unstable)
- `release/qa` branch = Stable code ready for testing (merged from `develop`)
- `main` branch = Production code (merged from `release/qa`)

When you switch branches (`git checkout develop` vs `git checkout release/qa`), Git swaps the entire codebase. The files in your workspace change to match that branch.

### "Can I build dev flavor from main?"

**Answer:** Technically yes, but **don't do this!** The convention is:
- **dev flavor** → Always build from `develop` branch
- **qa flavor** → Always build from `release/qa` branch
- **prod flavor** → Always build from `main` branch

This ensures prod is always stable!

### "Do I need separate code folders?"

**Answer:** No! Git handles this. One workspace, switch branches as needed.

