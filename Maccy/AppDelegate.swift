import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel<ContentView>!

  @objc
  private lazy var statusItem: NSStatusItem = {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.behavior = .removalAllowed
    statusItem.button?.image = Defaults[.menuIcon].image
    statusItem.button?.imagePosition = .imageLeft
    return statusItem
  }()

  private var isStatusItemDisabled: Bool {
    Defaults[.ignoreEvents] || Defaults[.enabledPasteboardTypes].isEmpty
  }

  private var statusItemVisibilityObserver: NSKeyValueObservation?

  func applicationWillFinishLaunching(_ notification: Notification) { // swiftlint:disable:this function_body_length
    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      SPUUpdater(hostBundle: Bundle.main,
                 applicationBundle: Bundle.main,
                 userDriver: SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil),
                 delegate: nil)
      .automaticallyChecksForUpdates = false
    }
    #endif

    // Bridge FloatingPanel via AppDelegate.
    AppState.shared.appDelegate = self

    // Menu-bar icon shows a menu (Clipboard / Clear / Preferences / About / Quit).
    // The clipboard popup opens via its menu item or the global shortcut.
    statusItem.menu = buildStatusMenu()

    Clipboard.shared.onNewCopy { History.shared.add($0) }
    Clipboard.shared.start()

    Task {
      for await _ in Defaults.updates(.clipboardCheckInterval, initial: false) {
        Clipboard.shared.restart()
      }
    }

    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
      if let newValue = change.newValue, Defaults[.showInStatusBar] != newValue {
        Defaults[.showInStatusBar] = newValue
      }
    }

    Task {
      for await value in Defaults.updates(.showInStatusBar) {
        statusItem.isVisible = value
      }
    }

    Task {
      for await value in Defaults.updates(.menuIcon, initial: false) {
        statusItem.button?.image = value.image
      }
    }

    synchronizeMenuIconText()
    Task {
      for await value in Defaults.updates(.showRecentCopyInMenuBar) {
        if value {
          statusItem.button?.title = AppState.shared.menuIconText
        } else {
          statusItem.button?.title = ""
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.ignoreEvents) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }

    Task {
      for await _ in Defaults.updates(.enabledPasteboardTypes) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    migrateUserDefaults()
    disableUnusedGlobalHotkeys()

    // Request Accessibility upfront so the user grants it at launch
    // instead of being interrupted during their first paste.
    Accessibility.promptIfNeeded()
    Accessibility.observeChanges()

    panel = FloatingPanel(
      contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
      identifier: Bundle.main.bundleIdentifier ?? "com.pp-dev.ClipHub",
      statusBarButton: statusItem.button,
      onClose: { AppState.shared.popup.reset() }
    ) {
      ContentView()
    }

    #if DEBUG
    renderSettingsPreviewsIfRequested()
    renderPopupPreviewsIfRequested()
    #endif
  }

  #if DEBUG
  private func renderPopupPreviewsIfRequested() {
    guard let flagIndex = CommandLine.arguments.firstIndex(of: "--render-popup"),
          CommandLine.arguments.count > flagIndex + 1 else {
      return
    }
    let dir = URL(fileURLWithPath: CommandLine.arguments[flagIndex + 1])
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    Task { @MainActor in
      try? await AppState.shared.history.load()
      try? await Task.sleep(for: .seconds(1))

      for (suffix, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
        let root = WindowsClipboardPreview()
          .environment(AppState.shared)
          .modelContainer(Storage.shared.container)
        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.frame = NSRect(x: 0, y: 0, width: 340, height: 500)
        hosting.appearance = NSAppearance(named: appearanceName)

        let window = NSWindow(
          contentRect: hosting.frame,
          styleMask: [.borderless],
          backing: .buffered,
          defer: false
        )
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(300))

        if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
          hosting.cacheDisplay(in: hosting.bounds, to: rep)
          if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent("popup-\(suffix).png"))
          }
        }

        // Missing-Accessibility centered state.
        let permissionRoot = AccessibilityPermissionState()
          .frame(width: 340, height: 380)
          .background(Color(nsColor: .windowBackgroundColor))
        let permissionHost = NSHostingView(rootView: AnyView(permissionRoot))
        permissionHost.frame = NSRect(x: 0, y: 0, width: 340, height: 380)
        permissionHost.appearance = NSAppearance(named: appearanceName)
        let permissionWindow = NSWindow(contentRect: permissionHost.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        permissionWindow.contentView = permissionHost
        permissionHost.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(200))
        if let rep = permissionHost.bitmapImageRepForCachingDisplay(in: permissionHost.bounds) {
          permissionHost.cacheDisplay(in: permissionHost.bounds, to: rep)
          if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent("permission-\(suffix).png"))
          }
        }

        // Revealed-card variant.
        let revealRoot = WindowsRevealedPreview().modelContainer(Storage.shared.container)
        let revealHost = NSHostingView(rootView: AnyView(revealRoot))
        revealHost.frame = NSRect(x: 0, y: 0, width: 356, height: 320)
        revealHost.appearance = NSAppearance(named: appearanceName)
        let revealWindow = NSWindow(contentRect: revealHost.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        revealWindow.contentView = revealHost
        revealHost.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(200))
        if let rep = revealHost.bitmapImageRepForCachingDisplay(in: revealHost.bounds) {
          revealHost.cacheDisplay(in: revealHost.bounds, to: rep)
          if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent("reveal-\(suffix).png"))
          }
        }
      }
      NSApp.terminate(nil)
    }
  }
  #endif

  #if DEBUG
  /// Debug-only: `ClipHub --render-settings <dir>` renders every settings tab
  /// to PNG files (light + dark) and exits. Used to verify UI design offscreen.
  private func renderSettingsPreviewsIfRequested() {
    guard let flagIndex = CommandLine.arguments.firstIndex(of: "--render-settings"),
          CommandLine.arguments.count > flagIndex + 1 else {
      return
    }
    let dir = URL(fileURLWithPath: CommandLine.arguments[flagIndex + 1])
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      for tab in ClipHubSettingsTab.allCases {
        for (suffix, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
          let root = ClipHubSettingsRootView(initialTab: tab)
            .environment(AppState.shared)
            .modelContainer(Storage.shared.container)
          let hosting = NSHostingView(rootView: AnyView(root))
          hosting.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
          hosting.appearance = NSAppearance(named: appearanceName)

          let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
          )
          window.contentView = hosting
          hosting.layoutSubtreeIfNeeded()

          guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { continue }
          hosting.cacheDisplay(in: hosting.bounds, to: rep)
          if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent("\(tab.rawValue)-\(suffix).png"))
          }
        }
      }
      NSApp.terminate(nil)
    }
  }
  #endif

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    panel.toggle(height: AppState.shared.popup.height)
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    // "Clear on quit" means the user's quit — not the invisible self-restart
    // after an Accessibility grant, which must not touch their history.
    if Defaults[.clearOnQuit] && !Accessibility.isRelaunching {
      AppState.shared.history.clear()
    }
  }

  private func migrateUserDefaults() {
    if Defaults[.migrations]["2024-07-01-version-2"] != true {
      // Start 2.x from scratch.
      Defaults.reset(.migrations)

      // Inverse hide* configuration keys.
      Defaults[.showFooter] = !UserDefaults.standard.bool(forKey: "hideFooter")
      Defaults[.showSearch] = !UserDefaults.standard.bool(forKey: "hideSearch")
      Defaults[.showTitle] = !UserDefaults.standard.bool(forKey: "hideTitle")
      UserDefaults.standard.removeObject(forKey: "hideFooter")
      UserDefaults.standard.removeObject(forKey: "hideSearch")
      UserDefaults.standard.removeObject(forKey: "hideTitle")

      Defaults[.migrations]["2024-07-01-version-2"] = true
    }

    // The following defaults are not used in Maccy 2.x
    // and should be removed in 3.x.
    // - LaunchAtLogin__hasMigrated
    // - avoidTakingFocus
    // - saratovSeparator
    // - maxMenuItemLength
    // - maxMenuItems
  }

  @MainActor private func buildStatusMenu() -> NSMenu {
    let menu = NSMenu()

    let clipboardItem = NSMenuItem(title: "Clipboard", action: #selector(menuOpenClipboard), keyEquivalent: "")
    clipboardItem.target = self
    // Show the current global popup shortcut (e.g. ⌘⇧C) next to the item.
    clipboardItem.setShortcut(for: .popup)
    menu.addItem(clipboardItem)

    menu.addItem(.separator())

    let clearItem = NSMenuItem(title: "Clear", action: #selector(menuClear), keyEquivalent: "")
    clearItem.target = self
    menu.addItem(clearItem)

    menu.addItem(.separator())

    let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(menuPreferences), keyEquivalent: ",")
    prefsItem.target = self
    menu.addItem(prefsItem)

    let aboutItem = NSMenuItem(title: "About ClipHub", action: #selector(menuAbout), keyEquivalent: "")
    aboutItem.target = self
    menu.addItem(aboutItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit ClipHub", action: #selector(menuQuit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  @MainActor @objc private func menuOpenClipboard() {
    // Open the clipboard popup from the menu-bar menu.
    panel.toggle(height: AppState.shared.popup.height, at: .statusItem)
  }

  @MainActor @objc private func menuClear() {
    AppState.shared.history.clear()
  }

  @MainActor @objc private func menuPreferences() {
    AppState.shared.openPreferences()
  }

  @MainActor @objc private func menuAbout() {
    AppState.shared.openAbout()
  }

  @MainActor @objc private func menuQuit() {
    NSApp.terminate(nil)
  }

  private func synchronizeMenuIconText() {
    _ = withObservationTracking {
      AppState.shared.menuIconText
    } onChange: {
      DispatchQueue.main.async {
        if Defaults[.showRecentCopyInMenuBar] {
          self.statusItem.button?.title = AppState.shared.menuIconText
        }
        self.synchronizeMenuIconText()
      }
    }
  }

  private func disableUnusedGlobalHotkeys() {
    let names: [KeyboardShortcuts.Name] = [.delete, .pin]
    KeyboardShortcuts.disable(names)

    NotificationCenter.default.addObserver(
      forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil,
      queue: nil
    ) { notification in
      if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name, names.contains(name) {
        KeyboardShortcuts.disable(name)
      }
    }
  }
}
