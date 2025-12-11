# Family Hub - Formal Code Review & Technical Implementation Plan

**Document Version:** 1.0  
**Review Date:** December 11, 2025  
**Reviewer:** Claude (AI Code Review Agent)  
**Classification:** Technical Documentation

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Architecture Review](#architecture-review)
3. [Code Quality Analysis](#code-quality-analysis)
4. [Technical Debt Assessment](#technical-debt-assessment)
5. [Security Review](#security-review)
6. [Performance Analysis](#performance-analysis)
7. [Strategic Roadmap Technical Plan](#strategic-roadmap-technical-plan)
8. [Implementation Timeline](#implementation-timeline)
9. [Risk Assessment](#risk-assessment)
10. [Recommendations](#recommendations)

---

## 1. Executive Summary

### 1.1 Project Overview
Family Hub is a comprehensive Flutter-based family management application targeting Android, iOS, web, and desktop platforms. The app provides features for family coordination including:
- Calendar & event management
- Task/job management with rewards system
- Real-time chat (family, private, and hub-based)
- Location sharing
- Photo albums
- Shopping lists
- Games (Chess with AI, 2048, Slide Puzzle, Tetris)
- Video calling (Agora)

### 1.2 Codebase Statistics
- **Total Dart files:** ~175+ files in `lib/`
- **Services:** 42+ service classes
- **Models:** 24+ data models
- **Screens:** 50+ screens across multiple modules
- **Test coverage:** Limited (5 test files found)

### 1.3 Overall Assessment

| Category | Rating | Notes |
|----------|--------|-------|
| Architecture | ⭐⭐⭐⭐ Good | Clean separation, service-oriented |
| Code Quality | ⭐⭐⭐⭐ Good | Consistent patterns, good logging |
| Documentation | ⭐⭐⭐ Adequate | Comments present, needs API docs |
| Test Coverage | ⭐⭐ Needs Work | Very limited test coverage |
| Security | ⭐⭐⭐ Adequate | Firebase rules needed, some concerns |
| Performance | ⭐⭐⭐⭐ Good | Caching, pagination implemented |
| Scalability | ⭐⭐⭐⭐ Good | Ready for roadmap expansion |

### 1.4 Key Findings

**Strengths:**
1. Well-structured service layer with clear separation of concerns
2. Comprehensive logging system via `LoggerService`
3. Robust error handling with custom exceptions (`AppExceptions`)
4. Multi-environment support (dev/qa/prod) via flavor configs
5. Good use of Firebase ecosystem (Auth, Firestore, Storage, Messaging)
6. Caching layer implemented (`QueryCacheService`, `CacheService`)
7. Feature-complete games module with chess AI

**Critical Issues:**
1. **Firestore prefix not implemented** - Dev/QA/Prod share same data
2. **No subscription/IAP infrastructure** - Required for premium hubs
3. **Limited test coverage** - Risk for regression bugs
4. **Hub model lacks type system** - Cannot differentiate hub types
5. **No message encryption** - Privacy concern for sensitive communications (solution: Encrypted Chat premium feature)

---

## 2. Architecture Review

### 2.1 Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Screens │  │ Widgets │  │ Dialogs │  │ Modals  │        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       └────────────┴────────────┴────────────┘              │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────────┐
│                     State Management                         │
│  ┌────────────┐  ┌─────────────────┐  ┌────────────┐       │
│  │ Provider   │  │ UserDataProvider│  │  AppState  │       │
│  └────────────┘  └─────────────────┘  └────────────┘       │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────────┐
│                      Service Layer                           │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌────────────┐    │
│  │AuthService│ │ChatService│ │TaskService│ │CalendarSvc │    │
│  └──────────┘ └───────────┘ └──────────┘ └────────────┘    │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌────────────┐    │
│  │HubService│ │GameService│ │PhotoSvc  │ │ShoppingSvc │    │
│  └──────────┘ └───────────┘ └──────────┘ └────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────────┐
│                      Data Layer                              │
│  ┌────────────┐  ┌───────────────┐  ┌────────────┐         │
│  │  Firebase  │  │ Local Storage │  │   Cache    │         │
│  │ Firestore  │  │  Hive/Prefs   │  │  Service   │         │
│  └────────────┘  └───────────────┘  └────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Module Structure Analysis

#### 2.2.1 Core Module (`lib/core/`)
✅ **Well Structured**
- `constants/app_constants.dart` - Centralized constants
- `di/service_locator.dart` - GetIt dependency injection
- `errors/app_exceptions.dart` - Custom exception hierarchy
- `services/logger_service.dart` - Comprehensive logging

**Recommendation:** Expand DI to include more services.

#### 2.2.2 Services Module (`lib/services/`)
✅ **Good Separation of Concerns**
- 42+ service files with single responsibilities
- Consistent patterns for Firestore operations
- Good use of streams for real-time data

**Issues Found:**
1. Services instantiate each other directly instead of via DI
2. Hardcoded collection paths (no `firestorePrefix` usage)
3. Duplicate code for familyId resolution across services

**Example of Hardcoded Paths (Critical):**
```dart
// chat_service.dart - Line 28
return 'families/$familyId/messages';  // ❌ No prefix

// Should be:
return '${Config.current.firestorePrefix}families/$familyId/messages';  // ✅
```

#### 2.2.3 Models Module (`lib/models/`)
✅ **Clean Data Models**
- Good use of `fromJson`/`toJson` patterns
- Proper null safety handling
- `copyWith` methods for immutability

**Issues Found:**
1. `Hub` model lacks `hubType` field
2. `UserModel` lacks subscription fields
3. Some models handle Timestamp inconsistently

#### 2.2.4 Config Module (`lib/config/`)
✅ **Multi-Environment Support**
- `AppConfig` abstract interface
- `DevConfig`, `QaConfig`, `ProdConfig` implementations
- `firestorePrefix` defined but **NOT USED**

### 2.3 Dependency Analysis

```yaml
# Key Dependencies
flutter: SDK
firebase_core: ^3.6.0
firebase_auth: ^5.7.0
cloud_firestore: ^5.4.4
firebase_messaging: ^15.1.3
firebase_storage: ^12.3.4
firebase_app_check: ^0.3.2+10
provider: ^6.1.1  # State management
get_it: ^7.6.4    # Dependency injection
hive_flutter: ^1.1.0  # Local storage
agora_rtc_engine: ^6.3.0  # Video calls
chess: ^0.7.0     # Chess game logic
```

**Observations:**
- Dependencies are relatively up-to-date
- No IAP package (required for roadmap)
- Missing `home_widget` package for widget support

---

## 3. Code Quality Analysis

### 3.1 Coding Standards

✅ **Positive Findings:**
- Consistent naming conventions (camelCase, snake_case files)
- Good use of Dart null safety
- Comprehensive error handling with try-catch blocks
- Structured logging with tags and levels

⚠️ **Areas for Improvement:**
- Some files exceed 1000 lines (e.g., `auth_service.dart` ~1900 lines)
- Magic numbers/strings in some places
- Inconsistent async/await patterns

### 3.2 Error Handling Review

**Excellent error hierarchy:**
```dart
// app_exceptions.dart
abstract class AppException implements Exception { ... }
class AuthException extends AppException { ... }
class FirestoreException extends AppException { ... }
class ValidationException extends AppException { ... }
class PermissionException extends AppException { ... }
```

**Issues:**
1. Some services rethrow generic exceptions
2. Network errors not always handled gracefully
3. Timeout handling inconsistent across services

### 3.3 Logging Analysis

**Well-implemented logging:**
```dart
Logger.info('Message', tag: 'AuthService');
Logger.warning('Warning', error: e, tag: 'ChatService');
Logger.error('Error', error: e, stackTrace: st, tag: 'TaskService');
```

**Recommendation:** Add log aggregation service (Crashlytics is included but not fully utilized).

### 3.4 Code Duplication

**Identified Patterns:**
1. FamilyId resolution repeated in ~15 services
2. Timestamp parsing duplicated in multiple models
3. Collection path construction duplicated

**Suggested Refactoring:**
```dart
// Create base service class
abstract class BaseFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _cachedFamilyId;
  
  Future<String?> get familyId async { ... }
  
  String getCollectionPath(String basePath) {
    return '${Config.current.firestorePrefix}$basePath';
  }
}
```

---

## 4. Technical Debt Assessment

### 4.1 Critical Technical Debt

| Issue | Impact | Effort | Priority |
|-------|--------|--------|----------|
| Firestore prefix not implemented | HIGH - Data leakage between envs | 2-3 hrs | P0 |
| No subscription infrastructure | HIGH - Blocks monetization | 4-6 hrs | P0 |
| Hub type system missing | HIGH - Blocks premium hubs | 3-4 hrs | P0 |
| No message encryption | HIGH - Privacy/security concern | 16-24 hrs | P1 |
| Limited test coverage | MEDIUM - Regression risk | 20+ hrs | P1 |
| Service layer DI | MEDIUM - Maintenance | 4-5 hrs | P1 |
| Large file refactoring | LOW - Readability | 8-10 hrs | P2 |

### 4.2 Technical Debt Details

#### 4.2.1 Firestore Prefix (P0)
**Current State:** `Config.current.firestorePrefix` defined but unused.
```dart
// dev_config.dart
String get firestorePrefix => 'dev_';

// chat_service.dart (CURRENT - WRONG)
return 'families/$familyId/messages';
```

**Required Change:**
```dart
// All services must use:
return '${Config.current.firestorePrefix}families/$familyId/messages';
```

**Affected Services:** All 20+ services using Firestore.

#### 4.2.2 Subscription Infrastructure (P0)
**Current State:** No subscription/premium feature support.
**Required:**
1. `SubscriptionService` class
2. `UserModel` subscription fields
3. IAP integration (Google Play/App Store)
4. Premium feature gating widgets

#### 4.2.3 Hub Type System (P0)
**Current Hub Model:**
```dart
class Hub {
  final String id;
  final String name;
  final String description;
  // Missing: hubType, permissions, typeSpecificData
}
```

**Required Hub Model:**
```dart
class Hub {
  final String id;
  final String name;
  final String description;
  final HubType type;  // NEW
  final Map<String, dynamic>? typeSpecificData;  // NEW
  final HubPermissions permissions;  // NEW
  // ...
}

enum HubType {
  family,          // Free
  extendedFamily,  // Premium
  homeschooling,   // Premium
  coparenting,     // Premium
}
```

---

## 5. Security Review

### 5.1 Authentication
✅ **Good Implementation:**
- Firebase Auth with email/password
- Secure password handling
- Session persistence
- Re-authentication for sensitive ops

⚠️ **Concerns:**
- No MFA support
- Password strength not enforced in UI
- Account deletion requires recent auth (good)

### 5.2 Authorization
⚠️ **Needs Review:**
- Role-based access (Admin, Banker, Approver) implemented
- Family membership checks present
- **Firestore rules need verification**

### 5.3 Data Protection
⚠️ **Areas for Improvement:**
1. Sensitive data (location) should have privacy controls ✅ (PrivacyService exists)
2. Message encryption not implemented (end-to-end) → **Solution: Encrypted Chat (Premium Feature) planned for Phase 1**
3. Photo URLs are public Firebase Storage links

### 5.4 API Key Security
✅ **Observations:**
- API keys in platform-specific configs
- App Check implemented for Firebase
- reCAPTCHA Enterprise configured

---

## 6. Performance Analysis

### 6.1 Data Loading
✅ **Good Practices:**
- Pagination implemented in services
- Query limits applied (`limit: 50`, `limit: 500`)
- Caching layer (`QueryCacheService`)
- Optimistic UI updates

### 6.2 Memory Management
✅ **Proper Cleanup:**
- Stream subscriptions cancelled in `dispose()`
- Controllers disposed properly
- Image compression service implemented

### 6.3 Network Optimization
✅ **Implemented:**
- Offline queue service for failed operations
- Background sync service
- Connectivity checks

⚠️ **Improvements Needed:**
- Image lazy loading could be improved
- Consider WebSocket for real-time chess instead of polling

### 6.4 Firestore Usage
⚠️ **Optimization Opportunities:**
1. Compound queries could reduce reads
2. Some services fetch full documents when partial data needed
3. Consider Firestore bundles for initial load

---

## 7. Strategic Roadmap Technical Plan

### 7.1 Phase 1: Foundation & Infrastructure (Current - Q1 2025)

#### 7.1.1 Data Isolation Implementation (Priority: P0)

**Task 1.1: Create Collection Path Helper**
```dart
// lib/core/utils/firestore_utils.dart
class FirestoreUtils {
  static String getCollectionPath(String basePath) {
    return '${Config.current.firestorePrefix}$basePath';
  }
  
  static String getFamilyCollectionPath(String familyId, String subcollection) {
    return '${Config.current.firestorePrefix}families/$familyId/$subcollection';
  }
}
```

**Task 1.2: Refactor All Services**

| Service | Collections to Update |
|---------|----------------------|
| `AuthService` | `users`, `families` |
| `ChatService` | `families/.../messages`, `families/.../privateMessages` |
| `TaskService` | `families/.../tasks` |
| `CalendarService` | `families/.../events` |
| `PhotoService` | `families/.../photos`, `families/.../albums` |
| `ShoppingService` | `families/.../shoppingLists` |
| `GamesService` | `families/.../games` |
| `HubService` | `hubs`, `hubInvites` |
| `WalletService` | `families/.../wallet` |
| `PrivacyService` | `families/.../privacySettings` |
| `UATService` | `uat_test_cases`, `uat_test_results` |

**Estimated Effort:** 2-3 hours

**Task 1.3: Add Integration Tests**
```dart
// test/integration/firestore_prefix_test.dart
void main() {
  group('Firestore Prefix Tests', () {
    test('Dev environment uses dev_ prefix', () async {
      // Initialize dev config
      await Config.initialize();
      expect(FirestoreUtils.getCollectionPath('users'), 'dev_users');
    });
  });
}
```

#### 7.1.2 Subscription Infrastructure (Priority: P0)

**Task 2.1: Extend UserModel**
```dart
// lib/models/user_model.dart - Add fields
class UserModel {
  // Existing fields...
  
  // NEW: Subscription fields
  final String subscriptionTier;  // 'free', 'premium', 'family_plus', 'family_premium'
  final String subscriptionStatus;  // 'active', 'expired', 'cancelled', 'trial'
  final DateTime? subscriptionExpiresAt;
  final List<String> premiumHubTypes;  // ['extended_family', 'homeschooling']
  final String? subscriptionPlatform;  // 'google', 'apple'
  final DateTime? subscriptionPurchaseDate;
  
  // Helper methods
  bool hasActiveSubscription() => subscriptionStatus == 'active';
  bool hasPremiumHubAccess(String hubType) => 
      hasActiveSubscription() && premiumHubTypes.contains(hubType);
}
```

**Task 2.2: Create SubscriptionService**
```dart
// lib/services/subscription_service.dart
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  /// Check if user has active premium subscription
  Future<bool> hasActiveSubscription() async {
    final user = await _authService.getCurrentUserModel();
    return user?.subscriptionStatus == 'active' &&
           (user?.subscriptionExpiresAt?.isAfter(DateTime.now()) ?? false);
  }
  
  /// Check if user can access specific premium hub type
  Future<bool> hasPremiumHubAccess(String hubType) async {
    final user = await _authService.getCurrentUserModel();
    if (user == null) return false;
    
    return user.hasActiveSubscription() && 
           user.premiumHubTypes.contains(hubType);
  }
  
  /// Verify and process IAP purchase
  Future<void> verifyPurchase({
    required String purchaseToken,
    required String productId,
    required String platform,
  }) async {
    // Verify with backend or Firebase Functions
    // Update user subscription in Firestore
  }
  
  /// Restore purchases (for account recovery)
  Future<void> restorePurchases() async {
    // Query IAP for existing purchases
    // Restore subscription status
  }
  
  /// Stream subscription status changes
  Stream<SubscriptionStatus> subscriptionStatusStream() {
    // Real-time subscription updates
  }
}
```

**Task 2.3: Add IAP Package**
```yaml
# pubspec.yaml additions
dependencies:
  in_app_purchase: ^3.1.13
  # Or revenue_cat for easier IAP management:
  # purchases_flutter: ^6.0.0
```

**Task 2.4: Create Premium Feature Gate Widget**
```dart
// lib/widgets/premium_feature_gate.dart
class PremiumFeatureGate extends StatelessWidget {
  final String? requiredHubType;
  final String? requiredTier;
  final Widget child;
  final Widget? fallback;
  
  const PremiumFeatureGate({
    this.requiredHubType,
    this.requiredTier,
    required this.child,
    this.fallback,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAccess(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return child;
        }
        return fallback ?? const UpgradePromptWidget();
      },
    );
  }
  
  Future<bool> _checkAccess() async {
    final subscriptionService = SubscriptionService();
    
    if (requiredHubType != null) {
      return subscriptionService.hasPremiumHubAccess(requiredHubType!);
    }
    
    if (requiredTier != null) {
      // Check tier level
    }
    
    return subscriptionService.hasActiveSubscription();
  }
}
```

**Estimated Effort:** 4-6 hours

#### 7.1.3 Hub Type System (Priority: P0)

**Task 3.1: Create Hub Type Enum**
```dart
// lib/models/hub_type.dart
enum HubType {
  family('family', 'Family', false),
  extendedFamily('extended_family', 'Extended Family', true),
  homeschooling('homeschooling', 'Homeschooling', true),
  coparenting('coparenting', 'Co-Parenting', true);
  
  const HubType(this.id, this.displayName, this.isPremium);
  
  final String id;
  final String displayName;
  final bool isPremium;
  
  static HubType fromString(String id) {
    return HubType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => HubType.family,
    );
  }
}
```

**Task 3.2: Extend Hub Model**
```dart
// lib/models/hub.dart - Extended
class Hub {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? icon;
  final bool videoCallsEnabled;
  
  // NEW FIELDS
  final HubType type;
  final Map<String, dynamic>? typeSpecificData;
  final HubPermissions permissions;
  
  // Type-specific getters
  bool get isExtendedFamilyHub => type == HubType.extendedFamily;
  bool get isHomeschoolingHub => type == HubType.homeschooling;
  bool get isCoparentingHub => type == HubType.coparenting;
  bool get isPremiumHub => type.isPremium;
}

class HubPermissions {
  final bool canInvite;
  final bool canEdit;
  final bool canDelete;
  final bool canManageMembers;
  final List<String> viewOnlyMemberIds;
  final List<String> limitedAccessMemberIds;
}
```

**Task 3.3: Create Hub Type Registry**
```dart
// lib/services/hub_type_registry.dart
class HubTypeRegistry {
  static final Map<HubType, HubTypeConfig> _configs = {
    HubType.family: HubTypeConfig(
      features: ['chat', 'calendar', 'tasks', 'photos', 'location'],
      maxMembers: 20,
      allowsSubgroups: false,
    ),
    HubType.extendedFamily: HubTypeConfig(
      features: ['chat', 'calendar', 'photos', 'familyTree', 'privacyControls'],
      maxMembers: 100,
      allowsSubgroups: true,
    ),
    HubType.homeschooling: HubTypeConfig(
      features: ['curriculum', 'assignments', 'progress', 'resources', 'calendar'],
      maxMembers: 20,
      allowsSubgroups: true,
    ),
    HubType.coparenting: HubTypeConfig(
      features: ['custody', 'expenses', 'communication', 'documents'],
      maxMembers: 4,
      allowsSubgroups: false,
    ),
  };
  
  static HubTypeConfig getConfig(HubType type) => _configs[type]!;
  
  static bool hubTypeHasFeature(HubType type, String feature) {
    return _configs[type]?.features.contains(feature) ?? false;
  }
}

class HubTypeConfig {
  final List<String> features;
  final int maxMembers;
  final bool allowsSubgroups;
  
  const HubTypeConfig({
    required this.features,
    required this.maxMembers,
    required this.allowsSubgroups,
  });
}
```

**Estimated Effort:** 3-4 hours

#### 7.1.4 Widget Framework Architecture (Priority: P1)

**Task 4.1: Add Widget Packages**
```yaml
# pubspec.yaml
dependencies:
  home_widget: ^0.6.0  # Cross-platform widget support
```

**Task 4.2: Create Widget Data Service**
```dart
// lib/services/widget_service.dart
class WidgetService {
  static const String _appGroupId = 'group.com.example.familyhub';
  
  /// Initialize widget framework
  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
    HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  }
  
  /// Update widget data
  Future<void> updateWidgetData({
    required String widgetName,
    required Map<String, dynamic> data,
  }) async {
    for (final entry in data.entries) {
      await HomeWidget.saveWidgetData<String>(entry.key, entry.value.toString());
    }
    await HomeWidget.updateWidget(
      name: widgetName,
      androidName: widgetName,
      iOSName: widgetName,
    );
  }
  
  /// Handle widget tap actions
  @pragma('vm:entry-point')
  static Future<void> widgetBackgroundCallback(Uri? uri) async {
    if (uri == null) return;
    
    final hubId = uri.queryParameters['hubId'];
    if (hubId != null) {
      // Navigate to hub
    }
  }
}
```

**Task 4.3: Create Android Widget Provider**
```kotlin
// android/app/src/main/kotlin/.../FamilyHubWidget.kt
class FamilyHubWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.hub_widget)
            
            val hubName = widgetData.getString("hub_name", "Family Hub")
            val upcomingEvents = widgetData.getString("upcoming_events", "No events")
            val unreadCount = widgetData.getInt("unread_count", 0)
            
            views.setTextViewText(R.id.hub_name, hubName)
            views.setTextViewText(R.id.upcoming_events, upcomingEvents)
            views.setTextViewText(R.id.unread_badge, unreadCount.toString())
            
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
```

**Estimated Effort:** 6-8 hours (full widget implementation)

#### 7.1.5 Encrypted Chat (Premium Feature) (Priority: P1)

**Overview:**
End-to-end encrypted (E2EE) messaging as a premium feature for users who require enhanced privacy. Messages are encrypted on the sender's device and can only be decrypted by intended recipients, ensuring that even Family Hub servers cannot read message contents.

**Task 5.1: Add Encryption Dependencies**
```yaml
# pubspec.yaml additions
dependencies:
  cryptography: ^2.7.0          # Cross-platform cryptography
  pointycastle: ^3.7.4          # Dart crypto implementations
  flutter_secure_storage: ^9.0.0 # Secure key storage
  # Alternative: Use libsodium bindings for better performance
  # sodium_libs: ^2.2.0
```

**Task 5.2: Create Encryption Key Models**
```dart
// lib/models/encryption/encryption_key.dart
import 'dart:typed_data';

/// Represents a user's encryption key pair
class EncryptionKeyPair {
  final String odId;
  final String oderId;
  final Uint8List publicKey;
  final Uint8List privateKey;  // Stored only locally, never sent to server
  final DateTime createdAt;
  final int keyVersion;
  
  EncryptionKeyPair({
    required this.userId,
    required this.publicKey,
    required this.privateKey,
    required this.createdAt,
    this.keyVersion = 1,
  });
  
  /// Export public key for sharing (Base64 encoded)
  String get publicKeyBase64 => base64Encode(publicKey);
  
  /// Create from stored data
  factory EncryptionKeyPair.fromSecureStorage(Map<String, dynamic> data) { ... }
  
  /// Serialize for secure storage (private key encrypted with device key)
  Map<String, dynamic> toSecureStorage() { ... }
}

/// Public key stored in Firestore for other users to encrypt messages
class PublicKeyRecord {
  final String odId;
  final String oderId;
  final String publicKeyBase64;
  final int keyVersion;
  final DateTime uploadedAt;
  final String? deviceId;  // Optional: support multiple devices
  
  PublicKeyRecord({...});
  
  Map<String, dynamic> toJson() => { ... };
  factory PublicKeyRecord.fromJson(Map<String, dynamic> json) => ...;
}
```

**Task 5.3: Create Encrypted Message Model**
```dart
// lib/models/encryption/encrypted_message.dart
class EncryptedChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String recipientId;  // For private chats
  final String? hubId;       // For hub/group chats
  
  // Encrypted content fields
  final String encryptedContent;     // Base64-encoded encrypted message
  final String encryptedContentIv;   // Initialization vector for AES
  final String encryptedSymmetricKey; // Symmetric key encrypted with recipient's public key
  
  // Metadata (not encrypted - needed for routing/display)
  final DateTime timestamp;
  final String messageType;  // 'text', 'image', 'voice', etc.
  final bool isEncrypted;    // Flag to distinguish from legacy messages
  final int encryptionVersion;
  
  // For group chats: map of recipientId -> encrypted symmetric key
  final Map<String, String>? groupEncryptedKeys;
  
  EncryptedChatMessage({...});
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'recipientId': recipientId,
    'hubId': hubId,
    'encryptedContent': encryptedContent,
    'encryptedContentIv': encryptedContentIv,
    'encryptedSymmetricKey': encryptedSymmetricKey,
    'timestamp': timestamp.toIso8601String(),
    'messageType': messageType,
    'isEncrypted': true,
    'encryptionVersion': encryptionVersion,
    'groupEncryptedKeys': groupEncryptedKeys,
  };
  
  factory EncryptedChatMessage.fromJson(Map<String, dynamic> json) => ...;
}
```

**Task 5.4: Create Encryption Service**
```dart
// lib/services/encryption_service.dart
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Algorithms
  final _keyExchangeAlgorithm = X25519();  // For key exchange
  final _encryptionAlgorithm = AesGcm.with256bits();  // For message encryption
  
  EncryptionKeyPair? _cachedKeyPair;
  final Map<String, SimplePublicKey> _publicKeyCache = {};
  
  /// Initialize encryption for current user
  /// Generates key pair if not exists, loads from secure storage if exists
  Future<void> initialize() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    // Try to load existing key pair from secure storage
    final storedKeyPair = await _loadKeyPairFromStorage(userId);
    
    if (storedKeyPair != null) {
      _cachedKeyPair = storedKeyPair;
      Logger.info('Loaded existing encryption key pair', tag: 'EncryptionService');
    } else {
      // Generate new key pair
      await generateAndStoreKeyPair(userId);
    }
    
    // Upload public key to Firestore (if not already there or if key version changed)
    await _syncPublicKeyToFirestore(userId);
  }
  
  /// Generate new key pair and store securely
  Future<EncryptionKeyPair> generateAndStoreKeyPair(String userId) async {
    Logger.info('Generating new encryption key pair', tag: 'EncryptionService');
    
    // Generate X25519 key pair
    final keyPair = await _keyExchangeAlgorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    
    final encryptionKeyPair = EncryptionKeyPair(
      userId: userId,
      publicKey: Uint8List.fromList(publicKey.bytes),
      privateKey: Uint8List.fromList(privateKeyBytes),
      createdAt: DateTime.now(),
      keyVersion: 1,
    );
    
    // Store in secure storage
    await _secureStorage.write(
      key: 'encryption_key_$userId',
      value: jsonEncode(encryptionKeyPair.toSecureStorage()),
    );
    
    _cachedKeyPair = encryptionKeyPair;
    return encryptionKeyPair;
  }
  
  /// Encrypt a message for a single recipient (private chat)
  Future<EncryptedChatMessage> encryptMessage({
    required String plaintext,
    required String recipientId,
    required String senderId,
    required String senderName,
    String messageType = 'text',
  }) async {
    // Get recipient's public key
    final recipientPublicKey = await _getPublicKey(recipientId);
    if (recipientPublicKey == null) {
      throw EncryptionException('Recipient public key not found');
    }
    
    // Generate random symmetric key for this message
    final symmetricKey = await _encryptionAlgorithm.newSecretKey();
    final symmetricKeyBytes = await symmetricKey.extractBytes();
    
    // Encrypt message content with symmetric key
    final secretBox = await _encryptionAlgorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: symmetricKey,
    );
    
    // Encrypt symmetric key with recipient's public key (ECDH + HKDF)
    final sharedSecret = await _deriveSharedSecret(recipientPublicKey);
    final encryptedSymmetricKey = await _encryptWithSharedSecret(
      symmetricKeyBytes,
      sharedSecret,
    );
    
    return EncryptedChatMessage(
      id: const Uuid().v4(),
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      encryptedContent: base64Encode(secretBox.cipherText),
      encryptedContentIv: base64Encode(secretBox.nonce),
      encryptedSymmetricKey: base64Encode(encryptedSymmetricKey),
      timestamp: DateTime.now(),
      messageType: messageType,
      isEncrypted: true,
      encryptionVersion: 1,
    );
  }
  
  /// Encrypt a message for multiple recipients (group/hub chat)
  Future<EncryptedChatMessage> encryptGroupMessage({
    required String plaintext,
    required List<String> recipientIds,
    required String hubId,
    required String senderId,
    required String senderName,
    String messageType = 'text',
  }) async {
    // Generate random symmetric key for this message
    final symmetricKey = await _encryptionAlgorithm.newSecretKey();
    final symmetricKeyBytes = await symmetricKey.extractBytes();
    
    // Encrypt message content with symmetric key
    final secretBox = await _encryptionAlgorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: symmetricKey,
    );
    
    // Encrypt symmetric key for each recipient
    final groupEncryptedKeys = <String, String>{};
    for (final recipientId in recipientIds) {
      final recipientPublicKey = await _getPublicKey(recipientId);
      if (recipientPublicKey != null) {
        final sharedSecret = await _deriveSharedSecret(recipientPublicKey);
        final encryptedSymmetricKey = await _encryptWithSharedSecret(
          symmetricKeyBytes,
          sharedSecret,
        );
        groupEncryptedKeys[recipientId] = base64Encode(encryptedSymmetricKey);
      }
    }
    
    return EncryptedChatMessage(
      id: const Uuid().v4(),
      senderId: senderId,
      senderName: senderName,
      recipientId: '',
      hubId: hubId,
      encryptedContent: base64Encode(secretBox.cipherText),
      encryptedContentIv: base64Encode(secretBox.nonce),
      encryptedSymmetricKey: '',  // Not used for group messages
      groupEncryptedKeys: groupEncryptedKeys,
      timestamp: DateTime.now(),
      messageType: messageType,
      isEncrypted: true,
      encryptionVersion: 1,
    );
  }
  
  /// Decrypt a message received from another user
  Future<String> decryptMessage(EncryptedChatMessage message) async {
    if (_cachedKeyPair == null) {
      throw EncryptionException('Encryption not initialized');
    }
    
    // Get the encrypted symmetric key for current user
    String encryptedSymmetricKeyBase64;
    if (message.groupEncryptedKeys != null) {
      // Group message
      final userId = FirebaseAuth.instance.currentUser?.uid;
      encryptedSymmetricKeyBase64 = message.groupEncryptedKeys![userId] ?? '';
      if (encryptedSymmetricKeyBase64.isEmpty) {
        throw EncryptionException('Message not encrypted for current user');
      }
    } else {
      // Private message
      encryptedSymmetricKeyBase64 = message.encryptedSymmetricKey;
    }
    
    // Get sender's public key to derive shared secret
    final senderPublicKey = await _getPublicKey(message.senderId);
    if (senderPublicKey == null) {
      throw EncryptionException('Sender public key not found');
    }
    
    // Derive shared secret and decrypt symmetric key
    final sharedSecret = await _deriveSharedSecret(senderPublicKey);
    final symmetricKeyBytes = await _decryptWithSharedSecret(
      base64Decode(encryptedSymmetricKeyBase64),
      sharedSecret,
    );
    
    // Decrypt message content with symmetric key
    final symmetricKey = SecretKey(symmetricKeyBytes);
    final secretBox = SecretBox(
      base64Decode(message.encryptedContent),
      nonce: base64Decode(message.encryptedContentIv),
      mac: Mac.empty,  // GCM includes MAC in ciphertext
    );
    
    final plaintextBytes = await _encryptionAlgorithm.decrypt(
      secretBox,
      secretKey: symmetricKey,
    );
    
    return utf8.decode(plaintextBytes);
  }
  
  /// Get public key for a user (from cache or Firestore)
  Future<SimplePublicKey?> _getPublicKey(String odId) async {
    // Check cache first
    if (_publicKeyCache.containsKey(userId)) {
      return _publicKeyCache[userId];
    }
    
    // Fetch from Firestore
    try {
      final doc = await _firestore
          .collection('${Config.current.firestorePrefix}publicKeys')
          .doc(userId)
          .get();
      
      if (!doc.exists) return null;
      
      final record = PublicKeyRecord.fromJson(doc.data()!);
      final publicKey = SimplePublicKey(
        base64Decode(record.publicKeyBase64),
        type: KeyPairType.x25519,
      );
      
      _publicKeyCache[userId] = publicKey;
      return publicKey;
    } catch (e) {
      Logger.error('Error fetching public key', error: e, tag: 'EncryptionService');
      return null;
    }
  }
  
  /// Derive shared secret using ECDH
  Future<SecretKey> _deriveSharedSecret(SimplePublicKey otherPublicKey) async {
    if (_cachedKeyPair == null) {
      throw EncryptionException('Encryption not initialized');
    }
    
    final privateKey = SimpleKeyPairData(
      _cachedKeyPair!.privateKey,
      publicKey: SimplePublicKey(
        _cachedKeyPair!.publicKey,
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
    
    return await _keyExchangeAlgorithm.sharedSecretKey(
      keyPair: privateKey,
      remotePublicKey: otherPublicKey,
    );
  }
  
  /// Sync public key to Firestore
  Future<void> _syncPublicKeyToFirestore(String userId) async {
    if (_cachedKeyPair == null) return;
    
    final record = PublicKeyRecord(
      userId: userId,
      publicKeyBase64: _cachedKeyPair!.publicKeyBase64,
      keyVersion: _cachedKeyPair!.keyVersion,
      uploadedAt: DateTime.now(),
    );
    
    await _firestore
        .collection('${Config.current.firestorePrefix}publicKeys')
        .doc(userId)
        .set(record.toJson());
    
    Logger.info('Public key synced to Firestore', tag: 'EncryptionService');
  }
  
  /// Export recovery key (for backup)
  Future<String> exportRecoveryKey() async {
    if (_cachedKeyPair == null) {
      throw EncryptionException('Encryption not initialized');
    }
    
    // Create encrypted backup of private key
    // User should store this securely (e.g., write down, password manager)
    final recoveryData = {
      'privateKey': base64Encode(_cachedKeyPair!.privateKey),
      'publicKey': base64Encode(_cachedKeyPair!.publicKey),
      'keyVersion': _cachedKeyPair!.keyVersion,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    
    // Encode as base64 for easy copying
    return base64Encode(utf8.encode(jsonEncode(recoveryData)));
  }
  
  /// Import recovery key (for account recovery)
  Future<void> importRecoveryKey(String recoveryKeyBase64, String userId) async {
    try {
      final recoveryData = jsonDecode(
        utf8.decode(base64Decode(recoveryKeyBase64)),
      ) as Map<String, dynamic>;
      
      final keyPair = EncryptionKeyPair(
        userId: userId,
        privateKey: base64Decode(recoveryData['privateKey']),
        publicKey: base64Decode(recoveryData['publicKey']),
        createdAt: DateTime.now(),
        keyVersion: recoveryData['keyVersion'] ?? 1,
      );
      
      // Store in secure storage
      await _secureStorage.write(
        key: 'encryption_key_$userId',
        value: jsonEncode(keyPair.toSecureStorage()),
      );
      
      _cachedKeyPair = keyPair;
      
      // Sync public key to Firestore
      await _syncPublicKeyToFirestore(userId);
      
      Logger.info('Recovery key imported successfully', tag: 'EncryptionService');
    } catch (e) {
      Logger.error('Error importing recovery key', error: e, tag: 'EncryptionService');
      throw EncryptionException('Invalid recovery key format');
    }
  }
  
  /// Check if user has encryption enabled
  Future<bool> isEncryptionEnabled() async {
    return _cachedKeyPair != null;
  }
  
  /// Clear encryption keys (for logout/account deletion)
  Future<void> clearKeys() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _secureStorage.delete(key: 'encryption_key_$userId');
    }
    _cachedKeyPair = null;
    _publicKeyCache.clear();
  }
}

/// Custom exception for encryption errors
class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}
```

**Task 5.5: Create Encrypted Chat Service**
```dart
// lib/services/encrypted_chat_service.dart
class EncryptedChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final AuthService _authService = AuthService();
  
  /// Send an encrypted private message
  Future<void> sendEncryptedPrivateMessage({
    required String recipientId,
    required String content,
    String messageType = 'text',
  }) async {
    final currentUser = await _authService.getCurrentUserModel();
    if (currentUser == null) throw AuthException('Not authenticated');
    
    // Encrypt message
    final encryptedMessage = await _encryptionService.encryptMessage(
      plaintext: content,
      recipientId: recipientId,
      senderId: currentUser.uid,
      senderName: currentUser.displayName,
      messageType: messageType,
    );
    
    // Store in Firestore
    final chatId = _getChatId(currentUser.uid, recipientId);
    final familyId = currentUser.familyId;
    
    await _firestore
        .collection('${Config.current.firestorePrefix}families/$familyId/encryptedMessages')
        .doc(chatId)
        .collection('messages')
        .add(encryptedMessage.toJson());
  }
  
  /// Send an encrypted hub/group message
  Future<void> sendEncryptedHubMessage({
    required String hubId,
    required String content,
    String messageType = 'text',
  }) async {
    final currentUser = await _authService.getCurrentUserModel();
    if (currentUser == null) throw AuthException('Not authenticated');
    
    // Get hub members
    final hubDoc = await _firestore
        .collection('${Config.current.firestorePrefix}hubs')
        .doc(hubId)
        .get();
    
    if (!hubDoc.exists) throw FirestoreException('Hub not found');
    
    final memberIds = List<String>.from(hubDoc.data()?['memberIds'] ?? []);
    
    // Encrypt message for all members
    final encryptedMessage = await _encryptionService.encryptGroupMessage(
      plaintext: content,
      recipientIds: memberIds,
      hubId: hubId,
      senderId: currentUser.uid,
      senderName: currentUser.displayName,
      messageType: messageType,
    );
    
    // Store in Firestore
    await _firestore
        .collection('${Config.current.firestorePrefix}hubs/$hubId/encryptedMessages')
        .add(encryptedMessage.toJson());
  }
  
  /// Stream decrypted private messages
  Stream<List<ChatMessage>> getDecryptedPrivateMessagesStream(String otherUserId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);
    
    return Stream.fromFuture(_authService.getCurrentUserModel()).asyncExpand((userModel) {
      if (userModel?.familyId == null) return Stream.value([]);
      
      final chatId = _getChatId(currentUserId, otherUserId);
      final familyId = userModel!.familyId!;
      
      return _firestore
          .collection('${Config.current.firestorePrefix}families/$familyId/encryptedMessages')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
            final messages = <ChatMessage>[];
            
            for (var doc in snapshot.docs) {
              try {
                final encryptedMessage = EncryptedChatMessage.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                });
                
                // Decrypt message
                final plaintext = await _encryptionService.decryptMessage(encryptedMessage);
                
                // Convert to regular ChatMessage for UI
                messages.add(ChatMessage(
                  id: encryptedMessage.id,
                  senderId: encryptedMessage.senderId,
                  senderName: encryptedMessage.senderName,
                  content: plaintext,
                  timestamp: encryptedMessage.timestamp,
                  type: encryptedMessage.messageType,
                  isEncrypted: true,
                ));
              } catch (e) {
                Logger.warning('Failed to decrypt message', error: e, tag: 'EncryptedChatService');
                // Add placeholder for failed decryption
                messages.add(ChatMessage(
                  id: doc.id,
                  senderId: doc.data()['senderId'] ?? '',
                  senderName: doc.data()['senderName'] ?? 'Unknown',
                  content: '[Unable to decrypt message]',
                  timestamp: DateTime.tryParse(doc.data()['timestamp'] ?? '') ?? DateTime.now(),
                  type: 'text',
                  isEncrypted: true,
                ));
              }
            }
            
            return messages;
          });
    });
  }
  
  String _getChatId(String odId1, String odId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
```

**Task 5.6: Create Encrypted Chat UI Components**
```dart
// lib/widgets/encrypted_chat_indicator.dart
class EncryptedChatIndicator extends StatelessWidget {
  final bool isEncrypted;
  
  const EncryptedChatIndicator({required this.isEncrypted, super.key});
  
  @override
  Widget build(BuildContext context) {
    if (!isEncrypted) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 14, color: Colors.green[700]),
          const SizedBox(width: 4),
          Text(
            'End-to-end encrypted',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// lib/widgets/encryption_setup_dialog.dart
class EncryptionSetupDialog extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.enhanced_encryption, color: Colors.green),
          const SizedBox(width: 8),
          const Text('Enable Encrypted Chat'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'End-to-end encryption ensures only you and your recipients can read your messages.',
          ),
          const SizedBox(height: 16),
          const Text(
            '⚠️ Important:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('• Save your recovery key securely'),
          const Text('• Lost keys cannot be recovered'),
          const Text('• Encrypted messages cannot be read on new devices without recovery key'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton.icon(
          onPressed: () => _enableEncryption(context),
          icon: const Icon(Icons.lock),
          label: const Text('Enable Encryption'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
```

**Task 5.7: Premium Feature Gating for Encrypted Chat**
```dart
// Integration with SubscriptionService
class EncryptedChatFeatureGate extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  
  const EncryptedChatFeatureGate({
    required this.child,
    this.fallback,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkEncryptedChatAccess(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return child;
        }
        return fallback ?? const EncryptedChatUpgradePrompt();
      },
    );
  }
  
  Future<bool> _checkEncryptedChatAccess() async {
    final subscriptionService = SubscriptionService();
    final userModel = await AuthService().getCurrentUserModel();
    
    // Encrypted chat available for:
    // 1. Premium subscribers
    // 2. Family Plus/Premium tier
    // 3. Users with 'encrypted_chat' feature flag
    return subscriptionService.hasActiveSubscription() ||
           (userModel?.premiumHubTypes.contains('encrypted_chat') ?? false);
  }
}

class EncryptedChatUpgradePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.enhanced_encryption, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Encrypted Chat',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upgrade to Premium to enable end-to-end encrypted messaging for maximum privacy.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/subscription'),
              child: const Text('Upgrade to Premium'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Task 5.8: Update ChatMessage Model for Encryption Support**
```dart
// lib/models/chat_message.dart - Add encryption fields
class ChatMessage {
  // ... existing fields ...
  
  // NEW: Encryption indicator
  final bool isEncrypted;
  
  ChatMessage({
    // ... existing parameters ...
    this.isEncrypted = false,
  });
  
  Map<String, dynamic> toJson() => {
    // ... existing fields ...
    'isEncrypted': isEncrypted,
  };
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    // ... existing parsing ...
    isEncrypted: json['isEncrypted'] as bool? ?? false,
  );
}
```

**Task 5.9: Firestore Security Rules for Encrypted Messages**
```javascript
// firestore.rules additions
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Public keys - readable by authenticated users, writable only by owner
    match /{prefix}publicKeys/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Encrypted messages - same rules as regular messages
    match /{prefix}families/{familyId}/encryptedMessages/{chatId}/messages/{messageId} {
      allow read: if request.auth != null && 
                    exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
                    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.familyId == familyId;
      allow create: if request.auth != null && 
                      request.auth.uid == request.resource.data.senderId;
      allow update, delete: if false;  // Messages are immutable
    }
    
    // Hub encrypted messages
    match /{prefix}hubs/{hubId}/encryptedMessages/{messageId} {
      allow read: if request.auth != null &&
                    request.auth.uid in get(/databases/$(database)/documents/hubs/$(hubId)).data.memberIds;
      allow create: if request.auth != null &&
                      request.auth.uid in get(/databases/$(database)/documents/hubs/$(hubId)).data.memberIds &&
                      request.auth.uid == request.resource.data.senderId;
      allow update, delete: if false;  // Messages are immutable
    }
  }
}
```

**Task 5.10: Key Recovery UI**
```dart
// lib/screens/settings/encryption_settings_screen.dart
class EncryptionSettingsScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encryption Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encryption status
          _buildEncryptionStatusCard(),
          const SizedBox(height: 16),
          
          // Export recovery key
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('Export Recovery Key'),
            subtitle: const Text('Save your key to recover messages on new devices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exportRecoveryKey,
          ),
          
          // Import recovery key
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Import Recovery Key'),
            subtitle: const Text('Restore your encryption keys'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importRecoveryKey,
          ),
          
          const Divider(),
          
          // Regenerate keys (danger)
          ListTile(
            leading: Icon(Icons.warning, color: Colors.red),
            title: Text('Regenerate Keys', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Warning: You will lose access to old messages'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _regenerateKeys,
          ),
        ],
      ),
    );
  }
}
```

**Estimated Effort:** 16-24 hours
- Encryption service implementation: ~8 hours
- Encrypted chat service: ~4 hours
- UI components: ~4 hours
- Key management & recovery: ~4 hours
- Testing & security review: ~4 hours

**Security Considerations:**
1. Private keys NEVER leave the device
2. Use secure storage for key persistence
3. Implement proper key rotation mechanism
4. Add device verification for multi-device support
5. Consider Signal Protocol for advanced forward secrecy
6. Regular security audits recommended

**Dependencies:**
- Requires Subscription Infrastructure (7.1.2) for premium gating
- Requires Firestore Prefix (7.1.1) for proper collection paths
- Flutter Secure Storage for key persistence
- Cryptography package for encryption primitives

**Success Criteria:**
- Messages encrypted before leaving device
- Only intended recipients can decrypt
- Key recovery works across devices
- No plaintext messages stored in Firestore
- Premium feature gating works correctly
- Backward compatible with unencrypted messages

### 7.2 Phase 2: Extended Family Hubs (Q2 2025)

#### 7.2.1 Extended Family Features

**Task 5.1: Family Tree Data Model**
```dart
// lib/models/family_tree.dart
class FamilyTreeMember {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String relationshipType;  // 'grandparent', 'aunt', 'uncle', 'cousin', etc.
  final String? parentId;  // For tree hierarchy
  final List<String> childIds;
  final DateTime? birthday;
  
  FamilyTreeMember({...});
}

class FamilyTree {
  final String hubId;
  final List<FamilyTreeMember> members;
  final Map<String, List<String>> relationships;
  
  FamilyTree({...});
  
  /// Get ancestors of a member
  List<FamilyTreeMember> getAncestors(String memberId) { ... }
  
  /// Get descendants of a member
  List<FamilyTreeMember> getDescendants(String memberId) { ... }
  
  /// Build tree visualization data
  Map<String, dynamic> toTreeVisualization() { ... }
}
```

**Task 5.2: Extended Family Privacy Controls**
```dart
// lib/services/extended_family_privacy_service.dart
class ExtendedFamilyPrivacyService {
  /// Default: Minimal sharing for extended family
  static const PrivacyLevel defaultExtendedFamilyPrivacy = PrivacyLevel.minimal;
  
  /// Privacy levels
  enum PrivacyLevel {
    full,      // Full access to all content
    limited,   // Can view events, photos (shared only), chat
    viewOnly,  // Can only view shared content, cannot interact
    minimal,   // Basic profile only
  }
  
  /// Check if member can view content
  Future<bool> canViewContent({
    required String memberId,
    required String contentType,
    required String hubId,
  }) async {
    final privacySettings = await _getPrivacySettings(hubId, memberId);
    return _checkPermission(privacySettings, contentType);
  }
  
  /// Set privacy level for extended family member
  Future<void> setPrivacyLevel({
    required String hubId,
    required String memberId,
    required PrivacyLevel level,
  }) async { ... }
}
```

**Task 5.3: Extended Family Hub Screen**
```dart
// lib/screens/hubs/extended_family_hub_screen.dart
class ExtendedFamilyHubScreen extends StatefulWidget {
  final Hub hub;
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(hub.name),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.account_tree), text: 'Family Tree'),
              Tab(icon: Icon(Icons.event), text: 'Events'),
              Tab(icon: Icon(Icons.chat), text: 'Chat'),
              Tab(icon: Icon(Icons.photo_library), text: 'Photos'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FamilyTreeView(hubId: hub.id),
            ExtendedFamilyEventsView(hubId: hub.id),
            HubChatScreen(hub: hub),
            HubPhotosView(hubId: hub.id),
            ExtendedFamilySettingsView(hubId: hub.id),
          ],
        ),
      ),
    );
  }
}
```

**Estimated Effort:** 40-60 hours

### 7.3 Phase 3: Homeschooling Hubs (Q3 2025)

#### 7.3.1 Curriculum & Assignment System

**Task 6.1: Curriculum Data Models**
```dart
// lib/models/homeschooling/curriculum.dart
class Subject {
  final String id;
  final String name;
  final String? description;
  final String color;
  final String icon;
  final List<String> learningObjectives;
  final String? standardsAlignment;  // Common Core, etc.
}

