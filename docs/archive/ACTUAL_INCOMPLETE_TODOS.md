# Actual Incomplete TODOs - Assessment & Action Plan
**Review Date:** December 2024  
**Status:** Ready for Review & Prioritization

---

## 📋 Executive Summary

This document contains a comprehensive review of all TODO items, FIXME comments, and incomplete tasks found throughout the codebase. Each item has been assessed for:
- **Current Relevance**: Is this still needed?
- **Completion Status**: Has it been done but not marked?
- **Priority**: How important is this?
- **Effort Estimate**: How much work is required?

---

## ✅ Assessment Methodology

For each TODO found:
1. ✅ **Already Complete**: Checked if functionality exists elsewhere
2. ⏭️ **No Longer Needed**: Assessed if app design/functionality changed
3. 🔄 **Still Needed**: Confirmed it's a legitimate incomplete task
4. 📝 **Documentation Only**: Marked as informational, not actionable

---

## 🔍 Complete TODO List

### 1. Offline Queue Service - Local Storage Implementation

**Location:** `lib/services/offline_queue_service.dart` (lines 257, 267)

**Current State:**
```dart
// TODO: Implement with Hive or SharedPreferences
Future<void> _saveToLocalStorage(QueuedOperation operation) async {
  // Currently just logs, doesn't actually save
}

Future<void> _removeFromLocalStorage(String operationId) async {
  // Currently just logs, doesn't actually remove
}
```

**Assessment:** 🔄 **STILL NEEDED** - Critical for offline functionality

**Impact:**
- **High**: Without persistent storage, queued operations are lost on app restart
- **Current Behavior**: Operations only persist in memory (lost on app close)
- **User Impact**: Data loss if app crashes while offline

**Priority:** **HIGH**  
**Effort:** 2-3 hours  
**Dependencies:** Hive or SharedPreferences package (already available)

**Recommendation:** ✅ **IMPLEMENT** - Essential for production readiness

---

### 2. Shopping Analytics Screen - Analytics Loading

**Location:** `lib/screens/shopping/shopping_analytics_screen.dart` (line 26)

**Current State:**
```dart
// TODO: Implement analytics loading
Future<void> _loadAnalytics() async {
  setState(() => _isLoading = true);
  try {
    await Future.delayed(const Duration(milliseconds: 500)); // Placeholder
  } catch (e, st) {
    // Error handling exists but no actual data loading
  }
}
```

**Assessment:** 🔄 **STILL NEEDED** - Feature incomplete

**Impact:**
- **Medium**: Screen exists but shows no data
- **Current Behavior**: Shows loading spinner then empty screen
- **User Impact**: Users can't view shopping analytics

**Priority:** **MEDIUM**  
**Effort:** 4-6 hours  
**Dependencies:** ShoppingService (exists), Analytics calculations needed

**Recommendation:** ✅ **IMPLEMENT** - Complete the feature or remove the screen

**Note:** Could leverage existing `AnalyticsService` or create shopping-specific analytics

---

### 3. Video Call Service - Token Generation

**Location:** `lib/services/video_call_service.dart` (line 165)

**Current State:**
```dart
// TODO: Implement token generation via Cloud Function
Future<String> generateToken(String channelName, int uid) async {
  throw UnimplementedError('Token generation must be implemented server-side');
}
```

**Assessment:** 🔄 **STILL NEEDED** - But may be intentional for now

**Impact:**
- **High**: Video calls won't work without tokens
- **Current Behavior**: Throws error when trying to generate token
- **User Impact**: Video calls non-functional

**Priority:** **HIGH** (if video calls are a priority)  
**Effort:** 4-8 hours (requires Cloud Function setup)  
**Dependencies:** Firebase Cloud Functions, Agora SDK

**Recommendation:** ⚠️ **DECIDE** - Either implement or disable video call feature

**Note:** For MVP, could use temporary tokens from Agora Console for testing

---

### 4. Agora Configuration - App ID & Certificate

**Location:** 
- `lib/config/dev_config.dart` (lines 36, 39)
- `lib/config/qa_config.dart` (lines 36, 39)
- `lib/config/prod_config.dart` (lines 36, 39)

**Current State:**
```dart
String? get agoraAppId => null; // TODO: Add Agora App ID for [env] environment
String? get agoraAppCertificate => null; // TODO: Add Agora App Certificate for [env] environment
```

**Assessment:** 🔄 **STILL NEEDED** - Required for video calls

