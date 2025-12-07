# Testing Guide for UI/UX Improvements

This document provides step-by-step testing instructions for all the changes made in this release.

## ✅ Automated Checks Completed

- ✅ No linter errors found
- ✅ All imports verified
- ✅ Code structure validated
- ✅ Syntax checks passed

## 🧪 Manual Testing Required

### 1. Home Screen (formerly Dashboard)

#### Test 1.1: Navigation Label
**Steps:**
1. Launch the app
2. Check the bottom navigation bar
3. **Expected:** The first tab should show "Home" (not "Dashboard")
4. **Expected:** Icon should be home icon (not dashboard icon)

#### Test 1.2: My Family Section Removal
**Steps:**
1. Navigate to Home screen
2. Scroll to the top
3. **Expected:** "My Family" header section should NOT be visible
4. **Expected:** Family members should still be accessible via the hub dropdown at the top

#### Test 1.3: Jobs Section Redesign
**Steps:**
1. Navigate to Home screen
2. Find the Jobs section
3. **Expected:** Should see:
   - Row 1: Tick icon + Active Jobs count | Check icon + Completed count
   - Row 2: "Active Jobs" label | "Completed" label
   - Row 3: "Add Job" button (full width)
4. **Expected:** Total height should be approximately 3 rows (compact)

#### Test 1.4: Avatar Photo Upload
**Steps:**
1. Navigate to Home screen
2. Long-press on your own avatar (your profile picture)
3. **Expected:** Menu should appear with options:
   - Take Photo
   - Choose from Gallery
   - Enter Bitmoji URL
4. Select "Choose from Gallery" or "Take Photo"
5. Select/upload a photo
6. **Expected:** Photo should upload successfully (no "unauthorized" error)
7. **Note:** If you get an error, deploy Firebase Storage rules from `FIREBASE_STORAGE_RULES.md`

**Firebase Storage Rules Deployment:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click **Storage** → **Rules** tab
4. Copy rules from `FIREBASE_STORAGE_RULES.md`
5. Paste and click **Publish**

---

### 2. Calendar Screen

#### Test 2.1: Add to Calendars Section
**Steps:**
1. Navigate to Calendar screen
2. Tap the "+" FAB or create a new event
3. Scroll down in the event creation form
4. **Expected:** Should see "Add to Calendars" section with:
   - "Family Calendar" toggle (should be ON by default)
   - List of available hubs with toggles
5. Toggle different calendars on/off
6. Save the event
7. **Expected:** Event should appear in all selected calendars

#### Test 2.2: Family Day View Date Selection
**Steps:**
1. Navigate to Calendar screen
2. Tap the timeline icon (Gantt chart icon) in the AppBar
3. **Expected:** Date picker should appear immediately (not defaulting to today)
4. Select a date
5. **Expected:** Gantt chart should load for that date
6. **Expected:** If you cancel, should return to previous screen

#### Test 2.3: Blue Event Indicator Dots
**Steps:**
1. Navigate to Calendar screen
2. Look at the calendar widget (TableCalendar)
3. **Expected:** Days with events should show:
   - Blue circular dot at the bottom of the day cell
   - If multiple events on same day, should show number (e.g., "3")
   - Single event days show just a blue dot
4. **Expected:** Dots should be clearly visible and blue

#### Test 2.4: Conflict Warning Contrast
**Steps:**
1. Navigate to Calendar screen
2. Tap timeline icon (Gantt chart)
3. Select a date with scheduling conflicts
4. **Expected:** Conflict warning should be visible with good contrast in:
   - Light mode: Orange background with dark text
   - Dark mode: Dark orange background with light text
5. Switch between light/dark mode to verify both

#### Test 2.5: Clickable Conflict Indicator
**Steps:**
1. Navigate to Calendar screen
2. Tap timeline icon (Gantt chart)
3. Select a date with conflicts
4. **Expected:** Should see conflict count badge (e.g., "2 conflicts") in the header
5. Tap the conflict badge
6. **Expected:** Dialog should open showing:
   - Member names with conflicts
   - List of overlapping events for each member
   - Event times and titles
