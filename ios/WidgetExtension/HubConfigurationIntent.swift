import Foundation
import AppIntents

/// Intent for configuring hub selection in widget
@available(iOS 16.0, *)
struct HubConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Hub Configuration"
    static var description = IntentDescription("Select which hub to display in the widget.")
    
    @Parameter(title: "Hub")
    var hub: HubAppEntity?
}

/// App entity for hub selection
@available(iOS 16.0, *)
struct HubAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Hub"
    static var defaultQuery = HubQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    var name: String
}

/// Query for fetching available hubs
@available(iOS 16.0, *)
struct HubQuery: EntityQuery {
    func entities(for identifiers: [HubAppEntity.ID]) async throws -> [HubAppEntity] {
        // In a real implementation, this would fetch hubs from UserDefaults or App Group
        // For now, return empty array - will be populated by app when widget is configured
        return []
    }
    
    func suggestedEntities() async throws -> [HubAppEntity] {
        // Return suggested hubs from UserDefaults/App Group
        // This will be populated by the main app
        guard let userDefaults = UserDefaults(suiteName: "group.com.example.familyhubMvp"),
              let data = userDefaults.data(forKey: "widgetHubs"),
              let hubsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return []
        }
        
        // Convert dictionary array to HubAppEntity array
        return hubsArray.compactMap { hubDict in
            guard let id = hubDict["id"],
                  let name = hubDict["name"] else {
                return nil
            }
            return HubAppEntity(id: id, name: name)
        }
    }
}

