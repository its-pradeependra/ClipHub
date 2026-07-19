import AppKit
import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import SwiftData
import SwiftUI

// MARK: - Window Controller (fixed size, non-resizing)

final class ClipHubSettingsWindowController: NSWindowController {
  convenience init() {
    let root = ClipHubSettingsRootView()
      .environment(AppState.shared)
      .modelContainer(Storage.shared.container)
    let hosting = NSHostingController(rootView: root)

    let window = NSWindow(contentViewController: hosting)
    window.title = "ClipHub Settings"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
    window.isRestorable = false
    window.isMovableByWindowBackground = true
    window.setContentSize(NSSize(width: 900, height: 640))
    window.center()

    self.init(window: window)
  }
}

// MARK: - Tabs

enum ClipHubSettingsTab: String, CaseIterable, Identifiable {
  case general, storage, appearance, pins, ignore, advanced

  var id: Self { self }

  var title: String {
    switch self {
    case .general: return "General"
    case .storage: return "Storage"
    case .appearance: return "Appearance"
    case .pins: return "Pins"
    case .ignore: return "Ignore"
    case .advanced: return "Advanced"
    }
  }

  var symbol: String {
    switch self {
    case .general: return "gearshape"
    case .storage: return "externaldrive"
    case .appearance: return "paintpalette"
    case .pins: return "pin"
    case .ignore: return "nosign"
    case .advanced: return "gearshape.2"
    }
  }
}

// MARK: - Root

struct ClipHubSettingsRootView: View {
  @State private var tab: ClipHubSettingsTab

  init(initialTab: ClipHubSettingsTab = .general) {
    _tab = State(initialValue: initialTab)
  }

  var body: some View {
    VStack(spacing: 0) {
      ClipHubTabBar(selection: $tab)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(ClipHubTheme.card)

      Divider().opacity(0.35)

      ScrollView {
        content
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .top)
      }
      .background(ClipHubTheme.canvas)
    }
    .frame(width: 900, height: 640)
  }

  @ViewBuilder private var content: some View {
    switch tab {
    case .general: ClipHubGeneralTab()
    case .storage: ClipHubStorageTab()
    case .appearance: ClipHubAppearanceTab()
    case .pins: ClipHubPinsTab()
    case .ignore: ClipHubIgnoreTab()
    case .advanced: ClipHubAdvancedTab()
    }
  }
}

// MARK: - Tab Bar (pill style, centered)

struct ClipHubTabBar: View {
  @Binding var selection: ClipHubSettingsTab

  var body: some View {
    HStack(spacing: 6) {
      ForEach(ClipHubSettingsTab.allCases) { tab in
        Button {
          selection = tab
        } label: {
          VStack(spacing: 4) {
            Image(systemName: tab.symbol)
              .font(.system(size: 16, weight: .medium))
              .frame(height: 18)
            Text(tab.title)
              .font(.system(size: 11, weight: selection == tab ? .semibold : .medium))
          }
          .frame(width: 78, height: 52)
          .foregroundStyle(selection == tab ? Color.accentColor : Color.secondary)
          .background {
            if selection == tab {
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.13))
            }
          }
          .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
  }
}

// MARK: - Card chrome

struct ClipHubCard<Content: View>: View {
  let icon: String
  let title: String
  let subtitle: String?
  let accessory: AnyView?
  @ViewBuilder let content: Content

  init(
    icon: String,
    title: String,
    subtitle: String? = nil,
    accessory: AnyView? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.icon = icon
    self.title = title
    self.subtitle = subtitle
    self.accessory = accessory
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 9) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 18, height: 18)
          .padding(.top, 1)
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.system(size: 14, weight: .semibold))
          if let subtitle {
            Text(subtitle)
              .font(.system(size: 11.5))
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 0)
        if let accessory {
          accessory
        }
      }
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .clipHubCardStyle()
  }
}

