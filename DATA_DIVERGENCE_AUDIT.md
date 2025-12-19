# Data Divergence Audit Report

**Date:** December 19, 2025  
**Status:** 🔄 In Progress

## Critical Issue: Chat Preview vs Full View Divergence

### ✅ FIXED
**Issue:** ChatWidget preview on dashboard shows ALL messages via `ChatService.getMessagesStream()`, but "View Full" (ChatTabsScreen) was showing FeedScreen which uses `FeedService.getFeedStream()` with:
- Limit of 20 messages
- Only top-level posts (parentMessageId is null)
- Descending order (newest first)

**Fix:** Changed ChatTabsScreen "All" tab from `FeedScreen` to `ChatScreen` to use the same `ChatService.getMessagesStream()` as the preview.

**Files Changed:**
- `lib/screens/chat/chat_tabs_screen.dart` - Changed "All" tab from FeedScreen to ChatScreen
- `lib/screens/dashboard/dashboard_screen.dart` - Updated navigation to ChatScreen instead of ChatTabsScreen

---

## Other Potential Divergences Found

### 1. TaskService: getTasksStream() vs getTasks()

**Issue:** 
- `getTasksStream()` has a hardcoded limit of 50 tasks
- `getTasks()` accepts a limit parameter (default 50) but can be changed

**Status:** ⚠️ POTENTIAL ISSUE - Need to verify if any screens use different limits

**Files to Check:**
- `lib/screens/tasks/tasks_screen.dart` - Verify which method is used
- Any widgets that show task previews vs full task screens

**Action Required:** Ensure all task views use consistent limits and filtering

---

### 2. ChatService: getMessagesStream() vs getMessages()

**Issue:**
- `getMessagesStream()` returns ALL messages (no limit)
- `getMessages()` has a default limit of 50, max 500

**Status:** ⚠️ POTENTIAL ISSUE - Stream shows all, non-stream shows limited

**Impact:** If any screen uses `getMessages()` instead of `getMessagesStream()`, it will show fewer messages

**Action Required:** Verify all chat-related screens use `getMessagesStream()` for consistency

---

### 3. FeedService: getFeedStream() vs ChatService

**Issue:**
- `FeedService.getFeedStream()` filters to top-level posts only (parentMessageId is null)
- `ChatService.getMessagesStream()` shows ALL messages including replies

**Status:** ✅ BY DESIGN - Feed is meant to show posts, Chat shows all messages

**Note:** This is intentional - Feed is for social posts, Chat is for all messages. But we need to ensure navigation is clear.

---

## Systematic Review Checklist

### Services with Both Stream and Non-Stream Methods
- [x] ChatService - getMessagesStream() vs getMessages() - **DIVERGENCE FOUND**
- [x] TaskService - getTasksStream() vs getTasks() - **POTENTIAL DIVERGENCE**
- [ ] ShoppingService - streamShoppingLists() vs getShoppingLists() - **TO CHECK**
- [ ] CalendarService - streamEvents() vs getEvents() - **TO CHECK**
- [ ] PhotoService - streamPhotos() vs getPhotos() - **TO CHECK**

### Preview Widgets vs Full Screens
- [x] ChatWidget (dashboard) vs ChatScreen - **FIXED**
- [ ] Task preview widgets vs TasksScreen - **TO CHECK**
- [ ] Shopping list previews vs ShoppingListDetailScreen - **TO CHECK**
- [ ] Photo album previews vs AlbumPhotosScreen - **TO CHECK**
- [ ] Book previews vs BookDetailScreen - **TO CHECK**

### Filtering Inconsistencies
- [x] FeedService filters by parentMessageId - **BY DESIGN**
- [ ] TaskService filtering (active/completed) - **TO CHECK**
- [ ] ShoppingService filtering (archived) - **TO CHECK**

---

## Verification Results

### ✅ TaskService - CONSISTENT
- `getTasks()` default limit: 50
- `getTasksStream()` limit: 50
- **Status:** ✅ Both use same limit, no divergence

### ✅ ShoppingService - TO VERIFY
- `streamShoppingLists()` - filters archived lists
- `getShoppingLists()` - need to check if it also filters archived
- **Action:** Verify both methods use same filtering logic

### ✅ CalendarService - TO VERIFY
- `streamEvents()` vs `getEvents()` - need to check for consistency
- **Action:** Verify both methods use same query parameters

## Next Steps

1. ✅ Fix chat preview/full view divergence - **COMPLETED**
2. ✅ Verify TaskService stream vs non-stream consistency - **VERIFIED CONSISTENT**
3. ⏳ Check ShoppingService stream vs non-stream consistency
4. ⏳ Check CalendarService stream vs non-stream consistency
5. ⏳ Check all preview widgets use same data sources as full screens
6. ⏳ Document any intentional divergences (like Feed vs Chat)
7. ⏳ Create test cases to prevent future divergences

---

## Prevention Strategy

1. **Shared Stream Pattern:** When possible, use the same stream for preview and full views
2. **Consistent Limits:** Ensure stream and non-stream methods use same default limits
3. **Documentation:** Document any intentional divergences (e.g., Feed vs Chat)
4. **Code Review:** Add checklist item for data consistency between preview/full views

