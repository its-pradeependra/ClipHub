import AppKit
import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import SwiftData
import SwiftUI

// MARK: - Window Controller (fixed size, non-resizing)

final class ClipHubSettingsWindowController: NSWindowController {
  static let windowSize = NSSize(width: 720, height: 600)

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
    window.setContentSize(Self.windowSize)
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
    case .storage: return "internaldrive"
    case .appearance: return "paintbrush"
    case .pins: return "pin"
    case .ignore: return "hand.raised"
    case .advanced: return "wrench.and.screwdriver"
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
        .background(.bar)

      Divider()

      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(
      width: ClipHubSettingsWindowController.windowSize.width,
      height: ClipHubSettingsWindowController.windowSize.height
    )
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
    HStack(spacing: 4) {
      ForEach(ClipHubSettingsTab.allCases) { tab in
        Button {
          selection = tab
        } label: {
          VStack(spacing: 4) {
            Image(systemName: tab.symbol)
              .font(.system(size: 15, weight: .medium))
              .frame(height: 18)
            Text(tab.title)
              .font(.system(size: 11, weight: selection == tab ? .semibold : .regular))
          }
          .frame(width: 76, height: 50)
          .foregroundStyle(selection == tab ? Color.accentColor : Color.secondary)
          .background {
            if selection == tab {
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
            }
          }
          .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
  }
}

// MARK: - Shared row: toggle with an optional description

struct SettingsToggle: View {
  let title: String
  var subtitle: String?
  @Binding var isOn: Bool

  init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
    self.title = title
    self.subtitle = subtitle
    self._isOn = isOn
  }

  var body: some View {
    Toggle(isOn: $isOn) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        if let subtitle {
          Text(subtitle)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}

// MARK: - General

struct ClipHubGeneralTab: View {
  @Default(.searchMode) private var searchMode
  @Default(.pasteByDefault) private var pasteByDefault
  @Default(.removeFormattingByDefault) private var removeFormatting

  @State private var updater = SoftwareUpdater()

  var body: some View {
    Form {
      Section("Startup") {
        LaunchAtLogin.Toggle { Text("Launch at login") }
        Toggle("Check for updates automatically", isOn: $updater.automaticallyChecksForUpdates)
        Button("Check for Updates Now") { updater.checkForUpdates() }
      }

      Section("Shortcut") {
        LabeledContent("Open ClipHub") {
          KeyboardShortcuts.Recorder(for: .popup)
        }
      }

      Section("Pasting") {
        Picker("Search mode", selection: $searchMode) {
          ForEach(Search.Mode.allCases) { mode in
            Text(mode.description).tag(mode)
          }
        }
        SettingsToggle(
          "Paste directly on selection",
          subtitle: "Choosing a clip pastes it straight into the app you’re using.",
          isOn: $pasteByDefault
        )
        SettingsToggle(
          "Paste without formatting",
          subtitle: "Paste clips as plain text, dropping fonts and colors.",
          isOn: $removeFormatting
        )
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Storage

struct ClipHubStorageTab: View {
  @Observable
  final class TypesModel {
    var saveFiles = false {
      didSet { apply(saveFiles, StorageType.files.types) }
    }
    var saveImages = false {
      didSet { apply(saveImages, StorageType.images.types) }
    }
    var saveText = false {
      didSet { apply(saveText, StorageType.text.types) }
    }

    private func apply(_ on: Bool, _ types: [NSPasteboard.PasteboardType]) {
      Defaults.withoutPropagation {
        if on {
          Defaults[.enabledPasteboardTypes].formUnion(types)
        } else {
          Defaults[.enabledPasteboardTypes].subtract(types)
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
    Form {
      Section {
        Toggle("Text", isOn: $model.saveText)
        Toggle("Images", isOn: $model.saveImages)
        Toggle("Files", isOn: $model.saveFiles)
      } header: {
        Text("Store")
      } footer: {
        Text("Choose which kinds of copied content ClipHub keeps in history.")
      }

      Section("History") {
        LabeledContent("Maximum items") {
          HStack(spacing: 6) {
            TextField("", value: $size, formatter: sizeFormatter)
              .textFieldStyle(.roundedBorder)
              .frame(width: 62)
              .multilineTextAlignment(.trailing)
            Stepper("", value: $size, in: 50...1000, step: 10)
              .labelsHidden()
          }
        }
        LabeledContent("Estimated memory usage") {
          Text(storageSize).foregroundStyle(.secondary)
        }
        Picker("Sort order", selection: $sortBy) {
          ForEach(Sorter.By.allCases) { mode in
            Text(mode.description).tag(mode)
          }
        }
      }
    }
    .formStyle(.grouped)
    .onAppear { storageSize = Storage.shared.size }
  }
}

// MARK: - Appearance

struct ClipHubAppearanceTab: View {
  @Default(.popupPosition) private var popupAt
  @Default(.imageMaxHeight) private var imageHeight
  @Default(.menuIcon) private var menuIcon
  @Default(.showInStatusBar) private var showInStatusBar
  @Default(.showRecentCopyInMenuBar) private var showRecentCopy

  private let imageHeightFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 20
    formatter.maximum = 200
    return formatter
  }()

  var body: some View {
    Form {
      Section("Popup") {
        Picker("Open at", selection: $popupAt) {
          ForEach(PopupPosition.allCases) { position in
            Text(position.description).tag(position)
          }
        }
        LabeledContent("Image preview height") {
          HStack(spacing: 6) {
            TextField("", value: $imageHeight, formatter: imageHeightFormatter)
              .textFieldStyle(.roundedBorder)
              .frame(width: 56)
              .multilineTextAlignment(.trailing)
            Stepper("", value: $imageHeight, in: 20...200, step: 10)
              .labelsHidden()
          }
        }
      }

      Section("Menu Bar") {
        Toggle("Show menu-bar icon", isOn: $showInStatusBar)
        Picker("Icon style", selection: $menuIcon) {
          ForEach(MenuIcon.allCases) { icon in
            Image(nsImage: icon.image).tag(icon)
          }
        }
        .pickerStyle(.segmented)
        .disabled(!showInStatusBar)
        SettingsToggle(
          "Show recent copy next to icon",
          subtitle: "Display your most recently copied text in the menu bar.",
          isOn: $showRecentCopy
        )
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Pins

struct ClipHubPinsTab: View {
  @Environment(AppState.self) private var appState
  @Environment(\.modelContext) private var modelContext

  @Query(filter: #Predicate<HistoryItem> { $0.pin != nil }, sort: \.firstCopiedAt)
  private var items: [HistoryItem]

  @State private var availablePins: [String] = []

  var body: some View {
    Form {
      Section {
        if items.isEmpty {
          Text("No pinned items yet. Add one below, or press the pin button on any clip.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
        } else {
          ForEach(items) { item in
            pinRow(item)
          }
        }
      } header: {
        HStack {
          Text("Pinned Items")
          Spacer()
          Button {
            addPin()
          } label: {
            Label("Add Pin", systemImage: "plus")
          }
          .controlSize(.small)
          .textCase(nil)
        }
      } footer: {
        Text("Pinned items stay at the bottom of your clipboard list. While ClipHub is open, press ⌘ and the shortcut letter to paste one instantly.")
      }
    }
    .formStyle(.grouped)
    .onAppear { availablePins = HistoryItem.availablePins }
  }

  private func pinRow(_ item: HistoryItem) -> some View {
    HStack(spacing: 10) {
      pinShortcutChip(item)
        .frame(width: 52, alignment: .leading)

      PinTitleView(item: item)
        .textFieldStyle(.plain)
        .frame(width: 150, alignment: .leading)

      PinValueView(item: item)
        .textFieldStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(role: .destructive) {
        unpin(item)
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .help("Unpin")
    }
    .padding(.vertical, 2)
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
        .font(.system(size: 12, weight: .semibold, design: .rounded))
    }
    .menuStyle(.borderlessButton)
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

// MARK: - Ignore

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
    FriendlyType(id: "org.nspasteboard.TransientType", title: "Sensitive / Transient Data"),
    FriendlyType(id: "com.agilebits.onepassword", title: "1Password"),
    FriendlyType(id: "de.petermaurer.TransientPasteboardType", title: "Keyboard Maestro")
  ]

  var body: some View {
    Form {
      Section {
        if ignoredApps.isEmpty {
          Text("No applications added.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        } else {
          ForEach(ignoredApps, id: \.self) { app in
            appRow(app)
          }
        }
        SettingsToggle(
          "Only capture from these apps",
          subtitle: "When on, the list becomes an allow-list — everything else is ignored.",
          isOn: $ignoreAllExcept
        )
      } header: {
        HStack {
          Text("Ignored Applications")
          Spacer()
          Button {
            isAddingApp = true
          } label: {
            Label("Add App", systemImage: "plus")
          }
          .controlSize(.small)
          .textCase(nil)
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
      } footer: {
        Text("Anything copied while one of these apps is in front is never stored.")
      }

      Section {
        ForEach(friendlyTypes) { type in
          Toggle(type.title, isOn: Binding(
            get: { ignoredTypes.contains(type.id) },
            set: { on in
              if on { ignoredTypes.insert(type.id) } else { ignoredTypes.remove(type.id) }
            }
          ))
        }
      } header: {
        Text("Content Types")
      } footer: {
        Text("ClipHub already skips items apps mark as concealed. Toggle these to ignore extra known types.")
      }

      Section {
        if ignoredRegexps.isEmpty {
          Text("No patterns added.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        } else {
          ForEach(Array(ignoredRegexps.enumerated()), id: \.offset) { index, _ in
            HStack(spacing: 8) {
              TextField("pattern", text: Binding(
                get: { index < ignoredRegexps.count ? ignoredRegexps[index] : "" },
                set: { newValue in
                  if index < ignoredRegexps.count { ignoredRegexps[index] = newValue }
                }
              ))
              .textFieldStyle(.roundedBorder)
              .font(.system(.body, design: .monospaced))

              Button(role: .destructive) {
                if index < ignoredRegexps.count { ignoredRegexps.remove(at: index) }
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
            }
          }
        }
      } header: {
        HStack {
          Text("Regular Expressions")
          Spacer()
          Button {
            if !ignoredRegexps.contains("") { ignoredRegexps.append("") }
          } label: {
            Label("Add Pattern", systemImage: "plus")
          }
          .controlSize(.small)
          .textCase(nil)
        }
      } footer: {
        Text("Copied text that fully matches a pattern here is never stored (advanced).")
      }
    }
    .formStyle(.grouped)
  }

  private func appRow(_ bundleID: String) -> some View {
    HStack(spacing: 8) {
      if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
          .resizable()
          .frame(width: 18, height: 18)
        Text(NSWorkspace.shared.applicationName(url: url)).lineLimit(1)
      } else {
        Image(systemName: "questionmark.app")
          .foregroundStyle(.secondary)
          .frame(width: 18, height: 18)
        Text(bundleID).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer()
      Button(role: .destructive) {
        ignoredApps.removeAll { $0 == bundleID }
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
    }
  }
}

// MARK: - Advanced

struct ClipHubAdvancedTab: View {
  @Default(.ignoreEvents) private var ignoreEvents
  @Default(.clearOnQuit) private var clearOnQuit
  @Default(.clearSystemClipboard) private var clearSystemClipboard

  @State private var showCommands = false

  var body: some View {
    Form {
      Section {
        SettingsToggle(
          "Pause clipboard capture",
          subtitle: "Temporarily ignore all new copies — useful while handling sensitive data.",
          isOn: $ignoreEvents
        )
      } header: {
        Text("Capture")
      }

      Section("On Quit") {
        SettingsToggle(
          "Clear history on quit",
          subtitle: "Erase all clipboard history whenever ClipHub quits.",
          isOn: $clearOnQuit
        )
        SettingsToggle(
          "Also clear the system clipboard",
          subtitle: "Empty the macOS clipboard too when clearing history.",
          isOn: $clearSystemClipboard
        )
      }

      Section {
        Button("Show Command-Line Commands…") { showCommands = true }
          .popover(isPresented: $showCommands, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
              Text("Pause capture from the command line")
                .font(.headline)
              Text(NSLocalizedString("TurnOffShellScript", tableName: "AdvancedSettings", comment: ""))
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
              Divider()
              Text("Ignore only the next copy")
                .font(.headline)
              Text(NSLocalizedString("TurnOffNextShellScript", tableName: "AdvancedSettings", comment: ""))
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            }
            .padding(16)
            .frame(width: 440)
          }
      } header: {
        Text("Developer")
      }
    }
    .formStyle(.grouped)
  }
}
