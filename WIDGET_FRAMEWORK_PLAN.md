# Widget Framework Architecture - Implementation Plan
**Phase:** 1.4  
**Status:** 🚧 In Progress  
**Priority:** High (Required for Phase 2-4 Premium Hubs)

---

## 🎯 Objective

Create a cross-platform widget framework that enables single-click access to premium hub features from the device home screen. Widgets will display hub-specific information (events, messages, tasks) and provide deep linking to the app.

---

## 📋 Implementation Plan

### Step 1: Android Widget Foundation

#### 1.1 Create Android Widget Provider
- **File:** `android/app/src/main/kotlin/com/example/familyhub_mvp/widgets/FamilyHubWidgetProvider.kt`
- **Purpose:** Main widget provider class extending `AppWidgetProvider`
- **Features:**
  - Handle widget updates
  - Handle widget tap actions (deep linking)
  - Handle widget configuration

#### 1.2 Create Widget Configuration Activity
- **File:** `android/app/src/main/kotlin/com/example/familyhub_mvp/widgets/WidgetConfigurationActivity.kt`
- **Purpose:** Allow users to select which hub/widget type to display
- **Features:**
  - Hub selection UI
  - Widget size selection
  - Display preferences (events, messages, tasks)

#### 1.3 Create Widget Layouts
- **Files:** `android/app/src/main/res/layout/`
  - `widget_family_hub_small.xml` (1x1)
  - `widget_family_hub_medium.xml` (2x1)
  - `widget_family_hub_large.xml` (2x2)
- **Purpose:** Define widget UI layouts
- **Content:**
  - Hub name
  - Upcoming events (next 2-3)
  - Unread message count
  - Quick action button

#### 1.4 Create Widget Update Service
- **File:** `android/app/src/main/kotlin/com/example/familyhub_mvp/widgets/WidgetUpdateService.kt`
- **Purpose:** Background service to update widget data
- **Features:**
  - Fetch hub data from Firestore
  - Update widget views
  - Handle update frequency (every 15-30 minutes)

#### 1.5 Update AndroidManifest.xml
- Add widget provider declaration
- Add configuration activity
- Add update service
- Add deep link intent filters

---

### Step 2: Flutter Widget Service

#### 2.1 Create WidgetConfigurationService
- **File:** `lib/services/widget_configuration_service.dart`
- **Purpose:** Manage widget configurations in Firestore
- **Methods:**
  - `saveWidgetConfig(String widgetId, WidgetConfig config)`
  - `getWidgetConfig(String widgetId)`
  - `deleteWidgetConfig(String widgetId)`
  - `getUserWidgets(String userId)`

#### 2.2 Create WidgetConfig Model
- **File:** `lib/models/widget_config.dart`
- **Purpose:** Data model for widget configuration
- **Fields:**
  - `widgetId`: String
  - `userId`: String
  - `hubId`: String
  - `hubType`: String (family, extended_family, homeschooling, coparenting)
  - `widgetSize`: String (small, medium, large)
  - `displayOptions`: Map<String, bool> (events, messages, tasks, photos)
  - `updateFrequency`: int (minutes)

#### 2.3 Create WidgetDataService
- **File:** `lib/services/widget_data_service.dart`
- **Purpose:** Fetch and format data for widgets
- **Methods:**
  - `getWidgetData(String hubId, WidgetConfig config)`
  - `getUpcomingEvents(String hubId, int limit)`
  - `getUnreadMessageCount(String hubId)`
  - `getPendingTasksCount(String hubId)`

---

### Step 3: Deep Linking

#### 3.1 Create DeepLinkService
- **File:** `lib/services/deep_link_service.dart`
- **Purpose:** Handle deep links from widgets
- **Methods:**
  - `handleDeepLink(Uri uri)`
  - `generateHubDeepLink(String hubId, String screen)`
  - `navigateToHub(String hubId, String? screen)`

#### 3.2 Update MainActivity.kt
- Add deep link intent handling
- Route to Flutter app with parameters

#### 3.3 Update Flutter Router
- Add deep link route handling
- Navigate to hub screens based on deep link

---

### Step 4: iOS Widget (Future)

#### 4.1 Create WidgetKit Extension
- **File:** `ios/Widgets/FamilyHubWidget.swift`
- **Purpose:** iOS widget using WidgetKit
- **Note:** Will be implemented after Android widget is complete

---

## 🏗️ Architecture

### Data Flow
```
Widget (Android) 
  → WidgetUpdateService 
    → Firestore (read hub data)
      → Update Widget Views
        → User sees updated widget
          → User taps widget
            → Deep Link Intent
              → Flutter App
                → Navigate to Hub Screen
```

### Configuration Flow
```
User adds widget
  → WidgetConfigurationActivity opens
    → User selects hub/widget type
      → WidgetConfigurationService saves config
        → WidgetUpdateService fetches data
          → Widget displays hub information
```

---

## 📦 Dependencies

### Android
- No additional dependencies (uses native Android App Widget framework)

### Flutter
- No additional dependencies (uses existing Firestore, Auth services)

---

## 🧪 Testing Plan

### Unit Tests
- [ ] WidgetConfigurationService tests
- [ ] WidgetDataService tests
- [ ] DeepLinkService tests

### Integration Tests
- [ ] Widget update flow
- [ ] Deep link navigation
- [ ] Configuration persistence

### Manual Testing
- [ ] Add widget to home screen
- [ ] Configure widget (select hub)
- [ ] Verify widget updates with hub data
- [ ] Tap widget → verify app opens to correct hub
- [ ] Test different widget sizes
- [ ] Test update frequency

---

## 📝 Implementation Checklist

### Phase 1: Android Foundation
- [ ] Create `FamilyHubWidgetProvider.kt`
- [ ] Create `WidgetConfigurationActivity.kt`
- [ ] Create widget layout XML files (small, medium, large)
- [ ] Create `WidgetUpdateService.kt`
- [ ] Update `AndroidManifest.xml`
- [ ] Test basic widget display

### Phase 2: Flutter Integration
- [ ] Create `WidgetConfigurationService`
- [ ] Create `WidgetConfig` model
- [ ] Create `WidgetDataService`
- [ ] Test configuration persistence

### Phase 3: Deep Linking
- [ ] Create `DeepLinkService`
- [ ] Update `MainActivity.kt` for deep links
- [ ] Update Flutter router for deep links
- [ ] Test deep link navigation

### Phase 4: Polish & Testing
- [ ] Add error handling
- [ ] Add loading states
- [ ] Optimize update frequency
- [ ] Test on multiple devices
- [ ] Document widget usage

---

## 🎯 Success Criteria

1. ✅ Users can add Family Hub widget to Android home screen
2. ✅ Widget displays hub-specific information (events, messages)
3. ✅ Widget updates automatically (every 15-30 minutes)
4. ✅ Tapping widget opens app to correct hub screen
5. ✅ Widget configuration persists across app restarts
6. ✅ Multiple widgets can be configured (one per hub)

---

## 📅 Timeline

- **Week 1:** Android widget foundation (Provider, Layouts, Service)
- **Week 2:** Flutter integration (Configuration, Data services)
- **Week 3:** Deep linking & testing
- **Week 4:** Polish, optimization, documentation

**Total Estimated Effort:** 2-3 weeks

---

## 🔄 Future Enhancements

- iOS WidgetKit implementation
- Widget customization UI (in-app)
- Multiple widget types per hub
- Widget analytics (usage tracking)
- Widget refresh on-demand

---

**Next Steps:** Begin with Step 1.1 - Create Android Widget Provider

