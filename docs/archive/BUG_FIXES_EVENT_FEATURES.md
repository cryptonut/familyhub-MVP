# Bug Fixes for Event Features

## Issues Fixed

### 1. Event Chat Message Sending Error
**Problem**: Messages couldn't be sent in event chat
**Root Cause**: 
- `_extractMentions` was async but not awaited
- Missing `eventId` field in message data
- User display name might be null

**Fix Applied**:
- Added `await` to `_extractMentions` call
- Added `eventId` to message data explicitly
- Improved user display name fetching from AuthService

**Files Changed**:
- `lib/services/event_chat_service.dart` - Fixed async/await and message data
- `lib/screens/chat/event_chat_widget.dart` - Improved user name fetching

### 2. Photo Upload Not Showing After Upload
**Problem**: Photos uploaded but don't appear in UI
**Root Cause**:
- Photo URL added to Firestore but `_photoUrls` state not updated
- Errors silently caught without user feedback

**Fix Applied**:
- Update `_photoUrls` state after successful upload
- Added error handling with user-visible error messages
- Added success messages for photo uploads

**Files Changed**:
- `lib/screens/calendar/add_edit_event_screen.dart` - Added state updates and error handling

### 3. Pending Photos Not Uploading After Event Creation
**Problem**: Photos marked as "Pending" don't upload after event save
**Root Cause**:
- Errors during pending photo upload were silently caught
- No user feedback on upload status

**Fix Applied**:
- Improved error handling with per-photo error messages
- Added success message when photos upload
- Better error logging

**Files Changed**:
- `lib/screens/calendar/add_edit_event_screen.dart` - Enhanced pending photo upload logic

### 4. Calendar Screen Error
**Problem**: Error displayed beneath calendar
**Root Cause**:
- `description` field might be null in some events
- No error handling in `_loadEvents`

**Fix Applied**:
- Made `description` nullable-safe in `fromJson`
- Added error handling to `_loadEvents` with user feedback
- Fixed description null check in search filter

**Files Changed**:
- `lib/models/calendar_event.dart` - Fixed description null handling
- `lib/screens/calendar/calendar_screen.dart` - Added error handling

### 5. Event Chat Access Control for Legacy Events
**Problem**: Events without `createdBy` field (legacy) might block access
**Root Cause**:
- Access check only allowed creator or invited members
- Legacy events without `createdBy` would fail access check

**Fix Applied**:
- Added fallback for legacy events: if `createdBy` is null and no invites, allow all family members
- If invites exist, check if user is in list

**Files Changed**:
- `lib/services/event_chat_service.dart` - Improved access control logic

## Testing After Fixes

1. **Event Chat**:
   - Try sending a message - should work now
   - Check error messages are clear if access denied

2. **Photo Uploads**:
   - Upload photo to existing event - should appear immediately
   - Upload photo to new event - should upload after save
   - Check error messages if upload fails

3. **Calendar**:
   - Check if error beneath calendar is gone
   - Verify events load correctly

## Next Steps

If issues persist:
1. Check Firestore console for permission errors
2. Verify Firebase Storage rules allow uploads
3. Check device logs for detailed error messages
4. Ensure `createdBy` field is set on all new events

