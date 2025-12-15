import Foundation
import WidgetKit

/// Service for fetching widget data
/// This will communicate with Flutter via App Group UserDefaults or method channel
class WidgetDataService {
    static let shared = WidgetDataService()
    private let appGroupIdentifier = "group.com.example.familyhubMvp"
    
    /// Fetch widget data for a hub
    func fetchWidgetData(hubId: String, completion: @escaping (WidgetData?) -> Void) {
        // Try to get data from App Group UserDefaults (set by Flutter app)
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            completion(nil)
            return
        }
        
        // Get cached widget data
        if let data = userDefaults.data(forKey: "widgetData_\(hubId)"),
           let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) {
            completion(widgetData)
            return
        }
        
        // If no cached data, return nil (will show placeholder)
        completion(nil)
    }
}

/// Widget data model
struct WidgetData: Codable {
    let hubId: String
    let hubName: String
    let upcomingEvents: [WidgetEventData]
    let unreadMessageCount: Int
    let pendingTasksCount: Int
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case hubId
        case hubName
        case upcomingEvents
        case unreadMessageCount
        case pendingTasksCount
        case lastUpdated
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hubId = try container.decode(String.self, forKey: .hubId)
        hubName = try container.decode(String.self, forKey: .hubName)
        upcomingEvents = try container.decode([WidgetEventData].self, forKey: .upcomingEvents)
        unreadMessageCount = try container.decode(Int.self, forKey: .unreadMessageCount)
        pendingTasksCount = try container.decode(Int.self, forKey: .pendingTasksCount)
        
        // Decode date from ISO8601 string
        let dateString = try container.decode(String.self, forKey: .lastUpdated)
        let formatter = ISO8601DateFormatter()
        lastUpdated = formatter.date(from: dateString) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hubId, forKey: .hubId)
        try container.encode(hubName, forKey: .hubName)
        try container.encode(upcomingEvents, forKey: .upcomingEvents)
        try container.encode(unreadMessageCount, forKey: .unreadMessageCount)
        try container.encode(pendingTasksCount, forKey: .pendingTasksCount)
        
        // Encode date as ISO8601 string
        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: lastUpdated), forKey: .lastUpdated)
    }
}

struct WidgetEventData: Codable {
    let id: String
    let title: String
    let startTime: Date
    let location: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startTime
        case location
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        
        // Decode date from ISO8601 string
        let dateString = try container.decode(String.self, forKey: .startTime)
        let formatter = ISO8601DateFormatter()
        startTime = formatter.date(from: dateString) ?? Date()
        
        location = try container.decodeIfPresent(String.self, forKey: .location)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        
        // Encode date as ISO8601 string
        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: startTime), forKey: .startTime)
        
        try container.encodeIfPresent(location, forKey: .location)
    }
}