7. **Expected:** Dialog should be scrollable if many conflicts

---

### 3. Jobs Screen

#### Test 3.1: Removed Title
**Steps:**
1. Navigate to Jobs screen (3rd tab)
2. Look at the AppBar
3. **Expected:** Should NOT see "Jobs" title text
4. **Expected:** AppBar should still be present (for refresh button)

#### Test 3.2: Menu Items Moved to Admin
**Steps:**
1. Navigate to Jobs screen
2. Look at AppBar actions
3. **Expected:** Should only see refresh icon (not three-dot menu)
4. Navigate to Home screen
5. Tap the three-dot menu (top right)
6. If you're an admin, tap "Admin Menu"
7. **Expected:** Should see "Jobs" option with chevron
8. Tap "Jobs"
9. **Expected:** Should see submenu with:
   - Cleanup Duplicates
   - Delete Duplicate Document
   - Delete Duplicates by Task ID

#### Test 3.3: Search Bar Improvements
**Steps:**
1. Navigate to Jobs screen
2. Find the search bar
3. **Expected:** Should have good contrast in both light and dark modes
4. Type some text in the search bar
5. **Expected:** Should see:
   - Search icon on the left
   - Submit/search icon on the right (when text is entered)
   - Clear icon next to submit icon
6. Tap the submit icon
7. **Expected:** Search should execute
8. Switch between light/dark mode to verify contrast

#### Test 3.4: Admin Deletion Issue (Bug Fix)
**Steps:**
1. Log in as admin user (Simon Case)
2. Navigate to Jobs screen
3. Try to delete an active job
4. **Expected:** Should be able to delete (if this was previously broken)
5. **Note:** This may require investigation if still not working

---

### 4. Games Screen (Not Yet Implemented)

**Status:** These features are pending implementation:
- My Stats population and clickability
- Dedicated My Stats page
- Clickable leaderboard entries
- Chess move validation fix
- Word Scramble answer validation fix
- Family Bingo removal
- Tetris mobile layout improvements

---

### 5. Photos Screen (Not Yet Implemented)

**Status:** These features are pending implementation:
- Thumbnail addition to album covers
- Fix for photos not showing in specific albums

---

### 6. Location Screen (Not Yet Implemented)

**Status:** This feature is pending implementation:
- Request Location feature with consent prompt

---

## 🔍 Quick Verification Checklist

Before detailed testing, do a quick visual check:

- [ ] Home tab shows "Home" not "Dashboard"
- [ ] No "My Family" header on Home screen
- [ ] Jobs section is compact (3 rows)
- [ ] Calendar event creation has "Add to Calendars" section
- [ ] Calendar shows blue dots on days with events
- [ ] Jobs screen has no title in AppBar
- [ ] Search bar has submit icon when typing
- [ ] Admin menu has "Jobs" submenu

## 🐛 Known Issues to Watch For

1. **Firebase Storage Rules:** If avatar upload fails, deploy storage rules
2. **Date Picker:** Gantt chart should prompt for date selection immediately
3. **Event Indicators:** Blue dots should show on calendar days with events
4. **Menu Navigation:** Jobs menu items should be in Admin > Jobs, not in Jobs screen menu

## 📝 Testing Notes

- Test on both light and dark modes where applicable
- Test on different screen sizes if possible
- Verify all navigation flows work correctly
- Check that data persists correctly (events in multiple calendars, etc.)

## 🚨 Critical Paths to Test

1. **Avatar Upload** - Requires Firebase Storage rules deployment
2. **Multi-Calendar Events** - Verify events appear in correct calendars
3. **Conflict Detection** - Verify conflicts are detected and displayed correctly
4. **Search Functionality** - Verify search works with new submit icon

---

## Next Steps After Testing

1. Report any issues found
2. Verify Firebase Storage rules are deployed
3. Test remaining features (Games, Photos, Location) once implemented
4. Provide feedback on UI/UX improvements
