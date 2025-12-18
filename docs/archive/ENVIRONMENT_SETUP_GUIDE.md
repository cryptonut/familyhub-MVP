# Dev/Test/Prod Environment Setup Guide

## Overview

This guide sets up a professional three-environment structure:
- **Dev** - Development builds for active feature development
- **Test** - Stable builds for bug fixing and QA testing
- **Prod** - Production-ready builds for end users

## Recommended Structure

### ✅ Why This Approach is Good

1. **Isolation**: Each environment has separate app IDs, preventing conflicts
2. **Safety**: Can't accidentally deploy dev code to production
3. **Testing**: Test environment mirrors production for realistic testing
4. **Flexibility**: Developers can work on features without affecting testers
5. **Firebase Integration**: Each environment can use same Firebase project with different apps

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Git Branches                         │
├─────────────────────────────────────────────────────────┤
│  main (prod)  →  release/test  →  develop (dev)        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│              Flutter Flavors (Build Configs)            │
├─────────────────────────────────────────────────────────┤
│  prod       →  test       →  dev                        │
│  (stable)      (QA)         (features)                   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│         Firebase App Distribution Groups                 │
├─────────────────────────────────────────────────────────┤
│  prod-testers  →  test-testers  →  dev-testers          │
└─────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Flutter Flavors Setup

**App IDs:**
- Dev: `com.example.familyhub_mvp.dev`
- Test: `com.example.familyhub_mvp.test`
- Prod: `com.example.familyhub_mvp` (current)

**Benefits:**
- Install all three versions on same device
- Different app icons/names for easy identification
- Separate Firebase app configurations
- Environment-specific API endpoints (if needed)

### Phase 2: Git Branching Strategy

**Branches:**
- `main` → Production releases (stable, tested)
- `release/test` → Test environment (bug fixes, QA)
- `develop` → Development (new features, experiments)

**Workflow:**
1. Feature development → `develop` branch
2. Ready for testing → Merge to `release/test`
3. Tested and stable → Merge to `main`

### Phase 3: Firebase App Distribution Groups

**Groups:**
- `dev-testers` → Internal developers, early testers
- `test-testers` → QA team, beta testers
- `prod-testers` → Final testers before public release

### Phase 4: Version Management

**Versioning Strategy:**
- Dev: `1.0.0-dev.X` (increments frequently)
- Test: `1.0.0-test.X` (increments on bug fixes)
- Prod: `1.0.0+X` (semantic versioning)

## File Structure

```
familyhub-MVP/
├── android/
│   └── app/
│       ├── src/
│       │   ├── dev/
│       │   │   ├── AndroidManifest.xml
│       │   │   └── res/
│       │   ├── test/
│       │   │   ├── AndroidManifest.xml
│       │   │   └── res/
│       │   └── prod/
│       │       ├── AndroidManifest.xml
│       │       └── res/
│       ├── google-services.json (prod)
│       ├── google-services-dev.json
│       └── google-services-test.json
├── lib/
│   ├── config/
│   │   ├── app_config.dart
│   │   ├── dev_config.dart
│   │   ├── test_config.dart
│   │   └── prod_config.dart
│   └── main.dart
└── build_and_distribute.ps1 (updated for flavors)
```

## Next Steps

1. ✅ Review this structure
2. ⏳ Set up Flutter flavors
3. ⏳ Configure Firebase apps for each environment
4. ⏳ Update build scripts
5. ⏳ Set up Git branches
6. ⏳ Create Firebase App Distribution groups

## Questions to Consider

1. **Firebase Project**: Use same project with 3 apps, or separate projects?
   - **Recommendation**: Same project, 3 apps (easier management)

2. **Data Separation**: Should environments share Firestore data?
   - **Recommendation**: Separate collections/prefixes (dev_*, test_*, prod_*)

3. **Build Frequency**: How often to build each environment?
   - Dev: On every commit to `develop`
   - Test: Weekly or on bug fixes
   - Prod: On stable releases

4. **Tester Access**: Who gets access to which environment?
   - Dev: Developers only
   - Test: QA + selected beta testers
   - Prod: Final validation before Play Store

