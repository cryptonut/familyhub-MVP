# Firestore Rules Validation Guide

This document ensures field names in models match what's checked in Firestore rules.

## Field Name Consistency Checklist

### ✅ Hub Model
- **Model Field**: `creatorId` (lib/models/hub.dart)
- **Model Field**: `memberIds` (lib/models/hub.dart)
- **Rules Check**: `creatorId` ✅
- **Rules Check**: `memberIds` ✅

### ✅ Task Model
- **Model Field**: `createdBy` (lib/models/task.dart)
- **Rules Check**: `createdBy` ✅

### ✅ CalendarEvent Model
- **Model Field**: `createdBy` (lib/models/calendar_event.dart)
- **Rules Check**: `createdBy` ✅

### ✅ PhotoAlbum Model
- **Model Field**: `createdBy` (lib/models/photo_album.dart)
- **Rules Check**: `createdBy` ✅

### ✅ EventTemplate Model
- **Model Field**: `createdBy` (lib/models/event_template.dart)
- **Rules Check**: `createdBy` ✅

## Validation Process

Before deploying Firestore rules:

1. **Check Model Fields**: Review all model files in `lib/models/` for field names
2. **Check Rules**: Verify `firestore.rules` uses the same field names
3. **Check Services**: Ensure services use correct field names when creating/updating documents
4. **Test**: Always test create/update/delete operations after rule changes

## Common Mistakes to Avoid

- ❌ Using `createdBy` when model uses `creatorId` (Hub model)
- ❌ Using `members` when model uses `memberIds` (Hub model)
- ❌ Inconsistent field names between model and rules
- ❌ Not testing after rule changes

## Quick Validation Script

### Automated Validation
Run the Dart validation script:
```bash
dart scripts/validate_firestore_rules.dart
```

### Manual Validation
Run these commands to check for mismatches:

```bash
# Check for createdBy/creatorId usage
grep -r "createdBy\|creatorId" lib/models/
grep -r "createdBy\|creatorId" firestore.rules

# Check for members/memberIds usage
grep -r "members\|memberIds" lib/models/
grep -r "members\|memberIds" firestore.rules
```

## When Adding New Models

1. Define the model with consistent field naming
2. Update this validation document
3. Add Firestore rules using the exact same field names
4. Test create/update/delete operations
5. Document any exceptions (e.g., Hub uses `creatorId` instead of `createdBy`)

