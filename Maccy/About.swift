import Cocoa

class About {
  private let githubURL = "https://github.com/its-pradeependra"
  private let email = "its.pradeependra.pratap@gmail.com"

  private var credits: NSMutableAttributedString {
    let labelColor = NSColor.labelColor
    let text = NSMutableAttributedString()

    // Tagline + description shown under the app name/icon in the standard About panel.
    let body = NSMutableAttributedString(
      string: """
      Copy once. Paste anything, anytime.

      ClipHub keeps a searchable history of everything you copy, so any snippet \
      or image you need is always one shortcut away. It lives quietly in your \
      menu bar, keeps every clip on your Mac, and never touches the internet.
      """,
      attributes: [.foregroundColor: labelColor]
    )
    text.append(body)
    text.append(NSAttributedString(string: "\n\n"))

    // Clickable links.
    let links = NSMutableAttributedString(
      string: "GitHub  •  Email",
      attributes: [.foregroundColor: labelColor]
    )
    let ns = links.string as NSString
    links.addAttribute(.link, value: githubURL, range: ns.range(of: "GitHub"))
    links.addAttribute(.link, value: "mailto:\(email)", range: ns.range(of: "Email"))
    text.append(links)

    text.setAlignment(.center, range: NSRange(location: 0, length: text.length))
    return text
  }

  @objc
  func openAbout(_ sender: NSMenuItem?) {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
  }
}
