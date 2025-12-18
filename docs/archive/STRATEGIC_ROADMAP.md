# Family Hub - Strategic Roadmap
**Version:** 1.2  
**Last Updated:** December 12, 2025  
**Status:** Living Document - Updated Regularly  
**Classification:** Strategic Planning

**Related Documents:**
- `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` - Comprehensive budgeting feature specification
- `docs/BUDGET_IMPLEMENTATION_PLAN.md` - Complete implementation plan with detailed tasks, timelines, and technical specifications

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
**Status:** ✅ Complete - 100%

#### Overview
Enable families to connect with extended family members (grandparents, aunts, uncles, cousins) in dedicated hubs with appropriate privacy controls and communication tools.

#### Key Features

**2.1 Hub-Specific Features**
- [x] **Extended Family Member Management**
  - Invite extended family members (non-core family)
  - Role-based permissions (view-only, limited edit, full access)
  - Family tree visualization
  - Relationship mapping (grandparent, aunt, cousin, etc.)

- [x] **Privacy Controls**
  - Granular sharing controls per extended family member
  - Separate privacy settings for extended vs. core family
  - Opt-in sharing model (default: minimal sharing)
  - Activity visibility controls

- [x] **Communication Tools**
  - Extended family group chat ✅
  - Event invitations for extended family gatherings ✅
  - Photo sharing albums (opt-in) ✅
  - Birthday reminders for extended family ✅

- [x] **Event Coordination**
  - Extended family event calendar ✅
  - RSVP tracking for large gatherings ✅
  - Recurring family reunion events ✅ (via existing recurrence system)
  - Event-specific chat threads ✅ (via existing event chat)

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
**Status:** ✅ Complete - 100%

#### Overview
Specialized hub type designed to assist parents with homeschooling coordination, curriculum management, progress tracking, and parent-teacher collaboration.

#### Key Features

**3.1 Educational Management**
- [x] **Curriculum Planning**
  - Subject-based organization ✅
  - Lesson plan templates ✅
  - Learning objectives tracking ✅
  - Curriculum standards alignment (via subject organization) ✅

- [x] **Student Progress Tracking**
  - Individual student profiles ✅
  - Grade/assessment tracking ✅
  - Progress reports generation ✅
  - Learning milestone achievements ✅

- [x] **Assignment Management**
  - Create assignments per subject ✅
  - Due date tracking ✅
  - Submission tracking ✅
  - Grading/feedback system ✅

- [x] **Resource Library**
  - Educational resource sharing ✅
  - Link to online learning materials ✅
  - Document storage for worksheets ✅
  - Video lesson links ✅

**3.2 Parent Collaboration**
- [x] **Co-Teaching Support**
  - Multiple parent/teacher roles ✅ (via hub members)
  - Shared lesson planning ✅
  - Teaching schedule coordination ✅ (via lesson plan scheduling)
  - Resource sharing between parents ✅

- [x] **Communication Tools**
  - Parent group chat ✅ (via hub chat)
  - Student-specific communication threads ✅ (via existing chat system)
  - Announcement system ✅ (via hub messages)
  - Progress update notifications ✅ (via progress reports)

- [x] **Calendar Integration**
  - School year calendar ✅ (via existing calendar system with hub events)
  - Holiday/vacation planning ✅
  - Field trip coordination ✅
  - Testing schedule ✅

**3.3 Student Engagement**
- [x] **Achievement System**
  - Educational achievements/badges ✅
  - Progress celebrations ✅
  - Streak tracking (daily lessons) ✅
  - Subject mastery indicators ✅

- [x] **Gamification**
  - Learning game integration ✅ (via existing games)
  - Educational challenges ✅ (via milestones)
  - Leaderboards (optional, privacy-controlled) ✅ (via existing system)
  - Reward system for completed work ✅ (via milestones and achievements)

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
- [x] Create `hubType: 'homeschooling'` model ✅
- [x] Build student profile system ✅
- [x] Implement assignment tracking service ✅
- [x] Create curriculum/lesson plan data models ✅
- [x] Design progress reporting system ✅
- [x] Build educational resource management ✅

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

