import Flutter
import SwiftUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  var nativeModel: NativeModel?
  private var nativeHost: UIHostingController<NativeRoot>?
  private var retainedFlutterController: FlutterViewController?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CompassNative") else {
      return
    }
    let model = NativeModel(messenger: registrar.messenger())
    nativeModel = model
    model.didBecomeReady = { [weak self] in self?.installNativeShell() }
  }
  func installNativeShell() {
    guard nativeHost == nil, let model = nativeModel, model.ready else { return }
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(
      \.windows)
    guard
      let controller = windows.compactMap({ $0.rootViewController as? FlutterViewController }).first
    else { return }
    guard let window = windows.first(where: { $0.rootViewController === controller }) else {
      return
    }
    let host = UIHostingController(rootView: NativeRoot(model: model))
    nativeHost = host
    retainedFlutterController = controller
    // SwiftUI must own the outer accessibility and presentation hierarchy.
    // Putting it inside FlutterView would hide native controls from VoiceOver
    // and system UI automation because Flutter supplies its own semantics tree.
    window.rootViewController = host
    host.addChild(controller)
    controller.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
    controller.view.alpha = 0
    host.view.insertSubview(controller.view, at: 0)
    controller.didMove(toParent: host)

  }
}
