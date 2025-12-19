# Pets Hub - Comprehensive Design Document

**Version:** 1.0  
**Date:** December 19, 2025  
**Status:** 🚧 Design Phase  
**Classification:** Feature Specification

---

## 🎯 Executive Summary

The Pets Hub is a comprehensive pet management system integrated into Family Hub, allowing families to track and manage their pets' information, health records, and care schedules. The hub follows the freemium model with basic features free and advanced health/document management as premium features.

### Vision
Create a seamless, family-friendly pet management hub that centralizes all pet-related information, making it easy for families to care for their pets together while providing premium tools for comprehensive health management.

---

## 📋 Feature Overview

### Free Tier Features
- ✅ **Pet Profiles**
  - Pet name, species/breed, date of birth (or adoption date)
  - Pet photos (multiple photos per pet)
  - Basic info: gender, color, weight, size
  - Pet bio/notes
  - Microchip number (display only)
  - Emergency contact info (optional)
  - Vet contact info (optional)

- ✅ **Multi-Pet Management**
  - Add up to 3 pets per hub (free tier limit)
  - View all pets in hub
  - Quick access to each pet's profile
  - Premium: Unlimited pets

- ✅ **Basic Health Info**
  - Current weight
  - Basic medical notes (free text)
  - Last vet visit date

- ✅ **Photo Gallery**
  - Upload multiple photos per pet
  - Auto-create photo album per pet (accessible via Photos screen)
  - Each pet has separate album
  - View pet photo gallery
  - Set primary photo

- ✅ **Family Sharing**
  - All hub members can view pets
  - Only Parent/Admin roles can add/edit pets
  - View-only access for regular members

### Premium Tier Features
- 🔒 **Medication Management**
  - Add medication schedules
  - Set reminders for medications
  - Track medication history
  - Dosage and frequency tracking
  - Medication notes

- 🔒 **Document Storage**
  - Upload vet records (PDF, images)
  - Upload vaccination certificates
  - Upload insurance documents
  - Upload microchip registration
  - Upload adoption papers
  - Upload other documents (catch-all category)
  - Organize documents by category
  - View/download documents

- 🔒 **Advanced Health Tracking**
  - Vaccination schedule with reminders
  - Vet appointment tracking (integrated with main calendar)
  - Health event timeline
  - Medication history
  - Weight tracking over time (with charts) - Premium feature
  - Allergy tracking
  - Chronic condition management
  - Activity tracking: feeding schedules, walks, exercise

- 🔒 **Reminders & Notifications**
  - Medication reminders
  - Vaccination due date reminders
  - Vet appointment reminders
  - Grooming appointment reminders
  - Pet birthday reminders
  - Custom reminders (e.g., flea treatment, heartworm prevention)

- 🔒 **Vet Contact Management**
  - Store multiple vet contacts per pet
  - Emergency vet contacts
  - Vet appointment history
  - Quick call/email vet from app

---

## 🏗️ Technical Architecture

### Models

#### Pet Model
```dart
class Pet {
  final String id;
  final String hubId;
  final String name;
  final PetType type; // dog, cat, bird, fish, rabbit, horse, reptile, insect, other
  final String? breed;
  final DateTime? dateOfBirth;
  final DateTime? adoptionDate;
  final String? gender; // male, female, unknown
  final String? color;
  final double? currentWeight;
  final String? size; // small, medium, large, extra-large
  final String? microchipNumber;
  final String? bio;
  final String? primaryPhotoUrl;
  final List<String> photoUrls;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Optional emergency/vet info (free tier)
  final String? emergencyContact;
  final String? emergencyPhone;
  final VetContact? primaryVet; // Basic vet contact (free tier)
  
  // Premium fields
  final List<MedicationSchedule>? medications;
  final List<PetDocument>? documents;
  final List<HealthEvent>? healthEvents;
  final List<VetContact>? vetContacts; // Multiple vets (premium)
  final List<WeightEntry>? weightHistory;
  final List<ActivitySchedule>? activitySchedules; // Feeding, walks, exercise
}
```

