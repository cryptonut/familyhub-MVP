# FamilyHub MVP - QA Release Notes v2.1

**Release Date:** December 1, 2025  
**Version:** QA Build v2.1  
**Branch:** `release/qa` (merged from `develop`)

---

## 🎉 Major Features

### 📅 Calendar Sync - Complete Implementation
**Two-way synchronization between FamilyHub and device calendars (Google, Apple, Outlook)**

**Key Features:**
- ✅ Pull events from device calendars into FamilyHub
- ✅ Push FamilyHub events to device calendars
- ✅ Automatic duplicate prevention (tracks by deviceEventId)
- ✅ Real-time calendar updates via Firestore streams
- ✅ Event origin tracking (shows "Synced from [Calendar Name]")
- ✅ Creator tracking (shows "Created by [User Name]")
- ✅ Calendar selection with event count indicators
- ✅ Last synced timestamp display
- ✅ Manual sync and cleanup tools

**Technical Implementation:**
- Uses `device_calendar` plugin for cross-platform calendar access
- Firestore-based sync state management
- Background sync support via `BackgroundSyncService`
- Comprehensive error handling and logging
- Permission management for Android/iOS

### 📸 Photo Attachments in Events
**Secure photo uploads directly within calendar events**

**Key Features:**
- ✅ Multi-photo upload support
- ✅ 10MB file size limit with validation
- ✅ Real-time photo display in event details
- ✅ Photo deletion capability
- ✅ Firebase Storage integration with proper security rules
- ✅ Cross-platform support (mobile and web)

### 💬 Event-Specific Chats
**Discussion threads scoped to individual calendar events**

**Key Features:**
- ✅ Real-time chat via Firestore streams
- ✅ Access control (only event participants can chat)
- ✅ Message display with sender names
- ✅ Integrated into event details screen

### ♟️ Chess Game - PvP Fixes
**Fixed player vs player functionality for family games**

**Key Features:**
- ✅ Proper game invitation flow (waiting status)
- ✅ Real-time waiting games list via Firestore streams
- ✅ Opponent validation on join
- ✅ "Waiting for opponent" UI with join button
- ✅ Fixed game creation to not set opponent ID prematurely

**Technical Fixes:**
- Games now created in "waiting" status
- Added `invitedPlayerId` field to track intended opponent
- Real-time stream for waiting games
- Proper join validation

---

## 🐛 Bug Fixes

### Calendar Sync
- ✅ Fixed calendar ID type mismatch (now uses verified calendar ID)
- ✅ Fixed duplicate event creation (tracks by deviceEventId)
- ✅ Fixed calendar selection showing event counts
- ✅ Fixed calendar selection dialog showing "Unnamed Calendar" (now uses accountName fallback)
- ✅ **CRITICAL FIX: Fixed calendar sync in release APK builds** - Added ProGuard rules to prevent R8 obfuscation from breaking device_calendar plugin
- ✅ Fixed calendar names and event counts displaying correctly in release builds
- ✅ Fixed real-time calendar updates (uses Firestore streams)
- ✅ Fixed "last synced" timestamp display
- ✅ Fixed calendar sync screen layout issues
- ✅ Fixed event import not setting `createdBy` field
- ✅ Fixed sync not importing events (wider date range for first sync)
- ✅ Fixed `lastSyncedAt` updating even when no events imported

### Calendar Screen
- ✅ Fixed persistent "BOTTOM OVERFLOWED" error (using SingleChildScrollView)
- ✅ Fixed search functionality (now shows all filtered events)
- ✅ Fixed search text readability (proper theme colors)
- ✅ Fixed search bar auto-hide when cleared
- ✅ Fixed calendar events not refreshing after sync (real-time streams)

### Event Details
- ✅ Added event source display ("Synced from [Calendar]" or "Created in FamilyHub")
- ✅ Added creator display ("Created by [User Name]")
- ✅ Fixed event details screen navigation

### Chess Game
- ✅ Fixed PvP invitation flow (games now properly wait for opponent)
- ✅ Fixed opponent not actually joining (proper join validation)
- ✅ Fixed waiting games not updating in real-time
- ✅ Fixed game screen not handling waiting status

### UI/UX
- ✅ Fixed tasks screen layout (collapsible filters)
- ✅ Fixed calendar sync settings screen layout
- ✅ Fixed widget lifecycle errors (mounted checks)
- ✅ Fixed photo upload UI updates

---

## 🔧 Technical Changes

### New Files
- `lib/models/event_chat_message.dart` - Event chat message model
- `lib/services/event_chat_service.dart` - Event chat service
- `lib/screens/chat/event_chat_widget.dart` - Event chat UI widget
- `lib/screens/calendar/event_details_screen.dart` - Dedicated event details screen
- `scripts/clean_synced_events.dart` - Utility script for cleaning synced events
- `scripts/README_CLEAN_SYNCED_EVENTS.md` - Script documentation

