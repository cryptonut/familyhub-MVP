import WidgetKit
import SwiftUI
import Intents
import Foundation

/// Timeline entry for widget data
struct HubTimelineEntry: TimelineEntry {
    let date: Date
    let hubId: String
    let hubName: String
    let upcomingEvents: [WidgetEvent]
    let unreadMessageCount: Int
    let pendingTasksCount: Int
    let configuration: HubConfigurationIntent
}

/// Widget event model
struct WidgetEvent {
    let id: String
    let title: String
    let startTime: Date
    let location: String?
}

/// Timeline provider for Family Hub widget
struct HubTimelineProvider: IntentTimelineProvider {
    typealias Intent = HubConfigurationIntent
    typealias Entry = HubTimelineEntry
    
    func placeholder(in context: Context) -> HubTimelineEntry {
        HubTimelineEntry(
            date: Date(),
            hubId: "placeholder",
            hubName: "Family Hub",
            upcomingEvents: [],
            unreadMessageCount: 0,
            pendingTasksCount: 0,
            configuration: HubConfigurationIntent()
        )
    }
    
    func getSnapshot(for configuration: HubConfigurationIntent, in context: Context, completion: @escaping (HubTimelineEntry) -> Void) {
        let entry = HubTimelineEntry(
            date: Date(),
            hubId: configuration.hub?.identifier ?? "default",
            hubName: configuration.hub?.displayString ?? "Family Hub",
            upcomingEvents: [],
            unreadMessageCount: 0,
            pendingTasksCount: 0,
            configuration: configuration
        )
        completion(entry)
    }
    
    func getTimeline(for configuration: HubConfigurationIntent, in context: Context, completion: @escaping (Timeline<HubTimelineEntry>) -> Void) {
        let currentDate = Date()
        let hubId = configuration.hub?.identifier ?? "default"
        let hubName = configuration.hub?.displayString ?? "Family Hub"
        
        // Fetch widget data from App Group UserDefaults
        WidgetDataService.shared.fetchWidgetData(hubId: hubId) { widgetData in
            let entry: HubTimelineEntry
            
            if let data = widgetData {
                // Convert WidgetEventData to WidgetEvent
                let events = data.upcomingEvents.map { eventData in
                    WidgetEvent(
                        id: eventData.id,
                        title: eventData.title,
                        startTime: eventData.startTime,
                        location: eventData.location
                    )
                }
                
                entry = HubTimelineEntry(
                    date: currentDate,
                    hubId: data.hubId,
                    hubName: data.hubName,
                    upcomingEvents: events,
                    unreadMessageCount: data.unreadMessageCount,
                    pendingTasksCount: data.pendingTasksCount,
                    configuration: configuration
                )
            } else {
                // No data available - use placeholder
                entry = HubTimelineEntry(
                    date: currentDate,
                    hubId: hubId,
                    hubName: hubName,
                    upcomingEvents: [],
                    unreadMessageCount: 0,
                    pendingTasksCount: 0,
                    configuration: configuration
                )
            }
            
            // Refresh every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

/// Main widget view
struct FamilyHubWidgetEntryView: View {
    var entry: HubTimelineProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

/// Small widget view (1x1)
struct SmallWidgetView: View {
    let entry: HubTimelineProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.hubName)
                .font(.headline)
                .lineLimit(1)
            
            if entry.unreadMessageCount > 0 {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundColor(.blue)
                    Text("\(entry.unreadMessageCount)")
                        .font(.caption)
                        .bold()
                }
            }
            
            if entry.pendingTasksCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("\(entry.pendingTasksCount)")
                        .font(.caption)
                        .bold()
                }
            }
            
            Spacer()
        }
        .padding()
        .widgetURL(URL(string: "familyhub://hub/\(entry.hubId)"))
    }
}

/// Medium widget view (2x1)
struct MediumWidgetView: View {
    let entry: HubTimelineProvider.Entry
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.hubName)
                    .font(.headline)
                    .lineLimit(1)
                
                if !entry.upcomingEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entry.upcomingEvents.prefix(2), id: \.id) { event in
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(event.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                if entry.unreadMessageCount > 0 {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                        Text("\(entry.unreadMessageCount)")
                            .font(.caption)
                            .bold()
                    }
                }
                
                if entry.pendingTasksCount > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("\(entry.pendingTasksCount)")
                            .font(.caption)
                            .bold()
                    }
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "familyhub://hub/\(entry.hubId)"))
    }
}

/// Large widget view (2x2 or 4x2)
struct LargeWidgetView: View {
    let entry: HubTimelineProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.hubName)
                .font(.title2)
                .bold()
            
            if !entry.upcomingEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming Events")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ForEach(entry.upcomingEvents.prefix(3), id: \.id) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.subheadline)
                                    .bold()
                                if let location = event.location {
                                    Text(location)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(event.startTime, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            HStack(spacing: 16) {
                if entry.unreadMessageCount > 0 {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                        Text("\(entry.unreadMessageCount) messages")
                            .font(.caption)
                    }
                }
                
                if entry.pendingTasksCount > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("\(entry.pendingTasksCount) tasks")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "familyhub://hub/\(entry.hubId)"))
    }
}

/// Widget configuration
struct FamilyHubWidget: Widget {
    let kind: String = "FamilyHubWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: HubConfigurationIntent.self, provider: HubTimelineProvider()) { entry in
            FamilyHubWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Family Hub")
        .description("View your hub's upcoming events, messages, and tasks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Widget bundle
@main
struct FamilyHubWidgetBundle: WidgetBundle {
    var body: some Widget {
        FamilyHubWidget()
    }
}

