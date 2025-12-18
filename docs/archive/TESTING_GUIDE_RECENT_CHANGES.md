# Testing Guide - Recent Changes

## Overview
This guide covers testing for all recently implemented features and bug fixes. Test systematically to ensure everything works as expected.

---

## 1. Loading States & Skeleton Loaders

### Dashboard Screen
- [ ] **Initial Load**: Open Dashboard - should show skeleton cards (stat cards, event cards, task cards) instead of spinner
- [ ] **Loading Time**: Verify skeletons appear immediately, then transition to real data smoothly
- [ ] **No Flicker**: Ensure no white flash or layout shift when data loads

### Calendar Screen
- [ ] **Event List Loading**: Open Calendar - should show skeleton event list items
- [ ] **Smooth Transition**: Data should replace skeletons without jarring transitions

### Tasks Screen
- [ ] **Task List Loading**: Open Tasks - should show skeleton task cards
- [ ] **Loading Behavior**: Verify skeletons match the layout of actual task cards

### Photos Screen
- [ ] **Photo Grid Loading**: Open Photos - should show skeleton photo grid
- [ ] **Album List Loading**: If viewing albums, should show skeleton album list

---

## 2. Navigation Badges (Real-time Counts)

### Chat Badge
- [ ] **Unread Messages**: Send a message to yourself from another account
- [ ] **Badge Appears**: Check bottom navigation - Chat icon should show badge with count
- [ ] **Real-time Update**: Badge should update immediately when new message arrives
- [ ] **Badge Disappears**: Open chat and read messages - badge should disappear
- [ ] **Multiple Messages**: Send multiple messages - badge should show correct count

### Jobs Badge
- [ ] **Unclaimed Jobs**: Create a job that requires claiming
- [ ] **Badge Shows**: Check bottom navigation - Jobs icon should show badge
- [ ] **Claim Job**: Claim the job - badge count should decrease
- [ ] **Real-time Update**: Badge should update when jobs are claimed/completed

### Games Badge
- [ ] **Chess Challenge**: Have another user challenge you to chess
- [ ] **Badge Appears**: Check bottom navigation - Games icon should show badge
- [ ] **Accept Challenge**: Accept challenge - badge should decrease
- [ ] **Multiple Challenges**: Multiple waiting games should show correct count

---

## 3. Event Templates

### Create Template
- [ ] **Access**: Go to Calendar → Add Event → Tap "Use Template" button in AppBar
- [ ] **Template List**: Should see list of available templates (if any exist)
- [ ] **Create New Template**: 
  - Create an event with all fields filled
  - Save as template (if this feature exists)
  - Verify template appears in list

### Use Template
- [ ] **Select Template**: Choose a template from the list
- [ ] **Form Pre-filled**: Event form should be pre-filled with template data:
  - Title
  - Description
  - Location
  - Start/End time
  - Color
  - Default invitees
- [ ] **Edit Before Save**: Verify you can edit any field before saving
- [ ] **Save Event**: Save event - should create event with template data

### Template Management
- [ ] **View Templates**: Access template list
- [ ] **Edit Template**: Modify an existing template
- [ ] **Delete Template**: Delete a template (if feature exists)

---

## 4. Task Dependencies

### Create Task with Dependencies
- [ ] **Add Task**: Go to Tasks → Add New Job
- [ ] **Dependencies Section**: Scroll to "Dependencies" section
- [ ] **Add Dependency**: Tap "Add Dependency" button
- [ ] **Dependency Picker**: Should see dialog with available tasks
- [ ] **Select Tasks**: Select one or more tasks as dependencies
- [ ] **Save Selection**: Tap "Done" - selected tasks should appear in dependencies list
- [ ] **Visual Indicators**: 
  - Completed tasks should show green checkmark
  - Pending tasks should show orange indicator
  - Blocked status should be clear

### Task Blocking
- [ ] **Blocked Task**: Create a task with a dependency on an incomplete task
- [ ] **Visual Feedback**: Task should show as "blocked" or indicate it can't be started
- [ ] **Complete Dependency**: Complete the dependency task
- [ ] **Unblocked**: Original task should now be available to start
- [ ] **Status Update**: Blocked status should update in real-time

### Dependency Management
- [ ] **Remove Dependency**: Tap X on a dependency to remove it
- [ ] **Multiple Dependencies**: Add multiple dependencies - all should display
- [ ] **Circular Dependency**: Try to create circular dependency - should be prevented (if implemented)

---

## 5. Message Reactions

### Add Reaction
- [ ] **Open Chat**: Go to any chat (family or private)
- [ ] **Long Press Message**: Long press on a message
- [ ] **Reaction Menu**: Should see reaction options (👍, ❤️, 😂, etc.)
- [ ] **Select Reaction**: Tap a reaction - should be added to message
- [ ] **Visual Display**: Reaction should appear below/on the message
- [ ] **Multiple Reactions**: Add multiple different reactions to same message