#### MedicationSchedule Model
```dart
class MedicationSchedule {
  final String id;
  final String petId;
  final String medicationName;
  final String dosage;
  final MedicationFrequency frequency; // daily, twice_daily, weekly, etc.
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final bool isActive;
  final List<DateTime>? reminderTimes; // e.g., [08:00, 20:00]
}
```

#### PetDocument Model
```dart
class PetDocument {
  final String id;
  final String petId;
  final String fileName;
  final String fileUrl;
  final DocumentType type; // vet_record, vaccination, insurance, microchip, adoption, other
  final DateTime uploadDate;
  final String? description;
  final DateTime? documentDate; // Date on document (e.g., vaccination date)
}
```

#### HealthEvent Model
```dart
class HealthEvent {
  final String id;
  final String petId;
  final HealthEventType type; // vaccination, vet_visit, medication, illness, surgery, other
  final DateTime eventDate;
  final String? title;
  final String? description;
  final String? vetName;
  final double? cost;
  final List<String>? documentIds; // Links to PetDocument
}
```

#### VetContact Model
```dart
class VetContact {
  final String id;
  final String petId;
  final String name;
  final String? clinicName;
  final String? phoneNumber;
  final String? email;
  final String? address;
  final bool isPrimary;
  final bool isEmergency;
}
```

#### WeightEntry Model
```dart
class WeightEntry {
  final String id;
  final String petId;
  final double weight;
  final DateTime recordedDate;
  final String? notes;
}
```

#### ActivitySchedule Model
```dart
class ActivitySchedule {
  final String id;
  final String petId;
  final ActivityType type; // feeding, walk, exercise, grooming, other
  final String name; // e.g., "Morning Walk", "Breakfast"
  final ActivityFrequency frequency; // daily, twice_daily, weekly, custom
  final List<DateTime>? reminderTimes; // e.g., [08:00, 20:00]
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final bool isActive;
}
```

#### ActivityType & ActivityFrequency Enums
```dart
enum ActivityType {
  feeding,
  walk,
  exercise,
  grooming,
  other,
}

enum ActivityFrequency {
  onceDaily,
  twiceDaily,
  threeTimesDaily,
  weekly,
  monthly,
  custom,
}
```

### Enums

```dart
enum PetType {
  dog,
  cat,
  bird,
  fish,
  rabbit,
  horse,
  reptile,
  insect,
  other,
}

enum MedicationFrequency {
  onceDaily,
  twiceDaily,
  threeTimesDaily,
  weekly,
  monthly,
  asNeeded,
  custom,
}

enum DocumentType {
  vetRecord,
  vaccination,
  insurance,
  microchip,
  adoption,
  other, // Catch-all for any other document type
}

enum HealthEventType {
  vaccination,
  vetVisit,
  medication,
  illness,
  surgery,
  grooming,
  other,
}
```

---

## 📱 User Interface Design

### Main Pets Hub Screen
- **Header**: "Pets Hub" with pet count
- **Pet Grid/List**: 
  - Card view showing pet photo, name, type
  - Tap to view pet details
  - Add Pet button (prominent)
- **Quick Stats** (if pets exist):
  - Upcoming medications (next 24 hours)
  - Upcoming vet appointments (next 7 days)
  - Overdue vaccinations

### Pet Detail Screen
- **Header**: Pet photo, name, type/breed
- **Tabs**:
  1. **Overview** (Free)
     - Basic info
     - Current weight
     - Last vet visit
     - Recent photos
     - Bio/notes
   
  2. **Health** (Premium)
     - Medication schedules (with reminders)
     - Vaccination schedule
     - Health event timeline
     - Weight chart
     - Allergies/conditions
   
  3. **Documents** (Premium)
     - Document categories
     - Upload document button
     - Document list with preview
   
  4. **Vets** (Premium)
     - Vet contact list
     - Add vet button
     - Quick actions (call, email)
   
  5. **Photos** (Free)
     - Photo gallery
     - Upload photo button
     - Set primary photo

