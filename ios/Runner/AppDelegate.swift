import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let appGroupIdentifier = "group.com.example.familyhubMvp"
  private let appGroupChannel = "com.example.familyhub_mvp/app_group"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up App Group method channel for widget data sharing
    setupAppGroupChannel()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupAppGroupChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: appGroupChannel,
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      
      switch call.method {
      case "writeWidgetData":
        self.handleWriteWidgetData(call: call, result: result)
      case "writeAvailableHubs":
        self.handleWriteAvailableHubs(call: call, result: result)
      case "updateWidgetTimeline":
        self.handleUpdateWidgetTimeline(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func handleWriteWidgetData(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let hubId = args["hubId"] as? String,
          let data = args["data"] as? [String: Any] else {
      result(FlutterError(
        code: "INVALID_ARGUMENTS",
        message: "Missing hubId or data",
        details: nil
      ))
      return
    }
    
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      result(FlutterError(
        code: "APP_GROUP_ERROR",
        message: "Failed to access App Group",
        details: nil
      ))
      return
    }
    
    // Convert data to JSON
    if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
      let key = "widgetData_\(hubId)"
      userDefaults.set(jsonData, forKey: key)
      userDefaults.synchronize()
      
      // Trigger widget timeline update
      WidgetCenter.shared.reloadTimelines(ofKind: "FamilyHubWidget")
      
      result(true)
    } else {
      result(FlutterError(
        code: "SERIALIZATION_ERROR",
        message: "Failed to serialize widget data",
        details: nil
      ))
    }
  }
  
  private func handleWriteAvailableHubs(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let hubs = args["hubs"] as? [[String: String]] else {
      result(FlutterError(
        code: "INVALID_ARGUMENTS",
        message: "Missing hubs array",
        details: nil
      ))
      return
    }
    
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      result(FlutterError(
        code: "APP_GROUP_ERROR",
        message: "Failed to access App Group",
        details: nil
      ))
      return
    }
    
    // Convert hubs to JSON
    if let jsonData = try? JSONSerialization.data(withJSONObject: hubs) {
      userDefaults.set(jsonData, forKey: "widgetHubs")
      userDefaults.synchronize()
      result(true)
    } else {
      result(FlutterError(
        code: "SERIALIZATION_ERROR",
        message: "Failed to serialize hubs data",
        details: nil
      ))
    }
  }
  
  private func handleUpdateWidgetTimeline(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let _ = args["hubId"] as? String else {
      result(FlutterError(
        code: "INVALID_ARGUMENTS",
        message: "Missing hubId",
        details: nil
      ))
      return
    }
    
    // Reload widget timeline
    WidgetCenter.shared.reloadTimelines(ofKind: "FamilyHubWidget")
    result(true)
  }
}
