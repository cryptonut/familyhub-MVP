# Implementation Plan for Requested Changes

This document outlines all requested changes and their implementation status.

## 1. Home Screen (formerly Dashboard)

### 1.1 Rename Dashboard to Home Screen ✅
- [x] Update navigation label in `home_screen.dart`
- [ ] Update screen title/class name (optional - can keep DashboardScreen class name)

### 1.2 Remove My Family Header Section ✅
- [ ] Remove `_buildMyFamily` call from dashboard content
- [ ] Keep avatar functionality for long-press (move elsewhere if needed)

### 1.3 Redesign Jobs Section ✅
- [ ] Combine tick icon and job count into single row
- [ ] Move descriptive label to second row
- [ ] Keep "Add Job" button on third row
- [ ] Reduce total height to ~3 rows

### 1.4 Fix Avatar Photo Upload ✅
- [ ] Update Firebase Storage rules to include `profile_photos/{userId}/{photoId}.jpg` path
- [ ] Ensure rules allow authenticated users to upload their own profile images

## 2. Calendar Screen

### 2.1 Multi-Calendar Selection in Event Creation
- [ ] Add "Add to Calendars" section
- [ ] Add dropdown listing all hubs/family calendars
- [ ] Allow multi-selection with toggles

### 2.2 Family Day View Improvements
- [ ] Don't auto-default to current date
- [ ] Require explicit date selection
- [ ] Add blue event indicator dots to date picker

### 2.3 Conflict Warning Improvements
- [ ] Optimize text contrast for light/dark modes
- [ ] Convert conflict indicator to clickable button
- [ ] Show detailed conflict summary on click

## 3. Jobs Screen

### 3.1 Remove Top Row Title
- [ ] Remove "Jobs" title label from top

### 3.2 Move Menu Items to Admin Menu
- [ ] Move "Cleanup Duplicates" to Admin menu
- [ ] Move "Delete Duplicate Document" to Admin menu
- [ ] Move "Delete Duplicate Task by ID" to Admin menu

### 3.3 Search Bar Improvements
- [ ] Optimize text/background contrast
- [ ] Add visible send/submit icon

### 3.4 Fix Admin Job Deletion
- [ ] Investigate deletion issue for admin user (Simon Case)
- [ ] Ensure admin permissions work correctly

## 4. Games Screen

### 4.1 My Stats Section
- [ ] Populate with actual user data
- [ ] Make panel clickable
- [ ] Create dedicated "My Stats" page
- [ ] Display game stats with Attempts, Wins, Losses, Win Percentage

### 4.2 Leaderboards
- [ ] Make all leaderboard entries clickable
- [ ] Navigate to member's personal stats page on click

### 4.3 Individual Game Fixes
- [ ] Chess: Fix move validation logic
- [ ] Word Scramble: Fix answer validation logic
- [ ] Family Bingo: Remove game entirely
- [ ] Tetris: Improve mobile usability (move score/lines to right column)

## 5. Photos Screen

### 5.1 Album Cover Thumbnails
- [ ] Add representative thumbnails to all album covers

### 5.2 Fix Album Display Bug
- [ ] Fix bug where photos don't appear in specific albums
- [ ] Ensure photos assigned to albums show correctly

## 6. Location Screen

### 6.1 Request Location Feature
- [ ] Add "Request Location" button/feature
- [ ] Allow user to send location request to family member
- [ ] Show yes/no prompt to recipient
- [ ] Update location only after recipient approves

---

## Implementation Order

1. **Critical Fixes First:**
   - Firebase Storage rules for profile photos
   - Admin job deletion issue
   - Album display bug

2. **UI/UX Improvements:**
   - Home Screen changes
   - Calendar improvements
   - Jobs Screen improvements
   - Search bar improvements

3. **Feature Additions:**
   - Multi-calendar selection
   - Request Location feature
   - Games stats page

4. **Game Fixes:**
   - Chess/Word Scramble validation fixes
   - Tetris mobile improvements
   - Remove Family Bingo

---

## Notes

- All changes should maintain consistency across light/dark modes
- Test all changes thoroughly before marking as complete
- Ensure data integrity throughout all modifications

