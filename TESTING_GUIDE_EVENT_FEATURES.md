# Testing Guide: Event-Specific Chats & Photo Attachments

## Overview
This guide covers testing the newly implemented features:
1. **Event-Specific Chats** - Chat threads scoped to individual calendar events
2. **Photo Attachments in Events** - Upload and display photos within calendar events
3. **Event Details Screen** - New dedicated screen for viewing event details

## Prerequisites
- App is running on `develop` branch
- User is logged in and part of a family
- Firebase is properly configured

## Testing Event Details Screen

### Test 1: Navigate to Event Details
1. Open the Calendar screen
2. Tap on any existing event
3. **Expected**: Event Details Screen opens showing:
   - Event title, date, time, location
   - Description (if present)
   - Participants list
   - Photos section (if photos exist)
   - Event Chat section

### Test 2: Edit Event from Details Screen
1. Open an event you created (or have edit permissions)
2. Tap the edit icon (pencil) in the app bar
3. **Expected**: AddEditEventScreen opens with event data pre-filled
4. Make changes and save
5. **Expected**: Returns to Event Details Screen with updated information

## Testing Photo Attachments

### Test 3: Upload Photo to Existing Event
1. Open an existing event in Event Details Screen
2. Navigate to Add/Edit Event Screen
3. Scroll to "Photos" section
4. Tap "Add Photo" button
5. Select a photo from gallery
6. **Expected**: 
   - Photo uploads (shows "Uploading..." state)
   - Photo appears in the list after upload
   - Photo displays in Event Details Screen

### Test 4: Upload Photo to New Event
1. Create a new event
2. Before saving, tap "Add Photo"
3. Select a photo
4. **Expected**: Photo shows as "Pending" with orange badge
5. Fill in event details and save
6. **Expected**: 
   - Event is created
   - Pending photo uploads automatically
   - Photo appears in Event Details Screen

### Test 5: Multiple Photos
1. Open Add/Edit Event Screen
2. Upload multiple photos (2-3)
3. **Expected**: All photos display in horizontal scrollable list
4. Save event
5. **Expected**: All photos appear in Event Details Screen

### Test 6: Delete Photo
1. In Add/Edit Event Screen, view uploaded photos
2. Tap the X button on a photo
3. **Expected**: Photo is removed from list
4. Save event
5. **Expected**: Photo is removed from event

### Test 7: File Size Limit
1. Try to upload a photo larger than 10MB
2. **Expected**: Error message: "File size exceeds 10MB limit"

### Test 8: Photo Display
1. View an event with photos in Event Details Screen
2. **Expected**: 
   - Photos section shows horizontal scrollable list
   - Photos display as thumbnails (200x200)
   - Broken images show error icon

## Testing Event-Specific Chats

### Test 9: Access Event Chat
1. Open an event you're invited to (or created)
2. Scroll to "Event Chat" section
3. **Expected**: 
   - Chat widget loads
   - Shows "No messages yet" if empty
   - Shows existing messages if any

### Test 10: Send Message
1. In Event Chat, type a message
2. Tap send button
3. **Expected**: 
   - Message appears in chat
   - Message shows your name/avatar
   - Real-time update (no refresh needed)

### Test 11: Access Control
1. Create an event and invite specific family members
2. As an invited member, try to access event chat
3. **Expected**: Can access and send messages
4. As a non-invited member, try to access event chat
5. **Expected**: Cannot access (access denied error or empty chat)

### Test 12: Edit Message
1. Send a message in event chat
2. Tap the three-dot menu on your message
3. Select "Edit"
4. Modify the message text
5. Tap save
6. **Expected**: 
   - Message updates with new content
   - Shows "edited" indicator
   - Timestamp shows edit time

### Test 13: Delete Message
1. Send a message in event chat
2. Tap the three-dot menu on your message
3. Select "Delete"
4. Confirm deletion
5. **Expected**: 
   - Message shows "[Message deleted]"
   - Message is marked as deleted

### Test 14: Admin Delete (Moderation)
1. As an admin, view a message from another user
2. **Expected**: Admin can delete any message
3. Delete a message
4. **Expected**: Message shows "[Message deleted by admin]"

### Test 15: @Mentions
1. In event chat, type a message with @username
2. Send message
3. **Expected**: 
   - Message is sent
   - @mention is detected (stored in mentionedUserIds)
   - User receives notification (if FCM is configured)

### Test 16: Real-time Updates
1. Open event chat on Device A
2. Send a message from Device B (same event)
3. **Expected**: Message appears on Device A without refresh

### Test 17: Offline Resilience
1. Disable network connection
2. Send a message in event chat
3. **Expected**: 
   - Message queues locally (Firestore offline persistence)
   - Message sends when connection restored

## Testing Integration

### Test 18: Event with Both Features
1. Create an event with:
   - Title, description, location
   - Multiple photos
   - Invite family members
2. Save event
3. Open Event Details Screen
4. **Expected**: 
   - All event info displays correctly
   - Photos section shows all photos
   - Chat section is accessible
5. Send a message in chat mentioning event details
6. **Expected**: Message appears in chat

### Test 19: Event Creator Permissions
1. Create an event as User A
2. **Expected**: `createdBy` field is set to User A's ID
3. As User A, edit the event
4. **Expected**: Can edit (creator has permissions)
5. As User B (invited), try to edit
6. **Expected**: Cannot edit (only creator can edit)

## Known Issues to Watch For

1. **Photo Upload for New Events**: Photos marked as "Pending" should upload after event creation
2. **Chat Access**: Only event creator + invited members can access chat
3. **Real-time Sync**: Messages should appear immediately without refresh
4. **File Size**: 10MB limit enforced on upload

## Troubleshooting

### Photos Not Uploading
- Check Firebase Storage rules allow writes
- Verify file size is under 10MB
- Check network connection
- Review console logs for errors

### Chat Not Loading
- Verify user is event creator or invited member
- Check Firestore rules for `events/{eventId}/chats` collection
- Verify `createdBy` field exists on event document

### Messages Not Appearing
- Check Firestore rules allow reads on chat collection
- Verify real-time listeners are active
- Check for network connectivity issues

## Firestore Security Rules Required

Make sure these rules are in place:

```javascript
// Event chats
match /families/{familyId}/events/{eventId}/chats/{messageId} {
  allow read: if request.auth != null && 
    (resource.data.createdBy == request.auth.uid || 
     request.auth.uid in get(/databases/$(database)/documents/families/$(familyId)/events/$(eventId)).data.invitedMemberIds);
  allow create: if request.auth != null && 
    (resource.data.createdBy == request.auth.uid || 
     request.auth.uid in get(/databases/$(database)/documents/families/$(familyId)/events/$(eventId)).data.invitedMemberIds);
  allow update, delete: if request.auth != null && 
    (request.auth.uid == resource.data.senderId || 
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles has 'Admin');
}

// Event photos in Storage
match /eventPhotos/{familyId}/{eventId}/{photoId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null;
}
```

## Next Steps After Testing

If all tests pass:
1. Proceed with Multiple Distinct Calendars implementation
2. Continue with Web Version (calendar focus)
3. Create Home Screen Widgets plan/stub

If issues found:
1. Document issues in this file
2. Fix critical bugs before proceeding
3. Re-test affected features