### Add/Edit Pet Screen
- **Basic Info Section** (Free):
  - Name (required)
  - Type (dropdown: Dog, Cat, Bird, Fish, Rabbit, Horse, Reptile, Insect, Other)
  - Breed (text input, optional)
  - Date of Birth OR Adoption Date (date picker)
  - Gender (dropdown: Male, Female, Unknown)
  - Color (text input, optional)
  - Current Weight (number input, optional)
  - Size (dropdown: Small, Medium, Large, Extra-Large)
  - Microchip Number (text input, optional)
  - Bio/Notes (multiline text, optional)
  - Primary Photo (image picker)
  - Emergency Contact (optional, text input)
  - Emergency Phone (optional, phone input)
  - Basic Vet Contact (optional, free tier - single vet)

- **Premium Sections** (gated):
  - Medication Schedules
  - Multiple Vet Contacts
  - Initial Health Events
  - Activity Schedules (feeding, walks, exercise, grooming)
  - Document Upload

---

## 🔐 Premium Feature Gating

### Implementation
- Use `PremiumFeatureGate` widget for premium sections
- Check `SubscriptionService.hasActiveSubscription()`
- Show upgrade prompt for premium features
- Graceful degradation: Show basic info, hide premium sections

### Premium Feature Indicators
- Lock icon on premium tabs
- "Upgrade to Premium" badges
- Upgrade prompts with clear value proposition

---

## 📅 Integration Points

### Calendar Integration
- Vet appointments sync to main calendar (mandatory integration)
- Medication reminders can create calendar events (optional)
- Vaccination due dates as calendar events
- Grooming appointments sync to calendar
- Pet birthdays appear in calendar

### Notifications
- Push notifications for:
  - Medication reminders
  - Upcoming vet appointments
  - Vaccination due dates
  - Grooming appointment reminders
  - Pet birthday reminders
  - Activity reminders (feeding, walks, exercise)
  - Custom reminders

### Photo Storage
- Use Firebase Storage: `hubs/{hubId}/pets/{petId}/photos/{photoId}`
- Auto-create photo album per pet in Photos screen
- Each pet gets separate album
- Photos accessible via both Pets Hub and Photos screen
- Similar to existing photo service pattern

### Document Storage
- Use Firebase Storage: `hubs/{hubId}/pets/{petId}/documents/{documentId}`
- Support PDF, images (JPG, PNG)
- File size limits: 10MB per document

---

## 🗂️ Data Structure

### Firestore Collections

```
hubs/{hubId}/pets/{petId}
  - Basic pet info
  - References to subcollections
  - Pet limit: 3 for free tier, unlimited for premium

hubs/{hubId}/pets/{petId}/medications/{medicationId}
  - Medication schedules (premium)

hubs/{hubId}/pets/{petId}/documents/{documentId}
  - Document metadata (file stored in Storage) (premium)

hubs/{hubId}/pets/{petId}/healthEvents/{eventId}
  - Health event timeline (premium)

hubs/{hubId}/pets/{petId}/vetContacts/{contactId}
  - Vet contact information (premium - multiple vets)

hubs/{hubId}/pets/{petId}/weightHistory/{entryId}
  - Weight tracking entries (premium)

hubs/{hubId}/pets/{petId}/activitySchedules/{scheduleId}
  - Activity schedules (feeding, walks, exercise) (premium)
```

---

## 🎨 UI/UX Considerations

### Design Principles
- **Pet-Centric**: Each pet is a first-class entity
- **Family-Friendly**: Easy for all family members to use
- **Visual**: Photos are prominent
- **Quick Access**: Important info (medications, vet) easily accessible
- **Dark Mode**: Full dark mode support

### Empty States
- "No pets yet" with "Add Your First Pet" button
- "No medications" with "Add Medication" button (premium)
- "No documents" with "Upload Document" button (premium)

### Loading States
- Skeleton loaders for pet list
- Progress indicators for photo/document uploads

### Error Handling
- Clear error messages
- Retry mechanisms for uploads
- Offline support where possible

---

## 🔔 Reminder System

### Medication Reminders
- Configurable times (e.g., 8:00 AM, 8:00 PM)
- Push notifications
- In-app notification badge
- Mark as given functionality

### Vaccination Reminders
- Set reminder X days before due date
- Recurring reminders for annual vaccinations
- Link to vaccination document

### Vet Appointment Reminders
- Sync with calendar
- Reminder X days/hours before appointment
- Quick access to vet contact info

---

## 📊 Analytics & Insights (Future)