enum ClipHubTheme {
  /// Window canvas behind the cards: near-white in light mode, deep gray in dark.
  static let canvas = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(calibratedRed: 0.086, green: 0.086, blue: 0.094, alpha: 1)
      : NSColor(calibratedRed: 0.961, green: 0.965, blue: 0.973, alpha: 1)
  })

  /// Card surface: white in light mode, elevated gray in dark.
  static let card = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(calibratedRed: 0.153, green: 0.153, blue: 0.165, alpha: 1)
      : .white
  })
}

extension View {
  func clipHubCardStyle(padding: CGFloat = 16) -> some View {
    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    return self
      .padding(padding)
      .background(ClipHubTheme.card, in: shape)
      .overlay(shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
      .shadow(color: .black.opacity(0.05), radius: 2.5, y: 1)
  }
}

// MARK: - Reusable rows

struct ClipHubToggleRow: View {
  let title: String
  let subtitle: String?
  @Binding var isOn: Bool

  init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
    self.title = title
    self.subtitle = subtitle
    self._isOn = isOn
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 13))
        if let subtitle {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 12)
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
    }
  }
}

struct ClipHubIconRow: View {
  let symbol: String
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(Color.primary.opacity(0.06))
        .frame(width: 26, height: 26)
        .overlay {
          Image(systemName: symbol)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
      Text(title).font(.system(size: 13))
      Spacer()
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
    }
    .padding(.vertical, 2)
  }
}

struct ClipHubInfoBanner: View {
  let symbol: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.accentColor)
      Text(text)
        .font(.system(size: 12))
        .foregroundStyle(.primary.opacity(0.8))
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(
      Color.accentColor.opacity(0.09),
      in: RoundedRectangle(cornerRadius: 10, style: .continuous)
    )
  }
}

// MARK: - General Tab

struct ClipHubGeneralTab: View {
  @Default(.searchMode) private var searchMode
  @Default(.pasteByDefault) private var pasteByDefault
  @Default(.removeFormattingByDefault) private var removeFormatting
  @Default(.notifyOnCopy) private var notifyOnCopy
  @Default(.notifyOnPaste) private var notifyOnPaste

  @State private var updater = SoftwareUpdater()

  var body: some View {
    VStack(spacing: 16) {
      startupCard
      HStack(alignment: .top, spacing: 16) {
        VStack(spacing: 16) {
          shortcutsCard
          notificationsCard
        }
        VStack(spacing: 16) {
          searchCard
          behaviorCard
        }
      }
    }
    .frame(maxWidth: 680)
    .frame(maxWidth: .infinity)
  }

  private var startupCard: some View {
    ClipHubCard(icon: "airplane.departure", title: "Startup") {
      VStack(alignment: .leading, spacing: 10) {
        LaunchAtLogin.Toggle {
          Text("Launch at login").font(.system(size: 13))
        }
        .toggleStyle(ClipHubTrailingSwitchStyle())

        Toggle(isOn: $updater.automaticallyChecksForUpdates) {
          Text("Check for updates automatically").font(.system(size: 13))
        }
        .toggleStyle(ClipHubTrailingSwitchStyle())

        Button("Check Now") { updater.checkForUpdates() }
          .controlSize(.regular)
      }
    }
  }

  private var shortcutsCard: some View {
    ClipHubCard(icon: "keyboard", title: "Keyboard Shortcuts") {
      VStack(spacing: 10) {
        shortcutRow("Open Clipboard", name: .popup)
        shortcutRow("Pin Item", name: .pin)
        shortcutRow("Delete Item", name: .delete)
        shortcutRow("Quick Preview", name: .togglePreview)
      }
    }
  }

  private func shortcutRow(_ title: String, name: KeyboardShortcuts.Name) -> some View {
    HStack {
      Text(title).font(.system(size: 13))
      Spacer()
      KeyboardShortcuts.Recorder(for: name)
        .controlSize(.small)
    }
  }