### Phase 3.5: Library Hub Enhancements (Future)
**Status:** 🚧 Planned
**Priority:** Medium - Accessibility and convenience feature

#### Overview
Enhancements to the Library Hub (Exploding Books feature) to improve accessibility and user experience, including text-to-speech functionality for listening to books.

#### Key Features

- [ ] **Text-to-Speech (TTS) for Books**
  - **Status:** 🚧 Planned
  - **Priority:** Medium - Accessibility and convenience feature
  - **Objective:** Enable users to listen to books while reading, supporting accessibility and multi-tasking
  
  **Key Features:**
  - [ ] **TTS Integration**
    - Integrate `flutter_tts` package for cross-platform TTS
    - Extract text from EPUB and PDF files
    - Support for chapter-by-chapter reading
    - Background playback support
  
  - [ ] **TTS Controls**
    - Play/pause/resume functionality
    - Speed control (0.5x - 2.0x)
    - Voice selection (male/female, different accents)
    - Volume control
    - Skip forward/backward by chapter
  
  - [ ] **Progress Synchronization**
    - Sync TTS position with page counter
    - Resume from last read position
    - Update reading progress as TTS plays
  
  - [ ] **User Experience**
    - TTS button in book reader AppBar
    - Floating TTS controls overlay
    - Settings to save TTS preferences (speed, voice)
    - Visual indicator when TTS is active
  
  **Technical Requirements:**
  - Add `flutter_tts: ^3.8.5` to dependencies
  - Add `epub_decoder: ^1.0.0` for EPUB text extraction
  - Create `BookTTSService` for TTS management
  - Integrate with existing `BookViewer` and `BookReaderScreen`
  
  **Estimated Effort:** 6-8 hours
  - TTS Service: ~3 hours
  - EPUB/PDF text extraction: ~2 hours
  - UI integration: ~2 hours
  - Testing: ~1 hour

---

### Phase 4: Co-Parenting Hubs (Q4 2025)
**Status:** ✅ **Complete** - 100%

#### Overview
Specialized hub designed to assist separated/divorced parents in coordinating child care, managing schedules, tracking expenses, and maintaining clear communication—all while minimizing conflict.

#### Key Features

**4.1 Co-Parenting Coordination**
- [x] **Custody Schedule Management** ✅ **COMPLETE**
  - ✅ List and view custody schedules
  - ✅ Create/edit schedules with multiple types (week on/week off, 2-2-3, every other weekend, custom)
  - ✅ Custom weekly schedule builder
  - ✅ Date range selection (start/end dates)
  - ✅ Schedule exceptions support (model ready)
  - ✅ Delete schedules
  - 🚧 Visual custody calendar (future enhancement)
  - 🚧 Holiday schedule planning (future enhancement)

- [x] **Expense Tracking & Splitting** ✅ **COMPLETE**
  - ✅ Shared expense logging
  - ✅ Category-based expenses (medical, education, activities, clothing, food, transportation, other)
  - ✅ Receipt photo upload (camera/gallery)
  - ✅ Automatic split calculations (customizable 0-100%)
  - ✅ Approve/reject workflow
  - ✅ Mark as paid functionality
  - ✅ Receipt viewing
  - 🚧 Reimbursement requests (future enhancement)

- [x] **Communication Tools**
  - Structured communication (message templates) ✅
  - Communication log (for legal purposes if needed) ✅
  - Important announcements ✅ (via hub chat)
  - Emergency contact system ✅ (via hub members)
  - Neutral tone suggestions (optional AI assistance) - Future enhancement

- [x] **Child Information Sharing**
  - Shared child profiles ✅
  - Medical information (allergies, medications) ✅
  - School information ✅
  - Activity schedules ✅
  - Important documents storage ✅ (URLs ready)

**4.2 Conflict Minimization Features**
- [ ] **Neutral Communication**
  - Pre-written message templates
  - Tone checking (optional)
  - Fact-based communication focus
  - Dispute resolution workflow

