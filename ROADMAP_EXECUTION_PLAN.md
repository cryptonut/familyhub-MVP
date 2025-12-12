# Roadmap Execution Plan - Family Hub MVP
**Version:** 1.0  
**Created:** December 11, 2025  
**Status:** Ready for Execution  
**Classification:** Technical Implementation Plan

---

## 🎯 Executive Summary

This document provides a comprehensive technical execution plan for implementing the strategic roadmap items outlined in `STRATEGIC_ROADMAP.md`. The plan prioritizes foundational infrastructure that enables premium features, followed by premium hub types and advanced features.

### Strategic Alignment

This plan executes on:
- **Phase 1: Foundation & Infrastructure** (Q1 2025)
- **Premium Feature Infrastructure** (Required for all premium features)
- **Data Isolation & Environment Separation** (Critical for dev/qa/prod)
- **Freemium Foundation** (Required for monetization)

---

## 📋 Implementation Phases

### Phase 1: Foundation Infrastructure (Weeks 1-4)
**Priority:** CRITICAL - Blocks all premium features  
**Status:** 🚧 Ready to Execute

#### 1.1 Data Isolation & Environment Separation
**Objective:** Implement `firestorePrefix` usage across all services

**Current State:**
- ✅ `firestorePrefix` defined in all flavor configs (`dev_`, `test_`, `''`)
- ❌ **NOT USED** in any services - all services use hardcoded collection paths
- ⚠️ **Risk:** Dev, QA, and Prod share the same Firestore data

**Implementation Steps:**

1. **Create Firestore Path Utility** (Day 1)
   ```dart
   // lib/utils/firestore_path_utils.dart
   class FirestorePathUtils {
     static String getCollectionPath(String basePath) {
       final prefix = Config.current.firestorePrefix;
       if (prefix.isEmpty) return basePath;
       
       // Handle paths like 'families/$familyId/messages'
       if (basePath.contains('/')) {
         final parts = basePath.split('/');
         parts[0] = '$prefix${parts[0]}';
         return parts.join('/');
       }
       
       return '$prefix$basePath';
     }
     
     static String getUserPath(String userId) {
       return getCollectionPath('users/$userId');
     }
     
     static String getFamilyPath(String familyId) {
       return getCollectionPath('families/$familyId');
     }
   }
   ```

2. **Refactor All Services** (Days 2-3)
   - Update `TaskService` - Replace `'families/$familyId/tasks'` with `FirestorePathUtils.getCollectionPath('families/$familyId/tasks')`
   - Update `ChatService` - Replace `'families/$familyId/messages'` 
   - Update `CalendarService` - Replace `'families/$familyId/events'`
   - Update `PhotoService` - Replace `'families/$familyId/photos'`
   - Update `ShoppingService` - Replace `'families/$familyId/shoppingLists'`
   - Update `GamesService` - Replace `'families/$familyId/games'`
   - Update `EventTemplateService` - Replace `'families/$familyId/eventTemplates'`
   - Update `AuthService` - Replace `'users'`, `'families'`
   - Update `PrivacyService` - Replace `'families/$familyId/privacySettings'`
   - Update `NavigationOrderService` - Replace `'users/$userId'`
   - Update `UATService` - Replace `'uat_test_cases'`, `'uat_test_results'`
   - Update any other services using Firestore collections

3. **Testing & Verification** (Day 4)
   - Test dev flavor creates data in `dev_families`, `dev_users`
   - Test qa flavor creates data in `test_families`, `test_users`
   - Test prod flavor uses unprefixed paths
   - Verify data isolation: Create data in dev, verify it doesn't appear in qa/prod
   - Test cross-environment queries don't leak data

**Success Criteria:**
- ✅ All Firestore collection paths use `firestorePrefix`
- ✅ Dev environment data isolated from QA/Prod
- ✅ QA environment data isolated from Dev/Prod
- ✅ Production uses unprefixed paths (backward compatible)
- ⏳ No data leakage between environments verified (see `DATA_ISOLATION_TEST_PLAN.md`)

**Estimated Effort:** 2-3 days

---

#### 1.2 Freemium Foundation
**Objective:** Implement subscription management and premium feature gating

**Implementation Steps:**

