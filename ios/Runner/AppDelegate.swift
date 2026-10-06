import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // local notifications (step summary) show while the app is open, too
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    GeneratedPluginRegistrant.register(with: self)

    // the hourly step refresh runs in its own engine; give it the plugins too
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // must match stepsTaskId in lib/state/background.dart and Info.plist
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.ditalsolutions.nutristep.steps",
      earliestBeginInSeconds: 3600
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