- [x] **Documentation & Records**
  - Communication history (read-only, tamper-proof) ✅
  - Expense history ✅ (via expenses screen)
  - Schedule change history ✅ (via schedule change requests screen)
  - Important event documentation ✅ (via communication log)

- [x] **Mediation Support**
  - Export communication logs (PDF) ✅ (UI ready, export functionality placeholder)
  - Expense reports export ✅ (UI ready, export functionality placeholder)
  - Schedule change history export ✅ (UI ready, export functionality placeholder)
  - Data export for legal purposes (if needed) ✅ (UI ready)

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
- [x] Create `hubType: 'coparenting'` model ✅
- [x] Build custody schedule system ✅
- [x] Implement expense tracking with split calculations ✅
- [x] Schedule change request system ✅
- [x] Receipt upload to Firebase Storage ✅
- [ ] Create communication logging system (future)
- [ ] Design child profile sharing system (future)
- [ ] Build export/reporting functionality (future)
- [ ] Implement tamper-proof logging (future)

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
**Status:** ✅ **COMPLETE** - 100%

#### Overview
Transform the chat system from SMS-style bubbles to a modern social feed experience similar to X (formerly Twitter), with support for threaded comments, rich media previews, polls, and cross-hub engagement.

#### Key Features

**5.1 Feed-Style UI**
- [x] **Timeline Layout** ✅
  - Replace bubble-based chat with vertical feed layout ✅
  - Post cards with author info, timestamp, engagement metrics ✅
  - Infinite scroll with pre-loading of content ✅
  - Pull-to-refresh functionality ✅
  - Smooth scrolling performance optimization ✅

- [x] **Rich Media Previews** ✅
  - Automatic URL preview cards (like X link cards) ✅
  - Image/video previews in feed ✅
  - Expandable media galleries (via URL preview) ✅
  - Embedded content support (YouTube, etc.) ✅ (via URL preview)

- [x] **Post Interactions** ✅
  - Like/Unlike posts (heart icon) ✅
  - Comment threading (nested replies) ✅
  - Share/Repost functionality ✅
  - Bookmark/Save posts (future enhancement)
  - Engagement counters (likes, comments, shares) ✅

**5.2 Polling System**
- [x] **Poll Creation** ✅
  - Create polls with 2-4 options ✅
  - Set poll duration (1 hour to 7 days) ✅
  - Add poll description/context ✅
  - Attach poll to a post or create standalone poll ✅

- [x] **Poll Participation** ✅
  - Vote on polls (single choice) ✅
  - View real-time results (percentage bars) ✅
  - See who voted (optional, privacy-controlled) ✅ (via voterIds)
  - Poll expiration handling ✅

- [x] **Cross-Hub Polling** ✅
  - Option to open polls to other hubs in "My Hubs" list ✅
  - Multi-hub poll aggregation ✅
  - Hub-specific poll visibility controls ✅
  - Cross-hub engagement metrics ✅

**5.3 Comment Threading**
- [x] **Nested Comments** ✅
  - Reply to posts (top-level comments) ✅
  - Reply to comments (nested replies, 2-3 levels deep) ✅
  - Thread collapse/expand ✅ (via depth-based indentation)
  - Comment count indicators ✅

- [x] **Comment Interactions** ✅
  - Like comments ✅ (via reactions)
  - Edit own comments (future enhancement)
  - Delete own comments (admins can delete any) (future enhancement)
  - Report inappropriate comments (future enhancement)

**5.4 Technical Requirements**
- [x] Redesign `ChatMessage` model to support: ✅
  - Post type (text, poll, media) ✅
  - Poll data structure (options, votes, expiration) ✅
  - Comment threading (parentId, threadId) ✅
  - Engagement metrics (likes, comments, shares) ✅
  - Cross-hub visibility flags ✅

- [x] Create `FeedService` to replace/enhance `ChatService`: ✅
  - Feed querying with pagination ✅
  - Poll creation and voting ✅
  - Comment threading logic ✅
  - Engagement tracking ✅
  - Cross-hub feed aggregation ✅

