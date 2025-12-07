# Family Hub - QA Release Notes

## Version: QA Build
**Release Date:** $(Get-Date -Format "yyyy-MM-dd")
**Branch:** release/qa

---

## 🎉 New Features

### Shopping Lists
- **Complete Shopping List Management System**
  - Create, edit, and delete shopping lists
  - Real-time list updates using Firestore streams
  - Add, edit, and delete items within lists
  - Mark items as "Got It!" or "Unavailable"
  - Smart recurring lists functionality
  - Shopping categories and receipt management
  - Speech-to-text and OCR receipt scanning support

### Calendar Enhancements
- **Multi-Calendar Event Creation**
  - Add events to multiple family calendars/hubs simultaneously
  - Improved calendar selection UI with checkboxes
- **Family Day View Improvements**
  - Explicit date selection required (no auto-default)
  - Event indicator dots on date picker showing event counts
  - Clickable scheduling conflict warnings with detailed conflict summaries
  - Improved contrast for conflict warnings in light/dark modes

### Games
- **Personal Stats Screen**
  - Dedicated page showing detailed game statistics
  - Clickable "My Stats" card and leaderboard entries
  - Displays wins, streaks, high scores, and game-specific stats
- **Game Improvements**
  - Fixed Chess move validation logic
  - Fixed Word Scramble answer validation
  - Improved Tetris mobile usability (score/controls repositioned)
  - Removed Family Bingo game

### Photos
- **Album Display Fixes**
  - First photo of album used as cover thumbnail if no cover set
  - Fixed photo display bug where photos didn't appear in specific albums
  - Improved fallback mechanism for photo loading

### Location
- **Request Location Feature**
  - Privacy-conscious location sharing
  - Request/accept/deny location sharing between family members
  - Clear prompts for location requests

---

## 🐛 Bug Fixes

### Shopping Lists
- Fixed shopping lists not persisting after creation (now using real-time streams)
- Fixed Firestore rules to allow shopping list operations
- Added edit/delete functionality for lists and items

### Home Screen (formerly Dashboard)
- Restored family member avatars (removed only header text/logo/count)
- Centered avatar display
- Redesigned Jobs section to be more compact
- Active jobs badge overlay (similar to message notifications)

### Calendar
- Fixed scheduling conflict detection and display
- Improved date picker with event indicators

### Tasks/Jobs
- Fixed admin user deletion of tasks (Firestore rules updated)
- Removed redundant "Jobs" title from tasks screen
- Improved search bar contrast and added submit icon
- Moved admin cleanup tools to Admin menu submenu

### Photos
- Fixed album photo display when photos exist but don't show in album view
- Added fallback query mechanism for photo loading

### Games
- Fixed Chess move validation (now properly validates legal moves)
- Fixed Word Scramble answer validation (case-insensitive, trimmed)
- Improved Tetris mobile layout for better thumb reach

---

## 🔧 Technical Improvements

### Firebase
- Updated Firestore security rules for shopping lists, items, categories, receipts
- Updated Storage rules for profile photos
- Deployed Firebase rules via Firebase CLI

### Services
- Added `ShoppingService` with full CRUD operations
- Enhanced `PhotoService` with fallback query mechanisms
- Added `LocationService` request/response methods
- Improved `CalendarService` for multi-hub event creation

### UI/UX
- Improved contrast for search bars and conflict warnings
- Better mobile usability for games
- Streamlined navigation and reduced redundancy

---

## 📝 Developer Notes

### Breaking Changes
- None

### Migration Notes
- Shopping lists require Firestore rules update (already deployed)
- Profile photos now use new storage path: `profile_photos/{userId}/{photoId}.jpg`

### Dependencies
- No new dependencies added in this release
- All existing dependencies maintained

---

## 🧪 Testing Checklist

- [x] Shopping lists create/edit/delete
- [x] Shopping items add/edit/delete
- [x] Real-time list updates
- [x] Calendar multi-selection
- [x] Family Day View date selection
- [x] Scheduling conflict detection
- [x] Games stats display
- [x] Photo album display
- [x] Location request flow
- [x] Admin task deletion

---

## 📦 Build Information

- **Flavor:** QA
- **Build Type:** Release
- **Target SDK:** As per Flutter configuration
- **Min SDK:** As per Flutter configuration

---

## 🙏 Acknowledgments

This release includes significant improvements to shopping list functionality, calendar management, and overall app stability. Thank you to all testers for their feedback!
