import AppKit
import Defaults

enum MenuIcon: String, CaseIterable, Identifiable, Defaults.Serializable {
  case clipboard
  case scissors
  case paperclip

  var id: Self { self }

  var image: NSImage {
    switch self {
    case .clipboard:
      let symbol = NSImage(
        systemSymbolName: "list.clipboard.fill",
        accessibilityDescription: "ClipHub"
      )?.withSymbolConfiguration(
        NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
      ) ?? NSImage(named: .clipboard)!
      symbol.isTemplate = true
      return symbol
    case .scissors:
      return NSImage(named: .scissors)!
    case .paperclip:
      return NSImage(named: .paperclip)!
    }
  }
}
