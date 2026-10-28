import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets a tapped reminder reach the plugin while the app is foregrounded.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShareFolder") {
      ShareFolderChannel.register(with: registrar.messenger())
    }
  }
}

enum ShareFolderChannel {
  /// Also in the share extension's ShareFolder.swift and both entitlements files.
  static let appGroup = "group.com.zhfahim.anchor"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "anchor/share", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "folder" else { return result(FlutterMethodNotImplemented) }
      guard let root = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
        .appendingPathComponent("share", isDirectory: true)
      else { return result(nil) }
      try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      result(root.path)
    }
  }
}
