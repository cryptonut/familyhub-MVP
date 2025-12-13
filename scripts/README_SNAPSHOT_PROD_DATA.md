# Production Data Snapshot Script

## Overview

This script performs a **ONE-TIME** snapshot of production Firestore data and copies it to both `dev_*` and `test_*` collections. This seeds the dev and test environments with historical production data for testing purposes.

**Important:** After this operation, all new data will remain separated by environment. This is just for initial seeding.

## Purpose

After migrating to environment-specific data separation (using `dev_` and `test_` prefixes), dev and test environments had no historical data. This script:

1. Takes a snapshot of all production data (unprefixed collections)
2. Copies it to `dev_*` collections
3. Copies it to `test_*` collections
4. Handles subcollections recursively

## Requirements

1. **Service Account JSON File**
   - Location: `scripts/firebase-service-account.json`
   - Must have "Editor" role in Google Cloud Console
   - Same service account used for UAT test case creation

2. **Dart SDK**
   - Script runs standalone (no Flutter required)
   - Uses `http` and `googleapis_auth` packages

## Usage

```bash
dart scripts/snapshot_prod_data.dart
```

The script will:
1. Prompt for confirmation (type `yes` to continue)
2. Authenticate using the service account
3. Copy `users` collection → `dev_users` and `test_users`
4. Copy `families` collection → `dev_families` and `test_families`
   - Includes all subcollections: tasks, events, messages, photos, budgets, etc.
5. Display progress and completion status

## What Gets Copied

### Root Collections
- `users` → `dev_users`, `test_users`
- `families` → `dev_families`, `test_families`

### Family Subcollections (copied recursively)
- `tasks` (with `dependencies` subcollection)
- `events` (with `chats` subcollection)
- `messages` (with `reactions` and `replies` subcollections)
- `privateMessages` (with `messages` and `readStatus` subcollections)
- `photos` (with `comments` subcollection)
- `albums` (with `photos` subcollection)
- `payoutRequests`
- `payouts`
- `recurringPayments`
- `pocketMoneyPayments`
- `notifications`
- `game_stats`
- `shoppingLists` (with `items` subcollection)
- `shoppingReceipts`
- `budgets` (with `categories`, `transactions`, `savingsGoals` subcollections)

### User Subcollections
- `ignoredConflicts`

## Data Handling

- **Timestamps:** Preserved as-is
- **References:** Document IDs are preserved (references may need manual adjustment if IDs change)
- **Arrays:** Copied as-is
- **Nested Objects:** Copied recursively

## Safety Features

1. **Confirmation Prompt:** Requires explicit "yes" confirmation
2. **Error Handling:** Continues on individual document failures, reports errors
3. **Non-Destructive:** Only creates new documents, doesn't delete existing data
4. **Idempotent:** Can be run multiple times (will create duplicates if documents already exist)

## Troubleshooting

### "Service account file not found"
- Ensure `scripts/firebase-service-account.json` exists
- Check file permissions

### "Failed to create document: 403"
- Verify service account has "Editor" role
- Check Firestore security rules allow service account writes

### "Failed to create document: 400"
- May indicate malformed data
- Check the specific document in production
- Script will continue with other documents

### Missing Subcollections
- Some families may not have all subcollections
- Script handles missing subcollections gracefully
- Warnings are logged but don't stop the process

## After Running

1. **Verify in Firebase Console:**
   - Check `dev_users` and `test_users` collections
   - Check `dev_families` and `test_families` collections
   - Verify subcollections are present

2. **Test in App:**
   - Run dev flavor and verify data appears
   - Run QA flavor and verify data appears
   - Verify data isolation (new data goes to correct environment)

3. **Document:**
   - Note the date this snapshot was taken
   - All data created after this date will be environment-specific

## Notes

- This is a **ONE-TIME** operation
- Future data will remain separated by environment
- Production data is not modified
- Dev/test data can be modified/deleted independently after this