  private var notificationsCard: some View {
    ClipHubCard(icon: "bell.badge", title: "Notifications & Sounds") {
      VStack(alignment: .leading, spacing: 12) {
        ClipHubToggleRow(
          "Notify on copy",
          subtitle: "Notification and sound when a new clip is captured.",
          isOn: $notifyOnCopy
        )
        Divider().opacity(0.5)
        ClipHubToggleRow(
          "Notify on paste",
          subtitle: "Notification and sound when a clip is pasted.",
          isOn: $notifyOnPaste
        )
        Divider().opacity(0.5)
        Link(destination: notificationsURL) {
          HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(Color.accentColor)
            Text("System notification settings…")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(Color.accentColor)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.tertiary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var searchCard: some View {
    ClipHubCard(icon: "magnifyingglass", title: "Search") {
      HStack {
        Text("Search Mode").font(.system(size: 13))
        Spacer()
        Picker("", selection: $searchMode) {
          ForEach(Search.Mode.allCases) { mode in
            Text(mode.description).tag(mode)
          }
        }
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 130)
      }
    }
  }

  private var behaviorCard: some View {
    ClipHubCard(icon: "doc.on.clipboard", title: "Clipboard Behavior") {
      VStack(alignment: .leading, spacing: 12) {
        ClipHubToggleRow(
          "Paste automatically",
          subtitle: "When on, choosing a clip pastes it straight into the app you’re using.",
          isOn: $pasteByDefault
        )
        Divider().opacity(0.5)
        ClipHubToggleRow(
          "Paste without formatting",
          subtitle: "Paste the content without any formatting.",
          isOn: $removeFormatting
        )
      }
    }
  }

  private var notificationsURL: URL {
    URL(string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(Bundle.main.bundleIdentifier ?? "")")!
  }
}

/// Toggle style that puts the switch at the trailing edge of the row.
struct ClipHubTrailingSwitchStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.label
      Spacer()
      Toggle("", isOn: configuration.$isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
    }
  }
}

// MARK: - Storage Tab

struct ClipHubStorageTab: View {
  @Observable
  final class TypesModel {
    var saveFiles = false {
      didSet {
        Defaults.withoutPropagation {
          if saveFiles {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.files.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.files.types)
          }
        }
      }
    }
    var saveImages = false {
      didSet {
        Defaults.withoutPropagation {
          if saveImages {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.images.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.images.types)
          }
        }
      }
    }
    var saveText = false {
      didSet {
        Defaults.withoutPropagation {
          if saveText {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.text.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.text.types)
          }
        }
      }
    }

    private var observer: Defaults.Observation?

    init() {
      observer = Defaults.observe(.enabledPasteboardTypes) { change in
        self.saveFiles = change.newValue.isSuperset(of: StorageType.files.types)
        self.saveImages = change.newValue.isSuperset(of: StorageType.images.types)
        self.saveText = change.newValue.isSuperset(of: StorageType.text.types)
      }
    }