class Lesson {
  final String id;
  final String subjectId;
  final String title;
  final String? description;
  final DateTime scheduledDate;
  final Duration estimatedDuration;
  final List<String> resourceIds;
  final LessonStatus status;
}

class Assignment {
  final String id;
  final String lessonId;
  final String studentId;
  final String title;
  final String? instructions;
  final DateTime dueDate;
  final DateTime? submittedAt;
  final AssignmentStatus status;
  final int? grade;
  final String? feedback;
}

enum AssignmentStatus { pending, submitted, graded, late }
enum LessonStatus { scheduled, inProgress, completed, skipped }
```

**Task 6.2: Progress Tracking Service**
```dart
// lib/services/homeschooling/progress_service.dart
class HomeschoolProgressService {
  /// Track student progress
  Future<StudentProgress> getStudentProgress({
    required String studentId,
    required String hubId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    // Aggregate assignments, grades, completion rates
  }
  
  /// Generate progress report
  Future<ProgressReport> generateReport({
    required String studentId,
    required ReportPeriod period,
  }) async {
    // Create PDF-ready progress report
  }
  
  /// Get achievement badges
  Stream<List<Achievement>> streamAchievements(String studentId) {
    // Real-time achievement updates
  }
}
```

**Estimated Effort:** 60-80 hours

### 7.4 Phase 4: Co-Parenting Hubs (Q4 2025)

#### 7.4.1 Custody & Expense Management

**Task 7.1: Custody Schedule System**
```dart
// lib/models/coparenting/custody_schedule.dart
class CustodySchedule {
  final String id;
  final String hubId;
  final CustodyPattern pattern;  // 'week_on_off', '2_2_3', 'custom'
  final List<CustodyPeriod> periods;
  final List<HolidayOverride> holidayOverrides;
  final DateTime startDate;
}

class CustodyPeriod {
  final String parentId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isOverride;
  final String? note;
}

class ExpenseRecord {
  final String id;
  final String hubId;
  final String payerId;
  final ExpenseCategory category;
  final double amount;
  final String description;
  final String? receiptUrl;
  final DateTime date;
  final SplitType splitType;  // '50_50', 'percentage', 'custom'
  final Map<String, double> splits;
  final ReimbursementStatus status;
}
```

**Task 7.2: Communication Logging**
```dart
// lib/services/coparenting/communication_service.dart
class CoparentingCommunicationService {
  /// All communication is logged immutably
  Future<void> sendMessage({
    required String hubId,
    required String content,
    MessageTemplate? template,
  }) async {
    final message = CoparentingMessage(
      id: uuid.v4(),
      senderId: currentUserId,
      content: content,
      timestamp: DateTime.now(),
      isEdited: false,
      readBy: [],
    );
    
    // Messages cannot be deleted, only marked
    await _firestore
        .collection('${prefix}hubs/$hubId/messages')
        .doc(message.id)
        .set(message.toJson());
  }
  
