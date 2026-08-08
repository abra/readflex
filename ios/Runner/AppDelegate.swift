import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var dictionaryChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    dictionaryChannel = FlutterMethodChannel(
      name: "io.github.abra.readflex/dictionary",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    dictionaryChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "showDefinition" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let rawTerm = arguments["term"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing dictionary term",
            details: nil
          )
        )
        return
      }
      guard let self else {
        result(false)
        return
      }
      self.showSystemDefinition(rawTerm, result: result)
    }
  }

  private func showSystemDefinition(_ rawTerm: String, result: @escaping FlutterResult) {
    let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty, UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: term)
    else {
      result(false)
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let presenter = self?.topViewController() else {
        result(false)
        return
      }
      presenter.present(
        UIReferenceLibraryViewController(term: term),
        animated: true
      ) {
        result(true)
      }
    }
  }

  private func topViewController(from root: UIViewController? = nil) -> UIViewController? {
    let base = root ?? UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController

    if let presented = base?.presentedViewController {
      return topViewController(from: presented)
    }
    if let navigation = base as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tabs = base as? UITabBarController {
      return topViewController(from: tabs.selectedViewController)
    }
    return base
  }
}
