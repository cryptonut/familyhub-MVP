import '../models/calendar_event.dart';
import '../models/chat_message.dart';
import '../models/family_photo.dart';
import 'extended_family_hub_service.dart';
import 'hub_service.dart';

/// Service to filter content based on extended family hub privacy settings
class PrivacyFilterService {
  final ExtendedFamilyHubService _extendedFamilyService = ExtendedFamilyHubService();
  final HubService _hubService = HubService();

  /// Filter events based on extended family hub privacy settings
  Future<List<CalendarEvent>> filterEvents(
    List<CalendarEvent> events,
    String? hubId,
  ) async {
    if (hubId == null) return events;

    final hub = await _hubService.getHub(hubId);
    if (hub == null || !hub.isExtendedFamilyHub) {
      // Not an extended family hub, return all events
      return events;
    }

    // Filter events based on privacy
    final filteredEvents = <CalendarEvent>[];
    for (var event in events) {
      // Check if event belongs to this hub
      if (event.hubId == hubId || event.hubIds.contains(hubId)) {
        final canView = await _extendedFamilyService.canViewContent(hubId, 'events');
        if (canView) {
          filteredEvents.add(event);
        }
      } else {
        // Event doesn't belong to this hub, don't include it
        // (This handles the case where we're viewing a hub-specific calendar)
      }
    }

    return filteredEvents;
  }

  /// Filter photos based on extended family hub privacy settings
  Future<List<FamilyPhoto>> filterPhotos(
    List<FamilyPhoto> photos,
    String? hubId,
  ) async {
    if (hubId == null) return photos;

    final hub = await _hubService.getHub(hubId);
    if (hub == null || !hub.isExtendedFamilyHub) {
      // Not an extended family hub, return all photos
      return photos;
    }

    // Filter photos based on privacy
    final filteredPhotos = <FamilyPhoto>[];
    for (var photo in photos) {
      // For now, photos are family-level, not hub-specific
      // In the future, we might add hubId to photos
      // For extended family hubs, check privacy level
      final canView = await _extendedFamilyService.canViewContent(hubId, 'photos');
      if (canView) {
        filteredPhotos.add(photo);
      }
    }

    return filteredPhotos;
  }

  /// Filter messages based on extended family hub privacy settings
  Future<List<ChatMessage>> filterMessages(
    List<ChatMessage> messages,
    String? hubId,
  ) async {
    if (hubId == null) return messages;

    final hub = await _hubService.getHub(hubId);
    if (hub == null || !hub.isExtendedFamilyHub) {
      // Not an extended family hub, return all messages
      return messages;
    }

    // Filter messages based on privacy
    final filteredMessages = <ChatMessage>[];
    for (var message in messages) {
      // Check if message belongs to this hub
      if (message.hubId == hubId) {
        final canView = await _extendedFamilyService.canViewContent(hubId, 'messages');
        if (canView) {
          filteredMessages.add(message);
        }
      } else {
        // Message doesn't belong to this hub
      }
    }

    return filteredMessages;
  }

  /// Check if user can view a specific event in an extended family hub
  Future<bool> canViewEvent(CalendarEvent event, String? hubId) async {
    if (hubId == null) return true;

    final hub = await _hubService.getHub(hubId);
    if (hub == null || !hub.isExtendedFamilyHub) return true;

    // Check if event belongs to this hub
    if (event.hubId != hubId && !event.hubIds.contains(hubId)) {
      return false; // Event doesn't belong to this hub
    }

    return await _extendedFamilyService.canViewContent(hubId, 'events');
  }

  /// Check if user can view a specific photo in an extended family hub
  Future<bool> canViewPhoto(FamilyPhoto photo, String? hubId) async {
    if (hubId == null) return true;

    final hub = await _hubService.getHub(hubId);
    if (hub == null || !hub.isExtendedFamilyHub) return true;

    return await _extendedFamilyService.canViewContent(hubId, 'photos');
  }

  /// Check if user can view a specific message in an extended family hub
  Future<bool> canViewMessage(ChatMessage message, String? hubId) async {
    if (hubId == null) return true;

    final hub = await _hubService.getHub(hubId);
    if (hub == null || !hub.isExtendedFamilyHub) return true;

    // Check if message belongs to this hub
    if (message.hubId != hubId) {
      return false; // Message doesn't belong to this hub
    }

    return await _extendedFamilyService.canViewContent(hubId, 'messages');
  }
}

