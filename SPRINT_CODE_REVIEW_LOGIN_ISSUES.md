# Sprint Code Review - Login Issue Analysis
**Date:** December 12, 2025

## Changes Made This Sprint

### 1. FirestorePathUtils Implementation (Data Isolation)
- **Files Changed:**
  - `lib/utils/firestore_path_utils.dart` (NEW)
  - All services refactored to use `FirestorePathUtils.getUsersCollection()` and `FirestorePathUtils.getFamiliesCollection()`
  - `lib/services/auth_service.dart` - All user lookups now use prefixed paths
  - `lib/services/navigation_order_service.dart` - Uses prefixed paths

### 2. SubscriptionService Added
- **Files Changed:**
  - `lib/services/subscription_service.dart` (NEW)
  - `lib/main.dart` - Initializes SubscriptionService on startup
  - `lib/models/user_model.dart` - Added subscription fields

### 3. Navigation Order Service
- **Files Changed:**
  - `lib/services/navigation_order_service.dart` - Uses FirestorePathUtils
  - `lib/screens/home_screen.dart` - Loads navigation order in initState

### 4. UAT Service
- **Files Changed:**
  - `lib/services/uat_service.dart` - Uses FirestorePathUtils

## Potential Login Issues Identified

### 🔴 CRITICAL: Data Isolation Mismatch

**Issue:** User data may be in wrong collection due to prefix changes.

**Root Cause:**
- User was created before `firestorePrefix` was implemented
- User data exists in `users` collection (unprefixed)
- App now looks in `dev_users` collection (prefixed for dev flavor)
- AuthService can't find user document → login fails

**Evidence:**
- `AuthService.getCurrentUserModel()` uses `FirestorePathUtils.getUsersCollection()`
- For dev flavor, this returns `dev_users`
- If user was created before prefix, data is in `users`, not `dev_users`

**Fix Required:**
1. Add fallback logic to check both prefixed and unprefixed collections
2. Or migrate existing user data to prefixed collection
3. Or make prefix optional for existing users

### 🟡 MEDIUM: NavigationOrderService Called Too Early

**Issue:** `HomeScreen._loadNavigationOrder()` is called in `initState()`, which happens immediately when HomeScreen is created.

**Root Cause:**
- `NavigationOrderService.getNavigationOrder()` calls `FirestorePathUtils.getUsersCollection()`
- This happens before user is fully authenticated/loaded
- If user document doesn't exist yet, it returns default order (OK)
- But if there's an error, it could cause issues

**Current Behavior:**
- Returns default order if user not authenticated (line 20-22)
- Returns default order if document doesn't exist (line 27-29)
- Should be safe, but could be improved

**Fix Required:**
- Ensure NavigationOrderService gracefully handles unauthenticated state
- Add better error handling

### 🟡 MEDIUM: SubscriptionService Initialization

**Issue:** `SubscriptionService.initialize()` is called in `main.dart` before user is authenticated.

**Root Cause:**
- `_initializeSubscriptionService()` is called on app startup
- It's non-blocking, but if it calls `getCurrentUserModel()` internally, it could fail
- However, `SubscriptionService.initialize()` doesn't call `getCurrentUserModel()` - it only sets up IAP listeners
- Methods that call `getCurrentUserModel()` are only called when needed (hasActiveSubscription, etc.)

**Current Behavior:**
- `initialize()` only sets up IAP listeners
- Doesn't call `getCurrentUserModel()` during init
- Should be safe

**Fix Required:**
- None needed - already safe

### 🟢 LOW: HomeScreen Loading Navigation Order

**Issue:** `HomeScreen` loads navigation order in `initState()`, which happens after login.

**Root Cause:**
- `_loadNavigationOrder()` is called in `initState()`
- This happens after user is authenticated (HomeScreen only shows when authenticated)
- Should be safe, but if there's a Firestore error, it could cause issues

**Current Behavior:**
- Returns default order on error (line 50)
- Should be safe

**Fix Required:**
- None needed - already safe

## Recommended Fixes

### Fix 1: Add Fallback for User Data Lookup (CRITICAL)

**File:** `lib/services/auth_service.dart`

Add fallback logic to check both prefixed and unprefixed collections:

```dart
Future<UserModel?> getCurrentUserModel() async {
  // ... existing code ...
  
  // Try prefixed collection first (current environment)
  var userRef = _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(user.uid);
  var userDoc = await userRef.get(GetOptions(source: Source.server));
  
  // If not found and we're using a prefix, try unprefixed collection (migration path)
  if (!userDoc.exists && Config.current.firestorePrefix.isNotEmpty) {
    Logger.info('User not found in prefixed collection, trying unprefixed...', tag: 'AuthService');
    userRef = _firestore.collection('users').doc(user.uid);
    userDoc = await userRef.get(GetOptions(source: Source.server));
    
    // If found in unprefixed, migrate to prefixed
    if (userDoc.exists) {
      Logger.info('Migrating user data to prefixed collection...', tag: 'AuthService');
      final data = userDoc.data()!;
      await _firestore.collection(FirestorePathUtils.getUsersCollection())
          .doc(user.uid)
          .set(data, SetOptions(merge: false));
    }
  }
  
  // ... rest of existing code ...
}
```

### Fix 2: Ensure NavigationOrderService is Safe

**File:** `lib/services/navigation_order_service.dart`

Already safe - returns default order if user not authenticated or document doesn't exist.

### Fix 3: Add Better Error Handling in HomeScreen

**File:** `lib/screens/home_screen.dart`

Already has error handling - returns default order on error.

## Testing Plan

1. **Test with existing user (created before prefix):**
   - User data in `users` collection
   - App using `dev_users` collection
   - Should fallback to `users` and migrate

2. **Test with new user (created after prefix):**
   - User data in `dev_users` collection
   - Should work normally

3. **Test navigation order loading:**
   - Should return default if user not authenticated
   - Should return default if document doesn't exist
   - Should return saved order if exists

## Implementation Priority

1. **CRITICAL:** Fix 1 - Add fallback for user data lookup
2. **MEDIUM:** Verify NavigationOrderService is safe (already is)
3. **LOW:** Add logging for debugging

