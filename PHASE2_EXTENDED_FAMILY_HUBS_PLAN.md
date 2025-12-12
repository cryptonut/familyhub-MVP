# Phase 2: Extended Family Hubs - Implementation Plan
**Status:** 🚧 In Progress  
**Start Date:** December 12, 2025

---

## 🎯 Objective

Enable families to connect with extended family members (grandparents, aunts, uncles, cousins) in dedicated hubs with appropriate privacy controls and communication tools. This is the first premium hub type to be implemented.

---

## ✅ Completed Foundation

1. ✅ **Hub Model Extended** - Added `hubType` and `typeSpecificData` fields
2. ✅ **Widget Framework** - Complete and ready for hub-specific widgets
3. ✅ **Freemium Foundation** - SubscriptionService and PremiumFeatureGate ready
4. ✅ **Data Isolation** - FirestorePathUtils ready for hub-specific collections

---

## 📋 Implementation Checklist

### Step 1: Hub Type System ✅ **IN PROGRESS**
- [x] Extend Hub model with `hubType` enum
- [x] Add `typeSpecificData` field for hub-specific configuration
- [ ] Update HubService to handle hub types
- [ ] Add hub type validation in hub creation

### Step 2: Extended Family Hub Service
- [ ] Create `ExtendedFamilyHubService`
- [ ] Implement relationship tagging system
- [ ] Add extended family member invitation flow
- [ ] Implement privacy controls per member

### Step 3: Extended Family Hub UI
- [ ] Create hub creation screen with hub type selection
- [ ] Build extended family member management screen
- [ ] Create relationship tagging UI
- [ ] Build privacy controls UI

### Step 4: Widget Integration
- [ ] Extend widget configuration to support extended family hubs
- [ ] Update widget data service for extended family hubs
- [ ] Test widget with extended family hub

### Step 5: Premium Feature Gating
- [ ] Add PremiumFeatureGate to hub creation flow
- [ ] Verify subscription before creating extended family hub
- [ ] Show upgrade prompt if not subscribed

---

## 🏗️ Architecture

### Hub Type System
```
Hub
├── hubType: HubType (family, extended_family, homeschooling, coparenting)
├── typeSpecificData: Map<String, dynamic>
│   └── For extended_family:
│       ├── relationships: Map<userId, relationshipType>
│       ├── privacySettings: Map<userId, privacyLevel>
│       └── memberRoles: Map<userId, role>
```

### Extended Family Hub Data Model
```dart
class ExtendedFamilyHubData {
  final Map<String, String> relationships; // userId -> relationshipType
  final Map<String, PrivacyLevel> privacySettings; // userId -> privacyLevel
  final Map<String, ExtendedFamilyRole> memberRoles; // userId -> role
  final List<String> invitedMemberIds; // Pending invitations
}

enum RelationshipType {
  grandparent,
  aunt,
  uncle,
  cousin,
  sibling, // For extended family context
  other,
}

enum PrivacyLevel {
  minimal,    // Only basic info (name, birthday)
  standard,   // Events and photos (opt-in)
  full,       // Full access (like core family)
}

enum ExtendedFamilyRole {
  viewer,      // View-only access
  contributor, // Can add events, photos
  admin,       // Full management
}
```

---

## 📦 Files to Create

1. `lib/models/extended_family_hub_data.dart` - Extended family hub data model
2. `lib/services/extended_family_hub_service.dart` - Extended family hub service
3. `lib/screens/hubs/create_extended_family_hub_screen.dart` - Hub creation UI
4. `lib/screens/hubs/extended_family_member_management_screen.dart` - Member management
5. `lib/widgets/relationship_picker.dart` - Relationship selection widget
6. `lib/widgets/privacy_control_widget.dart` - Privacy settings widget

---

## 🔄 Next Steps

1. **Complete Hub Type System** - Update HubService to handle hub types
2. **Create Extended Family Hub Service** - Core service for extended family features
3. **Build Hub Creation UI** - Allow users to create extended family hubs
4. **Implement Member Management** - Invite, manage relationships, set privacy
5. **Add Premium Gating** - Ensure only subscribed users can create extended family hubs

---

**Estimated Time:** 2-3 weeks  
**Dependencies:** Widget Framework (✅ Complete), Freemium Foundation (✅ Complete)

