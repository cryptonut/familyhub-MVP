# iOS WidgetKit Setup Guide

## Overview

This guide explains how to set up the iOS Widget Extension for Family Hub widgets. The widget files have been created, but you need to configure the Xcode project to include the widget extension target.

## Files Created

1. `ios/WidgetExtension/FamilyHubWidget.swift` - Main widget implementation
2. `ios/WidgetExtension/HubConfigurationIntent.swift` - Widget configuration intent
3. `ios/WidgetExtension/WidgetDataService.swift` - Data fetching service
4. `ios/WidgetExtension/Info.plist` - Widget extension Info.plist

## Xcode Setup Steps

### 1. Add Widget Extension Target

1. Open `ios/Runner.xcworkspace` in Xcode
2. File → New → Target
3. Select "Widget Extension"
4. Click "Next"
5. Configure:
   - **Product Name:** `WidgetExtension`
   - **Organization Identifier:** `com.example`
   - **Bundle Identifier:** `com.example.familyhubMvp.WidgetExtension`
   - **Language:** Swift
   - **Include Configuration Intent:** ✅ Checked
6. Click "Finish"
7. When prompted, click "Activate" to add the scheme

### 2. Replace Generated Files

1. Delete the auto-generated `WidgetExtension.swift` file
2. Copy the created files to the WidgetExtension target:
   - `FamilyHubWidget.swift`
   - `HubConfigurationIntent.swift`
   - `WidgetDataService.swift`
3. Update the target membership for these files to include `WidgetExtension`

### 3. Configure Info.plist

1. Select the WidgetExtension target
2. Go to Build Settings
3. Set `INFOPLIST_FILE` to `WidgetExtension/Info.plist`
4. Or manually copy the contents of `ios/WidgetExtension/Info.plist` to the generated Info.plist

### 4. Configure App Group

1. Select the Runner target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "App Groups"
5. Create/select group: `group.com.example.familyhubMvp`
6. Repeat for WidgetExtension target (same group)

### 5. Update Deployment Target

1. Select WidgetExtension target
2. Set iOS Deployment Target to iOS 16.0 (required for WidgetKit with Intents)

### 6. Add Dependencies

The widget extension needs access to:
- `WidgetKit` framework (already included)
- `AppIntents` framework (for configuration)
- `SwiftUI` (for widget views)

These should be automatically available, but verify in Build Phases → Link Binary With Libraries

### 7. Update Main App Info.plist

The main app's `Info.plist` has been updated with deep linking support:
- `CFBundleURLTypes` with `familyhub://` scheme

### 8. Flutter Integration

To share data between Flutter and the widget:

1. **Create App Group UserDefaults Helper in Flutter:**
   ```dart
   // In lib/services/widget_data_service.dart or new file
   import 'package:shared_preferences/shared_preferences.dart';
   
   Future<void> updateWidgetData(String hubId, WidgetData data) async {
     // This would need a platform channel to write to App Group UserDefaults
     // Or use a plugin like app_group
   }
   ```

2. **Update WidgetDataService in Flutter:**
   - When widget data is fetched, write it to App Group UserDefaults
   - Widget extension reads from the same App Group

### 9. Test Widget

1. Build and run the app
2. Long press on home screen
3. Tap "+" to add widgets
4. Search for "Family Hub"
5. Add widget and configure hub selection
6. Verify widget displays data

## Deep Linking

Widget taps will open the app with deep link: `familyhub://hub/{hubId}`

The Flutter app's `DeepLinkService` already handles this format.

## Troubleshooting

### Widget Not Appearing
- Verify WidgetExtension target is included in build
- Check that `@main` is on `FamilyHubWidgetBundle`
- Ensure iOS 16.0+ deployment target

### Configuration Not Working
- Verify `HubConfigurationIntent` is properly configured
- Check that App Group is set up correctly
- Ensure UserDefaults data is being written from Flutter

### Data Not Updating
- Verify App Group identifier matches in both targets
- Check that Flutter is writing data to App Group UserDefaults
- Widget timeline refreshes every 30 minutes (configurable)

## Next Steps

1. Implement Flutter → App Group data sharing
2. Add method channel for real-time widget updates
3. Test on physical iOS device (widgets don't work in simulator for all features)
4. Add more widget sizes/styles as needed