  /// Export communication log (for legal purposes)
  Future<Uint8List> exportCommunicationLog({
    required String hubId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Generate PDF with all messages, timestamps, read receipts
  }
}
```

**Estimated Effort:** 60-80 hours

### 7.5 Phase 5: Social Feed Redesign (Q1-Q2 2026)

#### 7.5.1 Feed System Architecture

**Task 8.1: Feed Data Models**
```dart
// lib/models/feed/post.dart
class FeedPost {
  final String id;
  final String authorId;
  final String hubId;
  final PostType type;  // text, poll, media
  final String content;
  final DateTime timestamp;
  final List<String> mediaUrls;
  final Map<String, dynamic>? metadata;  // URL previews, etc.
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final List<String> likedBy;
  final Poll? poll;
  final List<String> crossHubIds;  // For cross-hub polls
}

class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final DateTime expiresAt;
  final bool allowCrossHub;
  final Map<String, String> votes;  // userId -> optionId
}

class PollOption {
  final String id;
  final String text;
  final int voteCount;
}

class Comment {
  final String id;
  final String postId;
  final String? parentCommentId;  // For threading
  final String authorId;
  final String content;
  final DateTime timestamp;
  final int likeCount;
  final List<String> likedBy;
}
```

**Task 8.2: Feed Service**
```dart
// lib/services/feed_service.dart
class FeedService {
  /// Get paginated feed
  Stream<List<FeedPost>> getFeedStream({
    required String hubId,
    int limit = 20,
    DateTime? before,
  }) {
    return _firestore
        .collection('${prefix}hubs/$hubId/feed')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedPost.fromJson(doc.data()))
            .toList());
  }
  
  /// Create post with poll
  Future<FeedPost> createPoll({
    required String hubId,
    required String question,
    required List<String> options,
    required Duration duration,
    List<String>? crossHubIds,
  }) async { ... }
  
  /// Vote on poll
  Future<void> voteOnPoll({
    required String postId,
    required String optionId,
  }) async { ... }
  
  /// Like/unlike post
  Future<void> toggleLike(String postId) async { ... }
  
  /// Add comment
  Future<Comment> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async { ... }
}
```

**Task 8.3: URL Preview Service**
```dart
// lib/services/url_preview_service.dart
class UrlPreviewService {
  final Map<String, UrlPreview> _cache = {};
  
