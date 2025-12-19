# Comprehensive Screen Review TODO List

This document tracks all addressable issues found during systematic screen-by-screen, field-by-field review.

## Status Legend
- ✅ **Completed** - Issue fixed and verified
- 🔄 **In Progress** - Currently being addressed
- ⏳ **Pending** - Not yet started
- ✅✅ **Verified OK** - Reviewed and confirmed working correctly

---

## Critical Filtering Bugs (Service Layer)

### ✅ COMPLETED
1. **`homeschooling_service.dart` - `getAssignments()`**
   - **Issue**: Conditional `where` clauses + `orderBy` can fail silently without composite indexes
   - **Fix**: Changed to fetch all, filter in memory, then sort
   - **Status**: ✅ Fixed

2. **`homeschooling_service.dart` - `getEducationalResources()`**
   - **Issue**: Same pattern - conditional where + orderBy
   - **Fix**: In-memory filtering
   - **Status**: ✅ Fixed

3. **`homeschooling_service.dart` - `getLessonPlans()`**
   - **Issue**: Same pattern - conditional where + orderBy  
   - **Fix**: In-memory filtering
   - **Status**: ✅ Fixed

4. **`homeschooling_service.dart` - `getLearningMilestones()`**
   - **Issue**: Same pattern - conditional where + orderBy
   - **Fix**: In-memory filtering
   - **Status**: ✅ Fixed

### ⏳ TO VERIFY (Other Services - May Not Have Same Issue)
- `budget_service.dart` - `getBudgets()` - Has fallback logic, appears OK
- `budget_item_service.dart` - `getItems()` - Uses conditional where but handles null correctly
- `task_service.dart` - Uses in-memory filtering for active/completed (correct pattern)
- `chat_service.dart` - No filtering issues (just orderBy, no conditional where)
- `shopping_service.dart` - Uses orderBy only, no conditional where
- `feed_service.dart` - Uses where + orderBy but fixed field (parentMessageId)

---

## Empty State Message Improvements (UI Layer)

### ✅ COMPLETED
1. **Assignment Tracking Screen** (`assignment_tracking_screen.dart`)
   - **Issue**: Empty state didn't account for active filters (student/status)
   - **Fix**: Added `_getEmptyStateMessage()` with context-aware messages
   - **Status**: ✅ Fixed

2. **Resource Library Screen** (`resource_library_screen.dart`)
   - **Issue**: Empty state didn't account for active filters (subject/type)
   - **Fix**: Added `_getEmptyStateMessage()` with filter-aware messages
   - **Status**: ✅ Fixed

3. **Tasks Screen** (`tasks_screen.dart`)
   - **Issue**: Empty state didn't account for active filters (search/priority/status/completed/time)
   - **Fix**: Added `_getEmptyStateMessage()` and `_hasActiveFilters()` methods, "Clear Filters" button
   - **Status**: ✅ Fixed

### ✅✅ VERIFIED OK
4. **Calendar Screen** (`calendar_screen.dart`)
   - **Status**: ✅✅ Empty state correctly handles search query - shows "No matching events" vs "No events"
   - No action needed

5. **Scheduling Conflicts Screen** (`scheduling_conflicts_screen.dart`)
   - **Status**: ✅✅ Empty state message accounts for time filter ("Your schedule for this [timeFilter] looks clear")
   - No action needed

---

## Screen-Specific Reviews

### Dashboard Screen
- ✅✅ Family member avatars display correctly (fixed in previous session)
- ⏳ **TODO**: Verify all widget sections render correctly when data is empty
- ⏳ **TODO**: Verify wallet balance display formatting
- ⏳ **TODO**: Verify upcoming events/tasks/birthdays display logic

### Tasks Screen  
- ✅ Empty state messages fixed (accounts for filters)
- ✅✅ Filtering uses in-memory (correct pattern)
- ⏳ **TODO**: Verify task card display fields (priority, status, assignee, etc.)
- ⏳ **TODO**: Verify swipe actions work correctly
- ⏳ **TODO**: Verify completion flow works correctly

### Calendar Screen
- ✅✅ Empty state handling verified correct
- ✅✅ Search filtering works correctly
- ⏳ **TODO**: Verify event display in calendar widget
- ⏳ **TODO**: Verify event list display for selected day
- ⏳ **TODO**: Verify recurring event handling

### Shopping Screens
- ✅✅ Shopping home screen has proper empty state
- ✅ **FIXED**: shopping_list_detail_screen - Empty state now accounts for completed items filter
  - **Issue**: Checked `_items.isEmpty` instead of `_groupedItems.isEmpty`, causing incorrect empty state when all items are completed and filter hides them
  - **Fix**: Changed to check `_groupedItems.isEmpty` and added context-aware message with option to show completed items
- ✅✅ List filtering/sorting works correctly (uses in-memory filtering)
- ⏳ **TODO**: Verify smart recurring lists display correctly

### Budget Screens
- ✅✅ Budget home screen has proper empty state
- ⏳ **TODO**: Review budget_detail_screen - verify item/transaction display
- ⏳ **TODO**: Verify budget item filtering/display logic
- ⏳ **TODO**: Verify transaction filtering and empty states

