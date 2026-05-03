import UIKit
import Flutter
import FirebaseCore
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    if FirebaseApp.app() == nil {
      let options = FirebaseOptions(
        googleAppID: "1:358333936335:ios:b4f070eb11719b4d54fdba",
        gcmSenderID: "358333936335"
      )

      options.apiKey = "AIzaSyD5xBmU_Qpr4PsCOYRsz6Ldjh4wIyl3zi4"
      options.projectID = "flutter-vietlove-dating"
      options.storageBucket = "flutter-vietlove-dating.firebasestorage.app"
      options.clientID = "358333936335-ipsfdl5slhmp1bia9nh02rl702qa62o2.apps.googleusercontent.com"

      FirebaseApp.configure(options: options)
    }

    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }

    return super.application(app, open: url, options: options)
  }
}