1. **UserModel Extensions** (Day 1)
   ```dart
   // lib/models/user_model.dart
   // Add to UserModel class:
   final SubscriptionTier? subscriptionTier;
   final SubscriptionStatus? subscriptionStatus;
   final DateTime? subscriptionExpiresAt;
   final List<String> premiumHubTypes; // e.g., ['extended_family', 'homeschooling']
   final DateTime? subscriptionPurchaseDate;
   final String? subscriptionPlatform; // 'google' | 'apple' | null
   ```

2. **AppConfig Extensions** (Day 1)
   ```dart
   // lib/config/app_config.dart
   // Add to AppConfig interface:
   bool get enablePremiumHubs;
   bool get enableExtendedFamilyHub;
   bool get enableHomeschoolingHub;
   bool get enableCoparentingHub;
   ```

3. **SubscriptionService Creation** (Days 2-3)
   ```dart
   // lib/services/subscription_service.dart
   class SubscriptionService {
     Future<bool> hasActiveSubscription();
     Future<bool> hasPremiumHubAccess(String hubType);
     Future<SubscriptionTier> getCurrentTier();
     Future<void> verifyPurchase(String purchaseToken, String platform);
     Future<void> restorePurchases();
     Stream<SubscriptionStatus> subscriptionStatusStream();
     Future<void> updateSubscriptionFromReceipt(String receipt);
   }
   ```

4. **IAP Integration** (Days 4-5)
   - Add `in_app_purchase` package to `pubspec.yaml`
   - Implement Google Play Billing
   - Implement Apple App Store IAP
   - Handle platform differences

5. **Premium Feature Gating** (Day 6)
   ```dart
   // lib/widgets/premium_feature_gate.dart
   class PremiumFeatureGate extends StatelessWidget {
     final String? requiredHubType;
     final Widget fallback;
     final Widget child;
     
     // Checks subscription and renders child or fallback
   }
   ```

6. **Subscription Management UI** (Day 7)
   - Create `SubscriptionScreen` for viewing/managing subscriptions
   - Display current tier, expiration, features
   - Purchase/upgrade buttons
   - Restore purchases button

**Success Criteria:**
- ✅ Users can purchase premium subscriptions
- ✅ Subscription status persists across app restarts
- ✅ Premium features are gated correctly
- ✅ Restore purchases works on both platforms
- ✅ Free tier users see upgrade prompts

**Estimated Effort:** 4-6 days

---

### Phase 2: Premium Hub Infrastructure (Weeks 5-8)
**Priority:** HIGH - Enables premium hub types  
**Status:** 🚧 Planned

#### 2.1 Hub Type System
**Objective:** Extend hub model to support multiple hub types

**Implementation Steps:**

1. **Extend Hub Model** (Day 1)
   ```dart
   // lib/models/hub.dart
   enum HubType {
     family,           // Core family (free)
     extendedFamily,    // Premium
     homeschooling,     // Premium
     coparenting,       // Premium
   }
   
   class Hub {
     final HubType type;
     final Map<String, dynamic> typeSpecificData;
     // ... existing fields
   }
   ```

2. **Hub Type Registry** (Day 2)
   ```dart
   // lib/services/hub_type_registry.dart
   class HubTypeRegistry {
     static Map<HubType, HubTypeConfig> getConfigs();
     static List<String> getRequiredFeatures(HubType type);
     static bool isPremium(HubType type);
   }
   ```

3. **Hub Type Switching UI** (Days 3-4)
   - Update hub creation flow to select hub type
   - Add hub type selector in hub settings
   - Visual indicators for premium hub types

**Estimated Effort:** 4-5 days

---

#### 2.2 Widget Framework Architecture
**Objective:** Design widget system for Android/iOS

**Implementation Steps:**

1. **Widget Configuration Service** (Days 1-2)
   ```dart
   // lib/services/widget_config_service.dart
   class WidgetConfigService {
     Future<void> configureWidget(String hubId, WidgetConfig config);
     Future<WidgetData> getWidgetData(String hubId);
     Future<void> updateWidget(String hubId);
   }
   ```

2. **Deep Linking** (Days 3-4)
   - Implement deep link routing
   - Hub-specific deep links
   - Widget → specific screen navigation

3. **Android Widgets** (Days 5-7)
   - Use Android App Widget framework
   - Implement `AppWidgetProvider`
   - Create widget layouts (multiple sizes)