### Photos Screen
- ✅✅ Albums tab has proper empty state
- ⏳ **TODO**: Review all photos tab - verify empty state
- ⏳ **TODO**: Verify photo grid display
- ⏳ **TODO**: Verify album card preview images display correctly

### Chat Screens
- ✅✅ Chat screen has basic empty state ("No messages yet")
- ⏳ **TODO**: Consider if empty state message could be improved (not critical, basic message is fine)
- ⏳ **TODO**: Verify message display formatting
- ⏳ **TODO**: Verify unread message indicators

### Hub Detail Screens

#### Homeschooling Hub Screen
- ⏳ **TODO**: Review display of students, assignments, resources
- ⏳ **TODO**: Verify empty states for all sections
- ⏳ **TODO**: Verify milestone display logic

#### Coparenting Hub Screen  
- ⏳ **TODO**: Review display of children, expenses, schedules
- ⏳ **TODO**: Verify empty states for all sections
- ⏳ **TODO**: Verify expense filtering and display

#### Library Hub Screen
- ⏳ **TODO**: Review book display and filtering
- ⏳ **TODO**: Verify empty states
- ⏳ **TODO**: Verify leaderboard display

#### Extended Family Hub Screen
- ⏳ **TODO**: Review member display and management
- ⏳ **TODO**: Verify empty states
- ⏳ **TODO**: Verify relationship display

### Wallet Screen
- ⏳ **TODO**: Review transaction display and filtering
- ⏳ **TODO**: Verify empty states
- ⏳ **TODO**: Verify balance calculations
- ⏳ **TODO**: Verify transaction grouping/display logic

### Feed Screen
- ✅ **FIXED**: FeedScreen "All" tab now shows same messages as ChatWidget preview
  - **Issue**: FeedScreen used `FeedService.getFeedStream()` with `includeReplies: false`, filtering out replies. ChatWidget uses `ChatService.getMessagesStream()` showing all messages.
  - **Fix**: Modified FeedScreen to use `ChatService.getMessagesStream()` for family feed (no hubId), matching ChatWidget behavior. Hub feeds still use FeedService for feed-style posts.
  - **Status**: ✅ Fixed
- ✅✅ Empty states verified OK
- ✅✅ Post ordering verified (newest first)

---

## Build Configuration Issues

### ✅ COMPLETED
1. **Release Build Consistency**
   - **Issue**: Local and distributed builds could differ due to build cache
   - **Fix**: Added Gradle clean to `release_to_qa_testers.ps1` script
   - **Status**: ✅ Fixed

2. **Build Configuration Documentation**
   - **Issue**: Missing comments explaining R8 doesn't affect Flutter widgets
   - **Fix**: Added comments to `build.gradle.kts`
   - **Status**: ✅ Fixed

---

## Known Patterns to Check

### Pattern 1: Conditional Where + OrderBy in Services
**Status**: ✅ All instances in `homeschooling_service.dart` fixed

### Pattern 2: Empty States Without Filter Awareness  
**Status**: ✅ Fixed in assignments, resources, tasks
**Remaining**: Need to verify other screens don't have this issue

### Pattern 3: Layout Issues (Expanded/Flexible conflicts)
**Status**: ✅ Fixed hub cards layout issue
**Action**: Watch for similar issues in other grid/list layouts

### Pattern 4: Field Display Logic
**Status**: ⏳ Need systematic review of all screens
**Action**: Verify each field displays intended data correctly

---

## Priority Order for Remaining Reviews

### High Priority (User-Facing Critical Screens)
1. Wallet screen - financial data display
2. Budget detail screen - transaction/item display
3. Hub detail screens - core feature functionality
4. Feed screen - social feature

### Medium Priority (Regularly Used Screens)
5. Shopping list detail screen
6. Photos all photos tab
7. Chat screens (basic functionality OK, improvements optional)

### Low Priority (Less Frequently Used)
8. Settings screens
9. Admin screens
10. Analytics screens

---

## Runtime Error Fixes

### ✅ COMPLETED
1. **MessageExpirationService Errors**
   - **Issue**: Periodic errors when checking family/hub messages for expiration
   - **Fix**: Added checks for empty collections, wrapped each family/hub in try-catch, added stack traces to error logs, fixed batch commit logic
   - **Status**: ✅ Fixed

2. **Flutter TransformLayer Invalid Matrix Errors**
   - **Issue**: `TransformLayer is constructed with an invalid matrix` errors in `reorderable_navigation_bar.dart`
   - **Fix**: Added `_isValidOffset()` helper to validate Offset values before use in `Transform.translate`, falling back to `Offset.zero` if invalid
   - **Status**: ✅ Fixed

---

## Notes

- All critical filtering bugs have been fixed
- Empty state improvements completed for most filtered screens
- Runtime errors (MessageExpirationService, TransformLayer) have been fixed
- FeedScreen "All" tab now matches ChatWidget preview behavior
- Remaining work is primarily verification and minor improvements
- Most screens follow correct patterns (in-memory filtering, proper empty states)

