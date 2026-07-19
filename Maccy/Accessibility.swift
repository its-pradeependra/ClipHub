import AppKit

struct Accessibility {
  private static var allowed: Bool { AXIsProcessTrustedWithOptions(nil) }

  static func check() {
    guard !allowed else {
      return
    }
  }

  /// Shows the system Accessibility permission prompt if access hasn't been granted yet.
  /// Called at launch so the user grants access upfront instead of being surprised mid-paste.
  static func promptIfNeeded() {
    guard !allowed else {
      return
    }

    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }
}
