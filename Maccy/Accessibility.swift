import AppKit

struct Accessibility {
  private static var allowed: Bool { AXIsProcessTrustedWithOptions(nil) }

  /// Posted by the system whenever any app's Accessibility trust changes.
  static let changedNotification = Notification.Name("com.apple.accessibility.api")

  /// True while the app is quitting only to relaunch itself after an Accessibility
  /// grant. Lets `applicationWillTerminate` skip user-quit behaviors like
  /// "Clear history on quit" — this restart is invisible to the user, so their
  /// data must survive it.
  private(set) static var isRelaunching = false

  private static var changeObserver: NSObjectProtocol?
  private static var didScheduleRelaunch = false

  /// Whether ClipHub currently has working Accessibility access (needed to paste into
  /// other apps). TCC's cached answer can lag in both directions while the app runs —
  /// it stays false right after a grant and stays true right after a revoke — so a
  /// positive answer is cross-checked against the live AX connection AND the event-post
  /// preflight, the gate that actually governs pasting and refreshes most reliably.
  static var isTrusted: Bool {
    AXIsProcessTrusted() && !connectionRejected && CGPreflightPostEventAccess()
  }

  /// Whether this process's live AX connection is rejected. A process that was untrusted
  /// when it launched keeps a rejected connection even after the user grants access —
  /// only a relaunch refreshes it. `.apiDisabled` is the only result that means "rejected";
  /// any other error just means there was nothing to inspect. The short messaging timeout
  /// keeps a hung focused app from stalling us — a timeout surfaces as `.cannotComplete`.
  private static var connectionRejected: Bool {
    let systemWide = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(systemWide, 0.5)

    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      systemWide,
      kAXFocusedApplicationAttribute as CFString,
      &value
    )
    return result == .apiDisabled
  }

  /// Watches for Accessibility changes while running. When the user turns the toggle on,
  /// TCC starts reporting this process as trusted, but its live AX connection stays
  /// rejected until the app restarts — pasting would silently fail and the permission
  /// UI would stay stuck. Relaunch once to pick up the fresh grant cleanly.
  static func observeChanges() {
    guard changeObserver == nil else {
      return
    }

    changeObserver = DistributedNotificationCenter.default().addObserver(
      forName: changedNotification,
      object: nil,
      queue: .main
    ) { _ in
      // tccd can lag the notification, so re-check a few times before giving up.
      for delay in [1.0, 3.0, 8.0] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          reconcileTrust()
        }
      }
    }
  }

  private static func reconcileTrust() {
    // The signals disagreeing means this process holds a stale trust state (a fresh
    // grant not yet effective, or a revocation the cached answers are masking) —
    // every variant repairs the same way: restart into a clean state.
    let stale = AXIsProcessTrusted() && (connectionRejected || !CGPreflightPostEventAccess())
    guard !didScheduleRelaunch, stale else {
      return
    }

    didScheduleRelaunch = true

    // Terminate only once a relauncher is confirmed alive; otherwise ask the user
    // to restart manually — a visible ask beats the app silently vanishing or
    // pasting staying broken behind a green permission UI.
    guard spawnRelauncher() else {
      promptManualRestart()
      return
    }

    isRelaunching = true
    DispatchQueue.main.async {
      NSApp.terminate(nil)
    }

    // If termination was deferred or canceled (e.g. an in-flight update), re-arm the
    // relaunch attempt so a later notification can still self-repair. isRelaunching
    // deliberately never resets: while any relaunch-quit may still complete, wiping
    // history via "clear on quit" would be irreversible, so the flag stays latched.
    DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
      didScheduleRelaunch = false
    }
  }

  /// Fallback when a relauncher can't be spawned (translocated bundle, spawn failure):
  /// without a restart the fresh grant never reaches this process and pasting stays
  /// silently broken, so tell the user directly. Asked at most once per session.
  private static func promptManualRestart() {
    let alert = NSAlert()
    alert.messageText = "Restart ClipHub to Finish"
    alert.informativeText = "Accessibility is now enabled, but ClipHub needs to restart before it can paste. Quit ClipHub and open it again."
    alert.addButton(withTitle: "Quit ClipHub")
    alert.addButton(withTitle: "Later")
    NSApp.activate(ignoringOtherApps: true)

    if alert.runModal() == .alertFirstButtonReturn {
      // This quit exists only to complete the grant — protect the history.
      isRelaunching = true
      NSApp.terminate(nil)
    }
  }

  /// Opens System Settings → Privacy & Security → Accessibility.
  static func openSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }

  static func check() {
    guard !allowed else {
      return
    }
  }

  /// Shows the system Accessibility permission prompt on the first launch ever, which
  /// also registers ClipHub in the Accessibility list with the toggle off. Later
  /// untrusted launches (including self-restarts after the user revokes access) stay
  /// quiet — the app is already listed, and the in-app permission UI does the guiding.
  static func promptIfNeeded() {
    guard !allowed else {
      return
    }

    let promptShownKey = "accessibilityPromptShown"
    guard !UserDefaults.standard.bool(forKey: promptShownKey) else {
      return
    }
    UserDefaults.standard.set(true, forKey: promptShownKey)

    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }

  private static func spawnRelauncher() -> Bool {
    let bundlePath = Bundle.main.bundlePath

    // A translocated copy (run straight from a quarantined download) has no stable
    // path to reopen — skip the auto-relaunch rather than risk quitting for good.
    guard !bundlePath.contains("/AppTranslocation/") else {
      return false
    }

    // Wait for this process to actually exit (capped at ~30s) before reopening; if it
    // never exits (termination canceled), do nothing rather than poke the live app.
    // The pid and path travel as $0/$1 so shell metacharacters in the path stay inert.
    let relauncher = Process()
    relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
    relauncher.arguments = [
      "-c",
      #"for _ in $(seq 1 150); do kill -0 "$0" 2>/dev/null || break; sleep 0.2; done; kill -0 "$0" 2>/dev/null || /usr/bin/open "$1""#,
      String(ProcessInfo.processInfo.processIdentifier),
      bundlePath
    ]

    do {
      try relauncher.run()
      return true
    } catch {
      return false
    }
  }
}
