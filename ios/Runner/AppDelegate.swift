import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var quickLaunchChannel: FlutterMethodChannel?
  private var pendingQuickLaunch = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = self.registrar(forPlugin: "com.patto/quick_launch") {
      quickLaunchChannel = FlutterMethodChannel(
        name: "com.patto/quick_launch",
        binaryMessenger: registrar.messenger()
      )
    }

    if launchOptions?[.shortcutItem] != nil {
      pendingQuickLaunch = true
    }

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if pendingQuickLaunch {
      pendingQuickLaunch = false
      DispatchQueue.main.async { [weak self] in
        self?.emitQuickLaunch(source: "ios_quick_action")
      }
    }

    return result
  }

  override func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    emitQuickLaunch(source: "ios_quick_action")
    completionHandler(true)
  }

  private func emitQuickLaunch(source: String) {
    quickLaunchChannel?.invokeMethod("onQuickLaunch", arguments: ["source": source])
  }
}
