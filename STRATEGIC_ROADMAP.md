# Family Hub - Strategic Roadmap
**Version:** 1.1  
**Last Updated:** December 10, 2025  
**Status:** Living Document - Updated Regularly  
**Classification:** Strategic Planning

---

## 🎯 Executive Summary

This document outlines the strategic roadmap for Family Hub's evolution from a core family management app to a comprehensive platform supporting multiple family relationship types and use cases. The roadmap focuses on premium hub types that will be offered as in-app purchases, with a strong emphasis on native mobile widget integration for seamless access.

### Vision Statement
Transform Family Hub into a multi-hub platform where families can manage not just their immediate family, but extended families, homeschooling communities, and co-parenting arrangements—all accessible instantly via home screen widgets.

### Strategic Pillars
1. **Premium Hub Expansion**: Extend beyond core family hub to specialized hub types
2. **Widget-First Access**: Each hub type accessible via dedicated home screen widgets
3. **In-App Purchase Model**: Premium features monetized through IAP
4. **Seamless Hub Switching**: Maintain single-app experience across all hub types
5. **Hub-Specific Features**: Customize functionality per hub type while maintaining core infrastructure

---

## 🗺️ Roadmap Overview

### Phase 1: Foundation & Infrastructure (Current - Q1 2025)
**Status:** ✅ In Progress / 🚧 Planning

#### Current State
- Core Family Hub fully functional
- Basic hub switching mechanism
- Foundation services (auth, storage, real-time sync)

#### Infrastructure Requirements
- [ ] **Widget Framework Architecture**
  - Design widget system for Android/iOS
  - Create widget configuration service
  - Implement deep linking for widget → hub navigation
  - Establish widget update mechanisms

- [ ] **Premium Feature Infrastructure**
  - In-app purchase (IAP) integration
  - Subscription management system
  - Feature flag system for premium hubs
  - Usage analytics for premium features
  - Subscription gifting system (see Phase 2)

