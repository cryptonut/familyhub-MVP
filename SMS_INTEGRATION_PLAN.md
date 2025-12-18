# SMS Integration Implementation Plan

## 1. Executive Summary

This document outlines the technical plan to integrate device SMS capabilities into the Family Hub application. The goal is to provide a unified messaging experience where users can view and send SMS messages directly from the app's chat interface, while maintaining strict privacy boundaries where SMS messages remain local to the user's device unless explicitly shared.

## 2. Architecture & Design

### 2.1. System Overview

The solution involves a "Dual-Stream" architecture:
1.  **Remote Stream**: The existing Firestore-based chat for family communications.
2.  **Local Stream**: A new local-only stream of SMS messages fetched directly from the device.

These two streams will be merged at the Service layer (`ChatService`) to present a unified list to the UI, ensuring seamless integration.

### 2.2. Data Model Updates

#### `ChatMessage` Model
We will extend the existing `ChatMessage` model to support local SMS data without polluting the database schema for non-shared messages.

```dart
class ChatMessage {
  // ... existing fields ...
  
  // New Fields for SMS Support
  final bool isSms;           // Distinguishes SMS from App Chat
  final bool isLocal;         // true = device only, false = in Firestore
  final String? phoneNumber;  // The external phone number (sender/recipient)
  final String? threadId;     // Android SMS thread ID (mapped to internal ID)
  
  // ... existing constructor ...
}
```

#### `UserModel` (Optional but Recommended)
To better identify family members in SMS threads, we should ideally allow users to add their mobile numbers to their profile.
- `String? mobileNumber;` added to `UserModel`.

### 2.3. New Services

#### `SmsService`
Handles all interaction with the device's telephony capabilities.
- **Responsibilities**:
  - Request/Check Permissions (`READ_SMS`, `SEND_SMS`, `READ_CONTACTS`).
  - `fetchSmsThreads()`: Retrieve SMS conversations (Android).
  - `sendSms(String address, String body)`: Send message via device default gateway.
  - `listenForIncomingSms()`: Stream new incoming messages (Android).
  - *Note on iOS*: Due to OS restrictions, full background sync of incoming SMS is not possible. The feature will be Android-focused for sync, while "Send via SMS" can be supported on both platforms.

#### `ContactService`
Handles resolving phone numbers to names and avatars.
- **Responsibilities**:
  - `getContact(String phoneNumber)`: Returns name/photo from device address book.
  - Cache results to minimize device lookups.

### 2.4. Service Layer Integration (`ChatService`)

The `ChatService` will be the single source of truth for the UI.

- **Unified Stream**:
  ```dart
  Stream<List<ChatMessage>> getUnifiedMessagesStream(String familyId) {
    return Rx.combineLatest2(
      getFirestoreMessages(familyId),
      _smsService.getSmsStream(), // Returns [] if SMS sync disabled
      (firestoreMsgs, smsMsgs) => _mergeAndSort(firestoreMsgs, smsMsgs)
    );
  }
  ```
- **Sending Logic**:
  - If `isSms` mode is active, route through `SmsService`.
  - Otherwise, route through standard Firestore `add()`.

## 3. User Experience (UX)

### 3.1. Setup & Onboarding
- **Toggle in Settings**: "Sync SMS Messages".
- **Permission Request**: Explain *why* permissions are needed (Privacy focused).
- **Identity Confirmation**: User inputs their own number (to identify "Me" in SMS threads) or selects "This Device".

### 3.2. Chat Interface
- **Unified Feed**: SMS messages appear chronologically with Family Chats.
- **Visual Distinction**: SMS messages have a subtle icon (e.g., SIM card or bubble color variant) to distinguish them.
- **Privacy by Default**: SMS messages are visible *only* to the current user.
- **"Share to Family"**: A specific action on an SMS message allows the user to upload it to the Family Chat, making it visible to everyone.

### 3.3. Sending
- **Input Switcher**: A toggle near the input field or send button to switch between "Family Chat" (Cloud) and "SMS" (Carrier).
- **Recipient Selection**: When sending SMS, if not in an existing SMS thread, prompt to select from Device Contacts.

## 4. Security & Privacy

1.  **Local-First Principle**: SMS data is never uploaded to Firestore automatically. It is read into memory/local cache only.
2.  **Explicit Sharing**: Upload code is only triggered by a distinct user action ("Share").
3.  **Permissions**: We strictly request only necessary permissions. If denied, the feature disables gracefully.
4.  **Data Minimization**: We do not store the user's entire contact list, only cache what is needed for active threads.

## 5. Implementation Roadmap

### Phase 1: Foundation (Dependencies & Models)
- Add dependencies: `flutter_contacts`, `telephony` (Android), `permission_handler`.
- Update `ChatMessage` model.
- Configure Android Manifest (permissions).

### Phase 2: Service Layer
- Implement `ContactService` to fetch and cache device contacts.
- Implement `SmsService` for Android SMS retrieval and sending.
- Update `ChatService` to merge streams.

### Phase 3: UI Implementation
- Update `ChatWidget` to render SMS variants.
- Add "Share" functionality.
- Add "Send Mode" toggle in input area.
- Add Settings toggle for the feature.

### Phase 4: Testing & Polish
- Unit tests for stream merging logic.
- Device testing on Android (Physical device required for accurate SMS testing).
- Handle edge cases (Dual SIM, formatting differences).

## 6. Constraints & Considerations
- **iOS Limitations**: Full SMS inbox sync is not possible on iOS. We will hide the "Sync" toggle on iOS or display a "Send Only" mode.
- **Cost**: SMS sending costs standard carrier rates.
