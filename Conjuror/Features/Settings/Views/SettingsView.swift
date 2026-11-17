import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore

  /// The unified title bar's height, in which the window controls are centred.
  private static let titleBarHeight: CGFloat = 52

  var body: some View {
    // The window's content runs under its title bar and toolbar, whose height is the top
    // safe area.
    GeometryReader { proxy in
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(SettingsSection.groups, id: \.self) { group in
            VStack(alignment: .leading, spacing: 2) {
              ForEach(group) { section in
                sidebarButton(for: section)
              }
            }
          }
          Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 164)
        .background(.thinMaterial)
        .overlay(alignment: .trailing) {
          Divider()
            .ignoresSafeArea()
        }

        VStack(alignment: .leading, spacing: 0) {
          Text(selection.title)
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 24)
            .frame(height: Self.titleBarHeight)
            .frame(height: proxy.safeAreaInsets.top, alignment: .top)

          detail(for: selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .top)
      }
    }
    .frame(width: 640)
    .frame(maxHeight: .infinity)
    .onAppear {
      launchAtLoginStore.refresh()
    }
  }

  @State private var selection = SettingsSection.general

  private func sidebarButton(for section: SettingsSection) -> some View {
    Button {
      selection = section
    } label: {
      HStack(spacing: 8) {
        SettingsIconTile(section: section)
        Text(section.title)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 8)
      .frame(height: 34)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      selection == section ? Color.primary.opacity(0.1) : .clear,
      in: RoundedRectangle(cornerRadius: 8, style: .continuous)
    )
    .accessibilityAddTraits(selection == section ? .isSelected : [])
  }

  @ViewBuilder
  private func detail(for section: SettingsSection) -> some View {
    switch section {
    case .general:
      GeneralSettingsView(
        store: store,
        launchAtLoginStore: launchAtLoginStore
      )
    case .apps:
      AppsSettingsView(store: store, launcherStore: launcherStore, hotKeyStore: hotKeyStore)
    case .emoji:
      EmojiSettingsView(store: store, hotKeyStore: hotKeyStore)
    case .clipboard:
      ClipboardSettingsView(store: store, launcherStore: launcherStore, hotKeyStore: hotKeyStore)
    case .shortcuts:
      ShortcutsSettingsView(store: store, hotKeyStore: hotKeyStore)
    case .calculator:
      CalculatorSettingsView(currencyRateStore: currencyRateStore)
    case .files:
      FilesSettingsView(
        store: store,
        hotKeyStore: hotKeyStore
      )
    case .quicklinks:
      QuicklinksSettingsView(store: store)
    case .about:
      AboutSettingsView()
    }
  }
}

enum SettingsSection: String, Identifiable {
  /// Sidebar order, with a gap between groups. The modes follow the order Tab cycles them
  /// in, then the panes for results that appear in apps search.
  static let groups: [[SettingsSection]] = [
    [.general],
    [.apps, .shortcuts, .emoji, .clipboard, .files, .calculator, .quicklinks],
    [.about],
  ]

  case general
  case apps
  case emoji
  case clipboard
  case shortcuts
  case calculator
  case files
  case quicklinks
  case about

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .apps: "Apps"
    case .emoji: "Emoji"
    case .clipboard: "Clipboard"
    case .shortcuts: "Shortcuts"
    case .calculator: "Calculator"
    case .files: "Files"
    case .quicklinks: "Quicklinks"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .apps: "square.grid.2x2"
    case .emoji: "face.smiling"
    case .clipboard: "doc.on.clipboard"
    case .shortcuts: "square.stack.3d.up"
    case .calculator: "function"
    case .files: "folder"
    case .quicklinks: "link"
    case .about: "info"
    }
  }

  var tint: Color {
    switch self {
    case .general: .gray
    case .apps: .blue
    case .emoji: .orange
    case .clipboard: .purple
    case .shortcuts: .pink
    case .calculator: .green
    case .files: .cyan
    case .quicklinks: .indigo
    case .about: .gray
    }
  }
}
