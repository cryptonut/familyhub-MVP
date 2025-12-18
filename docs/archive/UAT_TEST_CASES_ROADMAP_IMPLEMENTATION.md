# UAT Test Cases - Roadmap Implementation Features
**Created:** December 11, 2025  
**Purpose:** Test cases to be added to UAT system for testing new roadmap implementation features

---

## Test Round: Roadmap Phase 1.1 & 1.2 Implementation

### Test Case 1: Data Isolation & Environment Separation
**Number:** 1  
**Title:** Data Isolation Between Environments  
**Description:** Verify that data created in dev environment is isolated from QA and production environments  
**Feature:** Data Isolation  
**Test:** 
- Create data in dev environment (tasks, messages, events)
- Verify data appears in `dev_*` collections in Firebase Console
- Verify data does NOT appear in unprefixed or `test_*` collections
- Switch to QA environment and verify data is isolated

**Sub-Test Cases:**
1. **TC-1.1:** Verify users collection isolation
   - Create user in dev → verify in `dev_users`
   - Create user in QA → verify in `test_users`
   - Verify no cross-contamination

2. **TC-1.2:** Verify families collection isolation
   - Create family in dev → verify in `dev_families`
   - Create family in QA → verify in `test_families`
   - Verify no cross-contamination

3. **TC-1.3:** Verify subcollections isolation
   - Create tasks in dev → verify in `dev_families/{id}/tasks`
   - Create messages in dev → verify in `dev_families/{id}/messages`
   - Create events in dev → verify in `dev_families/{id}/events`
   - Verify QA environment doesn't see dev data

4. **TC-1.4:** Verify production uses unprefixed paths
   - Run app in prod flavor
   - Verify data created in unprefixed collections (`users`, `families`)
   - Verify backward compatibility with existing production data

---

### Test Case 2: Subscription Model & UserModel Extensions
**Number:** 2  
**Title:** Subscription Fields in UserModel  
**Description:** Verify that UserModel correctly stores and retrieves subscription information  
**Feature:** Subscription Management  
**Test:**
- Verify UserModel has subscription fields (tier, status, expiresAt, etc.)
- Verify subscription fields are saved to Firestore correctly
- Verify subscription fields are loaded from Firestore correctly
- Verify helper methods (hasActivePremiumSubscription, hasPremiumHubAccess) work correctly

**Sub-Test Cases:**
1. **TC-2.1:** Verify subscription tier storage
   - Set subscription tier to premium
   - Verify tier is saved to Firestore
   - Reload user model and verify tier is correct

2. **TC-2.2:** Verify subscription status storage
   - Set subscription status to active
   - Verify status is saved to Firestore
   - Reload user model and verify status is correct

3. **TC-2.3:** Verify subscription expiration
   - Set expiration date
   - Verify date is saved correctly
   - Verify days until expiration calculation works

4. **TC-2.4:** Verify premium hub access check
   - Add premium hub type to user
   - Verify hasPremiumHubAccess returns true for that hub type
   - Verify hasPremiumHubAccess returns false for other hub types

---

### Test Case 3: Premium Feature Flags
**Number:** 3  
**Title:** AppConfig Premium Feature Flags  
**Description:** Verify that premium feature flags are correctly configured per environment  
**Feature:** Feature Flags  
**Test:**
- Verify dev environment has premium features enabled
- Verify QA environment has premium features enabled
- Verify prod environment has premium features disabled (until launch)
- Verify flags are accessible via Config.current

**Sub-Test Cases:**
1. **TC-3.1:** Verify dev flags
   - Run app in dev flavor
   - Verify enablePremiumHubs = true
   - Verify enableExtendedFamilyHub = true
   - Verify enableHomeschoolingHub = true
   - Verify enableCoparentingHub = true
   - Verify enableEncryptedChat = true

2. **TC-3.2:** Verify QA flags
   - Run app in QA flavor
   - Verify all premium flags are true (same as dev)

3. **TC-3.3:** Verify prod flags
   - Run app in prod flavor
   - Verify enablePremiumHubs = false
   - Verify all premium hub flags are false
   - Verify enableEncryptedChat = false

---

### Test Case 4: Subscription Service - IAP Integration
**Number:** 4  
**Title:** Subscription Service Functionality  
**Description:** Verify that SubscriptionService correctly handles IAP operations  
**Feature:** In-App Purchases  
**Test:**
- Verify service initializes correctly
- Verify hasActiveSubscription() returns correct status
- Verify getCurrentTier() returns correct tier
- Verify getAvailableProducts() returns products (if configured)
- Verify purchase flow (if IAP products are configured)
- Verify restore purchases functionality

**Sub-Test Cases:**
1. **TC-4.1:** Verify service initialization
   - Initialize SubscriptionService
   - Verify no errors
   - Verify IAP availability check works

2. **TC-4.2:** Verify subscription status checks
   - Check hasActiveSubscription() for free user → should return false
   - Check hasActiveSubscription() for premium user → should return true
   - Check getCurrentTier() → should return correct tier