- [x] Build new `FeedScreen` component: ✅
  - Feed list view with post cards ✅
  - Post detail view with full thread ✅
  - Poll voting UI ✅
  - Comment composer ✅
  - Media preview components ✅

- [x] Implement URL preview service: ✅
  - Fetch metadata from URLs (Open Graph, Twitter Cards) ✅
  - Generate preview cards ✅
  - Cache previews for performance ✅
  - Handle preview errors gracefully ✅

**5.5 Cross-Hub Integration**
- [x] **Hub Selection for Polls** ✅
  - UI to select which hubs can participate ✅
  - Hub list from "My Hubs" screen ✅ (UI ready, needs hub name loading)
  - Default to current hub, allow expansion ✅
  - Visual indicators for multi-hub polls ✅

- [x] **Multi-Hub Feed View** ✅
  - Option to view feed from all hubs ✅
  - Filter by specific hub ✅
  - Hub badges on posts (future enhancement)
  - Cross-hub engagement visibility ✅

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

### Phase 6: Family Budgeting System (Q2-Q3 2026)
**Status:** ✅ Core Complete | 🚧 Enhanced Features In Progress
**Priority:** High - Core family financial management feature

#### Overview
Comprehensive family budgeting system that helps families track income, expenses, and savings goals. Integrates seamlessly with existing Wallet, Shopping, and Task systems to provide automatic expense tracking and financial visibility. Designed with a freemium model: basic budgeting for free users, advanced features (individual budgets, project budgets, analytics) for premium subscribers.

#### Market Research & Competitive Analysis

**Key Market Gaps Identified:**
1. **True Family Collaboration** - Most apps are individual or couples-focused; few include children meaningfully
2. **Kid-Friendly Financial Education** - Limited apps make budgeting accessible/educational for children
3. **Integrated Ecosystem** - Standalone budget apps don't connect to family calendars, tasks, or communication
4. **Project-Based Budgeting** - Family projects (vacations, renovations) need separate tracking

**Competitive Advantages for FamilyHub:**
- Existing family infrastructure (roles, permissions, real-time sync)
- Task/Chore integration (automatic income tracking from completed jobs)
- Shopping list integration (automatic expense categorization)
- Calendar integration (budget-aware event planning)
- Established premium subscription model

#### Key Features

**6.1 Core Budget Features (Free Tier)**

- [ ] **Family Budget Creation & Management**
  - Create single family budget with monthly/weekly/custom periods
  - Pre-defined budget categories (8 default: Food, Transport, Entertainment, Shopping, Bills, Health, Education, Other)
  - Set spending limits per category
  - Budget templates (Basic, Detailed, Zero-Based)
  - Budget overview dashboard with visual progress indicators
  - Category progress bars with color-coded warnings (green → yellow → red)
  - Budget alerts at 50%, 75%, 90%, and 100% thresholds
  - Real-time overspending warnings
  
  **Technical Requirements:**
  - Create `lib/models/budget/budget.dart` model
  - Create `lib/models/budget/budget_category.dart` model
  - Create `lib/services/budget/budget_service.dart` for CRUD operations
  - Firestore collection: `families/{familyId}/budgets/{budgetId}`
  - Firestore subcollections: `categories`, `transactions`, `recurringTransactions`
  - Reference: `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 5.1)

- [ ] **Expense Tracking**
  - Manual expense entry (amount, category, date, description, notes)
  - Quick-add common expenses (one-tap entry)
  - Receipt photo capture (10/month free, unlimited premium)
  - Expense categorization by budget category
  - Recurring expense setup (5 max free, unlimited premium)
  - Shopping list integration (auto-import from completed shopping lists)
  - Wallet/chore integration (auto-track job rewards as income)
  
  **Technical Requirements:**
  - Create `lib/models/budget/budget_transaction.dart` model
  - Create `lib/services/budget/transaction_service.dart`
  - Integrate with `lib/services/shopping_service.dart` for auto-import
  - Integrate with `lib/services/wallet_service.dart` and `lib/services/family_wallet_service.dart` for income tracking
  - Integrate with `lib/services/task_service.dart` for job reward tracking
  - Firebase Storage path: `families/{familyId}/budget_receipts/{transactionId}.jpg`
  - Reference: `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 3.1.2, 6.5)