    deinit { observer?.invalidate() }
  }

  @Default(.size) private var size
  @Default(.sortBy) private var sortBy

  @State private var model = TypesModel()
  @State private var storageSize = Storage.shared.size

  private let sizeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 50
    formatter.maximum = 1000
    return formatter
  }()

  var body: some View {
    VStack(spacing: 16) {
      contentCard
      sizeCard
      sortCard
    }
    .frame(maxWidth: 620)
    .frame(maxWidth: .infinity)
  }

  private var contentCard: some View {
    ClipHubCard(
      icon: "tray.full",
      title: "Store clipboard content",
      subtitle: "Choose what types of copied content should be stored."
    ) {
      VStack(spacing: 8) {
        ClipHubIconRow(symbol: "doc", title: "Files", isOn: $model.saveFiles)
        Divider().opacity(0.5)
        ClipHubIconRow(symbol: "photo", title: "Images", isOn: $model.saveImages)
        Divider().opacity(0.5)
        ClipHubIconRow(symbol: "textformat", title: "Text", isOn: $model.saveText)
      }
    }
  }

  private var sizeCard: some View {
    ClipHubCard(
      icon: "clock.arrow.circlepath",
      title: "History Size",
      subtitle: "Set the maximum number of items to keep in history."
    ) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          TextField("", value: $size, formatter: sizeFormatter)
            .textFieldStyle(.roundedBorder)
            .frame(width: 76)
          Stepper("", value: $size, in: 50...1000, step: 10)
            .labelsHidden()
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(storageSize)
              .font(.system(size: 13, weight: .semibold))
            Text("Estimated memory usage")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }
          .onAppear { storageSize = Storage.shared.size }
        }

        Slider(
          value: Binding(
            get: { Double(size) },
            set: { size = Int($0.rounded()) }
          ),
          in: 50...1000
        )
        HStack {
          Text("50 items").font(.system(size: 10.5)).foregroundStyle(.secondary)
          Spacer()
          Text("1000 items").font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
      }
    }
  }

  private var sortCard: some View {
    ClipHubCard(
      icon: "arrow.up.arrow.down",
      title: "Sort Order",
      subtitle: "Choose how the clipboard history should be sorted."
    ) {
      HStack {
        Text("Sort history by").font(.system(size: 13))
        Spacer()
        Picker("", selection: $sortBy) {
          ForEach(Sorter.By.allCases) { mode in
            Text(mode.description).tag(mode)
          }
        }
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 170)
      }
    }
  }
}

// MARK: - Pins Tab

struct ClipHubPinsTab: View {
  @Environment(AppState.self) private var appState
  @Environment(\.modelContext) private var modelContext

  @Query(filter: #Predicate<HistoryItem> { $0.pin != nil }, sort: \.firstCopiedAt)
  private var items: [HistoryItem]

  @State private var availablePins: [String] = []

  var body: some View {
    VStack(spacing: 16) {
      ClipHubCard(
        icon: "pin",
        title: "Pinned Items",
        subtitle: "Pin important items for quick and easy access.",
        accessory: AnyView(addPinButton)
      ) {
        VStack(spacing: 0) {
          headerRow
          Divider()
          if items.isEmpty {
            Text("No pinned items yet. Open ClipHub and press the pin shortcut on any clip, or click Add Pin.")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.vertical, 24)
          } else {
            ForEach(items) { item in
              pinRow(item)
              if item.id != items.last?.id {
                Divider().opacity(0.5)
              }
            }
          }
        }
      }

      ClipHubInfoBanner(
        symbol: "info.circle.fill",
        text: "Pinned items appear at the top of your clipboard history. Press ⌘ + the shortcut letter while ClipHub is open to paste the item instantly."
      )
    }
    .onAppear { availablePins = HistoryItem.availablePins }
  }

  private var addPinButton: some View {
    Button {
      addPin()
    } label: {
      Label("Add Pin", systemImage: "plus")
        .font(.system(size: 12, weight: .medium))
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.small)
  }

  private var headerRow: some View {
    HStack(spacing: 10) {
      Text("").frame(width: 14)
      Text("Shortcut")
        .frame(width: 70, alignment: .leading)
      Text("Title")
        .frame(width: 180, alignment: .leading)
      Text("Content")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("").frame(width: 58)
    }
    .font(.system(size: 11, weight: .medium))
    .foregroundStyle(.secondary)
    .padding(.vertical, 8)
  }

