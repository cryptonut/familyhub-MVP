# Family Hub - QA Release Notes

**Version:** 1.0.0-test  
**Release Date:** $(date)  
**Branch:** release/qa

## 🎉 Major Features

### Dashboard & UI Improvements
- **Hub Selector**: Replaced profile avatars in app bar with family/hub dropdown selector
  - Default shows "Case Family" (or current family name)
  - Allows switching between different hubs/families
  - Clean, modern dropdown design matching app theme

- **Dashboard Redesign**: 
  - Circular profile avatars with names displayed below
  - Removed data breach alerts section
  - Clean, minimal design matching modern family app aesthetics
  - Profile photo management: Click your own avatar to update photo/bitmoji
  - Admin features: Long-press other members' avatars to edit relationships

- **Profile Photo Management**:
  - Upload photos from camera or gallery
  - Enter Bitmoji URL directly
  - QR code scanning for Bitmoji URLs
  - Remove profile photos
  - New ProfilePhotoService for centralized photo management

### Chat Improvements
- **Chat Tabs Screen**: New tabbed interface for chat
  - "All" tab for family group chat (default)
  - Individual tabs for each family member for one-on-one chats
  - Horizontal tab bar with profile avatars

### Chess Game Enhancements
- **Complete Challenge Flow**:
  - Challenger can create a challenge and exit to wait
  - Challenger receives notification when challenge is accepted
  - Challenger can join game or return to lobby
  - Challenger can cancel pending challenges
  - Invited player sees challenges clearly with accept/decline options
  - Real-time challenge status updates

### Calendar Features
- **Duplicate Detection & Merging**:
  - Automatically detects duplicate calendar events
  - Merges duplicates based on title, time, and location
  - Preserves best event data (photos, participants, RSVP status)
  - Manual cleanup option in calendar sync settings
  - Prevents importing duplicates from device calendars

### Bug Fixes
- **Location Services**: Fixed context disposal error when updating location
  - Proper mounted checks before using context
  - Safe dialog navigation handling
  - No more "deactivated widget" errors

- **Calendar Sync**: Fixed "Not synced yet" label persistence
  - Clears user model cache after sync updates
  - UI immediately reflects sync status

- **Firestore Rules**: Updated security rules for:
  - Calendar event updates (duplicate cleanup)
  - Chess game invites
  - FCM message creation

## 🔧 Technical Improvements

- Added `ProfilePhotoService` for centralized photo management
- Added `ChatTabsScreen` for improved chat navigation
- Improved error handling in location services
- Enhanced calendar sync with duplicate prevention
- Updated Firestore security rules for new features

## 📱 Testing Notes

### Test on Multiple Devices
- Verify hub selector works correctly
- Test profile photo upload/update/removal
- Test Bitmoji URL entry and QR scanning
- Verify chess challenge flow end-to-end
- Test calendar duplicate detection and merging
- Verify location updates work without errors

### Known Limitations
- Hub switching logic is logged but not yet fully implemented (UI ready)
- Snapchat-style QR code sharing deferred for future release

## 🚀 Build Information

- **Flavor:** QA (test)
- **Application ID:** com.example.familyhub_mvp.test
- **Build Type:** Release
- **APK Location:** `build/app/outputs/flutter-apk/app-qa-release.apk`

## 📝 Next Steps

After QA testing, merge approved changes to `main` branch for production release.

---

**Commit:** ecd520e  
**Branch:** release/qa