4. **iOS Widgets** (Days 8-10)
   - Use WidgetKit framework
   - Create widget extensions
   - Implement timeline provider

**Estimated Effort:** 10-12 days

---

### Phase 3: Premium Features (Weeks 9-16)
**Priority:** MEDIUM - Revenue generation  
**Status:** 🚧 Planned

#### 3.1 Extended Family Hubs
- Implementation per Phase 2 in Strategic Roadmap
- Estimated: 4-6 weeks

#### 3.2 Home Schooling Hubs
- Implementation per Phase 3 in Strategic Roadmap
- Estimated: 4-6 weeks

#### 3.3 Co-Parenting Hubs
- Implementation per Phase 4 in Strategic Roadmap
- Estimated: 4-6 weeks

---

### Phase 4: Advanced Features (Weeks 17-24)
**Priority:** MEDIUM - User engagement  
**Status:** 🚧 Planned

#### 4.1 Social Feed Redesign
- Implementation per Phase 5 in Strategic Roadmap
- Estimated: 6-8 weeks

#### 4.2 Encrypted Chat
- Implementation per Encrypted Chat section in Strategic Roadmap
- Estimated: 4-6 weeks

---

## 🚀 Immediate Action Items (Next 2 Weeks)

### Week 1: Data Isolation
1. ✅ Create `FirestorePathUtils` helper class
2. ✅ Refactor all services to use `firestorePrefix`
3. ✅ Test data isolation between environments
4. ✅ Update Firestore security rules if needed

### Week 2: Freemium Foundation
1. ✅ Extend `UserModel` with subscription fields
2. ✅ Extend `AppConfig` with premium feature flags
3. ✅ Create `SubscriptionService`
4. ✅ Add IAP package and basic integration
5. ✅ Create `PremiumFeatureGate` widget
6. ✅ Build `SubscriptionScreen` UI

---

## 📊 Success Metrics

### Technical Metrics
- ✅ Data isolation: 100% separation between dev/qa/prod
- ✅ Subscription system: 100% feature gating accuracy
- ✅ IAP integration: 95%+ purchase success rate
- ✅ Widget framework: Supports 3+ widget types

### Business Metrics
- ✅ Premium conversion: 15-20% of users
- ✅ Subscription retention: 85%+ after 3 months
- ✅ Premium feature adoption: 60%+ of premium users

---

## 🔧 Technical Dependencies

### Required Packages
- `in_app_purchase: ^3.1.0` - For IAP integration
- `cryptography: ^2.7.0` - For encrypted chat (future)
- Existing packages: `firebase_core`, `cloud_firestore`, `provider`

### Firebase Requirements
- Firestore indexes for new queries
- Storage rules for premium content
- App Distribution for testing

---

## ⚠️ Risks & Mitigation

### Technical Risks
1. **Data Migration:** Existing prod data uses unprefixed paths
   - *Mitigation:* Prod uses empty prefix (backward compatible)

2. **IAP Complexity:** Platform differences between Google/Apple
   - *Mitigation:* Abstract platform differences in `SubscriptionService`

3. **Widget Performance:** Battery drain from frequent updates
   - *Mitigation:* Optimize update frequency, use efficient data fetching

### Business Risks
1. **Low Adoption:** Users don't see value in premium features
   - *Mitigation:* Free trials, clear value proposition, user education

2. **Pricing Sensitivity:** Pricing too high/low
   - *Mitigation:* A/B test pricing, market research, flexible tiers

---

## 📅 Timeline Summary

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| Phase 1: Foundation | 4 weeks | Week 1 | Week 4 |
| Phase 2: Premium Infrastructure | 4 weeks | Week 5 | Week 8 |
| Phase 3: Premium Hubs | 8 weeks | Week 9 | Week 16 |
| Phase 4: Advanced Features | 8 weeks | Week 17 | Week 24 |

**Total Timeline:** 24 weeks (6 months)

---

## ✅ Next Steps

1. **Review & Approve:** Review this plan with stakeholders
2. **Sprint Planning:** Break Phase 1 into 2-week sprints
3. **Resource Allocation:** Assign developers to tasks
4. **Kickoff:** Begin Phase 1.1 (Data Isolation)
5. **Daily Standups:** Track progress and blockers

---

*This execution plan is a living document and should be updated as development progresses.*

