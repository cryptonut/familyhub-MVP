# SMS Integration Technical Implementation Plan

**Document Version:** 1.0  
**Date:** December 18, 2025  
**Status:** Implementation Ready  
**Target Platforms:** Android (primary), iOS (limited due to platform restrictions)

---

## Executive Summary

This document outlines the technical implementation plan for integrating SMS messaging capabilities into the FamilyHub application. The feature allows users to sync their device SMS messages into the app and send SMS through the app's interface, creating a unified messaging experience. **Privacy is paramount**: SMS messages remain private to the current user unless explicitly shared to a hub.

---

## Table of Contents

1. [Feature Overview](#1-feature-overview)
2. [Platform Considerations](#2-platform-considerations)
3. [Architecture Design](#3-architecture-design)
4. [Data Models](#4-data-models)
5. [Service Layer](#5-service-layer)
6. [UI/UX Design](#6-uiux-design)
7. [Security & Privacy](#7-security--privacy)
8. [Database Schema](#8-database-schema)
9. [Implementation Phases](#9-implementation-phases)
10. [Testing Strategy](#10-testing-strategy)
11. [Dependencies & Packages](#11-dependencies--packages)
12. [Risk Assessment](#12-risk-assessment)
13. [Appendix: Code Templates](#13-appendix-code-templates)

---

## 1. Feature Overview

### 1.1 Core Functionality

1. **SMS Sync (Incoming)**
   - Read device SMS messages (with user permission)
   - Sync SMS conversations into the app's local storage
   - Display SMS messages in a dedicated SMS tab/view
   - Support background sync when app is not active

2. **SMS Sending (Outgoing)**
   - Send SMS from within the app
   - Select recipient from device address book or enter manually
   - Delivery status tracking (where platform supports)

3. **Unified Feed View**
   - Optional: View SMS messages alongside in-app messages
   - Clear visual differentiation between SMS and in-app messages
   - Filter options: All, In-App Only, SMS Only

4. **Hub Sharing (Opt-in)**
   - Share specific SMS conversations to a hub
   - Per-conversation toggle for hub visibility
   - Clear privacy indicators showing what is shared

### 1.2 User Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                    SMS INTEGRATION USER FLOW                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. User enables SMS Sync in Settings                           │
│     └─> App requests SMS permissions                            │
│         └─> User grants permission                              │
│             └─> Initial SMS sync begins                         │
│                                                                  │
│  2. SMS messages appear in dedicated SMS tab                    │
│     └─> User can view conversations                             │
│         └─> User can reply via SMS                              │
│             └─> (Optional) Send via in-app message instead      │
│                                                                  │
│  3. User wants to share SMS with family                         │
│     └─> Opens SMS conversation                                  │
│         └─> Taps "Share to Hub" toggle                          │
│             └─> Selects which hub(s) to share with              │
│                 └─> Conversation becomes visible in hub feed    │
│                                                                  │
│  4. Unified view (optional)                                     │
│     └─> User toggles "Show SMS in Feed"                         │
│         └─> SMS appears with distinct styling                   │
│             └─> Only user's SMS visible (unless shared)         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Platform Considerations

### 2.1 Android

Android provides full SMS access through the following APIs:
- **Read SMS**: `android.permission.READ_SMS`
- **Send SMS**: `android.permission.SEND_SMS`
- **Receive SMS**: `android.permission.RECEIVE_SMS`
- **Contacts Access**: `android.permission.READ_CONTACTS`

**Android Manifest Requirements:**
```xml
<uses-permission android:name="android.permission.READ_SMS"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
<uses-permission android:name="android.permission.READ_CONTACTS"/>
```

**Default SMS App Consideration:**
To receive incoming SMS in real-time, the app must either:
1. Register as default SMS handler (complex, requires additional permissions)
2. Use periodic background sync (simpler, slight delay)

**Recommendation:** Use periodic background sync (every 1-5 minutes) for initial implementation.

### 2.2 iOS

iOS is **highly restrictive** with SMS access:
- **No direct SMS reading** from third-party apps
- **Limited SMS sending** via `MFMessageComposeViewController` (requires user interaction)
- **No background SMS access**

**iOS Strategy:**
1. Show SMS feature as "Android-only" in settings
2. On iOS, offer "Share to Family" via share sheet extension
3. Future: Consider iMessage integration via Messages for Business (requires Apple approval)

### 2.3 Feature Parity Matrix

| Feature | Android | iOS |
|---------|---------|-----|
| Read SMS | ✅ Full | ❌ Not possible |
| Send SMS | ✅ Programmatic | ⚠️ User interaction required |
| Background Sync | ✅ Full | ❌ Not possible |
| Contacts Access | ✅ Full | ✅ Full |
| Share to Hub | ✅ Full | ⚠️ Via share sheet only |

---

## 3. Architecture Design

### 3.1 High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                             │
├──────────────────────────────────────────────────────────────────────┤
│  SMS Settings    SMS Conversations    SMS Compose    Unified Feed    │
│  Screen          Screen               Screen         Screen          │
└─────────────────────────┬────────────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────────────┐
│                        SERVICE LAYER                                  │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │
│  │   SmsService    │  │ SmsShareService │  │ContactsService  │       │
│  │                 │  │                 │  │                 │       │
│  │ - readSms()     │  │ - shareToHub()  │  │ - getContacts() │       │
│  │ - sendSms()     │  │ - unshare()     │  │ - searchContact │       │
│  │ - syncSms()     │  │ - getShared()   │  │ - getByPhone()  │       │
│  │ - watchInbox()  │  │                 │  │                 │       │
│  └────────┬────────┘  └────────┬────────┘  └─────────────────┘       │
│           │                    │                                      │
│  ┌────────▼────────────────────▼────────────────────────────────┐    │
│  │              SmsSyncService (Background)                      │    │
│  │  - Periodic sync via Workmanager                              │    │
│  │  - Handles incoming SMS notifications                         │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                                                                       │
└─────────────────────────┬────────────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────────────┐
│                        DATA LAYER                                     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │
│  │  Local Storage  │  │   Firestore     │  │  Device APIs    │       │
│  │     (Hive)      │  │   (Remote)      │  │  (Platform)     │       │
│  │                 │  │                 │  │                 │       │
│  │ - SMS Messages  │  │ - Shared SMS    │  │ - SMS Provider  │       │
│  │ - Sync State    │  │ - User Settings │  │ - Contacts DB   │       │
│  │ - Contact Cache │  │ - Share Config  │  │                 │       │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘       │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.2 Service Integration with Existing Architecture

The SMS integration follows the existing service patterns in the codebase:

```dart
// Integration with existing services
class SmsService {
  // Similar pattern to ChatService
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  
  // Uses existing path utilities
  // FirestorePathUtils.getUsersCollection()
  // FirestorePathUtils.getFamilySubcollectionPath()
}
```

### 3.3 Message Flow Architecture

```
                    ┌─────────────────────────────────────┐
                    │         DEVICE SMS INBOX            │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │       SmsSyncService                │
                    │   (Background Worker - Workmanager) │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
    ┌─────────▼─────────┐ ┌───────▼───────┐ ┌─────────▼─────────┐
    │   Local Hive DB   │ │ User Settings │ │ Sharing Service   │
    │ (Private Storage) │ │  (Firestore)  │ │ (if hub shared)   │
    └─────────┬─────────┘ └───────────────┘ └─────────┬─────────┘
              │                                       │
    ┌─────────▼─────────────────────────────────────▼─────────┐
    │                    UI LAYER                              │
    │  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
    │  │ SMS Tab      │  │ Unified Feed │  │ Hub Messages  │  │
    │  │ (Private)    │  │ (Private)    │  │ (Shared Only) │  │
    │  └──────────────┘  └──────────────┘  └───────────────┘  │
    └──────────────────────────────────────────────────────────┘
```

---

## 4. Data Models

### 4.1 SMS Message Model

```dart
// lib/models/sms_message.dart

import 'package:hive/hive.dart';

part 'sms_message.g.dart';

/// Source of the SMS message
enum SmsMessageSource {
  device,    // Read from device
  shared,    // Received via hub sharing
  sent,      // Sent via app
}

/// Direction of the message
enum SmsDirection {
  incoming,
  outgoing,
}

@HiveType(typeId: 20)
class SmsMessage {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String threadId;  // Conversation thread ID
  
  @HiveField(2)
  final String address;   // Phone number
  
  @HiveField(3)
  final String? contactName;  // Resolved contact name
  
  @HiveField(4)
  final String body;      // Message content
  
  @HiveField(5)
  final DateTime timestamp;
  
  @HiveField(6)
  final SmsDirection direction;
  
  @HiveField(7)
  final SmsMessageSource source;
  
  @HiveField(8)
  final bool isRead;
  
  @HiveField(9)
  final bool isSharedToHub;
  
  @HiveField(10)
  final List<String>? sharedHubIds;  // Hubs this is shared to
  
  @HiveField(11)
  final String ownerId;  // User who owns this SMS
  
  @HiveField(12)
  final DateTime? syncedAt;  // When synced to local storage
  
  @HiveField(13)
  final DeliveryStatus deliveryStatus;
  
  SmsMessage({
    required this.id,
    required this.threadId,
    required this.address,
    this.contactName,
    required this.body,
    required this.timestamp,
    required this.direction,
    this.source = SmsMessageSource.device,
    this.isRead = false,
    this.isSharedToHub = false,
    this.sharedHubIds,
    required this.ownerId,
    this.syncedAt,
    this.deliveryStatus = DeliveryStatus.unknown,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'threadId': threadId,
    'address': address,
    'contactName': contactName,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'direction': direction.name,
    'source': source.name,
    'isRead': isRead,
    'isSharedToHub': isSharedToHub,
    'sharedHubIds': sharedHubIds,
    'ownerId': ownerId,
    'syncedAt': syncedAt?.toIso8601String(),
    'deliveryStatus': deliveryStatus.name,
  };

  factory SmsMessage.fromJson(Map<String, dynamic> json) => SmsMessage(
    id: json['id'] as String,
    threadId: json['threadId'] as String,
    address: json['address'] as String,
    contactName: json['contactName'] as String?,
    body: json['body'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    direction: SmsDirection.values.firstWhere(
      (e) => e.name == json['direction'],
      orElse: () => SmsDirection.incoming,
    ),
    source: SmsMessageSource.values.firstWhere(
      (e) => e.name == json['source'],
      orElse: () => SmsMessageSource.device,
    ),
    isRead: json['isRead'] as bool? ?? false,
    isSharedToHub: json['isSharedToHub'] as bool? ?? false,
    sharedHubIds: (json['sharedHubIds'] as List?)?.cast<String>(),
    ownerId: json['ownerId'] as String,
    syncedAt: json['syncedAt'] != null 
        ? DateTime.parse(json['syncedAt'] as String) 
        : null,
    deliveryStatus: DeliveryStatus.values.firstWhere(
      (e) => e.name == json['deliveryStatus'],
      orElse: () => DeliveryStatus.unknown,
    ),
  );

  SmsMessage copyWith({
    String? id,
    String? threadId,
    String? address,
    String? contactName,
    String? body,
    DateTime? timestamp,
    SmsDirection? direction,
    SmsMessageSource? source,
    bool? isRead,
    bool? isSharedToHub,
    List<String>? sharedHubIds,
    String? ownerId,
    DateTime? syncedAt,
    DeliveryStatus? deliveryStatus,
  }) => SmsMessage(
    id: id ?? this.id,
    threadId: threadId ?? this.threadId,
    address: address ?? this.address,
    contactName: contactName ?? this.contactName,
    body: body ?? this.body,
    timestamp: timestamp ?? this.timestamp,
    direction: direction ?? this.direction,
    source: source ?? this.source,
    isRead: isRead ?? this.isRead,
    isSharedToHub: isSharedToHub ?? this.isSharedToHub,
    sharedHubIds: sharedHubIds ?? this.sharedHubIds,
    ownerId: ownerId ?? this.ownerId,
    syncedAt: syncedAt ?? this.syncedAt,
    deliveryStatus: deliveryStatus ?? this.deliveryStatus,
  );
}

enum DeliveryStatus {
  unknown,
  pending,
  sent,
  delivered,
  failed,
}
```

### 4.2 SMS Conversation Model

```dart
// lib/models/sms_conversation.dart

import 'package:hive/hive.dart';

part 'sms_conversation.g.dart';

@HiveType(typeId: 21)
class SmsConversation {
  @HiveField(0)
  final String threadId;
  
  @HiveField(1)
  final String address;  // Primary phone number
  
  @HiveField(2)
  final String? contactName;
  
  @HiveField(3)
  final String? contactPhotoUri;
  
  @HiveField(4)
  final String? lastMessageBody;
  
  @HiveField(5)
  final DateTime? lastMessageTime;
  
  @HiveField(6)
  final int messageCount;
  
  @HiveField(7)
  final int unreadCount;
  
  @HiveField(8)
  final bool isSharedToHub;
  
  @HiveField(9)
  final List<String>? sharedHubIds;
  
  @HiveField(10)
  final String ownerId;
  
  @HiveField(11)
  final bool isMuted;
  
  @HiveField(12)
  final bool isArchived;

  SmsConversation({
    required this.threadId,
    required this.address,
    this.contactName,
    this.contactPhotoUri,
    this.lastMessageBody,
    this.lastMessageTime,
    this.messageCount = 0,
    this.unreadCount = 0,
    this.isSharedToHub = false,
    this.sharedHubIds,
    required this.ownerId,
    this.isMuted = false,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() => {
    'threadId': threadId,
    'address': address,
    'contactName': contactName,
    'contactPhotoUri': contactPhotoUri,
    'lastMessageBody': lastMessageBody,
    'lastMessageTime': lastMessageTime?.toIso8601String(),
    'messageCount': messageCount,
    'unreadCount': unreadCount,
    'isSharedToHub': isSharedToHub,
    'sharedHubIds': sharedHubIds,
    'ownerId': ownerId,
    'isMuted': isMuted,
    'isArchived': isArchived,
  };

  factory SmsConversation.fromJson(Map<String, dynamic> json) => SmsConversation(
    threadId: json['threadId'] as String,
    address: json['address'] as String,
    contactName: json['contactName'] as String?,
    contactPhotoUri: json['contactPhotoUri'] as String?,
    lastMessageBody: json['lastMessageBody'] as String?,
    lastMessageTime: json['lastMessageTime'] != null 
        ? DateTime.parse(json['lastMessageTime'] as String) 
        : null,
    messageCount: json['messageCount'] as int? ?? 0,
    unreadCount: json['unreadCount'] as int? ?? 0,
    isSharedToHub: json['isSharedToHub'] as bool? ?? false,
    sharedHubIds: (json['sharedHubIds'] as List?)?.cast<String>(),
    ownerId: json['ownerId'] as String,
    isMuted: json['isMuted'] as bool? ?? false,
    isArchived: json['isArchived'] as bool? ?? false,
  );

  SmsConversation copyWith({
    String? threadId,
    String? address,
    String? contactName,
    String? contactPhotoUri,
    String? lastMessageBody,
    DateTime? lastMessageTime,
    int? messageCount,
    int? unreadCount,
    bool? isSharedToHub,
    List<String>? sharedHubIds,
    String? ownerId,
    bool? isMuted,
    bool? isArchived,
  }) => SmsConversation(
    threadId: threadId ?? this.threadId,
    address: address ?? this.address,
    contactName: contactName ?? this.contactName,
    contactPhotoUri: contactPhotoUri ?? this.contactPhotoUri,
    lastMessageBody: lastMessageBody ?? this.lastMessageBody,
    lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    messageCount: messageCount ?? this.messageCount,
    unreadCount: unreadCount ?? this.unreadCount,
    isSharedToHub: isSharedToHub ?? this.isSharedToHub,
    sharedHubIds: sharedHubIds ?? this.sharedHubIds,
    ownerId: ownerId ?? this.ownerId,
    isMuted: isMuted ?? this.isMuted,
    isArchived: isArchived ?? this.isArchived,
  );
}
```

### 4.3 SMS Settings Model

```dart
// lib/models/sms_settings.dart

class SmsSettings {
  final bool syncEnabled;
  final bool showInUnifiedFeed;
  final DateTime? lastSyncAt;
  final int syncIntervalMinutes;
  final bool notificationsEnabled;
  final List<String> defaultShareHubIds;
  final bool autoShareNewConversations;  // Advanced: auto-share new SMS
  final String? verifiedPhoneNumber;  // User's verified phone number
  
  SmsSettings({
    this.syncEnabled = false,
    this.showInUnifiedFeed = false,
    this.lastSyncAt,
    this.syncIntervalMinutes = 5,
    this.notificationsEnabled = true,
    this.defaultShareHubIds = const [],
    this.autoShareNewConversations = false,
    this.verifiedPhoneNumber,
  });

  Map<String, dynamic> toJson() => {
    'syncEnabled': syncEnabled,
    'showInUnifiedFeed': showInUnifiedFeed,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'syncIntervalMinutes': syncIntervalMinutes,
    'notificationsEnabled': notificationsEnabled,
    'defaultShareHubIds': defaultShareHubIds,
    'autoShareNewConversations': autoShareNewConversations,
    'verifiedPhoneNumber': verifiedPhoneNumber,
  };

  factory SmsSettings.fromJson(Map<String, dynamic> json) => SmsSettings(
    syncEnabled: json['syncEnabled'] as bool? ?? false,
    showInUnifiedFeed: json['showInUnifiedFeed'] as bool? ?? false,
    lastSyncAt: json['lastSyncAt'] != null 
        ? DateTime.parse(json['lastSyncAt'] as String) 
        : null,
    syncIntervalMinutes: json['syncIntervalMinutes'] as int? ?? 5,
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    defaultShareHubIds: (json['defaultShareHubIds'] as List?)?.cast<String>() ?? [],
    autoShareNewConversations: json['autoShareNewConversations'] as bool? ?? false,
    verifiedPhoneNumber: json['verifiedPhoneNumber'] as String?,
  );

  SmsSettings copyWith({
    bool? syncEnabled,
    bool? showInUnifiedFeed,
    DateTime? lastSyncAt,
    int? syncIntervalMinutes,
    bool? notificationsEnabled,
    List<String>? defaultShareHubIds,
    bool? autoShareNewConversations,
    String? verifiedPhoneNumber,
  }) => SmsSettings(
    syncEnabled: syncEnabled ?? this.syncEnabled,
    showInUnifiedFeed: showInUnifiedFeed ?? this.showInUnifiedFeed,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    defaultShareHubIds: defaultShareHubIds ?? this.defaultShareHubIds,
    autoShareNewConversations: autoShareNewConversations ?? this.autoShareNewConversations,
    verifiedPhoneNumber: verifiedPhoneNumber ?? this.verifiedPhoneNumber,
  );
}
```

### 4.4 Contact Model

```dart
// lib/models/device_contact.dart

class DeviceContact {
  final String id;
  final String displayName;
  final List<String> phoneNumbers;
  final String? photoUri;
  final String? email;
  
  DeviceContact({
    required this.id,
    required this.displayName,
    required this.phoneNumbers,
    this.photoUri,
    this.email,
  });

  /// Get the primary phone number
  String? get primaryPhone => phoneNumbers.isNotEmpty ? phoneNumbers.first : null;
  
  /// Get normalized phone numbers (E.164 format)
  List<String> get normalizedPhoneNumbers => 
      phoneNumbers.map(_normalizePhoneNumber).toList();
  
  static String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters except leading +
    String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    // Ensure it starts with + for international format
    if (!normalized.startsWith('+')) {
      // Assume US/Canada if no country code
      if (normalized.length == 10) {
        normalized = '+1$normalized';
      } else if (normalized.length == 11 && normalized.startsWith('1')) {
        normalized = '+$normalized';
      }
    }
    return normalized;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'phoneNumbers': phoneNumbers,
    'photoUri': photoUri,
    'email': email,
  };

  factory DeviceContact.fromJson(Map<String, dynamic> json) => DeviceContact(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    phoneNumbers: (json['phoneNumbers'] as List).cast<String>(),
    photoUri: json['photoUri'] as String?,
    email: json['email'] as String?,
  );
}
```

---

## 5. Service Layer

### 5.1 SMS Service (Core)

```dart
// lib/services/sms_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/sms_message.dart';
import '../models/sms_conversation.dart';
import '../models/sms_settings.dart';
import 'auth_service.dart';
import 'contacts_service.dart';

/// Service for reading and sending SMS messages
/// Uses platform channels for native SMS access
class SmsService {
  static const MethodChannel _channel = MethodChannel('com.familyhub/sms');
  
  final AuthService _authService = AuthService();
  final ContactsService _contactsService = ContactsService();
  
  // Hive boxes for local storage
  Box<SmsMessage>? _messagesBox;
  Box<SmsConversation>? _conversationsBox;
  
  // Stream controllers
  final StreamController<List<SmsMessage>> _messagesController = 
      StreamController<List<SmsMessage>>.broadcast();
  final StreamController<List<SmsConversation>> _conversationsController = 
      StreamController<List<SmsConversation>>.broadcast();

  /// Initialize the SMS service
  Future<void> initialize() async {
    try {
      _messagesBox = await Hive.openBox<SmsMessage>('sms_messages');
      _conversationsBox = await Hive.openBox<SmsConversation>('sms_conversations');
      
      // Set up native message listener
      _channel.setMethodCallHandler(_handleMethodCall);
      
      Logger.info('SMS Service initialized', tag: 'SmsService');
    } catch (e, st) {
      Logger.error('Error initializing SMS service', error: e, stackTrace: st, tag: 'SmsService');
      rethrow;
    }
  }

  /// Handle incoming method calls from native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSmsReceived':
        await _handleIncomingSms(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onSmsSent':
        await _handleSentSms(call.arguments as Map<dynamic, dynamic>);
        break;
      default:
        throw MissingPluginException();
    }
  }

  /// Check if SMS feature is available on this platform
  bool get isAvailable => Platform.isAndroid;

  /// Request SMS permissions
  Future<bool> requestPermissions() async {
    if (!isAvailable) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('requestSmsPermissions');
      return result ?? false;
    } catch (e) {
      Logger.error('Error requesting SMS permissions', error: e, tag: 'SmsService');
      return false;
    }
  }

  /// Check if SMS permissions are granted
  Future<bool> hasPermissions() async {
    if (!isAvailable) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('hasSmsPermissions');
      return result ?? false;
    } catch (e) {
      Logger.error('Error checking SMS permissions', error: e, tag: 'SmsService');
      return false;
    }
  }

  /// Read SMS messages from device
  Future<List<SmsMessage>> readDeviceSms({
    int limit = 100,
    DateTime? since,
  }) async {
    if (!isAvailable) return [];
    
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw const AuthException('User not authenticated', code: 'not-authenticated');
    
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('readSmsMessages', {
        'limit': limit,
        'since': since?.millisecondsSinceEpoch,
      });
      
      if (result == null) return [];
      
      final messages = <SmsMessage>[];
      for (final item in result) {
        final map = Map<String, dynamic>.from(item as Map);
        
        // Resolve contact name
        final address = map['address'] as String;
        final contact = await _contactsService.findContactByPhone(address);
        
        messages.add(SmsMessage(
          id: map['id'] as String,
          threadId: map['threadId'] as String,
          address: address,
          contactName: contact?.displayName,
          body: map['body'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
          direction: map['type'] == 1 ? SmsDirection.incoming : SmsDirection.outgoing,
          source: SmsMessageSource.device,
          isRead: (map['read'] as int?) == 1,
          ownerId: userId,
        ));
      }
      
      return messages;
    } catch (e, st) {
      Logger.error('Error reading SMS messages', error: e, stackTrace: st, tag: 'SmsService');
      return [];
    }
  }

  /// Send an SMS message
  Future<SmsMessage?> sendSms({
    required String address,
    required String body,
  }) async {
    if (!isAvailable) {
      throw const PlatformException('SMS sending not available on this platform', code: 'not-available');
    }
    
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw const AuthException('User not authenticated', code: 'not-authenticated');
    
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('sendSms', {
        'address': address,
        'body': body,
      });
      
      if (result == null) return null;
      
      final contact = await _contactsService.findContactByPhone(address);
      
      final message = SmsMessage(
        id: result['id'] as String,
        threadId: result['threadId'] as String,
        address: address,
        contactName: contact?.displayName,
        body: body,
        timestamp: DateTime.now(),
        direction: SmsDirection.outgoing,
        source: SmsMessageSource.sent,
        deliveryStatus: DeliveryStatus.pending,
        ownerId: userId,
        syncedAt: DateTime.now(),
      );
      
      // Store in local database
      await _storeMessage(message);
      
      Logger.info('SMS sent to $address', tag: 'SmsService');
      return message;
    } catch (e, st) {
      Logger.error('Error sending SMS', error: e, stackTrace: st, tag: 'SmsService');
      rethrow;
    }
  }

  /// Sync SMS messages from device to local storage
  Future<int> syncMessages({DateTime? since}) async {
    if (!isAvailable) return 0;
    
    try {
      final messages = await readDeviceSms(limit: 500, since: since);
      int syncedCount = 0;
      
      for (final message in messages) {
        final exists = _messagesBox?.get(message.id) != null;
        if (!exists) {
          await _storeMessage(message);
          syncedCount++;
        }
      }
      
      // Update conversations
      await _updateConversations();
      
      Logger.info('Synced $syncedCount SMS messages', tag: 'SmsService');
      return syncedCount;
    } catch (e, st) {
      Logger.error('Error syncing SMS messages', error: e, stackTrace: st, tag: 'SmsService');
      return 0;
    }
  }

  /// Get conversations stream
  Stream<List<SmsConversation>> getConversationsStream() {
    _loadConversations();
    return _conversationsController.stream;
  }

  /// Get messages for a conversation
  Stream<List<SmsMessage>> getConversationMessages(String threadId) {
    _loadConversationMessages(threadId);
    return _messagesController.stream;
  }

  /// Mark conversation as shared to hub
  Future<void> shareConversationToHub(String threadId, String hubId) async {
    final conversation = _conversationsBox?.get(threadId);
    if (conversation == null) return;
    
    final sharedHubs = List<String>.from(conversation.sharedHubIds ?? []);
    if (!sharedHubs.contains(hubId)) {
      sharedHubs.add(hubId);
    }
    
    final updated = conversation.copyWith(
      isSharedToHub: true,
      sharedHubIds: sharedHubs,
    );
    
    await _conversationsBox?.put(threadId, updated);
    
    // Also update all messages in this conversation
    final messages = _messagesBox?.values
        .where((m) => m.threadId == threadId)
        .toList() ?? [];
    
    for (final message in messages) {
      final updatedMessage = message.copyWith(
        isSharedToHub: true,
        sharedHubIds: sharedHubs,
      );
      await _messagesBox?.put(message.id, updatedMessage);
    }
    
    _loadConversations();
    Logger.info('Conversation $threadId shared to hub $hubId', tag: 'SmsService');
  }

  /// Remove conversation from hub sharing
  Future<void> unshareConversationFromHub(String threadId, String hubId) async {
    final conversation = _conversationsBox?.get(threadId);
    if (conversation == null) return;
    
    final sharedHubs = List<String>.from(conversation.sharedHubIds ?? []);
    sharedHubs.remove(hubId);
    
    final updated = conversation.copyWith(
      isSharedToHub: sharedHubs.isNotEmpty,
      sharedHubIds: sharedHubs,
    );
    
    await _conversationsBox?.put(threadId, updated);
    
    // Also update all messages in this conversation
    final messages = _messagesBox?.values
        .where((m) => m.threadId == threadId)
        .toList() ?? [];
    
    for (final message in messages) {
      final updatedMessage = message.copyWith(
        isSharedToHub: sharedHubs.isNotEmpty,
        sharedHubIds: sharedHubs,
      );
      await _messagesBox?.put(message.id, updatedMessage);
    }
    
    _loadConversations();
    Logger.info('Conversation $threadId unshared from hub $hubId', tag: 'SmsService');
  }

  // Private helper methods
  
  Future<void> _storeMessage(SmsMessage message) async {
    final stored = message.copyWith(syncedAt: DateTime.now());
    await _messagesBox?.put(message.id, stored);
  }

  Future<void> _handleIncomingSms(Map<dynamic, dynamic> data) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    
    final address = data['address'] as String;
    final contact = await _contactsService.findContactByPhone(address);
    
    final message = SmsMessage(
      id: data['id'] as String,
      threadId: data['threadId'] as String,
      address: address,
      contactName: contact?.displayName,
      body: data['body'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
      direction: SmsDirection.incoming,
      source: SmsMessageSource.device,
      ownerId: userId,
    );
    
    await _storeMessage(message);
    await _updateConversations();
    
    Logger.info('Received SMS from $address', tag: 'SmsService');
  }

  Future<void> _handleSentSms(Map<dynamic, dynamic> data) async {
    final messageId = data['id'] as String;
    final status = data['status'] as String;
    
    final message = _messagesBox?.get(messageId);
    if (message != null) {
      final updated = message.copyWith(
        deliveryStatus: DeliveryStatus.values.firstWhere(
          (e) => e.name == status,
          orElse: () => DeliveryStatus.unknown,
        ),
      );
      await _messagesBox?.put(messageId, updated);
    }
  }

  Future<void> _loadConversations() async {
    final conversations = _conversationsBox?.values.toList() ?? [];
    conversations.sort((a, b) => 
        (b.lastMessageTime ?? DateTime(0)).compareTo(a.lastMessageTime ?? DateTime(0)));
    _conversationsController.add(conversations);
  }

  Future<void> _loadConversationMessages(String threadId) async {
    final messages = _messagesBox?.values
        .where((m) => m.threadId == threadId)
        .toList() ?? [];
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _messagesController.add(messages);
  }

  Future<void> _updateConversations() async {
    final messages = _messagesBox?.values.toList() ?? [];
    final conversationsMap = <String, List<SmsMessage>>{};
    
    for (final message in messages) {
      conversationsMap.putIfAbsent(message.threadId, () => []);
      conversationsMap[message.threadId]!.add(message);
    }
    
    for (final entry in conversationsMap.entries) {
      final threadMessages = entry.value;
      threadMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      final lastMessage = threadMessages.first;
      final unreadCount = threadMessages.where((m) => !m.isRead && m.direction == SmsDirection.incoming).length;
      
      final existingConversation = _conversationsBox?.get(entry.key);
      
      final conversation = SmsConversation(
        threadId: entry.key,
        address: lastMessage.address,
        contactName: lastMessage.contactName,
        lastMessageBody: lastMessage.body,
        lastMessageTime: lastMessage.timestamp,
        messageCount: threadMessages.length,
        unreadCount: unreadCount,
        isSharedToHub: existingConversation?.isSharedToHub ?? false,
        sharedHubIds: existingConversation?.sharedHubIds,
        ownerId: lastMessage.ownerId,
        isMuted: existingConversation?.isMuted ?? false,
        isArchived: existingConversation?.isArchived ?? false,
      );
      
      await _conversationsBox?.put(entry.key, conversation);
    }
    
    _loadConversations();
  }

  /// Dispose of resources
  void dispose() {
    _messagesController.close();
    _conversationsController.close();
  }
}
```

### 5.2 SMS Sharing Service

```dart
// lib/services/sms_share_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/sms_message.dart';
import '../models/sms_conversation.dart';
import '../models/chat_message.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'sms_service.dart';

/// Service for sharing SMS conversations to hubs
class SmsShareService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final SmsService _smsService = SmsService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Share an SMS conversation to a hub
  /// Creates ChatMessage entries for shared SMS
  Future<void> shareConversationToHub({
    required String threadId,
    required String hubId,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('User not authenticated', code: 'not-authenticated');

    try {
      // Update local storage
      await _smsService.shareConversationToHub(threadId, hubId);
      
      // Create sharing record in Firestore
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'sms_shares'))
          .doc('${userId}_$threadId')
          .set({
        'threadId': threadId,
        'sharedBy': userId,
        'sharedAt': DateTime.now().toIso8601String(),
        'isActive': true,
      });

      // Sync existing messages to hub (as ChatMessage with SMS type indicator)
      await _syncSmsToHub(threadId, hubId);

      Logger.info('SMS conversation shared to hub: $threadId -> $hubId', tag: 'SmsShareService');
    } catch (e, st) {
      Logger.error('Error sharing SMS to hub', error: e, stackTrace: st, tag: 'SmsShareService');
      rethrow;
    }
  }

  /// Remove SMS conversation from hub sharing
  Future<void> unshareFromHub({
    required String threadId,
    required String hubId,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('User not authenticated', code: 'not-authenticated');

    try {
      // Update local storage
      await _smsService.unshareConversationFromHub(threadId, hubId);
      
      // Update sharing record in Firestore
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'sms_shares'))
          .doc('${userId}_$threadId')
          .update({
        'isActive': false,
        'unsharedAt': DateTime.now().toIso8601String(),
      });

      // Optionally: Remove SMS messages from hub feed (or mark as removed)
      // For audit trail, we mark as removed rather than deleting
      await _markSmsAsRemovedFromHub(threadId, hubId);

      Logger.info('SMS conversation unshared from hub: $threadId -> $hubId', tag: 'SmsShareService');
    } catch (e, st) {
      Logger.error('Error unsharing SMS from hub', error: e, stackTrace: st, tag: 'SmsShareService');
      rethrow;
    }
  }

  /// Get shared SMS conversations for a hub
  Stream<List<SmsConversation>> getSharedConversationsForHub(String hubId) {
    return _firestore
        .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'sms_shares'))
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      // This would return shared conversation metadata
      // Actual messages are stored as ChatMessage in hub
      return [];
    });
  }

  /// Sync SMS messages to hub as ChatMessage entries
  Future<void> _syncSmsToHub(String threadId, String hubId) async {
    final userId = currentUserId;
    final userModel = await _authService.getCurrentUserModel();
    if (userId == null || userModel == null) return;

    // Get SMS messages for this conversation
    // Note: This requires access to the local Hive storage
    // Implementation depends on how messages are accessed

    // For each SMS, create a ChatMessage in the hub
    // Messages are tagged with isSmsShared: true
  }

  /// Mark SMS messages as removed from hub (soft delete)
  Future<void> _markSmsAsRemovedFromHub(String threadId, String hubId) async {
    final userId = currentUserId;
    if (userId == null) return;

    // Query hub messages that are SMS shares from this user/thread
    final snapshot = await _firestore
        .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages'))
        .where('smsThreadId', isEqualTo: threadId)
        .where('senderId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isSmsShareRemoved': true,
        'removedAt': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit();
  }
}
```

### 5.3 Contacts Service

```dart
// lib/services/contacts_service.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/services/logger_service.dart';
import '../models/device_contact.dart';

/// Service for accessing device contacts
class ContactsService {
  static const MethodChannel _channel = MethodChannel('com.familyhub/contacts');
  
  Box<DeviceContact>? _contactsCache;
  List<DeviceContact>? _cachedContacts;

  /// Initialize the contacts service
  Future<void> initialize() async {
    try {
      _contactsCache = await Hive.openBox<DeviceContact>('contacts_cache');
      Logger.info('Contacts service initialized', tag: 'ContactsService');
    } catch (e, st) {
      Logger.error('Error initializing contacts service', error: e, stackTrace: st, tag: 'ContactsService');
    }
  }

  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasContactsPermission');
      return result ?? false;
    } catch (e) {
      Logger.error('Error checking contacts permission', error: e, tag: 'ContactsService');
      return false;
    }
  }

  /// Request contacts permission
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestContactsPermission');
      return result ?? false;
    } catch (e) {
      Logger.error('Error requesting contacts permission', error: e, tag: 'ContactsService');
      return false;
    }
  }

  /// Get all contacts from device
  Future<List<DeviceContact>> getContacts({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedContacts != null) {
      return _cachedContacts!;
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getContacts');
      if (result == null) return [];

      final contacts = result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return DeviceContact(
          id: map['id'] as String,
          displayName: map['displayName'] as String,
          phoneNumbers: (map['phoneNumbers'] as List).cast<String>(),
          photoUri: map['photoUri'] as String?,
          email: map['email'] as String?,
        );
      }).toList();

      // Cache contacts
      _cachedContacts = contacts;
      for (final contact in contacts) {
        await _contactsCache?.put(contact.id, contact);
      }

      Logger.info('Loaded ${contacts.length} contacts', tag: 'ContactsService');
      return contacts;
    } catch (e, st) {
      Logger.error('Error getting contacts', error: e, stackTrace: st, tag: 'ContactsService');
      return [];
    }
  }

  /// Find contact by phone number
  Future<DeviceContact?> findContactByPhone(String phoneNumber) async {
    final contacts = await getContacts();
    final normalized = _normalizePhoneNumber(phoneNumber);
    
    for (final contact in contacts) {
      for (final number in contact.normalizedPhoneNumbers) {
        if (number == normalized || number.endsWith(normalized) || normalized.endsWith(number)) {
          return contact;
        }
      }
    }
    return null;
  }

  /// Search contacts by name or number
  Future<List<DeviceContact>> searchContacts(String query) async {
    final contacts = await getContacts();
    final lowerQuery = query.toLowerCase();
    
    return contacts.where((contact) {
      if (contact.displayName.toLowerCase().contains(lowerQuery)) return true;
      for (final number in contact.phoneNumbers) {
        if (number.contains(query)) return true;
      }
      return false;
    }).toList();
  }

  String _normalizePhoneNumber(String phone) {
    String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!normalized.startsWith('+')) {
      if (normalized.length == 10) {
        normalized = '+1$normalized';
      } else if (normalized.length == 11 && normalized.startsWith('1')) {
        normalized = '+$normalized';
      }
    }
    return normalized;
  }
}
```

### 5.4 Background SMS Sync Service

```dart
// lib/services/sms_background_sync_service.dart

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../core/services/logger_service.dart';
import 'sms_service.dart';
import 'sms_settings_service.dart';

/// Service for background SMS synchronization
class SmsBackgroundSyncService {
  static const String _syncTaskName = 'smsSyncTask';
  static const String _syncTaskTag = 'sms_sync';

  /// Initialize background sync
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        _callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      Logger.info('SMS background sync service initialized', tag: 'SmsBackgroundSyncService');
    } catch (e, st) {
      Logger.error('Error initializing SMS background sync', error: e, stackTrace: st, tag: 'SmsBackgroundSyncService');
    }
  }

  /// Register periodic SMS sync task
  static Future<void> registerPeriodicSync({int intervalMinutes = 5}) async {
    try {
      await Workmanager().registerPeriodicTask(
        _syncTaskName,
        _syncTaskName,
        frequency: Duration(minutes: intervalMinutes),
        tag: _syncTaskTag,
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      Logger.info('Periodic SMS sync registered (every $intervalMinutes min)', tag: 'SmsBackgroundSyncService');
    } catch (e, st) {
      Logger.error('Error registering periodic SMS sync', error: e, stackTrace: st, tag: 'SmsBackgroundSyncService');
    }
  }

  /// Cancel periodic sync
  static Future<void> cancelPeriodicSync() async {
    try {
      await Workmanager().cancelByTag(_syncTaskTag);
      Logger.info('Periodic SMS sync cancelled', tag: 'SmsBackgroundSyncService');
    } catch (e, st) {
      Logger.error('Error cancelling SMS sync', error: e, stackTrace: st, tag: 'SmsBackgroundSyncService');
    }
  }

  /// Trigger immediate sync
  static Future<void> triggerSync() async {
    try {
      await Workmanager().registerOneOffTask(
        '${_syncTaskName}_${DateTime.now().millisecondsSinceEpoch}',
        _syncTaskName,
        initialDelay: const Duration(seconds: 1),
      );
      Logger.info('One-time SMS sync triggered', tag: 'SmsBackgroundSyncService');
    } catch (e, st) {
      Logger.error('Error triggering SMS sync', error: e, stackTrace: st, tag: 'SmsBackgroundSyncService');
    }
  }
}

/// Background callback dispatcher (must be top-level)
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      Logger.info('Background SMS sync started', tag: 'SmsBackgroundSyncService');
      
      // Check if sync is enabled
      final settingsService = SmsSettingsService();
      final settings = await settingsService.getSettings();
      
      if (!settings.syncEnabled) {
        Logger.info('SMS sync disabled, skipping', tag: 'SmsBackgroundSyncService');
        return true;
      }
      
      // Perform sync
      final smsService = SmsService();
      await smsService.initialize();
      
      final count = await smsService.syncMessages(since: settings.lastSyncAt);
      
      // Update last sync timestamp
      await settingsService.updateLastSyncTime();
      
      Logger.info('Background SMS sync completed: $count new messages', tag: 'SmsBackgroundSyncService');
      return true;
    } catch (e, st) {
      Logger.error('Background SMS sync error', error: e, stackTrace: st, tag: 'SmsBackgroundSyncService');
      return false;
    }
  });
}
```

---

## 6. UI/UX Design

### 6.1 New Screens Required

1. **SMS Settings Screen** (`lib/screens/settings/sms_settings_screen.dart`)
   - Enable/disable SMS sync
   - Phone number verification
   - Sync interval settings
   - Show in unified feed toggle
   - Default sharing settings

2. **SMS Conversations List Screen** (`lib/screens/sms/sms_conversations_screen.dart`)
   - List of SMS conversations
   - Search functionality
   - Share/unshare toggles

3. **SMS Conversation Detail Screen** (`lib/screens/sms/sms_conversation_detail_screen.dart`)
   - Message list view
   - Compose/reply input
   - Share to hub action

4. **Contact Picker Screen** (`lib/screens/sms/contact_picker_screen.dart`)
   - Search contacts
   - Enter number manually
   - Recent contacts

### 6.2 Screen Mockups

#### SMS Settings Screen
```
┌────────────────────────────────────────┐
│ ← SMS Integration                      │
├────────────────────────────────────────┤
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 📱 SMS Sync                    [●] │ │
│ │ Sync your SMS messages to app      │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 📋 Show in Unified Feed       [○] │ │
│ │ Display SMS in your main feed      │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ ⏱ Sync Interval                    │ │
│ │ Every 5 minutes              [▼]   │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 📞 Your Phone Number               │ │
│ │ +1 (555) 123-4567        [Verify]  │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 🔒 Privacy Note                    │ │
│ │ Your SMS messages are stored       │ │
│ │ locally and never shared unless    │ │
│ │ you explicitly choose to share     │ │
│ │ them with a hub.                   │ │
│ └────────────────────────────────────┘ │
│                                        │
│            [Open SMS Inbox]            │
│                                        │
└────────────────────────────────────────┘
```

#### SMS Conversations List
```
┌────────────────────────────────────────┐
│ ← SMS Messages              [Compose]  │
├────────────────────────────────────────┤
│ 🔍 Search conversations...             │
├────────────────────────────────────────┤
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 👤 Mom                    10:23 AM │ │
│ │ Can you pick up milk on your w...  │ │
│ │                          [Shared]  │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 👤 John Smith             Yesterday│ │
│ │ Thanks for letting me know!        │ │
│ │                                    │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 👤 +1 555-987-6543        Dec 15  │ │
│ │ Your verification code is 123456   │ │
│ │                                    │ │
│ └────────────────────────────────────┘ │
│                                        │
└────────────────────────────────────────┘
```

#### SMS Conversation Detail
```
┌────────────────────────────────────────┐
│ ← Mom                     [⋮ Options]  │
├────────────────────────────────────────┤
│                                        │
│ ┌──────────────────────────┐           │
│ │ Hi honey! How's your day?│  10:15 AM│
│ └──────────────────────────┘           │
│                                        │
│        ┌──────────────────────────┐    │
│        │ Great! Just got home.    │    │
│ 10:18 AM└──────────────────────────┘   │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ Can you pick up milk on your way  │ │
│ │ back from work tomorrow?           │ │
│ │                          10:23 AM  │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ────────── SMS Message ───────────     │
│                                        │
├────────────────────────────────────────┤
│ [📷] Type a message...       [Send ➤] │
└────────────────────────────────────────┘

Options Menu:
┌────────────────────────┐
│ 📤 Share to Hub        │
│ 🔕 Mute Conversation   │
│ 📁 Archive             │
│ 🗑️ Delete              │
└────────────────────────┘
```

### 6.3 Integration with Chat Tabs

Modify `ChatTabsScreen` to include SMS tab:

```dart
// Updated tab structure
TabBar(
  tabs: [
    Tab(text: 'All'),           // Unified feed (optionally includes SMS)
    Tab(text: 'SMS'),           // NEW: SMS conversations
    ...familyMemberTabs,        // Individual member chats
  ],
)
```

### 6.4 Visual Differentiation for SMS Messages

SMS messages in the unified feed should be clearly distinguished:

```dart
// SMS message indicator widget
Widget _buildSmsIndicator() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.green.shade100,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sms, size: 12, color: Colors.green.shade700),
        const SizedBox(width: 4),
        Text(
          'SMS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
      ],
    ),
  );
}
```

---

## 7. Security & Privacy

### 7.1 Privacy Principles

1. **Local-First Storage**
   - SMS messages stored locally in encrypted Hive database
   - No automatic cloud sync of SMS content
   - User has full control over what is shared

2. **Explicit Sharing Only**
   - SMS never shared to hubs without explicit user action
   - Per-conversation sharing toggle
   - Clear visual indicators of shared conversations

3. **Phone Number Verification**
   - Verify user's phone number before enabling SMS features
   - Prevents unauthorized access to SMS functionality

4. **Audit Trail**
   - Log all sharing/unsharing actions
   - Record who shared what and when

### 7.2 Security Measures

```dart
// Security service for SMS features
class SmsSecurity {
  /// Verify phone number via SMS code
  Future<bool> verifyPhoneNumber(String phoneNumber) async {
    // Implementation using Firebase Phone Auth or Twilio Verify
  }

  /// Check if current user can access SMS features
  Future<bool> canAccessSmsFeatures() async {
    final settings = await _settingsService.getSettings();
    return settings.verifiedPhoneNumber != null;
  }

  /// Encrypt SMS content for local storage
  String encryptSmsContent(String plainText) {
    // Use existing EncryptionService patterns
  }

  /// Log privacy-sensitive actions
  Future<void> logSmsAction(String action, Map<String, dynamic> details) async {
    // Log to privacy_activity collection
  }
}
```

### 7.3 Firestore Security Rules

```javascript
// Additional rules for SMS sharing
match /hubs/{hubId}/sms_shares/{shareId} {
  // Only authenticated users can read shares in hubs they belong to
  allow read: if isAuthenticated() && isHubMember(hubId);
  
  // Only the share owner can create/update/delete their shares
  allow create, update, delete: if isAuthenticated() && 
    request.auth.uid == resource.data.sharedBy;
}

// SMS messages in hub (when shared)
match /hubs/{hubId}/messages/{messageId} {
  // Allow read if user is hub member
  allow read: if isAuthenticated() && isHubMember(hubId);
  
  // For SMS shares, only the sharer can modify
  allow update, delete: if isAuthenticated() && 
    (resource.data.senderId == request.auth.uid);
}
```

### 7.4 Data Retention

- Local SMS cache: Configurable retention (default 90 days)
- Shared SMS in hubs: Follow hub message retention policies
- Unshared SMS: Removed from hub immediately, audit log retained

---

## 8. Database Schema

### 8.1 Firestore Collections

#### User SMS Settings
```
users/{userId}/settings/sms
{
  syncEnabled: boolean,
  showInUnifiedFeed: boolean,
  lastSyncAt: timestamp,
  syncIntervalMinutes: number,
  notificationsEnabled: boolean,
  verifiedPhoneNumber: string | null,
  defaultShareHubIds: string[],
  autoShareNewConversations: boolean,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### Hub SMS Shares
```
hubs/{hubId}/sms_shares/{userId_threadId}
{
  threadId: string,
  sharedBy: string (userId),
  sharedAt: timestamp,
  isActive: boolean,
  unsharedAt: timestamp | null,
  contactName: string | null,
  phoneNumber: string
}
```

#### SMS Messages in Hub (when shared)
```
hubs/{hubId}/messages/{messageId}
{
  // Standard ChatMessage fields
  id: string,
  senderId: string,
  senderName: string,
  content: string,
  timestamp: timestamp,
  type: string,
  
  // SMS-specific fields
  isSmsShare: boolean,
  smsThreadId: string,
  smsAddress: string,
  smsDirection: string,
  smsOriginalTimestamp: timestamp,
  isSmsShareRemoved: boolean,
  removedAt: timestamp | null
}
```

### 8.2 Local Hive Schema

```dart
// Hive type adapters (auto-generated)
// TypeId 20: SmsMessage
// TypeId 21: SmsConversation
// TypeId 22: DeviceContact

// Box names
const String smsMessagesBox = 'sms_messages';
const String smsConversationsBox = 'sms_conversations';
const String contactsCacheBox = 'contacts_cache';
const String smsSettingsBox = 'sms_settings';
```

---

## 9. Implementation Phases

### Phase 1: Foundation (Week 1-2)
**Goal:** Core infrastructure and permissions

- [ ] Create data models with Hive adapters
- [ ] Implement platform channel for Android SMS access
- [ ] Implement ContactsService
- [ ] Add Android manifest permissions
- [ ] Create SMS Settings screen with toggles
- [ ] Phone number verification flow

**Deliverables:**
- Working permission requests
- Contact picker functionality
- Settings persistence

### Phase 2: SMS Reading & Sync (Week 3-4)
**Goal:** Read and sync SMS messages

- [ ] Implement SmsService.readDeviceSms()
- [ ] Implement background sync with Workmanager
- [ ] Create SMS conversations list screen
- [ ] Create SMS conversation detail screen
- [ ] Local storage with Hive

**Deliverables:**
- Users can view SMS in app
- Background sync working
- Conversation threading

### Phase 3: SMS Sending (Week 5)
**Goal:** Send SMS from app

- [ ] Implement SmsService.sendSms()
- [ ] Compose message UI
- [ ] Delivery status tracking
- [ ] Contact selection flow

**Deliverables:**
- Working SMS sending
- Status updates in UI

### Phase 4: Hub Sharing (Week 6-7)
**Goal:** Share SMS to family hubs

- [ ] Implement SmsShareService
- [ ] Per-conversation share toggles
- [ ] Sync shared messages to Firestore
- [ ] Display shared SMS in hub feed
- [ ] Privacy indicators

**Deliverables:**
- Share/unshare functionality
- SMS visible in hub when shared
- Clear privacy controls

### Phase 5: Unified Feed (Week 8)
**Goal:** Integrate with existing chat/feed

- [ ] Add SMS tab to ChatTabsScreen
- [ ] Show SMS in unified feed (if enabled)
- [ ] Visual differentiation for SMS
- [ ] Filter options (All/In-App/SMS)

**Deliverables:**
- Seamless integration with existing UI
- Consistent user experience

### Phase 6: Polish & Testing (Week 9-10)
**Goal:** Production readiness

- [ ] Comprehensive testing
- [ ] Performance optimization
- [ ] Edge case handling
- [ ] Documentation
- [ ] App Store compliance check (especially iOS)

**Deliverables:**
- Production-ready feature
- Test coverage
- Documentation

---

## 10. Testing Strategy

### 10.1 Unit Tests

```dart
// test/services/sms_service_test.dart
void main() {
  group('SmsService', () {
    test('should normalize phone numbers correctly', () {
      expect(normalizePhone('(555) 123-4567'), equals('+15551234567'));
      expect(normalizePhone('555-123-4567'), equals('+15551234567'));
      expect(normalizePhone('+1 555 123 4567'), equals('+15551234567'));
    });

    test('should parse SMS message from native', () {
      final nativeData = {
        'id': '123',
        'address': '+15551234567',
        'body': 'Hello!',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 1,
      };
      
      final message = SmsMessage.fromNative(nativeData, 'userId');
      expect(message.direction, equals(SmsDirection.incoming));
    });
  });
}
```

### 10.2 Integration Tests

```dart
// test/integration/sms_integration_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SMS sync flow', (tester) async {
    // Enable SMS sync
    // Verify permission dialog
    // Check messages appear in list
    // Verify conversation threading
  });

  testWidgets('SMS sharing flow', (tester) async {
    // Open conversation
    // Tap share to hub
    // Select hub
    // Verify message appears in hub
  });
}
```

### 10.3 Manual Test Cases

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| TC-001: Enable SMS Sync | Settings > SMS > Enable Sync | Permission dialog shown, SMS loaded |
| TC-002: Send SMS | Open compose, select contact, send | Message sent, status updated |
| TC-003: Share to Hub | Conversation > Share > Select hub | SMS appears in hub |
| TC-004: Unshare | Conversation > Unshare | SMS removed from hub |
| TC-005: Unified Feed | Enable "Show in Feed" | SMS shows in main feed |
| TC-006: Background Sync | Leave app, receive SMS | New SMS synced on return |

---

## 11. Dependencies & Packages

### 11.1 New Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  # Existing dependencies preserved...
  
  # NEW: SMS & Contacts (for Android platform channel implementation)
  # No external packages needed - using platform channels
  
  # Optional: For international phone number parsing/validation
  phone_numbers_parser: ^8.2.0
```

### 11.2 Platform Channel Setup

**Android (Kotlin):**

Create `android/app/src/main/kotlin/.../SmsChannel.kt`:

```kotlin
class SmsChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.familyhub/sms"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasSmsPermissions" -> result.success(hasSmsPermissions())
            "requestSmsPermissions" -> requestSmsPermissions(result)
            "readSmsMessages" -> readSmsMessages(call, result)
            "sendSms" -> sendSms(call, result)
            else -> result.notImplemented()
        }
    }

    private fun hasSmsPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) == 
            PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) == 
            PackageManager.PERMISSION_GRANTED
    }
    
    // Additional implementation...
}
```

---

## 12. Risk Assessment

### 12.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| iOS SMS restrictions | High | High | iOS-specific UX explaining limitations |
| Android permission changes | Medium | Medium | Target appropriate SDK, test on multiple versions |
| Background sync battery impact | Medium | Low | Configurable intervals, battery optimization |
| Large SMS volume performance | Low | Medium | Pagination, lazy loading, indexing |
| Phone number format variations | Medium | Low | Robust normalization, libphonenumber |

### 12.2 Privacy/Compliance Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| User shares sensitive SMS accidentally | Medium | High | Confirmation dialogs, clear indicators |
| SMS data breach | Low | Critical | Local encryption, minimal cloud storage |
| App Store rejection (iOS) | Medium | High | Clear value proposition, follow guidelines |
| GDPR/CCPA compliance | Medium | High | Clear consent flows, data export/delete |

### 12.3 User Experience Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Confusion about what's shared | High | Medium | Clear visual indicators, onboarding |
| Feature complexity | Medium | Medium | Progressive disclosure, simple defaults |
| Slow sync performance | Low | Medium | Background sync, optimistic UI |

---

## 13. Appendix: Code Templates

### 13.1 Native Android SMS Reader

```kotlin
// android/app/src/main/kotlin/.../SmsReader.kt

package com.familyhub.mvp.sms

import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.Telephony

class SmsReader(private val context: Context) {
    
    fun readMessages(limit: Int = 100, since: Long? = null): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.THREAD_ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ
        )
        
        var selection: String? = null
        var selectionArgs: Array<String>? = null
        
        if (since != null) {
            selection = "${Telephony.Sms.DATE} > ?"
            selectionArgs = arrayOf(since.toString())
        }
        
        val sortOrder = "${Telephony.Sms.DATE} DESC LIMIT $limit"
        
        context.contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                messages.add(mapOf(
                    "id" to cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms._ID)),
                    "threadId" to cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)),
                    "address" to cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)),
                    "body" to cursor.getString(cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)),
                    "timestamp" to cursor.getLong(cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)),
                    "type" to cursor.getInt(cursor.getColumnIndexOrThrow(Telephony.Sms.TYPE)),
                    "read" to cursor.getInt(cursor.getColumnIndexOrThrow(Telephony.Sms.READ))
                ))
            }
        }
        
        return messages
    }
}
```

### 13.2 SMS Settings Screen Template

```dart
// lib/screens/settings/sms_settings_screen.dart

import 'package:flutter/material.dart';
import '../../services/sms_service.dart';
import '../../services/sms_settings_service.dart';
import '../../models/sms_settings.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  final SmsService _smsService = SmsService();
  final SmsSettingsService _settingsService = SmsSettingsService();
  
  SmsSettings? _settings;
  bool _isLoading = true;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final settings = await _settingsService.getSettings();
      final hasPermissions = await _smsService.hasPermissions();
      
      if (mounted) {
        setState(() {
          _settings = settings;
          _hasPermissions = hasPermissions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSmsSync(bool enabled) async {
    if (enabled && !_hasPermissions) {
      final granted = await _smsService.requestPermissions();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission required'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _hasPermissions = true);
    }
    
    await _settingsService.updateSettings(
      _settings!.copyWith(syncEnabled: enabled),
    );
    
    if (enabled) {
      await SmsBackgroundSyncService.registerPeriodicSync(
        intervalMinutes: _settings!.syncIntervalMinutes,
      );
      await SmsBackgroundSyncService.triggerSync();
    } else {
      await SmsBackgroundSyncService.cancelPeriodicSync();
    }
    
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('SMS Integration')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SMS Integration')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          // Platform warning for iOS
          if (!_smsService.isAvailable)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: AppTheme.spacingSM),
                    const Expanded(
                      child: Text(
                        'SMS features are only available on Android devices.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (_smsService.isAvailable) ...[
            // SMS Sync Toggle
            Card(
              child: SwitchListTile(
                title: const Text('SMS Sync'),
                subtitle: const Text('Sync SMS messages to this app'),
                value: _settings?.syncEnabled ?? false,
                onChanged: _toggleSmsSync,
                secondary: const Icon(Icons.sms),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            // Show in Unified Feed Toggle
            Card(
              child: SwitchListTile(
                title: const Text('Show in Unified Feed'),
                subtitle: const Text('Display SMS in your main message feed'),
                value: _settings?.showInUnifiedFeed ?? false,
                onChanged: _settings?.syncEnabled == true
                    ? (value) async {
                        await _settingsService.updateSettings(
                          _settings!.copyWith(showInUnifiedFeed: value),
                        );
                        await _loadSettings();
                      }
                    : null,
                secondary: const Icon(Icons.feed),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            // Sync Interval
            Card(
              child: ListTile(
                title: const Text('Sync Interval'),
                subtitle: Text('Every ${_settings?.syncIntervalMinutes ?? 5} minutes'),
                leading: const Icon(Icons.timer),
                trailing: const Icon(Icons.chevron_right),
                enabled: _settings?.syncEnabled == true,
                onTap: () => _showIntervalPicker(),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            // Privacy Note
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock, color: Colors.blue.shade700),
                        const SizedBox(width: AppTheme.spacingSM),
                        Text(
                          'Privacy',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Your SMS messages are stored securely on your device. '
                      'They are never shared with your family unless you explicitly '
                      'choose to share a conversation with a hub.',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingLG),
            
            // Open SMS Inbox Button
            if (_settings?.syncEnabled == true)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/sms/conversations');
                },
                icon: const Icon(Icons.inbox),
                label: const Text('Open SMS Inbox'),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _showIntervalPicker() async {
    final intervals = [1, 5, 15, 30, 60];
    final result = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sync Interval'),
        children: intervals.map((interval) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, interval),
          child: Text('Every $interval ${interval == 1 ? 'minute' : 'minutes'}'),
        )).toList(),
      ),
    );
    
    if (result != null) {
      await _settingsService.updateSettings(
        _settings!.copyWith(syncIntervalMinutes: result),
      );
      await _loadSettings();
    }
  }
}
```

---

## Summary

This implementation plan provides a comprehensive roadmap for adding SMS integration to the FamilyHub app. Key highlights:

1. **Privacy-First Design**: SMS messages remain private unless explicitly shared
2. **Seamless Integration**: Follows existing architectural patterns in the codebase
3. **Platform Awareness**: Full Android support, graceful iOS limitations
4. **Phased Rollout**: 10-week implementation timeline with clear milestones
5. **Security Focus**: Local encryption, minimal cloud storage, audit trails

The implementation leverages existing infrastructure (Hive, Workmanager, Firestore patterns) while introducing new platform channel-based native SMS access for Android.

---

*Document prepared for FamilyHub MVP development team*
*Last updated: December 18, 2025*