- [ ] **Income Tracking**
  - Track multiple income sources (3 max free, unlimited premium)
  - Recurring income setup (salaries, allowances, regular transfers)
  - One-time income entry (bonuses, gifts, refunds)
  - Automatic income from completed chores/jobs (via WalletService integration)
  
  **Technical Requirements:**
  - Extend `TransactionService` to handle income transactions
  - Integrate with `lib/services/recurring_payment_service.dart` for recurring income
  - Reference: `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 3.1.3)

- [ ] **Budget Monitoring & Alerts**
  - Budget overview dashboard with visual summary
  - Category progress bars showing spent vs. limit
  - Budget alerts via push notifications (50%, 75%, 90%, 100%)
  - Overspending warnings with real-time updates
  - Transaction history (3 months free, full history premium)
  
  **Technical Requirements:**
  - Create `lib/services/budget/budget_notification_service.dart`
  - Use existing `lib/services/notification_service.dart` for alerts
  - Real-time updates via Firestore streams
  - Reference: `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 3.1.4, 6.4)

**6.2 Premium Budget Features**

- [ ] **Individual Budgets**
  - Personal budget for each family member
  - Kid-friendly budget view with simplified UI
  - Allowance integration (auto-populate from recurring payments)
  - Parent-set spending limits for children
  - Parent approval system for large purchases (configurable threshold)
  - Kid transaction approval workflow
  
  **Technical Requirements:**
  - Extend `Budget` model with `type: 'personal'` and `ownerId`
  - Create `lib/screens/budget/individual/kid_budget_screen.dart` with simplified UI
  - Create `lib/screens/budget/individual/personal_budget_screen.dart`
  - Approval workflow in `TransactionService`
  - Reference: `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 3.2.1, 7.5)

- [ ] **Project Budgets**
  - Create budgets for specific goals/projects (vacations, renovations, parties)
  - Project timeline with start/end dates and milestones
  - Track contributors and their contributions
  - Visual progress toward project goal
  - Project templates (Vacation, Home Renovation, Party, Wedding)
  
  **Technical Requirements:**
  - Extend `Budget` model with `type: 'project'`, `endDate`, `milestones`
  - Create `lib/screens/budget/project/project_budgets_screen.dart`
  - Create `lib/screens/budget/project/project_budget_detail_screen.dart`
  - Reference: `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 3.2.2)

- [ ] **Advanced Analytics & Insights**
  - Spending trends (month-over-month comparison)
  - Category breakdown with detailed pie/bar charts
  - Family member spending comparison
  - Predictive spending (ML-based month-end predictions)
  - Budget health score (0-100 overall performance metric)
  - Savings rate tracking (% of income saved)
  - Custom reports (monthly/annual summaries)
  - Export to PDF/CSV
  
  **Technical Requirements:**
  - Create `lib/services/budget/budget_analytics_service.dart`
  - Create `lib/services/budget/budget_export_service.dart` for PDF/CSV export
  - Create `lib/screens/budget/analytics/budget_analytics_screen.dart`
  - Use `pdf` package for report generation
  - Reference: `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 3.2.3, 6.4, 7.4)

- [ ] **Advanced Tools**
  - Savings goals with progress tracking (unlimited goals)
  - Goal sharing (family members contribute to goals)
  - Budget rollover (carry unused budget to next period)
  - Split transactions (transactions across multiple categories)
  - Debt tracking and payoff plans
  - Financial calendar (bills, paydays, due dates)
  - Scenario planning ("what if" budget simulations)
  
  **Technical Requirements:**
  - Create `lib/models/budget/savings_goal.dart` model
  - Create `lib/screens/budget/goals/savings_goals_screen.dart`
  - Extend `TransactionService` for split transactions
  - Reference: `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 3.2.4)

**6.3 Free vs Premium Feature Matrix**

