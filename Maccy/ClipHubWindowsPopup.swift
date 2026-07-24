import AppKit
import Defaults
import SwiftUI

// MARK: - Windows 11-style clipboard popup (the only clipboard UI)

struct WindowsClipboardView: View {
  @Environment(AppState.self) private var appState
  @Environment(\.scenePhase) private var scenePhase
  @FocusState.Binding var searchFocused: Bool

  // Only one card's actions can be revealed at a time.
  @State private var revealedID: UUID?

  // Whether ClipHub has Accessibility access (needed to paste). Re-checked on each open.
  @State private var accessibilityGranted = Accessibility.isTrusted

  private var pinned: [HistoryItemDecorator] {
    appState.history.pinnedItems.filter(\.isVisible)
  }
  private var unpinned: [HistoryItemDecorator] {
    appState.history.unpinnedItems.filter(\.isVisible)
  }
  private var isEmpty: Bool { pinned.isEmpty && unpinned.isEmpty }

  var body: some View {
    VStack(spacing: 0) {
      header
      if accessibilityGranted {
        searchBar
      }
      Divider().opacity(0.35)

      // Without Accessibility nothing can be pasted, so the permission state IS the
      // popup — no banner stacked over clips that would not work anyway.
      if !accessibilityGranted {
        AccessibilityPermissionState()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if isEmpty {
        emptyState
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 6) {
            // Newest copies at the top.
            ForEach(unpinned) { card($0) }

            // Pinned items always pinned to the bottom.
            if !pinned.isEmpty {
              if !unpinned.isEmpty {
                HStack(spacing: 5) {
                  Image(systemName: "pin.fill").font(.system(size: 9))
                  Text("Pinned").font(.system(size: 10.5, weight: .semibold))
                  Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .padding(.bottom, 2)
              }
              ForEach(pinned) { card($0) }
            }
          }
          .padding(8)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background {
      // Tapping anywhere outside a revealed card closes it.
      if revealedID != nil {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation(.easeOut(duration: 0.18)) { revealedID = nil }
          }
      }
    }
    .onChange(of: scenePhase) { _, phase in
      // Each time the popup opens: clear search, close any reveal, focus the field.
      if phase == .active {
        appState.history.searchQuery = ""
        revealedID = nil
        searchFocused = true
        accessibilityGranted = Accessibility.isTrusted
      }
    }
    .onReceive(
      DistributedNotificationCenter.default().publisher(for: Accessibility.changedNotification)
    ) { _ in
      // Trust changed while the popup is open. tccd can lag the notification
      // by a few seconds, so check again a few times as it settles.
      accessibilityGranted = Accessibility.isTrusted
      for delay in [0.4, 1.5, 4.0] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          accessibilityGranted = Accessibility.isTrusted
        }
      }
    }
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 8) {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
      Text("Clipboard")
        .font(.system(size: 13, weight: .semibold))
      Spacer()

      WindowsCircleButton(systemImage: "trash", help: "Clear all", hoverTint: .red) {
        appState.history.clear()
      }
      .disabled(unpinned.isEmpty)
      .opacity(unpinned.isEmpty ? 0.4 : 1)

      WindowsCircleButton(systemImage: "gearshape", help: "Settings", hoverTint: Color.accentColor) {
        AppState.shared.appDelegate?.panel.close()
        DispatchQueue.main.async {
          AppState.shared.openPreferences()
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }

  private var searchBar: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      TextField("Search", text: Binding(
        get: { appState.history.searchQuery },
        set: { appState.history.searchQuery = $0 }
      ))
      .textFieldStyle(.plain)
      .font(.system(size: 13))
      .focused($searchFocused)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: 34))
        .foregroundStyle(.tertiary)
      Text(appState.history.searchQuery.isEmpty ? "No clipboard history yet" : "No matching clips")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      if appState.history.searchQuery.isEmpty {
        Text("Copy something and it will appear here.")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
      }
    }
    .multilineTextAlignment(.center)
    .padding(.horizontal, 24)
  }

  private func card(_ item: HistoryItemDecorator) -> some View {
    WindowsClipCard(
      item: item,
      onPaste: { Task { appState.history.select(item) } },
      onTogglePin: { appState.history.togglePin(item) },
      onDelete: { appState.history.delete(item) },
      revealedID: $revealedID
    )
    .onAppear { item.ensureThumbnailImage() }
  }

}

// MARK: - Permission state

// Replaces the empty state while Accessibility access is missing: one calm,
// centered message instead of a warning banner stacked above "No history yet".
struct AccessibilityPermissionState: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "hand.raised")
        .font(.system(size: 30, weight: .light))
        .foregroundStyle(.secondary)
        .padding(.bottom, 4)
      Text("Allow ClipHub to Paste")
        .font(.system(size: 14, weight: .semibold))
      Text("ClipHub needs Accessibility access to paste clips into other apps.")
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Button("Open System Settings") {
        AppState.shared.appDelegate?.panel.close()
        Accessibility.openSettings()
      }
      .buttonStyle(.borderedProminent)
      .padding(.top, 8)
      Text("Privacy & Security → Accessibility → ClipHub")
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .padding(.top, 2)
    }
    .multilineTextAlignment(.center)
    .padding(.horizontal, 28)
  }
}

// MARK: - Card

struct WindowsClipCard: View {
  let item: HistoryItemDecorator
  let onPaste: () -> Void
  let onTogglePin: () -> Void
  let onDelete: () -> Void

  @Binding var revealedID: UUID?
  @State private var hovering = false

  private var revealed: Bool { revealedID == item.id }

