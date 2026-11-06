import Cocoa
import FlutterMacOS
import SwiftUI

class MainFlutterWindow: NSWindow {
  private var flutterController: FlutterViewController?
  private var nativeModel: NativeModel?
  private var hostingController: NSHostingController<NativeRoot>?
  override func awakeFromNib() {
    let flutter = FlutterViewController()
    flutterController = flutter
    contentViewController = flutter
    RegisterGeneratedPlugins(registry: flutter)
    let model = NativeModel(messenger: flutter.engine.binaryMessenger)
    nativeModel = model
    model.didBecomeReady = { [weak self, weak model] in
      guard let self, let model, self.hostingController == nil else { return }
      let host = NSHostingController(rootView: NativeRoot(model: model))
      // Keep the Flutter engine and plugin view attached to this window; SwiftUI
      // owns presentation, while Dart owns all campus and planner state.
      flutter.removeFromParent()
      self.contentViewController = host
      host.addChild(flutter)
      flutter.view.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
      flutter.view.alphaValue = 0
      host.view.addSubview(flutter.view, positioned: .below, relativeTo: nil)
      self.hostingController = host
      self.title = "Compass"
      self.titleVisibility = .hidden
      self.titlebarAppearsTransparent = true
      self.toolbarStyle = .unified
      self.styleMask.insert(.fullSizeContentView)
      self.contentMinSize = NSSize(width: 900, height: 620)
      self.setContentSize(NSSize(width: 1100, height: 760))
      self.center()
    }
    super.awakeFromNib()
  }
}