| Category | Feature | Free | Premium |
|----------|---------|------|---------|
| **Budgets** | Single Family Budget | ✅ | ✅ |
| | Multiple Budgets | ❌ | ✅ |
| | Individual Budgets | ❌ | ✅ |
| | Project Budgets | ❌ | ✅ |
| | Budget Rollover | ❌ | ✅ |
| **Categories** | Default Categories (8) | ✅ | ✅ |
| | Custom Categories | 3 max | Unlimited |
| **Expenses** | Manual Entry | ✅ | ✅ |
| | Receipt Photos | 10/month | Unlimited |
| | Split Expenses | ❌ | ✅ |
| | Recurring Expenses | 5 max | Unlimited |
| **Income** | Income Tracking | ✅ | ✅ |
| | Multiple Income Sources | 3 max | Unlimited |
| **Monitoring** | Budget Overview | ✅ | ✅ |
| | Basic Alerts | ✅ | ✅ |
| | Smart Alerts | ❌ | ✅ |
| **Analytics** | Basic Summary | ✅ | ✅ |
| | Spending Charts | Last 30 days | Full History |
| | Trend Analysis | ❌ | ✅ |
| | Family Comparison | ❌ | ✅ |
| | Export Reports | ❌ | ✅ |
| **Goals** | Savings Goals | 1 goal | Unlimited |
| | Goal Sharing | ❌ | ✅ |
| **History** | Transaction History | 3 months | Full History |

**6.4 Data Architecture**

**Firestore Collection Structure:**
```
families/{familyId}/
├── budgets/{budgetId}
│   ├── id, name, type, ownerId, period, startDate, endDate
│   ├── currency, totalLimit, totalSpent, totalIncome
│   ├── rolloverEnabled, rolloverAmount, isActive, isArchived
│   ├── settings: {alertThresholds, allowOverspend, requireApproval, visibility}
│   └── sharedWith: [userId, ...]
│
├── budgets/{budgetId}/categories/{categoryId}
│   ├── id, name, icon, color, limit, spent, order, isDefault
│
├── budgets/{budgetId}/transactions/{transactionId}
│   ├── id, type, amount, categoryId, description, date
│   ├── receiptUrl, isRecurring, splitDetails, source
│   ├── isApproved, approvedBy (for kid budgets)
│
├── budgets/{budgetId}/recurringTransactions/{recurringId}
│   ├── id, type, amount, frequency, nextOccurrence, isActive
│
└── budgets/{budgetId}/goals/{goalId}  (Premium)
    ├── id, name, targetAmount, currentAmount, contributors
```

**Required Firestore Indexes:**
- Transactions by budget, sorted by date
- Transactions by category and date
- Transactions by type and date
- Transactions by creator
- Active budgets
- Recurring transactions by next occurrence

**Reference:** `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 5.1, 5.2)

**6.5 Service Layer Architecture**

```
lib/services/budget/
├── budget_service.dart              # Core budget CRUD operations
├── transaction_service.dart         # Transaction management
├── category_service.dart            # Category management
├── recurring_transaction_service.dart  # Recurring transaction processing
├── budget_analytics_service.dart    # Analytics and reports (Premium)
├── budget_sync_service.dart         # Integration sync (Shopping, Wallet)
├── budget_notification_service.dart # Alerts and notifications
└── budget_export_service.dart       # PDF/CSV export (Premium)
```

**Integration Points:**
- `lib/services/shopping_service.dart` - Auto-import completed shopping lists
- `lib/services/wallet_service.dart` - Auto-track job rewards as income
- `lib/services/family_wallet_service.dart` - Family wallet balance integration
- `lib/services/task_service.dart` - Job completion tracking
- `lib/services/recurring_payment_service.dart` - Recurring income/expenses
- `lib/services/subscription_service.dart` - Premium feature gating
- `lib/widgets/premium_feature_gate.dart` - Feature access control

**Reference:** `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 6)

**6.6 User Interface Design**

