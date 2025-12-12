# Data Isolation Test Plan
**Version:** 1.0  
**Created:** December 11, 2025  
**Status:** Ready for Testing  
**Purpose:** Verify that `firestorePrefix` correctly isolates data between dev, qa, and prod environments

---

## 🎯 Objective

Verify that data created in one environment (dev/qa/prod) does not appear in other environments, ensuring complete data isolation.

---

## 📋 Test Prerequisites

1. **Firebase Project:** `family-hub-71ff0` (shared across all environments)
2. **Flutter Flavors Configured:**
   - Dev: `com.example.familyhub_mvp.dev` → prefix: `dev_`
   - QA: `com.example.familyhub_mvp.test` → prefix: `test_`
   - Prod: `com.example.familyhub_mvp` → prefix: `` (empty)

3. **Firebase Console Access:** Required to verify data in Firestore

---

## ✅ Test Cases

### Test Case 1: Verify Path Construction

**Objective:** Confirm that `FirestorePathUtils` correctly constructs paths with prefixes.

**Steps:**
1. Run app in dev flavor: `flutter run --flavor dev`
2. Check console logs for: `🔧 Firestore Prefix: dev_`
3. Verify paths:
   - `FirestorePathUtils.getUsersCollection()` → `dev_users`
   - `FirestorePathUtils.getFamiliesCollection()` → `dev_families`
   - `FirestorePathUtils.getFamilySubcollectionPath('family123', 'tasks')` → `dev_families/family123/tasks`

**Expected Result:**
- All paths should be prefixed with `dev_`
- Console should show correct prefix in logs

**Repeat for QA and Prod:**
- QA: All paths prefixed with `test_`
- Prod: All paths unprefixed (no prefix)

---

### Test Case 2: Create Data in Dev Environment

**Objective:** Create test data in dev environment and verify it's stored in prefixed collections.

**Steps:**
1. Run app in dev flavor: `flutter run --flavor dev`
2. Sign in with test account
3. Create a test family (if not exists)
4. Create a test task: "DEV TEST TASK - DO NOT DELETE"
5. Create a test message: "DEV TEST MESSAGE - DO NOT DELETE"
6. Create a test event: "DEV TEST EVENT - DO NOT DELETE"

**Verification in Firebase Console:**
1. Open Firestore Database in Firebase Console
2. Navigate to collections
3. **Expected:** Data should be in:
   - `dev_users/{userId}`
   - `dev_families/{familyId}`
   - `dev_families/{familyId}/tasks/{taskId}`
   - `dev_families/{familyId}/messages/{messageId}`
   - `dev_families/{familyId}/events/{eventId}`

**Expected Result:**
- All data appears in `dev_*` collections
- No data appears in unprefixed collections (`users`, `families`, etc.)
- No data appears in `test_*` collections

---

### Test Case 3: Create Data in QA Environment

**Objective:** Create test data in QA environment and verify it's stored in prefixed collections.

**Steps:**
1. Run app in QA flavor: `flutter run --flavor qa` (or `test`)
2. Sign in with **same test account** (to verify isolation)
3. Create a test family (if not exists)
4. Create a test task: "QA TEST TASK - DO NOT DELETE"
5. Create a test message: "QA TEST MESSAGE - DO NOT DELETE"
6. Create a test event: "QA TEST EVENT - DO NOT DELETE"

**Verification in Firebase Console:**
1. Open Firestore Database in Firebase Console
2. Navigate to collections
3. **Expected:** Data should be in:
   - `test_users/{userId}`
   - `test_families/{familyId}`
   - `test_families/{familyId}/tasks/{taskId}`
   - `test_families/{familyId}/messages/{messageId}`
   - `test_families/{familyId}/events/{eventId}`

**Expected Result:**
- All data appears in `test_*` collections
- No data appears in `dev_*` collections
- No data appears in unprefixed collections
- **Same user account** should have separate data in each environment

---

### Test Case 4: Verify Production Environment (Unprefixed)

**Objective:** Verify that production environment uses unprefixed paths (backward compatible).

**Steps:**
1. Run app in prod flavor: `flutter run --flavor prod`
2. Check console logs for: `🔧 Firestore Prefix: ` (empty)
3. Verify paths:
   - `FirestorePathUtils.getUsersCollection()` → `users`
   - `FirestorePathUtils.getFamiliesCollection()` → `families`
   - `FirestorePathUtils.getFamilySubcollectionPath('family123', 'tasks')` → `families/family123/tasks`

**Expected Result:**
- All paths should be **unprefixed** (no prefix)
- Console should show empty prefix in logs
- Data should be stored in standard collections (`users`, `families`, etc.)

---

### Test Case 5: Cross-Environment Data Isolation

**Objective:** Verify that data created in one environment is not accessible from another.

**Steps:**
1. **In Dev Environment:**
   - Create a task: "DEV ONLY TASK"
   - Note the task ID