  Future<UrlPreview?> getPreview(String url) async {
    if (_cache.containsKey(url)) {
      return _cache[url];
    }
    
    try {
      final response = await http.get(Uri.parse(url));
      final document = parse(response.body);
      
      final preview = UrlPreview(
        url: url,
        title: _getMetaContent(document, 'og:title') ?? 
               document.querySelector('title')?.text,
        description: _getMetaContent(document, 'og:description'),
        imageUrl: _getMetaContent(document, 'og:image'),
        siteName: _getMetaContent(document, 'og:site_name'),
      );
      
      _cache[url] = preview;
      return preview;
    } catch (e) {
      Logger.warning('Failed to get URL preview', error: e);
      return null;
    }
  }
}
```

**Estimated Effort:** 80-100 hours

---

## 8. Implementation Timeline

### 8.1 Detailed Timeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        IMPLEMENTATION TIMELINE                               │
├──────────────────┬──────────────────────────────────────────────────────────┤
│ Q1 2025 (Jan-Mar)│ Phase 1: Foundation & Infrastructure                     │
│                  │ ├─ Week 1-2: Firestore Prefix Implementation            │
│                  │ ├─ Week 3-4: Subscription Service & IAP                 │
│                  │ ├─ Week 5-6: Hub Type System                            │
│                  │ ├─ Week 7-8: Widget Framework Setup                     │
│                  │ ├─ Week 9-11: Encrypted Chat (Premium Feature)          │
│                  │ └─ Week 12: Testing & Refinement                        │
├──────────────────┼──────────────────────────────────────────────────────────┤
│ Q2 2025 (Apr-Jun)│ Phase 2: Extended Family Hubs                           │
│                  │ ├─ Week 1-3: Family Tree Implementation                 │
│                  │ ├─ Week 4-6: Privacy Controls                           │
│                  │ ├─ Week 7-9: Extended Family Features                   │
│                  │ ├─ Week 10-11: Widget Implementation                    │
│                  │ └─ Week 12: Testing & Launch                            │
├──────────────────┼──────────────────────────────────────────────────────────┤
│ Q3 2025 (Jul-Sep)│ Phase 3: Homeschooling Hubs                             │
│                  │ ├─ Week 1-4: Curriculum System                          │
│                  │ ├─ Week 5-7: Assignment Management                      │
│                  │ ├─ Week 8-10: Progress Tracking                         │
│                  │ ├─ Week 11: Widget Implementation                       │
│                  │ └─ Week 12: Testing & Launch                            │
├──────────────────┼──────────────────────────────────────────────────────────┤
│ Q4 2025 (Oct-Dec)│ Phase 4: Co-Parenting Hubs                              │
│                  │ ├─ Week 1-3: Custody Schedule System                    │
│                  │ ├─ Week 4-6: Expense Tracking                           │
│                  │ ├─ Week 7-9: Communication Logging                      │
│                  │ ├─ Week 10-11: Widget & Export Features                 │
│                  │ └─ Week 12: Testing & Launch                            │
├──────────────────┼──────────────────────────────────────────────────────────┤
│ Q1-Q2 2026       │ Phase 5: Social Feed Redesign                           │
│                  │ ├─ Q1 W1-6: Feed UI Redesign                            │
│                  │ ├─ Q1 W7-12: Basic Polling                              │
│                  │ ├─ Q2 W1-6: Comment Threading                           │
│                  │ ├─ Q2 W7-10: Cross-Hub Polls                            │
│                  │ └─ Q2 W11-12: URL Previews & Polish                     │
└──────────────────┴──────────────────────────────────────────────────────────┘
```