  init(
    item: HistoryItemDecorator,
    onPaste: @escaping () -> Void,
    onTogglePin: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    revealedID: Binding<UUID?>
  ) {
    self.item = item
    self.onPaste = onPaste
    self.onTogglePin = onTogglePin
    self.onDelete = onDelete
    self._revealedID = revealedID
  }

  var body: some View {
    HStack(spacing: 0) {
      // Content — pastes on tap; when revealed, tapping slides it back.
      Button {
        if revealed {
          withAnimation(.easeOut(duration: 0.18)) { revealedID = nil }
        } else {
          onPaste()
        }
      } label: {
        HStack(alignment: .center, spacing: 8) {
          if item.isPinned {
            Image(systemName: "pin.fill")
              .font(.system(size: 10))
              .foregroundStyle(Color.accentColor)
          }
          contentPreview
          Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, revealed ? 6 : 34)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .overlay(alignment: .topTrailing) {
        if !revealed { moreButton }
      }

      // Actions — sit beside the content (same height), never overlapping it.
      if revealed {
        HStack(spacing: 6) {
          WindowsActionButton(systemImage: "doc.on.clipboard", help: "Paste") {
            onPaste(); closeReveal()
          }
          WindowsActionButton(
            systemImage: item.isPinned ? "pin.slash" : "pin",
            help: item.isPinned ? "Unpin" : "Pin"
          ) {
            onTogglePin(); closeReveal()
          }
          WindowsActionButton(systemImage: "trash", help: "Delete", tint: .red) {
            onDelete(); closeReveal()
          }
        }
        .padding(.vertical, 7)
        .padding(.trailing, 7)
        .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity)
    .fixedSize(horizontal: false, vertical: true)
    .background(cardBackground)
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(Color.primary.opacity(hovering ? 0.13 : 0.06), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .onHover { hovering = $0 }
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
      .fill(Color.primary.opacity(hovering ? 0.10 : 0.05))
  }

  private var moreButton: some View {
    Button {
      withAnimation(.easeOut(duration: 0.18)) { revealedID = item.id }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.secondary)
        .frame(width: 26, height: 22)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.primary.opacity(hovering ? 0.10 : 0.0))
        )
    }
    .buttonStyle(.plain)
    .padding(6)
  }

  private func closeReveal() {
    withAnimation(.easeOut(duration: 0.18)) { revealedID = nil }
  }

  @ViewBuilder private var contentPreview: some View {
    if let thumb = item.thumbnailImage {
      Image(nsImage: thumb)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity, maxHeight: CGFloat(Defaults[.imageMaxHeight]), alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    } else if !fileURLs.isEmpty {
      // Copied file(s) — show Finder-style icon + name with extension.
      VStack(alignment: .leading, spacing: 4) {
        ForEach(fileURLs.prefix(3), id: \.self) { url in
          HStack(spacing: 7) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
              .resizable()
              .frame(width: 20, height: 20)
            Text(url.lastPathComponent)
              .font(.system(size: 12.5))
              .lineLimit(1)
              .truncationMode(.middle)
              .foregroundStyle(.primary)
          }
        }
        if fileURLs.count > 3 {
          Text("+\(fileURLs.count - 3) more")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
      }
    } else {
      Text(cleanText)
        .font(.system(size: 12.5))
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var fileURLs: [URL] { item.item.fileURLs }

  // Raw text with real line breaks (no ⏎ symbol), outer whitespace trimmed.
  private var cleanText: String {
    item.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

// MARK: - Offscreen render wrapper (used by --render-popup debug mode)

// A circular icon button with a solid background and a hover highlight (header actions).
struct WindowsCircleButton: View {
  let systemImage: String
  let help: String
  var tint: Color = .secondary
  var hoverTint: Color = .primary
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(hovering ? hoverTint : tint)
        .frame(width: 28, height: 28)
        .background(Circle().fill(Color.primary.opacity(hovering ? 0.18 : 0.10)))
        .overlay(Circle().strokeBorder(Color.primary.opacity(hovering ? 0.22 : 0.12), lineWidth: 1))
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .help(help)
    .onHover { hovering = $0 }
    .animation(.easeOut(duration: 0.12), value: hovering)
  }
}

// A full-height rounded action button with a solid background and hover highlight (card reveal).
struct WindowsActionButton: View {
  let systemImage: String
  let help: String
  var tint: Color = .primary
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(tint)
        .frame(width: 34)
        .frame(maxHeight: .infinity)
        .background(
          RoundedRectangle(cornerRadius: 7)
            .fill(Color.primary.opacity(hovering ? 0.20 : 0.10))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 7)
            .strokeBorder(Color.primary.opacity(hovering ? 0.24 : 0.14), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(help)
    .onHover { hovering = $0 }
    .animation(.easeOut(duration: 0.12), value: hovering)
  }
}

struct WindowsClipboardPreview: View {
  @FocusState private var focused: Bool

  var body: some View {
    WindowsClipboardView(searchFocused: $focused)
      .background(Color(nsColor: .windowBackgroundColor))
  }
}

// Shows the first card in its revealed (Paste / Pin / Delete) state for offscreen verification.
struct WindowsRevealedPreview: View {
  var body: some View {
    let items = AppState.shared.history.unpinnedItems.filter(\.isVisible)
    VStack(spacing: 6) {
      if let first = items.first {
        WindowsClipCard(item: first, onPaste: {}, onTogglePin: {}, onDelete: {}, revealedID: .constant(first.id))
      }
      ForEach(items.dropFirst().prefix(3)) { item in
        WindowsClipCard(item: item, onPaste: {}, onTogglePin: {}, onDelete: {}, revealedID: .constant(nil))
      }
    }
    .padding(8)
    .frame(width: 340)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}
