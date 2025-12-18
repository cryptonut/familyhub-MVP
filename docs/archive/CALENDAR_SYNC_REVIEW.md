# Calendar Sync Implementation Review

## Issues Identified

### 1. **CRITICAL: Calendar ID Type Mismatch Risk**
**Location**: `lib/services/calendar_sync_service.dart:453-459`

**Problem**: After verifying the calendar exists and storing it in `selectedCalendar`, we still use the original `calendarId` parameter to call `retrieveEvents`. If there's any type mismatch or formatting issue, this could fail silently.

**Fix**: Use `selectedCalendar.id!` instead of the parameter `calendarId` after verification.

```dart
// CURRENT (Line 453):
final deviceEventsResult = await _deviceCalendar.retrieveEvents(
  calendarId,  // ❌ Using parameter
  ...
);

// SHOULD BE:
final deviceEventsResult = await _deviceCalendar.retrieveEvents(
  selectedCalendar?.id ?? calendarId,  // ✅ Use verified calendar ID
  ...
);
```

### 2. **Missing Null Safety Check**
**Location**: `lib/services/calendar_sync_service.dart:550`

**Problem**: Using `cal.id!` without null check when iterating through calendars.

**Fix**: Add null check:
```dart
if (cal.id == null || cal.id == calendarId) continue;
```

### 3. **Calendar ID Comparison May Fail on Android**
**Location**: `lib/services/calendar_sync_service.dart:421`

**Problem**: On Android, calendar IDs from `device_calendar` can be numeric strings (e.g., "2"), but comparison might fail if there are whitespace or type issues.

**Fix**: Normalize comparison:
```dart
selectedCalendar = calendarsResult.data!.firstWhere(
  (cal) => cal.id?.trim() == calendarId?.trim(),
  orElse: () => Calendar(),
);
```

### 4. **Missing Error Details in retrieveEvents**
**Location**: `lib/services/calendar_sync_service.dart:453-459`

**Problem**: If `retrieveEvents fails silently, we don't log the actual calendar ID being used.

**Fix**: Log the exact calendar ID being used:
```dart
Logger.info(
  'Calling retrieveEvents with calendarId: "$calendarId" (type: ${calendarId.runtimeType})',
  tag: 'CalendarSyncService',
);
```

### 5. **Potential Timezone Issue**
**Location**: `lib/services/calendar_sync_service.dart:212-215`

**Problem**: Using `tz.local` for all conversions. On Android, device calendars might use different timezones.

**Current**:
```dart
tz.TZDateTime _toTZDateTime(DateTime dateTime) {
  final location = tz.local;
  return tz.TZDateTime.from(dateTime, location);
}
```

**Recommendation**: Consider using the device's actual timezone or the calendar's timezone if available.

### 6. **Missing Permission Re-check Before retrieveEvents**
**Location**: `lib/services/calendar_sync_service.dart:453`

**Problem**: We check permissions at the start of `syncFromDevice`, but permissions might be revoked between checks.

**Fix**: Add permission check right before `retrieveEvents`:
```dart
if (!await hasPermissions()) {
  Logger.error('Calendar permissions revoked during sync', tag: 'CalendarSyncService');
  return;
}
```

### 7. **Empty Calendar Detection Logic**
**Location**: `lib/services/calendar_sync_service.dart:511-575`

**Problem**: The diagnostic code runs AFTER we've already determined there are no events, but we should check if the calendar is actually accessible first.

**Current Flow**:
1. Call `retrieveEvents` → Returns empty list
2. Run diagnostics

**Better Flow**:
1. Verify calendar exists and is accessible
2. Check if calendar has ANY events (wider range)
3. If yes, log warning about date range
4. If no, check other calendars

### 8. **Missing createdBy Field in Imported Events**
**Location**: `lib/services/calendar_sync_service.dart:626-641`

**Problem**: When importing events from device calendar, we don't set `createdBy` field, which is required for event details screen.

**Fix**: Add `createdBy` field:
```dart
batch.set(eventRef, {
  ...
  'createdBy': userModel.uid,  // ✅ Add this
  ...
}, SetOptions(merge: true));
```

## Best Practices Review

### ✅ Good Practices Found:
1. Comprehensive error handling with try-catch blocks
2. Detailed logging for debugging
3. Permission checks before operations
4. Date range logic for first sync vs. subsequent syncs
5. Skipping FamilyHub events to avoid duplicates
6. Using batch operations for Firestore writes

### ⚠️ Areas for Improvement:
1. **Calendar ID handling**: Should normalize and verify IDs consistently
2. **Error messages**: Could be more user-friendly
3. **Retry logic**: No automatic retry on transient failures
4. **Rate limiting**: No protection against too-frequent syncs
5. **Conflict resolution**: Currently FamilyHub wins, but no user notification

## Recommended Fixes (Priority Order)

1. **HIGH**: Use verified `selectedCalendar.id` instead of parameter `calendarId` in `retrieveEvents`
2. **HIGH**: Add `createdBy` field to imported events
3. **MEDIUM**: Normalize calendar ID comparison (trim whitespace)
4. **MEDIUM**: Add null safety check for `cal.id` in diagnostic loop
5. **LOW**: Add permission re-check before `retrieveEvents`
6. **LOW**: Improve timezone handling

## Testing Recommendations

1. Test with calendar IDs that are:
   - Numeric strings ("2", "123")
   - UUIDs
   - Strings with whitespace
   - Very long strings

2. Test with calendars that:
   - Have no events
   - Have events outside date range
   - Are read-only
   - Are from different accounts

3. Test permission scenarios:
   - Permissions granted
   - Permissions denied
   - Permissions revoked mid-sync