### 8.2 Effort Estimates

| Phase | Feature | Hours | Team Size | Duration |
|-------|---------|-------|-----------|----------|
| 1 | Firestore Prefix | 3 | 1 dev | 0.5 days |
| 1 | Subscription System | 6 | 1 dev | 1 day |
| 1 | Hub Type System | 4 | 1 dev | 0.5 days |
| 1 | Widget Framework | 8 | 1 dev | 1 day |
| 1 | **Encrypted Chat** | **20** | **1 dev** | **2.5 days** |
| 1 | Testing | 20 | 1 dev | 2.5 days |
| 2 | Extended Family | 60 | 2 devs | 3 weeks |
| 3 | Homeschooling | 80 | 2 devs | 4 weeks |
| 4 | Co-Parenting | 80 | 2 devs | 4 weeks |
| 5 | Social Feed | 100 | 2 devs | 5 weeks |

**Total Estimated Effort:** ~380 developer hours

---

## 9. Risk Assessment

### 9.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| IAP integration complexity | Medium | High | Use RevenueCat for abstraction |
| Widget platform differences | High | Medium | Design for lowest common denominator |
| Firestore query limits | Medium | Medium | Implement proper pagination |
| Data migration issues | Low | High | Thorough testing, rollback plan |
| Performance degradation | Medium | Medium | Load testing, caching |
| **Encryption key loss** | **Medium** | **High** | **Recovery key export, multi-device sync** |
| **Crypto library vulnerabilities** | **Low** | **Critical** | **Use audited libraries, regular updates** |