  private func pinRow(_ item: HistoryItem) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "line.3.horizontal")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .frame(width: 14)

      pinShortcutChip(item)
        .frame(width: 70, alignment: .leading)

      PinTitleView(item: item)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .frame(width: 180, alignment: .leading)

      PinValueView(item: item)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 6) {
        Button {
          NSApp.keyWindow?.makeFirstResponder(nil)
        } label: {
          Image(systemName: "pencil")
            .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("Click any field in the row to edit it inline")

        Button {
          unpin(item)
        } label: {
          Image(systemName: "trash")
            .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("Unpin this item")
      }
      .frame(width: 58, alignment: .trailing)
    }
    .padding(.vertical, 7)
  }

  private func pinShortcutChip(_ item: HistoryItem) -> some View {
    Menu {
      let current = item.pin ?? ""
      let pins = Array(Set(availablePins + [current])).sorted()
      ForEach(pins, id: \.self) { pin in
        Button("⌘\(pin.uppercased())") {
          item.pin = pin
          availablePins = HistoryItem.availablePins
        }
      }
    } label: {
      Text("⌘\((item.pin ?? "?").uppercased())")
        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
  }

  private func addPin() {
    let pin = HistoryItem.randomAvailablePin
    guard !pin.isEmpty else { return }
    let content = HistoryItemContent(
      type: NSPasteboard.PasteboardType.string.rawValue,
      value: "New pinned item".data(using: .utf8)
    )
    let item = HistoryItem(contents: [content])
    item.title = "New Pin"
    item.pin = pin
    modelContext.insert(item)
    try? modelContext.save()
    availablePins = HistoryItem.availablePins
  }

  private func unpin(_ item: HistoryItem) {
    if let decorator = appState.history.items.first(where: { $0.item == item }) {
      appState.history.togglePin(decorator)
    } else {
      item.pin = nil
    }
    try? modelContext.save()
    availablePins = HistoryItem.availablePins
  }
}

// MARK: - Ignore Tab

struct ClipHubIgnoreTab: View {
  @Default(.ignoredApps) private var ignoredApps
  @Default(.ignoreAllAppsExceptListed) private var ignoreAllExcept
  @Default(.ignoredPasteboardTypes) private var ignoredTypes
  @Default(.ignoreRegexp) private var ignoredRegexps

  @State private var isAddingApp = false

  private struct FriendlyType: Identifiable {
    let id: String
    let title: String
  }