2. **In QA Environment:**
   - Sign in with same account
   - Try to access the task created in dev
   - **Expected:** Task should NOT appear (different collection)

3. **In Prod Environment:**
   - Sign in with same account
   - Try to access tasks from dev or qa
   - **Expected:** Tasks should NOT appear (different collections)

**Expected Result:**
- Data created in dev is only visible in dev
- Data created in qa is only visible in qa
- Data created in prod is only visible in prod
- Complete isolation between environments

---

### Test Case 6: Service-Level Verification

**Objective:** Verify that all services correctly use `FirestorePathUtils`.

**Services to Test:**
- ✅ AuthService (users collection)
- ✅ TaskService (families/{id}/tasks)
- ✅ ChatService (families/{id}/messages)
- ✅ CalendarService (families/{id}/events)
- ✅ PhotoService (families/{id}/photos)
- ✅ ShoppingService (families/{id}/shoppingLists)
- ✅ GamesService (families/{id}/game_stats)
- ✅ NavigationOrderService (users/{id}/navigationOrder)
- ✅ EventTemplateService (families/{id}/eventTemplates)
- ✅ PrivacyService (users/{id} updates)

**Steps:**
1. Run app in dev flavor
2. Perform operations in each service:
   - Create a task
   - Send a message
   - Create an event
   - Upload a photo
   - Create a shopping list
   - Play a game (update stats)
   - Reorder navigation
   - Create event template
   - Update privacy settings

3. Verify in Firebase Console that all data is in `dev_*` collections

**Expected Result:**
- All services correctly use prefixed paths
- No data leaks to unprefixed collections

---

## 🔍 Verification Checklist

### Manual Verification in Firebase Console

1. **Open Firebase Console:** https://console.firebase.google.com/project/family-hub-71ff0/firestore
2. **Check Collections:**
   - [ ] `dev_users` exists (if dev data created)
   - [ ] `dev_families` exists (if dev data created)
   - [ ] `test_users` exists (if qa data created)
   - [ ] `test_families` exists (if qa data created)
   - [ ] `users` exists (production data)
   - [ ] `families` exists (production data)

3. **Verify Isolation:**
   - [ ] Dev data only in `dev_*` collections
   - [ ] QA data only in `test_*` collections
   - [ ] Prod data only in unprefixed collections
   - [ ] No cross-contamination between environments

---

## 🐛 Troubleshooting

### Issue: Data appears in wrong collection

**Possible Causes:**
1. Service not using `FirestorePathUtils`
2. Hardcoded collection path in service
3. Config not initialized correctly

**Solution:**
1. Check service imports: Should import `../utils/firestore_path_utils.dart`
2. Check service code: Should use `FirestorePathUtils.getCollectionPath()` or helper methods
3. Check console logs: Should show correct prefix on app start

### Issue: Same user sees different data in different environments

**Expected Behavior:** This is correct! Same user account should have separate data in each environment.

**Verification:**
- Dev: User sees data in `dev_*` collections
- QA: User sees data in `test_*` collections
- Prod: User sees data in unprefixed collections

### Issue: Production data appears in prefixed collections

**Possible Causes:**
1. Wrong flavor selected during build
2. Config initialization failed

**Solution:**
1. Verify flavor: `flutter run --flavor prod`
2. Check console logs: Should show `Firestore Prefix: ` (empty)
3. Verify package name: Should be `com.example.familyhub_mvp` (no suffix)

---

## 📊 Test Results Template

```
Test Date: __________
Tester: __________
Environment: Dev / QA / Prod

Test Case 1: Path Construction
[ ] Pass
[ ] Fail
Notes: __________

Test Case 2: Dev Data Creation
[ ] Pass
[ ] Fail
Notes: __________

Test Case 3: QA Data Creation
[ ] Pass
[ ] Fail
Notes: __________

Test Case 4: Prod Path Verification
[ ] Pass
[ ] Fail
Notes: __________

Test Case 5: Cross-Environment Isolation
[ ] Pass
[ ] Fail
Notes: __________

Test Case 6: Service-Level Verification
[ ] Pass
[ ] Fail
Notes: __________

Overall Result: [ ] PASS [ ] FAIL
```

---

## ✅ Success Criteria

- [x] All services use `FirestorePathUtils` for path construction
- [ ] Dev environment creates data in `dev_*` collections
- [ ] QA environment creates data in `test_*` collections
- [ ] Prod environment creates data in unprefixed collections
- [ ] No data leakage between environments
- [ ] Same user account has separate data in each environment
- [ ] All test cases pass

---

## 📝 Notes

- **Backward Compatibility:** Production uses unprefixed paths, so existing production data remains accessible
- **User Accounts:** Same Firebase Auth user can exist in all three environments, but will have separate Firestore data
- **Firebase Security Rules:** May need to be updated to allow access to prefixed collections (e.g., `dev_families`, `test_families`)

---

*This test plan should be executed after Phase 1.1 implementation to verify data isolation is working correctly.*

