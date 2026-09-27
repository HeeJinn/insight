import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Insight runs as a kiosk: a borderless window (no title bar or traffic
    // lights) covering the whole screen, with the Dock and menu bar hidden.
    // Cmd+Q still quits.
    self.styleMask = [.borderless]
    if let screen = self.screen ?? NSScreen.main {
      self.setFrame(screen.frame, display: true)
    }
    NSApp.presentationOptions = [.hideDock, .hideMenuBar]

    super.awakeFromNib()
  }

  // Borderless windows can't take keyboard focus by default; the kiosk and
  // admin screens need it for typing and shortcuts.
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