  private let friendlyTypes: [FriendlyType] = [
    FriendlyType(id: "org.nspasteboard.ConcealedType", title: "Passwords"),
    FriendlyType(id: "org.nspasteboard.AutoGeneratedType", title: "One-Time Codes"),
    FriendlyType(id: "org.nspasteboard.TransientType", title: "Sensitive Data"),
    FriendlyType(id: "com.agilebits.onepassword", title: "1Password Data"),
    FriendlyType(id: "com.typeit4me.clipping", title: "TypeIt4Me Clippings"),
    FriendlyType(id: "de.petermaurer.TransientPasteboardType", title: "Keyboard Maestro Data")
  ]

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      applicationsCard.frame(maxWidth: .infinity)
      typesCard.frame(maxWidth: .infinity)
      regexpCard.frame(maxWidth: .infinity)
    }
  }

  /// Content height shared by all three columns so the cards line up evenly.
  private let columnContentHeight: CGFloat = 372

  private var applicationsCard: some View {
    ClipHubCard(
      icon: "app.badge.checkmark",
      title: "Ignored Applications",
      subtitle: "Clipboard content copied from these applications will be ignored."
    ) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Spacer()
          Button {
            isAddingApp = true
          } label: {
            Label("Add Application", systemImage: "plus").font(.system(size: 11, weight: .medium))
          }
          .controlSize(.small)
          .fixedSize()
          .fileDialogDefaultDirectory(URL(string: "/Applications"))
          .fileImporter(isPresented: $isAddingApp, allowedContentTypes: [.application]) { result in
            if case .success(let url) = result,
               let bundle = Bundle(path: url.path),
               let bundleID = bundle.bundleIdentifier,
               !ignoredApps.contains(bundleID) {
              ignoredApps.append(bundleID)
            }
          }
        }

        if ignoredApps.isEmpty {
          Text("No ignored applications yet.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 18)
        } else {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(ignoredApps, id: \.self) { app in
              appRow(app)
              if app != ignoredApps.last {
                Divider().opacity(0.5)
              }
            }
          }
        }

        Spacer(minLength: 0)

        Divider().opacity(0.5)

        Toggle(isOn: $ignoreAllExcept) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Ignore all applications except listed").font(.system(size: 12))
            Text("When enabled, only the listed applications will be captured.")
              .font(.system(size: 10.5))
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .toggleStyle(.checkbox)
      }
      .frame(minHeight: columnContentHeight, alignment: .top)
    }
  }

  private func appRow(_ bundleID: String) -> some View {
    HStack(spacing: 8) {
      if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
          .resizable()
          .frame(width: 18, height: 18)
        Text(NSWorkspace.shared.applicationName(url: url))
          .font(.system(size: 12.5))
          .lineLimit(1)
      } else {
        Image(systemName: "questionmark.app")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .frame(width: 18, height: 18)
        Text(bundleID)
          .font(.system(size: 11.5))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      Button {
        ignoredApps.removeAll { $0 == bundleID }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 6)
  }

  private var typesCard: some View {
    ClipHubCard(
      icon: "list.clipboard",
      title: "Pasteboard Types",
      subtitle: "Ignore content of these types."
    ) {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(friendlyTypes) { type in
          Toggle(isOn: Binding(
            get: { ignoredTypes.contains(type.id) },
            set: { on in
              if on { ignoredTypes.insert(type.id) } else { ignoredTypes.remove(type.id) }
            }
          )) {
            Text(type.title).font(.system(size: 12.5))
          }
          .toggleStyle(.checkbox)
        }

        Spacer(minLength: 0)

        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "lightbulb")
            .font(.system(size: 12))
            .foregroundStyle(.orange)
          Text("Tip: For more accurate filtering, use Regular Expressions.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
      }
      .frame(minHeight: columnContentHeight, alignment: .top)
    }
  }

  private var regexpCard: some View {
    ClipHubCard(
      icon: "asterisk.circle",
      title: "Regular Expressions",
      subtitle: "Ignore content that matches these patterns."
    ) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Spacer()
          Button {
            if !ignoredRegexps.contains("") { ignoredRegexps.append("") }
          } label: {
            Label("Add Pattern", systemImage: "plus").font(.system(size: 11, weight: .medium))
          }
          .controlSize(.small)
          .fixedSize()
        }

        if ignoredRegexps.isEmpty {
          Text("No patterns yet.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 18)
        } else {
          VStack(spacing: 8) {
            ForEach(Array(ignoredRegexps.enumerated()), id: \.offset) { index, regexp in
              HStack(spacing: 6) {
                TextField("pattern", text: Binding(
                  get: { index < ignoredRegexps.count ? ignoredRegexps[index] : "" },
                  set: { newValue in
                    if index < ignoredRegexps.count { ignoredRegexps[index] = newValue }
                  }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

                Button {
                  if index < ignoredRegexps.count {
                    ignoredRegexps.remove(at: index)
                  }
                } label: {
                  Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
              }
            }
          }
        }

        Spacer(minLength: 0)
      }
      .frame(minHeight: columnContentHeight, alignment: .top)
    }
  }
}

// MARK: - Advanced Tab

struct ClipHubAdvancedTab: View {
  @Default(.ignoreEvents) private var ignoreEvents
  @Default(.clearOnQuit) private var clearOnQuit
  @Default(.clearSystemClipboard) private var clearSystemClipboard