**Impact:**
- **High**: Video calls require these credentials
- **Current Behavior**: All return null
- **User Impact**: Video calls won't work

**Priority:** **HIGH** (if video calls are a priority)  
**Effort:** 30 minutes (just configuration, not code)  
**Dependencies:** Agora account, credentials from Agora Console

**Recommendation:** ⚠️ **DECIDE** - Add credentials or remove video call feature

**Note:** This is configuration, not code. Need to obtain credentials from Agora.

---

### 5. Chess WebSocket URL Configuration

**Location:**
- `lib/config/dev_config.dart` (line 42)
- `lib/config/qa_config.dart` (line 42)
- `lib/config/prod_config.dart` (line 42)

**Current State:**
```dart
String? get chessWebSocketUrl => null; // TODO: Add WebSocket URL for real-time chess if needed
```

**Assessment:** ⏭️ **MAY NOT BE NEEDED** - Check if real-time chess is used

**Impact:**
- **Low-Medium**: Only affects real-time multiplayer chess (not family/local games)
- **Current Behavior**: Real-time chess may not work
- **User Impact**: Limited to family/local chess games

**Priority:** **LOW** (unless real-time chess is a priority feature)  
**Effort:** 1 hour (if WebSocket server exists)  
**Dependencies:** WebSocket server for chess

**Recommendation:** ⚠️ **INVESTIGATE** - Check if real-time chess is actually used/needed

**Note:** Family chess and solo chess work without this. Only affects open matchmaking.

---

### 6. Event Chat Service - CreatedBy Field

**Location:** `lib/services/event_chat_service.dart` (line 28)

**Current State:**
```dart
// TODO: Add createdBy field to CalendarEvent model
// For now, check if user is in invitedMemberIds
```

**Assessment:** 🔄 **STILL NEEDED** - Workaround in place but not ideal

**Impact:**
- **Low-Medium**: Affects permission checking for event chat
- **Current Behavior**: Uses workaround (checks invitedMemberIds)
- **User Impact**: May have incorrect permissions in edge cases

**Priority:** **LOW-MEDIUM**  
**Effort:** 1-2 hours  
**Dependencies:** CalendarEvent model update, migration if needed

**Recommendation:** ✅ **IMPLEMENT** - Clean up the workaround

**Note:** Workaround works but adding `createdBy` is cleaner and more reliable.

---

### 7. Calendar Sync Service - Recurrence Support

**Location:** `lib/services/calendar_sync_service.dart` (line 273)

**Current State:**
```dart
// TODO: Add proper recurrence support when device_calendar API is stable
// Note: Recurrence support is limited - we sync individual instances instead
```

**Assessment:** ⏭️ **MAY BE LIMITATION** - Platform API limitation

**Impact:**
- **Medium**: Recurring events sync as individual instances
- **Current Behavior**: Works but creates multiple events instead of one recurring
- **User Impact**: Cluttered calendar, but functional

**Priority:** **LOW** (if current workaround is acceptable)  
**Effort:** Unknown (depends on device_calendar package updates)  
**Dependencies:** device_calendar package API improvements

**Recommendation:** ⏭️ **DEFER** - Document limitation, revisit when API improves

**Note:** This is a known limitation of the device_calendar package, not our code.

---

### 8. Chess Game Screen - WebSocket URL

**Location:** `lib/games/chess/screens/chess_game_screen.dart` (line 126)

**Current State:**
```dart
final socketUrl = 'wss://your-backend.com/chess'; // TODO: Replace with actual WebSocket URL
```

**Assessment:** 🔄 **STILL NEEDED** - But only if real-time chess is used

**Impact:**
- **Low**: Only affects real-time multiplayer chess
- **Current Behavior**: Hardcoded placeholder URL
- **User Impact**: Real-time chess won't work