- [ ] **Encrypted Chat (Premium Feature)**
  - **Status:** 🚧 Planned for Premium Tier
  - **Priority:** High - Privacy and security differentiator
  - **Objective:** Provide end-to-end encrypted messaging with auto-destruct capabilities as a premium feature
  
  **Key Features:**
  - [ ] **End-to-End Encryption (E2EE)**
    - Implement Signal Protocol or similar E2EE standard
    - Key exchange and management system
    - Forward secrecy (keys rotate periodically)
    - Message encryption/decryption on device
    - Encrypted message storage in Firestore (server cannot read)
  
  - [ ] **Auto-Destruct Messages**
    - User-configurable message expiration (1 hour, 1 day, 1 week, custom)
    - Per-message or per-conversation settings
    - Automatic deletion after expiration
    - Visual indicators for expiring messages (countdown timer)
    - Screenshot detection (optional, platform-dependent)
    - Notification when message expires
  
  - [ ] **Security Features**
    - Device key management (secure key storage)
    - Key backup/recovery (optional, user-controlled)
    - Verification codes for contact verification
    - Security indicators (lock icons, encryption status)
    - Audit log for security events (optional)
  
  - [ ] **User Experience**
    - Seamless encryption (transparent to user)
    - Clear indicators when chat is encrypted
    - Settings to enable/disable encryption per hub
    - Migration path for existing unencrypted chats
    - Performance optimization (encryption shouldn't slow down messaging)
  
  - [ ] **Technical Requirements**
    - Choose encryption library (e.g., `cryptography` package for Dart)
    - Implement key exchange protocol
    - Encrypt messages before sending to Firestore
    - Decrypt messages on receipt
    - Handle key rotation and re-encryption
    - Implement message expiration service
    - Background job to delete expired messages
  
  - [ ] **Monetization**
    - Available to Premium tier subscribers
    - Can be enabled per hub (family, extended family, etc.)
    - Optional: One-time purchase for lifetime encryption access
    - Value proposition: "Private, secure family communication"
  
  **Success Metrics:**
  - 60%+ of premium users enable encrypted chat
  - 40%+ of encrypted messages use auto-destruct
  - Zero security incidents (no message leaks)
  - User satisfaction: 4.5+ stars for security features
  
  **Estimated Timeline:**
  - Q2 2026: E2EE implementation
  - Q3 2026: Auto-destruct and advanced features

- [ ] **Hub Type System**
  - Extend hub model to support hub types
  - Create hub type registry
  - Implement hub type-specific feature sets
  - Design hub type switching UI/UX

- [ ] **Multi-Hub Data Architecture**
  - Optimize data queries for multi-hub context
  - Implement hub-scoped data isolation
  - Create hub membership management
  - Design cross-hub analytics (if needed)

- [ ] **Data Isolation & Environment Separation (Post-Release Refactor)**
  - **Status:** 🚧 Planned for after next QA release
  - **Priority:** High - Required for proper dev/qa/prod separation
  - **Objective:** Implement `firestorePrefix` usage across all services to ensure complete data isolation between development, QA, and production environments
  
  **Current State:**
  - `firestorePrefix` is defined in all flavor configs (`dev_`, `test_`, `''`)
  - `Config.current.firestorePrefix` is available but **not currently used** in services
  - All services use hardcoded collection paths (e.g., `'families/$familyId/messages'`)
  - **Risk:** Dev, QA, and Prod environments share the same Firestore data
  
  **Implementation Plan:**
  1. **Create Helper Method**
     - Add `_getCollectionPath(String basePath)` helper to base service class or utility
     - Method should prepend `Config.current.firestorePrefix` to collection paths
     - Example: `_getCollectionPath('families')` → `'dev_families'` (in dev flavor)
  
  2. **Refactor All Services**
     - Update all `FirebaseFirestore.instance.collection()` calls
     - Services to update:
       - `TaskService` - `'families/$familyId/tasks'` → `'${prefix}families/$familyId/tasks'`
       - `ChatService` - `'families/$familyId/messages'` → `'${prefix}families/$familyId/messages'`
       - `CalendarService` - `'families/$familyId/events'` → `'${prefix}families/$familyId/events'`
       - `PhotoService` - `'families/$familyId/photos'` → `'${prefix}families/$familyId/photos'`
       - `ShoppingService` - `'families/$familyId/shoppingLists'` → `'${prefix}families/$familyId/shoppingLists'`
       - `GamesService` - `'families/$familyId/games'` → `'${prefix}families/$familyId/games'`
       - `EventTemplateService` - `'families/$familyId/eventTemplates'` → `'${prefix}families/$familyId/eventTemplates'`
       - `AuthService` - `'users'`, `'families'` → `'${prefix}users'`, `'${prefix}families'`
       - `PrivacyService` - `'families/$familyId/privacySettings'` → `'${prefix}families/$familyId/privacySettings'`
       - `NavigationOrderService` - `'users/$userId'` → `'${prefix}users/$userId'`
       - `UATService` - `'uat_test_cases'`, `'uat_test_results'` → `'${prefix}uat_test_cases'`, `'${prefix}uat_test_results'`
       - Any other services using Firestore collections
  
  3. **Storage Rules Path Updates**
     - Update Firebase Storage rules to include prefixed paths
     - Example: `match /${prefix}photos/{familyId}/{photoId}` (if prefix support needed)
     - Note: Storage paths may need different handling (verify Firebase Storage prefix support)
  
  4. **Testing & Verification**
     - Verify dev flavor creates data in `dev_families`, `dev_users`, etc.
     - Verify qa flavor creates data in `test_families`, `test_users`, etc.
     - Verify prod flavor uses unprefixed paths (`families`, `users`, etc.)
     - Test data isolation: Create data in dev, verify it doesn't appear in qa/prod
     - Test cross-environment queries don't leak data
  
  5. **Migration Considerations**
     - Existing data in production will remain unprefixed
     - Dev/QA environments will start fresh with prefixed collections
     - No migration needed for existing prod data (uses empty prefix)
     - Document the prefix system for future developers
  
  **Estimated Effort:** 2-3 hours
  - Service refactoring: ~1.5 hours
  - Testing & verification: ~1 hour
  - Documentation: ~30 minutes
  
  **Dependencies:**
  - Must complete after next QA release to avoid blocking testing
  - Requires all services to be stable before refactoring
  
  **Success Criteria:**
  - All Firestore collection paths use `firestorePrefix`
  - Dev environment data isolated from QA/Prod
  - QA environment data isolated from Dev/Prod
  - Production environment uses unprefixed paths (backward compatible)
  - No data leakage between environments verified

- [ ] **Freemium Foundation (Post-Release Refactor)**
  - **Status:** 🚧 Planned for after next QA release
  - **Priority:** Medium - Required for premium hub monetization
  - **Objective:** Implement foundation for freemium model with subscription management and premium feature flags
  
  **Current State:**
  - No subscription or premium feature infrastructure
  - All features currently available to all users
  - No IAP integration
  
  **Implementation Plan (Option C - Recommended):**
  1. **UserModel Extensions**
     - Add subscription fields to `UserModel`:
       - `subscriptionTier`: `'free' | 'premium' | 'family_plus' | 'family_premium'`
       - `subscriptionStatus`: `'active' | 'expired' | 'cancelled' | 'trial'`
       - `subscriptionExpiresAt`: `DateTime?`
       - `premiumHubTypes`: `List<String>` (e.g., `['extended_family', 'homeschooling']`)
       - `subscriptionPurchaseDate`: `DateTime?`
       - `subscriptionPlatform`: `'google' | 'apple' | null`
  
  2. **AppConfig Extensions**
     - Add premium feature flags to `AppConfig`:
       - `bool get enablePremiumHubs;`
       - `bool get enableExtendedFamilyHub;`
       - `bool get enableHomeschoolingHub;`
       - `bool get enableCoparentingHub;`
     - These can be environment-specific (e.g., enable in prod, disable in dev for testing)
  
  3. **SubscriptionService Creation**
     - Create new `lib/services/subscription_service.dart`
     - Methods:
       - `Future<bool> hasActiveSubscription()` - Check if user has active premium subscription
       - `Future<bool> hasPremiumHubAccess(String hubType)` - Check access to specific hub type
       - `Future<SubscriptionTier> getCurrentTier()` - Get user's current subscription tier
       - `Future<void> verifyPurchase(String purchaseToken, String platform)` - Verify IAP purchase
       - `Future<void> restorePurchases()` - Restore purchases (for account recovery)
       - `Stream<SubscriptionStatus> subscriptionStatusStream()` - Real-time subscription status
       - `Future<void> updateSubscriptionFromReceipt(String receipt)` - Update subscription from IAP receipt
  
  4. **IAP Integration (Google Play & App Store)**
     - Add `in_app_purchase` package to `pubspec.yaml`
     - Implement Google Play Billing:
       - Product ID configuration
       - Purchase flow
       - Receipt validation
     - Implement Apple App Store IAP:
       - Product ID configuration
       - Purchase flow
       - Receipt validation
     - Handle platform differences (Android vs iOS)
  
  5. **Premium Feature Gating**
     - Create `PremiumFeatureGate` widget for conditional rendering
     - Example usage:
       ```dart
       PremiumFeatureGate(
         requiredHubType: 'extended_family',
         fallback: UpgradePrompt(),
         child: ExtendedFamilyHubScreen(),
       )
       ```
     - Add checks in hub creation flows
     - Add upgrade prompts where premium features are accessed
  
  6. **Subscription Management UI**
     - Create `SubscriptionScreen` for viewing/managing subscriptions
     - Display current tier, expiration date, features included
     - Purchase/upgrade buttons
     - Restore purchases button
     - Subscription history
  
  7. **Backend Validation (Optional but Recommended)**
     - Create Cloud Function to validate IAP receipts server-side
     - Store subscription status in Firestore `users/{userId}/subscription`
     - Periodic validation to catch subscription changes
     - Handle subscription renewals, cancellations, refunds
  
  8. **Testing Strategy**
     - Test with Google Play test accounts
     - Test with App Store sandbox accounts
     - Test subscription expiration handling
     - Test restore purchases flow
     - Test premium feature access gating
  
  **Estimated Effort:** 4-6 hours
  - SubscriptionService: ~2 hours
  - IAP integration: ~2 hours
  - UI components: ~1 hour
  - Testing: ~1 hour
  
  **Dependencies:**
  - Must complete after next QA release
  - Requires IAP product IDs configured in Google Play Console / App Store Connect
  - Backend validation (optional) requires Cloud Functions setup
  
  **Success Criteria:**
  - Users can purchase premium subscriptions
  - Subscription status persists across app restarts
  - Premium features are gated correctly
  - Restore purchases works on both platforms
  - Subscription expiration handled gracefully
  - Free tier users see upgrade prompts

- [ ] **Subscription Gifting System**
  - **Status:** 🚧 Planned for Phase 2 (Q2 2025)
  - **Priority:** Medium - Monetization enhancement
  - **Objective:** Allow users to purchase premium subscriptions as gifts when inviting family members, creating a seamless onboarding experience and additional revenue stream
  
  **Key Features:**
  - [ ] **Gift Subscription IAP Products**
    - Create IAP product IDs for gift subscriptions:
      - `premium_gift_monthly` - 1 month premium gift
      - `premium_gift_yearly` - 1 year premium gift
      - `premium_gift_3months` - 3 months premium gift (optional)
    - Products should be consumable/non-consumable based on platform requirements
    - Pricing should match or slightly discount regular subscription prices
  
  - [ ] **Invitation Flow Integration**
    - Add "Gift Premium Subscription" option to invitation screens:
      - `FamilyInvitationScreen` - When inviting to family
      - `InviteMembersDialog` - When inviting to hub
    - Show gift subscription options before sending invitation
    - Allow invitor to select gift duration (1 month, 3 months, 1 year)
    - Display gift pricing and benefits clearly
  
  - [ ] **Gift Purchase Flow**
    - User selects gift subscription option during invitation
    - Initiate IAP purchase flow for gift product
    - Store gift purchase details in Firestore:
      - `gift_subscriptions/{giftId}` collection
      - Fields: `purchaserId`, `recipientEmail`, `recipientUserId` (null until redeemed), `subscriptionTier`, `duration`, `purchaseDate`, `expiresAt`, `status` ('pending' | 'redeemed' | 'expired'), `purchaseToken`
    - Link gift to invitation code/email
  
  - [ ] **Gift Redemption**
    - When invitee accepts invitation and creates account:
      - Check if invitation has associated gift subscription
      - If gift exists and status is 'pending':
        - Automatically apply premium subscription to new user
        - Update gift status to 'redeemed'
        - Set subscription expiration based on gift duration
        - Send notification to both invitor and invitee
    - Handle case where invitee already has account (apply gift on acceptance)
    - Handle case where gift expires before redemption (show expired message)
  
  - [ ] **Gift Management UI**
    - Add "Gift Subscriptions" section to subscription screen
    - Show pending gifts (not yet redeemed)
    - Show redeemed gifts (with recipient info)
    - Show expired gifts
    - Allow invitor to resend gift notification
    - Display gift status and expiration dates
  
  - [ ] **Notifications & Communication**
    - Send email/SMS to invitee when gift is purchased:
      - "You've been gifted a Premium subscription!"
      - Include invitation link and gift details
      - Explain benefits of premium subscription
    - Send confirmation to invitor when gift is purchased
    - Send notification to invitor when gift is redeemed
    - Send reminder if gift is about to expire (7 days before)
  
  - [ ] **Technical Requirements**
    - Extend `SubscriptionService` with gift methods:
      - `Future<String> purchaseGiftSubscription(String recipientEmail, SubscriptionDuration duration)`
      - `Future<void> redeemGiftSubscription(String giftId, String userId)`
      - `Future<List<GiftSubscription>> getGiftSubscriptions({String? recipientEmail})`
      - `Future<GiftSubscription?> getGiftByInvitationCode(String invitationCode)`
    - Create `GiftSubscription` model:
      - `id`, `purchaserId`, `recipientEmail`, `recipientUserId`, `subscriptionTier`, `duration`, `purchaseDate`, `expiresAt`, `status`, `purchaseToken`, `invitationCode`
    - Update invitation models to include optional `giftSubscriptionId`
    - Add gift subscription collection to Firestore security rules
    - Handle IAP purchase verification for gifts (same as regular subscriptions)
  
  - [ ] **User Experience**
    - Clear value proposition: "Give the gift of premium features"
    - Show gift options prominently in invitation flow
    - Make it easy to add gift during invitation (one-tap option)
    - Show gift status in invitation confirmation
    - Celebrate gift redemption with both parties
  
  - [ ] **Monetization Strategy**
    - Gift subscriptions priced same as regular subscriptions (or slight discount for yearly)
    - Consider "gift bundles" (e.g., buy 3 months, get 1 month free)
    - Track gift purchase conversion rate
    - Track gift redemption rate
    - Monitor average gift duration purchased
  
  **Success Metrics:**
  - 15%+ of invitations include gift subscriptions
  - 80%+ gift redemption rate (gifts are actually used)
  - Average gift duration: 6+ months
  - Gift subscriptions drive 20%+ of new premium subscriptions
  - User satisfaction: 4.5+ stars for gift feature
  
  **Estimated Timeline:**
  - Q2 2025: IAP products and purchase flow
  - Q2 2025: Invitation integration and redemption
  - Q3 2025: Gift management UI and notifications
  
  **Dependencies:**
  - Requires IAP infrastructure to be complete
  - Requires invitation system to support gift linking
  - Requires subscription service to support gift redemption
  - Backend validation recommended for gift purchases

**Deliverables:**
- Widget framework MVP
- IAP integration complete
- Hub type system architecture
- Multi-hub data model

**Success Metrics:**
- Widget framework supports at least 3 widget types
- IAP system processes purchases successfully
- Hub type system allows seamless switching
- Data isolation verified across hubs

---

### Phase 2: Extended Family Hubs (Q2 2025)
**Status:** 🚧 Planned

#### Overview
Enable families to connect with extended family members (grandparents, aunts, uncles, cousins) in dedicated hubs with appropriate privacy controls and communication tools.

#### Key Features

**2.1 Hub-Specific Features**
- [ ] **Extended Family Member Management**
  - Invite extended family members (non-core family)
  - Role-based permissions (view-only, limited edit, full access)
  - Family tree visualization
  - Relationship mapping (grandparent, aunt, cousin, etc.)

- [ ] **Privacy Controls**
  - Granular sharing controls per extended family member
  - Separate privacy settings for extended vs. core family
  - Opt-in sharing model (default: minimal sharing)
  - Activity visibility controls

- [ ] **Communication Tools**
  - Extended family group chat
  - Event invitations for extended family gatherings
  - Photo sharing albums (opt-in)
  - Birthday reminders for extended family

- [ ] **Event Coordination**
  - Extended family event calendar
  - RSVP tracking for large gatherings
  - Recurring family reunion events
  - Event-specific chat threads

**2.2 Widget Implementation**
- [ ] **Extended Family Hub Widget**
  - Quick access to extended family hub
  - Display upcoming extended family events
  - Show unread messages count
  - One-tap navigation to hub

- [ ] **Widget Customization**
  - Choose which extended family hub (if multiple)
  - Widget size options (1x1, 2x1, 2x2)
  - Display preferences (events, messages, photos)

**2.3 Technical Requirements**
- [ ] Extend hub model with `hubType: 'extended_family'`
- [ ] Create extended family invitation flow
- [ ] Implement relationship tagging system
- [ ] Build family tree visualization component
- [ ] Design privacy control UI for extended family

**2.4 Monetization**
- [ ] **Pricing Strategy**
  - One-time purchase: $X.XX per extended family hub
  - OR subscription: $X.XX/month for unlimited extended family hubs
  - Free tier: 1 extended family hub (limited to 10 members)

- [ ] **IAP Integration**
  - Purchase flow for extended family hub
  - Subscription management
  - Feature unlock verification

**Success Metrics:**
- 80% of premium users create at least one extended family hub
- Average 15+ members per extended family hub
- Widget usage: 60%+ of users with extended family hub use widget
- IAP conversion rate: Target 15-20%

---

### Phase 3: Home Schooling Hubs (Q3 2025)
**Status:** 🚧 Planned

#### Overview
Specialized hub type designed to assist parents with homeschooling coordination, curriculum management, progress tracking, and parent-teacher collaboration.

#### Key Features

**3.1 Educational Management**
- [ ] **Curriculum Planning**
  - Subject-based organization
  - Lesson plan templates
  - Learning objectives tracking
  - Curriculum standards alignment (Common Core, state standards)

- [ ] **Student Progress Tracking**
  - Individual student profiles
  - Grade/assessment tracking
  - Progress reports generation
  - Learning milestone achievements

- [ ] **Assignment Management**
  - Create assignments per subject
  - Due date tracking
  - Submission tracking
  - Grading/feedback system

- [ ] **Resource Library**
  - Educational resource sharing
  - Link to online learning materials
  - Document storage for worksheets
  - Video lesson links

**3.2 Parent Collaboration**
- [ ] **Co-Teaching Support**
  - Multiple parent/teacher roles
  - Shared lesson planning
  - Teaching schedule coordination
  - Resource sharing between parents

- [ ] **Communication Tools**
  - Parent group chat
  - Student-specific communication threads
  - Announcement system
  - Progress update notifications

- [ ] **Calendar Integration**
  - School year calendar
  - Holiday/vacation planning
  - Field trip coordination
  - Testing schedule

**3.3 Student Engagement**
- [ ] **Achievement System**
  - Educational achievements/badges
  - Progress celebrations
  - Streak tracking (daily lessons)
  - Subject mastery indicators

- [ ] **Gamification**
  - Learning game integration
  - Educational challenges
  - Leaderboards (optional, privacy-controlled)
  - Reward system for completed work

**3.4 Widget Implementation**
- [ ] **Home Schooling Hub Widget**
  - Quick access to hub
  - Display today's lessons/assignments
  - Show pending assignments count
  - Upcoming test/assessment reminders
  - One-tap navigation

- [ ] **Widget Variants**
  - Student view widget (for child's device)
  - Parent view widget (for parent's device)
  - Different information displayed per role

**3.5 Technical Requirements**
- [ ] Create `hubType: 'homeschooling'` model
- [ ] Build student profile system
- [ ] Implement assignment tracking service
- [ ] Create curriculum/lesson plan data models
- [ ] Design progress reporting system
- [ ] Build educational resource management

**3.6 Monetization**
- [ ] **Pricing Strategy**
  - Subscription model: $X.XX/month per homeschooling hub
  - Family plan: $X.XX/month for up to 5 students
  - Free trial: 30 days full access

- [ ] **Value Proposition**
  - Time savings on organization
  - Professional progress tracking
  - Collaboration tools
  - Resource library access

**Success Metrics:**
- 70% of homeschooling hub users active weekly
- Average 3+ students per homeschooling hub
- 80%+ assignment completion rate tracked
- Widget usage: 70%+ of users use widget daily
- Subscription retention: 85%+ after 3 months

---

### Phase 4: Co-Parenting Hubs (Q4 2025)
**Status:** 🚧 Planned

#### Overview
Specialized hub designed to assist separated/divorced parents in coordinating child care, managing schedules, tracking expenses, and maintaining clear communication—all while minimizing conflict.

#### Key Features

**4.1 Co-Parenting Coordination**
- [ ] **Custody Schedule Management**
  - Visual custody calendar
  - Recurring schedule templates (week on/week off, etc.)
  - Holiday schedule planning
  - Schedule change requests/approvals

- [ ] **Expense Tracking & Splitting**
  - Shared expense logging
  - Category-based expenses (medical, education, activities, etc.)
  - Receipt photo upload
  - Automatic split calculations (50/50, percentage-based)
  - Reimbursement requests
  - Payment tracking

- [ ] **Communication Tools**
  - Structured communication (message templates)
  - Communication log (for legal purposes if needed)
  - Important announcements
  - Emergency contact system
  - Neutral tone suggestions (optional AI assistance)

- [ ] **Child Information Sharing**
  - Shared child profiles
  - Medical information (allergies, medications)
  - School information
  - Activity schedules
  - Important documents storage

**4.2 Conflict Minimization Features**
- [ ] **Neutral Communication**
  - Pre-written message templates
  - Tone checking (optional)
  - Fact-based communication focus
  - Dispute resolution workflow

- [ ] **Documentation & Records**
  - Communication history (read-only, tamper-proof)
  - Expense history
  - Schedule change history
  - Important event documentation

- [ ] **Mediation Support**
  - Export communication logs (PDF)
  - Expense reports export
  - Schedule change history export
  - Data export for legal purposes (if needed)

**4.3 Widget Implementation**
- [ ] **Co-Parenting Hub Widget**
  - Quick access to hub
  - Display current custody schedule (whose day/week)
  - Show pending expense approvals
  - Unread messages count
  - Upcoming schedule changes
  - One-tap navigation

- [ ] **Widget Privacy**
  - Optional: Hide sensitive information on lock screen
  - Widget content customization
  - Privacy controls for widget display

**4.4 Technical Requirements**
- [ ] Create `hubType: 'coparenting'` model
- [ ] Build custody schedule system
- [ ] Implement expense tracking with split calculations
- [ ] Create communication logging system
- [ ] Design child profile sharing system
- [ ] Build export/reporting functionality
- [ ] Implement tamper-proof logging

**4.5 Monetization**
- [ ] **Pricing Strategy**
  - Subscription: $X.XX/month per co-parenting hub
  - OR one-time: $X.XX per hub (lifetime access)
  - Premium tier: Additional features (export, advanced scheduling)

- [ ] **Value Proposition**
  - Reduce conflict through structured communication
  - Save time on expense tracking
  - Legal documentation support
  - Peace of mind through organization

**Success Metrics:**
- 75% of co-parenting hub users active monthly
- Average 2 parents per hub (as expected)
- 90%+ expense tracking accuracy
- Widget usage: 65%+ daily usage
- User satisfaction: 4.5+ stars
- Conflict reduction: Measured via user surveys

---

## 🔧 Technical Architecture Considerations

### Widget System Architecture

#### Android Widgets
- [ ] **App Widgets (Android)**
  - Use Android App Widget framework
  - Implement `AppWidgetProvider`
  - Create widget configuration activity
  - Design widget layouts (multiple sizes)
  - Implement widget update service
  - Handle widget tap actions (deep links)

#### iOS Widgets
- [ ] **WidgetKit (iOS)**
  - Use WidgetKit framework
  - Create widget extensions
  - Implement timeline provider
  - Design widget UI (SwiftUI)
  - Handle widget interactions
  - Support multiple widget families (small, medium, large)

#### Cross-Platform Considerations
- [ ] **Unified Widget Configuration**
  - Shared widget configuration service
  - Consistent widget data model
  - Platform-specific implementations
  - Widget update synchronization

- [ ] **Deep Linking**
  - Implement deep link routing
  - Hub-specific deep links
  - Widget → specific screen navigation
  - Handle deep links when app closed

### Hub Type System

#### Data Model Extensions
```dart
// Conceptual model
class Hub {
  final String id;
  final String name;
  final HubType type; // 'family', 'extended_family', 'homeschooling', 'coparenting'
  final Map<String, dynamic> typeSpecificData;
  final List<String> memberIds;
  final HubPermissions permissions;
  // ... existing fields
}

enum HubType {
  family,           // Core family (free)
  extendedFamily,    // Premium
  homeschooling,     // Premium
  coparenting,       // Premium
}
```

#### Feature Flag System
- [ ] Implement feature flags per hub type
- [ ] Enable/disable features based on hub type
- [ ] A/B testing capabilities
- [ ] Gradual feature rollout

### IAP Integration

#### Purchase Flow
1. User navigates to hub creation
2. Selects premium hub type
3. Sees pricing information
4. Initiates purchase
5. Platform processes payment (Google Play / App Store)
6. Receipt validation
7. Feature unlock
8. Hub creation enabled

#### Subscription Management
- [ ] Subscription status tracking
- [ ] Renewal handling
- [ ] Cancellation flow
- [ ] Grace period handling
- [ ] Subscription restoration

---

## 📱 Widget Design Specifications

### Widget Types by Hub

#### 1. Extended Family Hub Widget
**Sizes:** 2x1, 2x2, 4x2

**Content:**
- Hub name
- Upcoming extended family events (next 2-3)
- Unread message count
- Recent photo thumbnail (optional)
- Quick action: "View Hub"

**Customization:**
- Choose which extended family hub
- Display preferences (events, messages, photos)
- Update frequency

#### 2. Home Schooling Hub Widget
**Sizes:** 2x2, 4x2, 4x4

**Content (Parent View):**
- Hub name
- Today's lessons/assignments
- Pending assignments count
- Upcoming tests/assessments
- Student progress summary
- Quick action: "View Hub"

**Content (Student View):**
- Today's assignments
- Completed vs. pending
- Upcoming deadlines
- Achievement badges
- Quick action: "View Assignments"

**Customization:**
- Role-based content (parent vs. student)
- Subject filters
- Display preferences

#### 3. Co-Parenting Hub Widget
**Sizes:** 2x1, 2x2, 4x2

**Content:**
- Hub name
- Current custody status (e.g., "Mom's Week")
- Pending expense approvals
- Unread messages
- Upcoming schedule changes
- Quick action: "View Hub"

**Customization:**
- Privacy level (hide sensitive info)
- Display preferences
- Update frequency

### Widget Implementation Priority

1. **Phase 1**: Core widget framework
2. **Phase 2**: Extended Family Hub widget (MVP)
3. **Phase 3**: Home Schooling Hub widget
4. **Phase 4**: Co-Parenting Hub widget
5. **Future**: Additional widget types, customization options

---

## 💰 Monetization Strategy

### Pricing Models

#### Option 1: Per-Hub Pricing
- **Extended Family Hub**: $4.99 one-time OR $2.99/month
- **Home Schooling Hub**: $9.99/month (up to 5 students)
- **Co-Parenting Hub**: $7.99/month OR $49.99 one-time

#### Option 2: Subscription Tiers
- **Family Plus**: $9.99/month
  - Unlimited extended family hubs
  - 1 homeschooling hub
  - 1 co-parenting hub
  
- **Family Premium**: $19.99/month
  - Everything in Plus
  - Unlimited all hub types
  - Priority support
  - Advanced analytics

#### Option 3: Hybrid Model (Recommended)
- **Individual Hub Purchases**: One-time or monthly
- **Family Bundle**: Discounted subscription for multiple hub types
- **Free Tier**: 1 extended family hub (limited features)

### IAP Implementation Checklist
- [ ] Google Play Billing integration
- [ ] Apple App Store IAP integration
- [ ] Receipt validation service
- [ ] Subscription management UI
- [ ] Purchase restoration
- [ ] Free trial support
- [ ] Promotional pricing support

---

## 🎯 Success Metrics & KPIs

### User Engagement
- **Daily Active Users (DAU)** per hub type
- **Widget Usage Rate**: % of premium users using widgets
- **Hub Creation Rate**: % of users creating premium hubs
- **Hub Activity Rate**: % of hubs with weekly activity

### Revenue Metrics
- **IAP Conversion Rate**: % of users who purchase premium hubs
- **Average Revenue Per User (ARPU)**
- **Monthly Recurring Revenue (MRR)** for subscriptions
- **Churn Rate**: % of subscribers canceling

### Product Metrics
- **Feature Adoption**: % of users using hub-specific features
- **Widget Engagement**: Taps per widget per day
- **User Satisfaction**: App store ratings, in-app surveys
- **Support Tickets**: Volume and resolution time

### Technical Metrics
- **Widget Update Performance**: Time to update widget data
- **App Launch Time**: From widget tap to hub screen
- **Data Sync Performance**: Real-time update latency
- **Crash Rate**: Per hub type

---

## 🚧 Risks & Mitigation

### Technical Risks
1. **Widget Performance**
   - *Risk*: Widgets slow to update or drain battery
   - *Mitigation*: Optimize update frequency, use efficient data fetching, implement caching

2. **Platform Limitations**
   - *Risk*: Android/iOS widget capabilities differ
   - *Mitigation*: Design for lowest common denominator, platform-specific optimizations

3. **Data Isolation**
   - *Risk*: Data leakage between hubs
   - *Mitigation*: Strict hub-scoped queries, comprehensive testing

### Business Risks
1. **Low Adoption**
   - *Risk*: Users don't see value in premium hubs
   - *Mitigation*: Free trials, clear value proposition, user education

2. **Pricing Sensitivity**
   - *Risk*: Pricing too high/low
   - *Mitigation*: A/B test pricing, market research, flexible pricing tiers

3. **Competition**
   - *Risk*: Competitors launch similar features
   - *Mitigation*: Focus on unique value, rapid iteration, user feedback

### Legal/Compliance Risks
1. **Co-Parenting Data Privacy**
   - *Risk*: Sensitive data handling requirements
   - *Mitigation*: Strong encryption, privacy controls, legal review

2. **Educational Data (COPPA/FERPA)**
   - *Risk*: Compliance with educational data regulations
   - *Mitigation*: Legal review, privacy controls, data minimization

---

## 📅 Timeline & Milestones

### Q1 2025: Foundation
- **Month 1**: Widget framework architecture
- **Month 2**: IAP integration
- **Month 3**: Hub type system & Extended Family Hub MVP

### Q2 2025: Extended Family Hubs
- **Month 4**: Extended Family Hub features
- **Month 5**: Extended Family Hub widget
- **Month 6**: Testing, launch, iteration

### Q3 2025: Home Schooling Hubs
- **Month 7**: Home Schooling Hub features
- **Month 8**: Home Schooling Hub widget
- **Month 9**: Testing, launch, iteration

### Q4 2025: Co-Parenting Hubs
- **Month 10**: Co-Parenting Hub features
- **Month 11**: Co-Parenting Hub widget
- **Month 12**: Testing, launch, iteration

---

## 🔄 Living Document Updates

This roadmap is a **living document** and should be updated:
- **Monthly**: Review progress, update status, adjust timelines
- **Quarterly**: Major review, reprioritization, new feature consideration
- **After Major Releases**: Update based on user feedback, metrics, market changes
- **When Market Conditions Change**: Pivot strategy if needed

### Update Log
- **2024-12**: Initial roadmap created
- **2025-12-10**: Added detailed refactor plans for Data Isolation & Environment Separation (firestorePrefix implementation) and Freemium Foundation (subscription management and premium feature gating)

---

## 📞 Stakeholder Communication

### Regular Updates
- **Weekly**: Development team standups
- **Monthly**: Executive summary of progress
- **Quarterly**: Full roadmap review with stakeholders

### Decision Points
- Pricing decisions: Marketing + Product + Finance
- Feature prioritization: Product + Engineering + User Research
- Technical architecture: Engineering + Product
- Go-to-market: Marketing + Product + Sales (if applicable)

---

## 🎓 Lessons & Best Practices

### Widget Development
- Start with simple widgets, iterate based on usage
- Monitor battery impact closely
- Test on multiple device types and OS versions
- Consider widget update frequency vs. battery trade-off

### Premium Feature Rollout
- Launch with free trial to drive adoption
- Gather user feedback early and often
- Iterate based on usage patterns
- Don't over-engineer initial versions

### Hub Type Design
- Maintain core infrastructure consistency
- Customize features per hub type thoughtfully
- Avoid feature bloat—focus on hub-specific value
- Ensure seamless switching between hub types

---

### Phase 5: Social Feed Redesign (Q1-Q2 2026)
**Status:** 🚧 Planned

#### Overview
Transform the chat system from SMS-style bubbles to a modern social feed experience similar to X (formerly Twitter), with support for threaded comments, rich media previews, polls, and cross-hub engagement.

#### Key Features

**5.1 Feed-Style UI**
- [ ] **Timeline Layout**
  - Replace bubble-based chat with vertical feed layout
  - Post cards with author info, timestamp, engagement metrics
  - Infinite scroll with pre-loading of content
  - Pull-to-refresh functionality
  - Smooth scrolling performance optimization

- [ ] **Rich Media Previews**
  - Automatic URL preview cards (like X link cards)
  - Image/video previews in feed
  - Expandable media galleries
  - Embedded content support (YouTube, etc.)

- [ ] **Post Interactions**
  - Like/Unlike posts (heart icon)
  - Comment threading (nested replies)
  - Share/Repost functionality
  - Bookmark/Save posts
  - Engagement counters (likes, comments, shares)

**5.2 Polling System**
- [ ] **Poll Creation**
  - Create polls with 2-4 options
  - Set poll duration (1 hour to 7 days)
  - Add poll description/context
  - Attach poll to a post or create standalone poll

- [ ] **Poll Participation**
  - Vote on polls (single choice)
  - View real-time results (percentage bars)
  - See who voted (optional, privacy-controlled)
  - Poll expiration handling

- [ ] **Cross-Hub Polling**
  - Option to open polls to other hubs in "My Hubs" list
  - Multi-hub poll aggregation
  - Hub-specific poll visibility controls
  - Cross-hub engagement metrics

**5.3 Comment Threading**
- [ ] **Nested Comments**
  - Reply to posts (top-level comments)
  - Reply to comments (nested replies, 2-3 levels deep)
  - Thread collapse/expand
  - Comment count indicators

- [ ] **Comment Interactions**
  - Like comments
  - Edit own comments
  - Delete own comments (admins can delete any)
  - Report inappropriate comments

**5.4 Technical Requirements**
- [ ] Redesign `ChatMessage` model to support:
  - Post type (text, poll, media)
  - Poll data structure (options, votes, expiration)
  - Comment threading (parentId, threadId)
  - Engagement metrics (likes, comments, shares)
  - Cross-hub visibility flags

- [ ] Create `FeedService` to replace/enhance `ChatService`:
  - Feed querying with pagination
  - Poll creation and voting
  - Comment threading logic
  - Engagement tracking
  - Cross-hub feed aggregation

- [ ] Build new `FeedScreen` component:
  - Feed list view with post cards
  - Post detail view with full thread
  - Poll voting UI
  - Comment composer
  - Media preview components

- [ ] Implement URL preview service:
  - Fetch metadata from URLs (Open Graph, Twitter Cards)
  - Generate preview cards
  - Cache previews for performance
  - Handle preview errors gracefully

**5.5 Cross-Hub Integration**
- [ ] **Hub Selection for Polls**
  - UI to select which hubs can participate
  - Hub list from "My Hubs" screen
  - Default to current hub, allow expansion
  - Visual indicators for multi-hub polls

- [ ] **Multi-Hub Feed View**
  - Option to view feed from all hubs
  - Filter by specific hub
  - Hub badges on posts
  - Cross-hub engagement visibility

**5.6 Migration Strategy**
- [ ] **Backward Compatibility**
  - Migrate existing chat messages to feed format
  - Preserve message history
  - Convert old bubbles to feed posts
  - Maintain existing chat functionality during transition

- [ ] **Feature Flags**
  - Enable/disable feed UI per hub
  - Gradual rollout to test groups
  - A/B testing between old and new UI
  - Rollback capability

**Success Metrics:**
- 80%+ user engagement with new feed UI
- 60%+ poll participation rate
- 50%+ cross-hub poll engagement
- Average 3+ comments per post
- 90%+ URL preview success rate
- User satisfaction: 4.5+ stars

**Estimated Timeline:**
- **Q1 2026**: Feed UI redesign, basic polling
- **Q2 2026**: Comment threading, cross-hub polls, URL previews

---

**Document Owner**: Product & Engineering Teams  
**Last Reviewed**: December 10, 2025  
**Next Review**: January 2026  
**Status**: Active Planning

---

*This roadmap is subject to change based on user feedback, market conditions, technical constraints, and business priorities.*

