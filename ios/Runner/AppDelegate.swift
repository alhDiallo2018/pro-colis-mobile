import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Canal du badge de l'icone, jumeau de celui d'Android (`AppBadgeHelper`).
  /// Sans lui, `NotificationBadgeService` etait un no-op sur iPhone : le badge
  /// n'apparaissait qu'a la reception d'une push (champ `aps.badge`) et ne
  /// redescendait jamais a zero apres lecture.
  private let badgeChannelName = "sendprocolis/badge"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Clé du SDK Google Maps natif (rendu de la carte). Distincte de la clé
    // Dart passée en --dart-define, qui ne couvre que Places / Geocoding :
    // sans elle, la carte reste grise. Renseigner `GoogleMapsApiKey` dans
    // Info.plist (idéalement alimenté par un .xcconfig hors dépôt).
    if let key = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
       !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Le messager binaire s'obtient via un registrar : le pont de moteur
    // implicite n'expose que le registre de plugins.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SendProColisBadge") {
      registerBadgeChannel(with: registrar.messenger())
    }
  }

  private func registerBadgeChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: badgeChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setBadgeCount":
        let count = max(0, (call.arguments as? NSNumber)?.intValue ?? 0)
        AppDelegate.applyBadge(count)
        result(nil)
      case "removeBadge":
        AppDelegate.applyBadge(0)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func applyBadge(_ count: Int) {
    DispatchQueue.main.async {
      if #available(iOS 16.0, *) {
        // `applicationIconBadgeNumber` est deprecie depuis iOS 17 : la voie
        // officielle passe desormais par le centre de notifications.
        UNUserNotificationCenter.current().setBadgeCount(count)
      } else {
        UIApplication.shared.applicationIconBadgeNumber = count
      }
    }
  }
}