  @State private var showCommands = false

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(spacing: 16) {
        captureCard
        historyCard
        developerCard
      }
      infoSidebar
        .frame(width: 240)
    }
  }

  private var captureCard: some View {
    ClipHubCard(
      icon: "pause.circle",
      title: "Clipboard Capture Control",
      subtitle: "Temporarily ignore all new clipboard changes."
    ) {
      HStack(alignment: .center, spacing: 16) {
        Toggle(isOn: $ignoreEvents) {
          Text("Turn off").font(.system(size: 13))
        }
        .toggleStyle(ClipHubTrailingSwitchStyle())
        .frame(width: 180)

        Text("Useful when working with sensitive data or when the app is copying undesired content.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var historyCard: some View {
    ClipHubCard(icon: "clock.arrow.circlepath", title: "History") {
      VStack(alignment: .leading, spacing: 12) {
        ClipHubToggleRow(
          "Clear history on quit",
          subtitle: "Automatically clear clipboard history when ClipHub quits.",
          isOn: $clearOnQuit
        )
        Divider().opacity(0.5)
        ClipHubToggleRow(
          "Clear the system clipboard too",
          subtitle: "Also clear macOS clipboard when clearing history.",
          isOn: $clearSystemClipboard
        )
      }
    }
  }

  private var developerCard: some View {
    ClipHubCard(icon: "terminal", title: "Developer") {
      HStack {
        Text("Show advanced commands and configuration.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
        Spacer()
        Button("Show Commands") { showCommands = true }
          .controlSize(.small)
          .popover(isPresented: $showCommands, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
              Text("Pause capture from the command line")
                .font(.system(size: 12, weight: .semibold))
              Text(NSLocalizedString("TurnOffShellScript", tableName: "AdvancedSettings", comment: ""))
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
              Divider()
              Text("Ignore only the next copy")
                .font(.system(size: 12, weight: .semibold))
              Text(NSLocalizedString("TurnOffNextShellScript", tableName: "AdvancedSettings", comment: ""))
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
            }
            .padding(14)
            .frame(width: 420)
          }
      }
    }
  }

  private var infoSidebar: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "shield.lefthalf.filled")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        Text("Advanced Information")
          .font(.system(size: 13, weight: .semibold))
      }
      Text("Advanced settings are for power users. Use with caution.")
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(
      Color.accentColor.opacity(0.08),
      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
    )
    .frame(height: 420)
  }
}

// MARK: - Appearance Tab

struct ClipHubAppearanceTab: View {
  @Default(.popupPosition) private var popupAt
  @Default(.pinTo) private var pinTo
  @Default(.imageMaxHeight) private var imageHeight
  @Default(.openPreviewAutomatically) private var openPreviewAutomatically
  @Default(.previewDelay) private var previewDelay
  @Default(.highlightMatch) private var highlightMatch
  @Default(.menuIcon) private var menuIcon
  @Default(.showInStatusBar) private var showInStatusBar
  @Default(.showSearch) private var showSearch
  @Default(.searchVisibility) private var searchVisibility
  @Default(.showFooter) private var showFooter
  @Default(.showApplicationIcons) private var showApplicationIcons
  @Default(.showSpecialSymbols) private var showSpecialSymbols
  @Default(.showRecentCopyInMenuBar) private var showRecentCopy
  @Default(.showTitle) private var showTitle
  @Default(.showHexColorSwatch) private var showHexSwatch

