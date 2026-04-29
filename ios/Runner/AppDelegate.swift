import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = FlutterViewController()
    window?.makeKeyAndVisible()

    GeneratedPluginRegistrant.register(with: self)

    return true
  }
}