3. **TC-4.3:** Verify product listing
   - Call getAvailableProducts()
   - Verify products are returned (if configured in Play Console/App Store)
   - Verify product details (price, description) are correct

4. **TC-4.4:** Verify purchase flow (requires IAP setup)
   - Attempt to purchase subscription
   - Verify purchase is processed
   - Verify subscription status is updated in Firestore
   - Verify user model reflects new subscription

5. **TC-4.5:** Verify restore purchases
   - Call restorePurchases()
   - Verify existing purchases are restored
   - Verify subscription status is updated

---

### Test Case 5: Premium Feature Gate Widget
**Number:** 5  
**Title:** Premium Feature Gate Widget  
**Description:** Verify that PremiumFeatureGate correctly gates premium features  
**Feature:** Feature Gating  
**Test:**
- Verify widget shows child for premium users
- Verify widget shows fallback/upgrade prompt for free users
- Verify widget handles loading state
- Verify widget checks subscription correctly

**Sub-Test Cases:**
1. **TC-5.1:** Verify free user sees upgrade prompt
   - Wrap feature in PremiumFeatureGate
   - Verify free user sees upgrade prompt
   - Verify upgrade button is clickable

2. **TC-5.2:** Verify premium user sees content
   - Wrap feature in PremiumFeatureGate
   - Verify premium user sees actual content (child widget)
   - Verify no upgrade prompt is shown

3. **TC-5.3:** Verify hub-specific gating
   - Use PremiumFeatureGate with requiredHubType
   - Verify user with access sees content
   - Verify user without access sees upgrade prompt

4. **TC-5.4:** Verify custom fallback
   - Provide custom fallback widget
   - Verify custom fallback is shown for free users
   - Verify custom fallback is not shown for premium users

---

### Test Case 6: Subscription Screen UI
**Number:** 6  
**Title:** Subscription Screen Functionality  
**Description:** Verify that SubscriptionScreen displays and manages subscriptions correctly  
**Feature:** Subscription Management UI  
**Test:**
- Verify screen loads without errors
- Verify current subscription is displayed correctly
- Verify premium features list is shown
- Verify upgrade options are displayed for free users
- Verify purchase buttons work (if IAP configured)
- Verify restore purchases button works

**Sub-Test Cases:**
1. **TC-6.1:** Verify screen loads
   - Navigate to Subscription screen
   - Verify no errors
   - Verify loading indicator shows then disappears

2. **TC-6.2:** Verify free user view
   - View subscription screen as free user
   - Verify "Free" tier is displayed
   - Verify upgrade options are shown
   - Verify product cards are displayed (if products available)

3. **TC-6.3:** Verify premium user view
   - View subscription screen as premium user
   - Verify "Premium" tier is displayed
   - Verify subscription status is shown
   - Verify expiration date is displayed
   - Verify days remaining is calculated correctly
   - Verify "Manage Subscription" section is shown

4. **TC-6.4:** Verify premium features list
   - Verify all premium features are listed
   - Verify features show checkmark for premium users
   - Verify features show lock icon for free users

5. **TC-6.5:** Verify purchase flow (requires IAP setup)
   - Tap purchase button on product card
   - Verify purchase dialog appears
   - Complete purchase
   - Verify subscription screen updates
   - Verify success message is shown

6. **TC-6.6:** Verify restore purchases
   - Tap "Restore Purchases" button
   - Verify restore process completes
   - Verify subscription screen updates
   - Verify success message is shown

---

## How to Add These Test Cases to UAT System

### Option 1: Manual Addition via Firebase Console
1. Open Firebase Console → Firestore Database
2. Navigate to `uat_test_rounds` collection
3. Create a new test round document with:
   - `name`: "Roadmap Phase 1.1 & 1.2 Implementation"
   - `description`: "Testing data isolation, subscription management, and premium features"
   - `createdAt`: Current timestamp
   - `createdBy`: Your user ID
4. For each test case above, create a document in `test_cases` subcollection
5. For each sub-test case, create a document in `sub_test_cases` subcollection

### Option 2: Script-Based Addition
Create a script to add these test cases programmatically (can be done via Flutter/Dart script or Firebase Admin SDK)

### Option 3: UAT Screen Admin Feature
Add an "Add Test Cases" feature to the UAT screen for admins/testers to add test cases directly from the app

---

## Test Priority

**High Priority (Must Test):**
- TC-1: Data Isolation (Critical for environment separation)
- TC-2: Subscription Model (Core functionality)
- TC-4: Subscription Service (IAP integration)
- TC-6: Subscription Screen (User-facing feature)

**Medium Priority:**
- TC-3: Feature Flags (Configuration verification)
- TC-5: Premium Feature Gate (UI component)

---

## Notes

- IAP products must be configured in Google Play Console / App Store Connect before testing purchase flows
- Data isolation testing requires access to Firebase Console to verify collection names
- Subscription testing may require test accounts with active subscriptions
- Some tests may be blocked until IAP products are fully configured

---

*This document should be used to populate the UAT system with test cases for the new roadmap implementation features.*