### Potential Premium Features
- Health trends over time
- Medication compliance tracking
- Cost tracking (vet visits, medications)
- Weight trend analysis
- Vaccination history reports

---

## 🚀 Implementation Phases

### Phase 1: Foundation (Free Tier)
- [ ] Pet model and service
- [ ] Basic pet CRUD operations
- [ ] Pet list/detail screens
- [ ] Photo upload and gallery
- [ ] Hub integration

### Phase 2: Premium Health Features
- [ ] Medication management
- [ ] Document storage
- [ ] Health event tracking
- [ ] Vet contact management
- [ ] Premium feature gating

### Phase 3: Reminders & Notifications
- [ ] Medication reminder system
- [ ] Vaccination reminders
- [ ] Vet appointment reminders
- [ ] Push notification integration

### Phase 4: Advanced Features
- [ ] Weight tracking with charts
- [ ] Calendar integration
- [ ] Health insights/analytics
- [ ] Export pet records (PDF)

---

## ✅ Design Decisions (Confirmed)

1. **Multiple Pets**: ✅ Multiple pets per hub
   - **Free Tier**: Limit of 3 pets per hub
   - **Premium Tier**: Unlimited pets

2. **Pet Types**: ✅ Dog, Cat, Bird, Fish, Rabbit, Horse, Reptile, Insect, Other

3. **Shared Access**: ✅ All hub members can view pets
   - **Edit Permissions**: Only Parent/Admin roles can add/edit pets
   - **View Access**: All members can view all pets

4. **Vet Appointments**: ✅ Integrate with main calendar (mandatory)

5. **Activity Tracking**: ✅ All activity types included
   - Feeding schedules
   - Walk schedules
   - Exercise tracking
   - Grooming appointments

6. **Photo Storage**: ✅ Per-pet albums
   - Auto-create photo album per pet
   - Accessible via Photos screen
   - Each pet has separate album

7. **Document Types**: ✅ All types supported
   - Vet records
   - Vaccination certificates
   - Insurance documents
   - Microchip registration
   - Adoption papers
   - Other (catch-all category)

8. **Reminders**: ✅ Comprehensive reminder system
   - Medication reminders
   - Vaccination due dates
   - Vet appointments
   - Grooming appointments
   - Pet birthdays
   - Custom reminders

9. **Weight Tracking**: ✅ Premium feature with charts
   - Track weight over time
   - Visual charts/graphs
   - Premium users only

10. **Emergency Info**: ✅ Optional in edit screen
    - Emergency contact info
    - Vet contact info
    - Microchip number
    - All optional fields

---

## 📝 Next Steps

1. ✅ **Get User Feedback** on design and assumptions - **COMPLETE**
2. ✅ **Refine Design** based on feedback - **COMPLETE**
3. **Create Detailed Implementation Plan** - Next step
4. ✅ **Add to Strategic Roadmap** - **COMPLETE** (Phase 7)
5. **Update Hub Type Registry** - Pending implementation
6. **Begin Phase 1 Implementation** - Pending

---

## 🔗 Related Documents

- `STRATEGIC_ROADMAP.md` - Overall roadmap (Phase 7 added)
- `ROADMAP_IMPLEMENTATION_TRACKER.md` - Implementation status (Phase 7 added)
- `lib/models/hub.dart` - Hub model structure (needs `HubType.pets` addition)
- `lib/services/subscription_service.dart` - Premium feature gating

---

## 📊 Design Summary

**Free Tier:**
- Up to 3 pets per hub
- Basic pet profiles with photos
- Per-pet photo albums (auto-created)
- View access for all members
- Edit access: Parent/Admin only

**Premium Tier:**
- Unlimited pets
- Medication management with reminders
- Document storage (all types including "Other")
- Advanced health tracking with weight charts
- Activity tracking (feeding, walks, exercise, grooming)
- Multiple vet contacts
- Comprehensive reminder system (medications, vaccinations, vet appointments, grooming, birthdays)
- Calendar integration (mandatory for vet appointments)

**Pet Types Supported:**
Dog, Cat, Bird, Fish, Rabbit, Horse, Reptile, Insect, Other

**Status**: ✅ Design complete and confirmed. Ready for implementation planning.