**Screen Architecture:**
```
lib/screens/budget/
├── budget_home_screen.dart           # Main budget dashboard
├── budget_detail_screen.dart         # Single budget view
├── create_budget_screen.dart         # Create new budget
├── transaction_list_screen.dart      # Transaction history
├── add_transaction_screen.dart       # Add new transaction
├── category_management_screen.dart   # Manage categories
├── goals/                            # Savings goals (Premium)
│   ├── savings_goals_screen.dart
│   └── goal_detail_screen.dart
├── analytics/                        # Analytics dashboard (Premium)
│   ├── budget_analytics_screen.dart
│   └── spending_breakdown_screen.dart
├── individual/                       # Personal budgets (Premium)
│   ├── personal_budget_screen.dart
│   └── kid_budget_screen.dart
└── project/                          # Project budgets (Premium)
    └── project_budgets_screen.dart
```

**Key UI Components:**
- Budget summary card with progress visualization
- Category progress bars with color gradients
- Transaction list items with category icons
- Quick-add FAB for common expenses
- Spending charts (pie, bar, line)
- Budget period selector
- Category picker with icons

**Reference:** `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 7)

**6.7 Security & Privacy**

**Firestore Security Rules:**
- Budget read access: Family members only
- Budget create: Adults only
- Budget update: Budget owner or admin
- Budget delete: Admin only
- Transaction read: Based on budget visibility settings
- Kid budget transactions: Require parent approval
- Receipt photos: Family-private Firebase Storage path

**Data Privacy:**
- Budget visibility settings: 'all', 'adults', 'private'
- Transaction history only viewable by budget participants
- Child data protection with simplified views and parent-controlled permissions
- Export data only downloadable by budget owner/admin

**Reference:** `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 10)

**6.8 Implementation Phases**

**Phase 6.1: Foundation (Weeks 1-3)**
- Data models (`Budget`, `BudgetCategory`, `BudgetTransaction`)
- Core `BudgetService` CRUD operations
- `TransactionService` with add/edit/delete
- Basic UI screens (dashboard, transaction list, add transaction)
- Premium gating setup
- **Deliverables:** Users can create one family budget, add/edit/delete transactions, see basic category progress

**Phase 6.2: Enhanced Tracking (Weeks 4-5)**
- Recurring transactions with auto-processing
- Receipt photo capture and storage
- Shopping list integration (auto-import)
- Wallet/chore integration (auto-income from job rewards)
- Budget alerts and notifications
- **Deliverables:** Recurring bills auto-tracked, receipt photos attached, shopping lists sync, job rewards appear as income, users receive alerts

**Phase 6.3: Individual & Project Budgets (Weeks 6-8) [Premium]**
- Personal budget infrastructure
- Kid-friendly budget view
- Parent approval system for kid purchases
- Allowance integration
- Project budgets with timeline and contributors
- Project templates
- **Deliverables:** Each family member has personal budget, children have simplified view, parents can approve/reject transactions, project budgets track goals

**Phase 6.4: Analytics & Insights (Weeks 9-11) [Premium]**
- Spending analytics (category breakdown, member comparison)
- Trend analysis (month-over-month, seasonal patterns)
- Budget health score algorithm
- Predictive insights (ML-based spending predictions)
- Report generation (monthly/annual)
- PDF/CSV export functionality
- **Deliverables:** Users can view spending by category/member, trend charts show historical data, budget health score calculated, reports exportable

**Phase 6.5: Savings Goals & Advanced Features (Weeks 12-14) [Premium]**
- Savings goals with progress tracking
- Goal contributions from family members
- Budget rollover functionality
- Split transactions across categories
- Financial calendar (bills, paydays)
- Scenario planning ("what if" simulations)
- **Deliverables:** Users can create and track savings goals, family members contribute, rollover works, transactions can be split, calendar shows financial events

**Phase 6.6: Polish & Optimization (Weeks 15-16)**
- Performance optimization (query optimization, caching)
- Offline support (local storage, sync queue)
- UX refinement (animations, accessibility)
- Comprehensive testing and bug fixes
- **Deliverables:** App performs smoothly with large datasets, basic offline functionality, accessibility requirements met, all critical bugs fixed