### 9.2 Business Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Low premium adoption | Medium | High | Free trials, clear value prop |
| Competition | Medium | Medium | Rapid iteration, user feedback |
| Platform policy changes | Low | High | Diversify revenue streams |
| COPPA/FERPA compliance | Medium | High | Legal review, privacy by design |

### 9.3 Operational Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Server costs increase | Medium | Medium | Monitor usage, optimize queries |
| Support volume increase | High | Medium | FAQ, in-app help, chatbot |
| Security breach | Low | Critical | Regular audits, E2E encryption (Encrypted Chat feature) |

---

## 10. Recommendations

### 10.1 Immediate Actions (This Week)

1. **Implement Firestore Prefix** - Critical for data isolation
2. **Create UserModel subscription fields** - Foundation for monetization
3. **Add HubType enum to Hub model** - Foundation for premium hubs
4. **Set up test infrastructure** - Prevent regressions

### 10.2 Short-Term (Q1 2025)

1. **Complete Phase 1 foundation work**
2. **Add comprehensive unit tests** (target 60% coverage)
3. **Implement IAP integration**
4. **Create widget framework prototype**
5. **Implement Encrypted Chat** - Premium feature for privacy-conscious users

### 10.3 Medium-Term (Q2-Q3 2025)

1. **Launch Extended Family Hubs** as first premium feature
2. **Gather user feedback** and iterate
3. **Build Homeschooling Hub MVP**
4. **Establish pricing strategy**