  private let imageHeightFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1
    formatter.maximum = 200
    return formatter
  }()

  private let previewDelayFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 200
    formatter.maximum = 100_000
    return formatter
  }()

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(spacing: 16) {
        popupCard
        previewCard
      }
      VStack(spacing: 16) {
        menuBarCard
        listCard
      }
    }
  }

  private var popupCard: some View {
    ClipHubCard(icon: "macwindow", title: "Popup Window") {
      VStack(spacing: 10) {
        pickerRow("Open at", width: 150) {
          Picker("", selection: $popupAt) {
            ForEach(PopupPosition.allCases) { position in
              Text(position.description).tag(position)
            }
          }
        }
        pickerRow("Pin clips to", width: 150) {
          Picker("", selection: $pinTo) {
            ForEach(PinsPosition.allCases) { position in
              Text(position.description).tag(position)
            }
          }
        }
        HStack {
          Text("Image preview height").font(.system(size: 13))
          Spacer()
          TextField("", value: $imageHeight, formatter: imageHeightFormatter)
            .textFieldStyle(.roundedBorder)
            .frame(width: 64)
          Stepper("", value: $imageHeight, in: 1...200)
            .labelsHidden()
        }
      }
    }
  }

  private var previewCard: some View {
    ClipHubCard(icon: "eye", title: "Preview") {
      VStack(alignment: .leading, spacing: 10) {
        ClipHubToggleRow(
          "Open preview automatically",
          subtitle: "Show a larger preview of a clip when you hover over it.",
          isOn: $openPreviewAutomatically
        )
        HStack {
          Text("Preview delay (ms)").font(.system(size: 13))
          Spacer()
          TextField("", value: $previewDelay, formatter: previewDelayFormatter)
            .textFieldStyle(.roundedBorder)
            .frame(width: 76)
          Stepper("", value: $previewDelay, in: 200...100_000, step: 100)
            .labelsHidden()
        }
        .disabled(!openPreviewAutomatically)
        .opacity(openPreviewAutomatically ? 1 : 0.5)
      }
    }
  }

  private var menuBarCard: some View {
    ClipHubCard(icon: "menubar.rectangle", title: "Menu Bar") {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Toggle(isOn: $showInStatusBar) {
            Text("Show menu icon").font(.system(size: 13))
          }
          .toggleStyle(ClipHubTrailingSwitchStyle())

          Picker("", selection: $menuIcon) {
            ForEach(MenuIcon.allCases) { icon in
              Image(nsImage: icon.image).tag(icon)
            }
          }
          .labelsHidden()
          .controlSize(.small)
          .frame(width: 60)
          .disabled(!showInStatusBar)
        }
        ClipHubToggleRow(
          "Show recent copy next to icon",
          subtitle: "Display your most recent clip’s text in the menu bar.",
          isOn: $showRecentCopy
        )
      }
    }
  }

  private var listCard: some View {
    ClipHubCard(icon: "list.bullet.rectangle", title: "Clipboard List") {
      VStack(alignment: .leading, spacing: 9) {
        pickerRow("Highlight matches", width: 130) {
          Picker("", selection: $highlightMatch) {
            ForEach(HighlightMatch.allCases) { match in
              Text(match.description).tag(match)
            }
          }
        }
        Divider().opacity(0.5)
        HStack {
          Toggle(isOn: $showSearch) {
            Text("Show search field").font(.system(size: 13))
          }
          .toggleStyle(ClipHubTrailingSwitchStyle())

          Picker("", selection: $searchVisibility) {
            ForEach(SearchVisibility.allCases) { type in
              Text(type.description).tag(type)
            }
          }
          .labelsHidden()
          .controlSize(.small)
          .frame(width: 110)
          .disabled(!showSearch)
        }
        toggleLine("Show title above search", $showTitle)
        toggleLine("Show application icons", $showApplicationIcons)
        toggleLine("Show color swatches for hex codes", $showHexSwatch)
        toggleLine("Show special symbols", $showSpecialSymbols)
        toggleLine("Show footer menu", $showFooter)
        if !showFooter {
          Text("Without the footer, open Settings by pressing ⌘, while ClipHub is open.")
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private func toggleLine(_ title: String, _ binding: Binding<Bool>) -> some View {
    Toggle(isOn: binding) {
      Text(title).font(.system(size: 13))
    }
    .toggleStyle(ClipHubTrailingSwitchStyle())
  }

  private func pickerRow<P: View>(
    _ title: String,
    width: CGFloat,
    @ViewBuilder picker: () -> P
  ) -> some View {
    HStack {
      Text(title).font(.system(size: 13))
      Spacer()
      picker()
        .labelsHidden()
        .controlSize(.small)
        .frame(width: width)
    }
  }
}