### View Reactions
- [ ] **Reaction Count**: Should see count of each reaction type
- [ ] **Who Reacted**: Tap reaction to see who reacted (if feature exists)
- [ ] **Remove Reaction**: Tap your own reaction to remove it

### Real-time Updates
- [ ] **Other User Reacts**: Have another user react to your message
- [ ] **Real-time Update**: Reaction should appear immediately without refresh

---

## 6. Message Threading

### Create Thread
- [ ] **Reply to Message**: Long press message → "Reply" or tap reply button
- [ ] **Thread View**: Should open thread view or show reply indicator
- [ ] **Thread Messages**: Send messages in thread
- [ ] **Thread Indicator**: Original message should show thread count

### View Thread
- [ ] **Open Thread**: Tap on thread indicator or reply count
- [ ] **Thread Messages**: Should see all messages in the thread
- [ ] **Reply in Thread**: Add more replies to thread
- [ ] **Thread Updates**: Thread count should update in real-time

### Thread Navigation
- [ ] **Back Navigation**: Return to main chat from thread
- [ ] **Thread Context**: Should maintain context of which message was threaded

---

## 7. Toast Notifications

### Success Toast
- [ ] **Save Event**: Create and save an event
- [ ] **Toast Appears**: Should see success toast at bottom of screen
- [ ] **Auto-dismiss**: Toast should disappear after a few seconds
- [ ] **Non-blocking**: Toast should not block interaction with app

### Error Toast
- [ ] **Trigger Error**: Try to save invalid data (e.g., empty required field)
- [ ] **Error Toast**: Should see error toast with message
- [ ] **Clear Message**: Error message should be clear and actionable

### Info Toast
- [ ] **Info Actions**: Perform actions that show info messages
- [ ] **Info Display**: Should see informational toast notifications

### Toast Positioning
- [ ] **Multiple Toasts**: Trigger multiple toasts quickly
- [ ] **Stacking**: Toasts should stack or replace appropriately
- [ ] **No Overlap**: Toasts should not overlap with important UI elements

---

## 8. Swipeable List Items

### Tasks Screen
- [ ] **Swipe Left**: Swipe a task item left - should reveal delete action
- [ ] **Swipe Right**: Swipe a task item right - should reveal edit action
- [ ] **Action Buttons**: Action buttons should be clearly labeled
- [ ] **Swipe to Edit**: Swipe right and tap edit - should open edit screen
- [ ] **Swipe to Delete**: Swipe left and tap delete - should delete with undo option

### Calendar Screen
- [ ] **Swipe Event**: Swipe an event item
- [ ] **Edit/Delete Actions**: Should reveal edit and delete actions
- [ ] **Action Execution**: Actions should work correctly

### Swipe Behavior
- [ ] **Smooth Animation**: Swipe should be smooth and responsive
- [ ] **Cancel Swipe**: Swipe partially and release - should snap back
- [ ] **Multiple Items**: Swipe multiple items - each should work independently

---

## 9. Context Menus

### Long Press Menu
- [ ] **Tasks**: Long press a task - should show context menu
- [ ] **Menu Options**: Should see Edit, Delete, View Details options
- [ ] **Event Items**: Long press an event - should show context menu
- [ ] **Menu Actions**: All menu actions should work correctly

### Context Menu Behavior
- [ ] **Menu Positioning**: Menu should appear near the pressed item
- [ ] **Menu Dismissal**: Tap outside menu - should dismiss
- [ ] **Action Execution**: Tap menu item - should execute action and close menu

---

## 10. Quick Actions FAB

### Dashboard FAB
- [ ] **FAB Visible**: Go to Dashboard - should see FAB in bottom right
- [ ] **FAB Icon**: FAB should have appropriate icon (e.g., +)
- [ ] **Tap FAB**: Tap FAB - should show action menu or navigate to add screen
- [ ] **Quick Actions**: Should see quick action options (Add Event, Add Task, etc.)

### FAB Actions
- [ ] **Add Event**: Tap "Add Event" - should navigate to event creation
- [ ] **Add Task**: Tap "Add Task" - should navigate to task creation
- [ ] **Other Actions**: Test all available quick actions

---

## 11. Caching & Performance

### Offline Support
- [ ] **Load Data**: Load events, tasks, messages while online
- [ ] **Go Offline**: Turn off network/WiFi
- [ ] **View Cached Data**: Should still see previously loaded data
- [ ] **Cache Indicators**: Should see indication that data is cached (if implemented)

### Performance
- [ ] **Fast Loading**: App should load quickly on subsequent opens
- [ ] **Smooth Scrolling**: Lists should scroll smoothly
- [ ] **Image Loading**: Images should load efficiently (check network tab)

