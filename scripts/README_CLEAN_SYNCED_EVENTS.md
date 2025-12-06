# Clean Synced Events Script

This script removes all calendar events that were imported from device calendars, allowing you to test calendar sync from scratch.

## Prerequisites

1. **You must be logged into the app first** - The script uses your current Firebase authentication session
2. Firebase must be properly configured in your project

## Usage

### Option 1: Run as Flutter Script (Recommended)

```bash
flutter run scripts/clean_synced_events.dart
```

### Option 2: Run as Dart Script

```bash
dart run scripts/clean_synced_events.dart
```

## What the Script Does

1. **Authenticates**: Checks if you're logged into Firebase
2. **Finds Synced Events**: Queries all events with `importedFromDevice: true` in your family's events collection
3. **Shows Summary**: Displays a list of events that will be deleted
4. **Asks Confirmation**: Requires you to type "yes" to proceed
5. **Deletes Events**: Removes all synced events in batches (Firestore batch limit: 500)
6. **Optional Reset**: Optionally resets your `lastSyncedAt` timestamp

## Safety Features

- ✅ Requires explicit confirmation before deleting
- ✅ Shows exactly what will be deleted
- ✅ Only deletes events with `importedFromDevice: true` (won't touch manually created events)
- ✅ Uses Firestore batches for efficient deletion
- ✅ Provides clear progress feedback

## Example Output

```
============================================================
Clean Synced Calendar Events Script
============================================================

✓ Firebase initialized
✓ User authenticated: user@example.com

✓ Family ID: abc123

Searching for synced events...
Found 2 synced events

Events to be deleted:
  - Testing sync 1 (Synced from simoncase78@gmail.com)
  - Meeting with team (Synced from simoncase78@gmail.com)

⚠️  WARNING: This will permanently delete 2 synced events.
This action cannot be undone.

Do you want to continue? (yes/no): yes

Deleting events...
  Deleted 2 / 2 events...

✓ Successfully deleted 2 synced events

Do you want to reset lastSyncedAt timestamp? (yes/no): yes
✓ Reset lastSyncedAt timestamp

============================================================
Cleanup complete! You can now sync from scratch.
============================================================
```

## Notes

- **This only deletes synced events** - Events you created manually in FamilyHub are NOT affected
- **The deletion is permanent** - Make sure you want to delete these events before confirming
- **You can sync again immediately** - After cleanup, run calendar sync again to re-import events
- **Duplicate prevention** - The new sync logic will prevent duplicates from being created again

## Troubleshooting

### "No user logged in"
- Make sure you're logged into the app first
- Run the app and log in, then run this script

### "User is not part of a family"
- Make sure you've created or joined a family in the app

### "Error initializing Firebase"
- Make sure Firebase is properly configured
- Check that `lib/firebase_options.dart` exists and is configured correctly