**Priority:** **LOW** (same as #5)  
**Effort:** 30 minutes (if server exists)  
**Dependencies:** WebSocket server

**Recommendation:** ⚠️ **INVESTIGATE** - Same as #5, check if needed

---

### 9. Chess Lobby Screen - Open Mode Setting

**Location:** `lib/games/chess/screens/chess_lobby_screen.dart` (line 146)

**Current State:**
```dart
_openModeEnabled = false; // TODO: Load from family settings
```

**Assessment:** 🔄 **STILL NEEDED** - Feature enhancement

**Impact:**
- **Low**: Open matchmaking always disabled
- **Current Behavior**: Open mode hardcoded to false
- **User Impact**: Can't enable open matchmaking per family

**Priority:** **LOW**  
**Effort:** 2-3 hours (add to family settings, load on init)  
**Dependencies:** Family settings model, UI for toggling

**Recommendation:** ⏭️ **DEFER** - Nice to have, not critical

---

### 10. Chess Move Validator - Promotion Handling

**Location:** `lib/games/chess/utils/chess_move_validator.dart` (line 152)

**Current State:**
```dart
'promotion': null, // TODO: handle promotion
```

**Assessment:** 🔄 **STILL NEEDED** - Feature incomplete

**Impact:**
- **Medium**: Pawn promotion doesn't work correctly
- **Current Behavior**: Promotion moves may fail or not work as expected
- **User Impact**: Chess games incomplete when pawn reaches end

**Priority:** **MEDIUM**  
**Effort:** 2-3 hours  
**Dependencies:** Chess logic library (already using chess package)

**Recommendation:** ✅ **IMPLEMENT** - Important for complete chess functionality

---

## 📊 Summary by Priority

### HIGH Priority (Implement Soon)
1. ✅ **Offline Queue Service - Local Storage** (2-3 hours)
2. ⚠️ **Video Call Token Generation** (4-8 hours) - *OR disable feature*
3. ⚠️ **Agora Configuration** (30 min) - *OR disable feature*

### MEDIUM Priority (Implement When Time Permits)
4. ✅ **Shopping Analytics Implementation** (4-6 hours)
5. ✅ **Chess Promotion Handling** (2-3 hours)
6. ✅ **Event Chat CreatedBy Field** (1-2 hours)

### LOW Priority (Nice to Have)
7. ⏭️ **Calendar Recurrence Support** (Unknown - API limitation)
8. ⚠️ **Chess WebSocket URLs** (1 hour) - *Only if real-time chess needed*
9. ⏭️ **Chess Open Mode Settings** (2-3 hours)

---

## 🎯 Recommended Action Plan

### Phase 1: Critical Fixes (This Sprint)
1. **Offline Queue Service** - Implement Hive/SharedPreferences storage
2. **Chess Promotion** - Fix pawn promotion logic
3. **Event Chat CreatedBy** - Add field to CalendarEvent model

**Estimated Time:** 5-8 hours  
**Impact:** Improves reliability and completes existing features

### Phase 2: Feature Decisions (Next Sprint)
4. **Video Calls** - Decide: Implement token generation OR disable feature
5. **Agora Config** - If video calls proceed, add credentials
6. **Shopping Analytics** - Complete analytics or remove screen

**Estimated Time:** 8-14 hours (if video calls implemented)  
**Impact:** Completes or removes incomplete features

### Phase 3: Enhancements (Future)
7. **Chess WebSocket** - Only if real-time chess is a priority
8. **Chess Open Mode** - Add family settings toggle
9. **Calendar Recurrence** - Wait for API improvements

**Estimated Time:** Variable  
**Impact:** Nice-to-have enhancements

---

## ❌ Items Removed (No Longer Needed)

### Already Complete
- ✅ TaskService caching - **COMPLETE** (verified in code)
- ✅ Pagination - **COMPLETE** (all services have loadMore methods)
- ✅ Query caching - **COMPLETE** (all services integrated)

### No Longer Relevant
- ⏭️ Old migration TODOs - **COMPLETE** (migration done)
- ⏭️ Setup TODOs - **COMPLETE** (setup complete)

---

## 📝 Notes

1. **Video Calls**: This is the biggest decision point. Either implement properly or disable the feature to avoid confusion.

2. **Offline Queue**: This is critical for production. Without persistent storage, the offline queue is essentially useless.

3. **Shopping Analytics**: Screen exists but is empty. Either implement or remove to avoid user confusion.

4. **Chess Features**: Most chess TODOs are for advanced features (real-time, open matchmaking). Core chess works fine.

5. **Configuration TODOs**: These are just missing credentials/config, not code issues.

---

## ✅ Next Steps

1. **Review this list** with stakeholders
2. **Prioritize** based on business needs
3. **Create tickets** for approved items
4. **Update TODOs** in code as items are completed
5. **Remove TODOs** for items that are no longer needed

---

**Document Owner**: Development Team  
**Last Updated**: December 2024  
**Status**: Ready for Review & Approval

