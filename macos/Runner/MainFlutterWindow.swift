import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    styleMask.insert(.fullSizeContentView)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    titlebarSeparatorStyle = .none
    self.setFrame(windowFrame, display: true)

    let titleBarMetrics = FlutterEventChannel(
      name: "compass/macos_title_bar_inset",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    titleBarMetrics.setStreamHandler(TitleBarMetrics(window: self))

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func sendEvent(_ event: NSEvent) {
    let location = event.locationInWindow
    if event.type == .leftMouseDown,
       event.clickCount == 1,
       isMovable,
       !styleMask.contains(.fullScreen),
       let contentView,
       contentView.convert(contentView.bounds, to: nil)
         .insetBy(dx: 4, dy: 4).contains(location),
       location.y >= contentLayoutRect.maxY,
       !isOverWindowButton(location) {
      performDrag(with: event)
      return
    }
    super.sendEvent(event)
  }

  private func isOverWindowButton(_ location: NSPoint) -> Bool {
    let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    return buttonTypes.contains { type in
      guard let button = standardWindowButton(type), !button.isHidden else { return false }
      return button.convert(button.bounds, to: nil).insetBy(dx: -3, dy: -3).contains(location)
    }
  }
}

private final class TitleBarMetrics: NSObject, FlutterStreamHandler {
  private weak var window: NSWindow?
  private var observation: NSKeyValueObservation?

  init(window: NSWindow) {
    self.window = window
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    observation = window?.observe(\.contentLayoutRect, options: [.initial, .new]) { window, _ in
      guard let contentView = window.contentView else { return }
      let contentTop = contentView.convert(contentView.bounds, to: nil).maxY
      events(Double(max(0, contentTop - window.contentLayoutRect.maxY)))
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    observation = nil
    return nil
  }
}