### Updated Services
- `CalendarService` - Added photo upload methods (mobile & web), 10MB limit
- `CalendarSyncService` - Complete rewrite with duplicate prevention, verified calendar IDs, diagnostic logging
- `EventChatService` - New service for event-specific chats
- `ChessService` - Fixed PvP flow, added waiting games queries and streams
- `AuthService` - Added `getUserById` method

### Updated Models
- `CalendarEvent` - Added `createdBy`, `photoUrls`, `sourceCalendar` fields
- `ChessGame` - Added `invitedPlayerId` field for proper invitation tracking

### Updated Screens
- `CalendarScreen` - Real-time Firestore streams, fixed overflow, improved search
- `AddEditEventScreen` - Photo upload integration, proper state management
- `EventDetailsScreen` - New dedicated screen with photos, chat, source/creator info
- `CalendarSyncSettingsScreen` - Improved layout, event count indicators, last synced timestamp
- `ChessFamilyGameScreen` - Real-time waiting games, proper invitation flow
- `ChessGameScreen` - Waiting status handling, join button for invited players

### Infrastructure
- Updated `.gitignore` to exclude `*.logcat` and `*.log` files
- Added Firebase Storage rules for event photos
- Updated Firestore rules for event chats
- Added calendar permissions to AndroidManifest.xml
- **Added ProGuard/R8 rules** (`android/app/proguard-rules.pro`) to prevent code obfuscation issues in release builds
- Enhanced logging for calendar sync debugging in release builds

---

## 📋 Testing Checklist

### Calendar Sync
- [ ] Grant calendar permissions
- [ ] Select calendar with events
- [ ] Verify events import correctly
- [ ] Verify events show source and creator
- [ ] Verify duplicate prevention (sync twice, no duplicates)
- [ ] Verify real-time updates (events appear immediately)
- [ ] Test manual sync
- [ ] Test cleanup tool (remove all synced events)

### Photo Attachments
- [ ] Upload photo to new event
- [ ] Upload photo to existing event
- [ ] Upload multiple photos
- [ ] Verify 10MB limit enforcement
- [ ] Delete photos
- [ ] Verify photos display in event details

### Event Chats
- [ ] Send message in event chat
- [ ] Verify real-time updates
- [ ] Verify access control (non-participants can't access)

### Chess PvP
- [ ] Create game invitation
- [ ] Verify game appears in opponent's waiting list
- [ ] Verify opponent can join
- [ ] Verify game starts after join
- [ ] Verify moves sync in real-time

---

## 🚀 Installation & Testing

### Building the QA APK
```bash
flutter build apk --flavor qa --dart-define=FLAVOR=qa
```

The APK will be located at:
```
build/app/outputs/flutter-apk/app-qa-release.apk
```

---

## 📝 Notes for Testers

1. **Calendar Sync**: 
   - First sync looks back 90 days to catch existing events
   - Subsequent syncs only get new events since last sync
   - If sync shows "0 events imported", check the calendar selection - some calendars may be empty
   - Use the calendar selection dialog to see which calendars have events

2. **Photo Uploads**: 
   - 10MB size limit per photo
   - Photos upload immediately when selected
   - Photos appear in event details screen

3. **Chess PvP**: 
   - When you invite someone, the game is created in "waiting" status
   - The opponent must see the game in their waiting list and tap to join
   - Game only starts after both players have joined

4. **Real-time Updates**: 
   - Calendar events update automatically via Firestore streams
   - No need to refresh or log out/login to see new events

---

## 🔄 Migration Notes

### Database Changes
- New Firestore collection: `families/{familyId}/events/{eventId}/chats`
- New Firestore field: `events.photoUrls` (array of strings)
- New Firestore field: `events.createdBy` (string)
- New Firestore field: `events.sourceCalendar` (string)
- New Firestore field: `events.deviceEventId` (string, for duplicate prevention)
- New Firestore field: `events.importedFromDevice` (boolean)
- New Firestore field: `chess_games.invitedPlayerId` (string)

### Required Actions
1. **Firebase Storage Rules**: Deploy the updated rules from `FIREBASE_STORAGE_RULES_COMPLETE.md`
2. **Firestore Rules**: Deploy the updated rules (includes event chats)
3. **Calendar Permissions**: Users must grant calendar permissions in device settings

---

## 📞 Support

For issues or questions, please contact the development team or create an issue in the repository.

---

---

## 🔧 Build Configuration Changes

### ProGuard/R8 Rules Added
- **File:** `android/app/proguard-rules.pro`
- **Purpose:** Prevent R8 code obfuscation from breaking `device_calendar` plugin in release builds
- **Impact:** Calendar sync now works identically in debug and release builds
- **Technical Details:** See `CALENDAR_SYNC_RELEASE_BUILD_FIX.md` for full explanation

### Enhanced Logging
- Added detailed logging for calendar object properties (name, accountName, id)
- Better error diagnostics for release build issues
- Warnings when calendar properties are null (indicates obfuscation issues)

---

**Previous Release:** QA Build v2 (December 1, 2025)  
**Next Release:** Production (after QA validation)