**Reference:** `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 8)

**6.9 Testing Strategy**

**Unit Tests:**
- `test/services/budget/budget_service_test.dart` - Budget CRUD, premium checks, rollover
- `test/services/budget/transaction_service_test.dart` - Transaction operations, split transactions, approval workflow
- `test/services/budget/budget_analytics_service_test.dart` - Analytics calculations, health score

**Widget Tests:**
- `test/screens/budget/budget_home_screen_test.dart` - Dashboard display, navigation, premium gates

**Integration Tests:**
- `integration_test/budget_flow_test.dart` - Complete budget creation → transaction → analytics flow
- Shopping list → budget sync integration
- Wallet job reward → budget income sync

**UAT Test Cases:**
- BUD-001: Create family budget
- BUD-002: Add manual expense
- BUD-003: Add income
- BUD-004: Exceed category limit (alert triggered)
- BUD-005: Create personal budget (Premium)
- BUD-006: Kid adds transaction (pending approval)
- BUD-007: Parent approves transaction
- BUD-008: View spending analytics
- BUD-009: Export report to PDF
- BUD-010: Create savings goal

**Reference:** `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 9)

**6.10 Monetization Strategy**

**Premium Value Proposition:**
- "Track individual spending to eliminate surprise expenses"
- "Plan for major purchases with project budgets"
- "Teach kids financial responsibility with kid budgets"
- "Get insights that help families save an average of $200/month"

**Upgrade Triggers:**
1. Category limit reached (3 custom categories)
2. History limit (3 months)
3. Analytics teaser (blurred advanced analytics with upgrade prompt)
4. Goal limit (1 savings goal)
5. Individual budget request
6. Project budget creation
7. Export request

**Pricing:** Aligned with existing premium subscription ($4.99/month or $49.99/year)

**6.11 Success Metrics**

- 70%+ of active families create a budget within first month
- 60%+ of premium users create individual budgets
- 50%+ reduction in overspending alerts after 3 months of use
- 80%+ family member participation rate in budgeting
- 25%+ conversion rate from budget feature usage to premium
- 4.5+ star rating for budget feature
- Average 15+ transactions per budget per month

**6.12 Future Enhancements (Post-Launch)**

- **Q2 2026**: Bank sync (connect to bank accounts for auto-import)
- **Q3 2026**: Bill detection (OCR for receipt scanning)
- **Q3 2026**: AI insights (GPT-powered financial advice)
- **Q4 2026**: Debt payoff plans (snowball/avalanche calculators)
- **Q1 2027**: Multi-currency support

**Reference:** `docs/FAMILY_BUDGET_COMPONENT_PLAN.md` (Section 11)

**Implementation Status:** ✅ **COMPLETE** (December 12, 2025)
- ✅ Foundation and enhanced tracking (Phases 6.1-6.2) - **COMPLETE**
- ✅ Core services and UI screens - **COMPLETE**
- ✅ Analytics and sync services - **COMPLETE**
- ✅ Premium features infrastructure - **COMPLETE**
- 🚧 Advanced features (charts, recurring transactions) - **PENDING**

**Estimated Timeline (Original):**
- **Q2 2026**: Foundation and enhanced tracking (Phases 6.1-6.2) - ✅ **AHEAD OF SCHEDULE**
- **Q3 2026**: Premium features and analytics (Phases 6.3-6.5) - ✅ **AHEAD OF SCHEDULE**
- **Q4 2026**: Polish and optimization (Phase 6.6) - 🚧 **IN PROGRESS**

**Dependencies:**
- Requires subscription service infrastructure (Phase 1)
- Integrates with existing Wallet, Shopping, and Task services
- Requires Firebase Storage for receipt photos
- Premium features require IAP integration

---

**Document Owner**: Product & Engineering Teams  
**Last Reviewed**: December 12, 2025  
**Next Review**: January 2026  
**Status**: Active Planning

---

*This roadmap is subject to change based on user feedback, market conditions, technical constraints, and business priorities.*