---

## 12. Image Optimization

### Image Upload
- [ ] **Upload Photo**: Upload a large photo
- [ ] **Compression**: Photo should be compressed before upload
- [ ] **Upload Speed**: Upload should be faster due to compression
- [ ] **Image Quality**: Compressed image should still look good

### Image Display
- [ ] **Optimized Loading**: Images should load with appropriate size
- [ ] **Caching**: Images should be cached for faster subsequent loads
- [ ] **Thumbnails**: Thumbnails should load first, then full image

---

## 13. Accessibility Features

### Screen Reader
- [ ] **Enable TalkBack/VoiceOver**: Enable screen reader on device
- [ ] **Navigate App**: Navigate through app using screen reader
- [ ] **Labels**: All interactive elements should have proper labels
- [ ] **Descriptions**: Important elements should have descriptions

### High Contrast
- [ ] **High Contrast Theme**: Enable high contrast mode (if available)
- [ ] **Visibility**: All UI elements should be visible and readable
- [ ] **Contrast Ratios**: Text should meet contrast requirements

### Keyboard Navigation
- [ ] **Tab Navigation**: Navigate using keyboard (if on desktop/web)
- [ ] **Focus Indicators**: Focus should be clearly visible
- [ ] **Keyboard Shortcuts**: Test any keyboard shortcuts (if implemented)

---

## 14. Bug Fixes Verification

### Compilation Errors
- [ ] **Build Success**: App should compile without errors
- [ ] **No Runtime Errors**: App should run without crashes
- [ ] **All Screens Load**: All screens should load correctly

### Event Template Service
- [ ] **Template Loading**: Templates should load without errors
- [ ] **Template Creation**: Creating events from templates should work
- [ ] **No Type Errors**: No type-related errors in console

### Task Dependencies
- [ ] **Dependency Picker**: Dependency picker dialog should work
- [ ] **No Null Errors**: No null safety errors when managing dependencies
- [ ] **Task Saving**: Tasks with dependencies should save correctly

---

## 15. Integration Testing

### Feature Interactions
- [ ] **Templates + Dependencies**: Create event from template, then add task with dependencies
- [ ] **Reactions + Threading**: React to a message, then reply in thread
- [ ] **Badges + Notifications**: Verify badges update when notifications arrive
- [ ] **Swipe + Context Menu**: Both swipe actions and long-press menus should work

### Cross-Screen Functionality
- [ ] **Navigation**: Navigate between all screens - should work smoothly
- [ ] **State Persistence**: App state should persist when navigating
- [ ] **Real-time Updates**: Updates should sync across screens

---

## 16. Edge Cases

### Empty States
- [ ] **No Templates**: Test when no templates exist
- [ ] **No Dependencies**: Test task creation with no available dependencies
- [ ] **No Messages**: Test chat with no messages
- [ ] **No Tasks**: Test tasks screen with no tasks

### Error Handling
- [ ] **Network Errors**: Test behavior when network fails
- [ ] **Invalid Data**: Test with invalid input data
- [ ] **Permission Denied**: Test when permissions are denied
- [ ] **Firebase Errors**: Test behavior when Firebase operations fail

### Performance Under Load
- [ ] **Many Items**: Test with many events, tasks, messages
- [ ] **Rapid Actions**: Perform many actions quickly
- [ ] **Memory Usage**: Monitor memory usage during extended use

---

## Testing Checklist Summary

### Critical Paths (Must Test)
- [ ] App compiles and runs without errors
- [ ] All screens load correctly
- [ ] Navigation works between all screens
- [ ] Real-time updates work (badges, messages, etc.)
- [ ] Core features work (create event, create task, send message)

### High Priority Features
- [ ] Loading states (skeleton loaders)
- [ ] Navigation badges
- [ ] Event templates
- [ ] Task dependencies
- [ ] Message reactions
- [ ] Toast notifications

### Medium Priority Features
- [ ] Message threading
- [ ] Swipeable list items
- [ ] Context menus
- [ ] Quick Actions FAB

### Lower Priority Features
- [ ] Caching and performance
- [ ] Image optimization
- [ ] Accessibility features

---

## Reporting Issues

When reporting issues, please include:
1. **Feature/Area**: Which feature or area of the app
2. **Steps to Reproduce**: Detailed steps to reproduce the issue
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happens
5. **Screenshots/Logs**: If applicable
6. **Device/Platform**: Device model, OS version, app version
7. **Network Status**: Online/offline when issue occurred

---

## Notes

- Test on both Android and Chrome (if applicable)
- Test with multiple user accounts
- Test with different family configurations
- Test with various data states (empty, many items, etc.)
- Pay attention to performance and responsiveness
- Verify real-time updates work correctly
- Check for any console errors or warnings