### 10.4 Long-Term (Q4 2025+)

1. **Launch Co-Parenting Hubs**
2. **Implement Social Feed redesign**
3. **Consider B2B partnerships** (homeschool co-ops, mediation services)
4. **Explore additional revenue streams** (coaching, resources)

### 10.5 Technical Recommendations

1. **Refactor AuthService** - Split into smaller, focused services
2. **Implement base service class** - Reduce code duplication
3. **Add Crashlytics integration** - Better error tracking
4. **Create API documentation** - Using dartdoc
5. **Set up CI/CD pipeline** - Automated testing and deployment

---

## Appendix A: File Inventory

### Services Requiring Prefix Update

```
lib/services/auth_service.dart
lib/services/chat_service.dart
lib/services/task_service.dart
lib/services/calendar_service.dart
lib/services/photo_service.dart
lib/services/shopping_service.dart
lib/services/games_service.dart
lib/services/hub_service.dart
lib/services/wallet_service.dart
lib/services/family_wallet_service.dart
lib/services/privacy_service.dart
lib/services/location_service.dart
lib/services/event_template_service.dart
lib/services/event_chat_service.dart
lib/services/message_reaction_service.dart
lib/services/message_thread_service.dart
lib/services/payout_service.dart
lib/services/recurring_payment_service.dart
lib/services/uat_service.dart
lib/services/achievement_service.dart
lib/services/badge_service.dart
lib/services/birthday_service.dart
lib/games/chess/services/chess_service.dart
```

### New Files to Create

```
lib/core/utils/firestore_utils.dart
lib/services/subscription_service.dart
lib/models/hub_type.dart
lib/models/hub_permissions.dart
lib/services/hub_type_registry.dart
lib/widgets/premium_feature_gate.dart
lib/widgets/upgrade_prompt_widget.dart
lib/services/widget_service.dart

# Encrypted Chat (Premium Feature)
lib/models/encryption/encryption_key.dart
lib/models/encryption/encrypted_message.dart
lib/services/encryption_service.dart
lib/services/encrypted_chat_service.dart
lib/widgets/encrypted_chat_indicator.dart
lib/widgets/encryption_setup_dialog.dart
lib/widgets/encrypted_chat_feature_gate.dart
lib/screens/settings/encryption_settings_screen.dart
```

---

**Document End**

*This document should be reviewed and updated as the project progresses. Last reviewed: December 11, 2025*
