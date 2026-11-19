import SwiftUI

struct SelectableResultRow<Content: View>: View {
  let id: LauncherResultID
  let isSelected: Bool
  let layout: LauncherLayout
  let actionTitle: String
  let accessibilityLabel: String
  let accessibilityHint: String
  let help: String
  let action: () -> Void
  let onHover: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    Button(action: action) {
      HStack(spacing: layout.resultIconSpacing) {
        content()
        LauncherResultHint(id: id, isSelected: isSelected, layout: layout, actionTitle: actionTitle)
      }
      .padding(.horizontal, 7)
      .frame(height: layout.resultRowHeight)
      .contentShape(Rectangle())
      .modifier(LauncherResultHighlight(layout: layout, isSelected: isSelected))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    .onHover { isHovering in
      if isHovering { onHover() }
    }
    .help(help)
  }
}

struct LauncherResultHighlight: ViewModifier {
  let layout: LauncherLayout
  let isSelected: Bool
  var cornerRadius: CGFloat = 8
  var accentOpacity: Double = 0.14
  var allowsAccentBar = true

  private var fill: Color {
    guard isSelected else { return .clear }
    return layout.appearance.usesDarkMaterial
      ? .white.opacity(0.09) : .accentColor.opacity(accentOpacity)
  }

  func body(content: Content) -> some View {
    content
      .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(alignment: .leading) {
        if isSelected, layout.appearance.usesDetachedResults, allowsAccentBar {
          Capsule()
            .fill(Color(red: 1, green: 0.72, blue: 0.31))
            .frame(width: 3, height: 22)
            .shadow(color: .orange.opacity(0.8), radius: 4)
            .padding(.leading, 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
  }
}

struct LauncherResultHint: View {
  let id: LauncherResultID
  let isSelected: Bool
  let layout: LauncherLayout
  let actionTitle: String

  var body: some View {
    if let title {
      Text(title)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .fixedSize()
        .accessibilityHidden(true)
    }
  }

  @Environment(\.launcherResultNumbers) private var numbers

  private var title: String? {
    if layout.appearance.usesTypography {
      if isSelected { return "⏎" }
      if let number = numbers[id] { return "⌘\(number)" }
    } else if layout.appearance.usesDetachedResults, isSelected {
      return "⏎ \(actionTitle)"
    }
    return nil
  }
}

struct LauncherResultTitle: View {
  let name: String
  let layout: LauncherLayout
  var secondaryText = ""
  var alias: String?
  var highlightsName = true

  var body: some View {
    Group {
      if layout.appearance.usesTypography {
        highlightedTitle
          .font(.system(size: layout.resultFontSize, weight: .light))
          .foregroundStyle(.white.opacity(0.68))
      } else {
        Text(name)
          .font(.system(size: layout.resultFontSize, weight: .medium))
          .foregroundStyle(.primary)
      }
    }
    .lineLimit(1)
  }

  @Environment(\.launcherSearchQuery) private var query

  private var highlightedTitle: Text {
    let ranges =
      highlightsName
      ? SearchableName.matchingRanges(
        in: name,
        query: query,
        secondaryText: secondaryText,
        alias: alias
      )
      : []
    guard !ranges.isEmpty else { return Text(verbatim: name) }

    var title = Text(verbatim: "")
    var start = name.startIndex
    for range in ranges {
      let unmatched = Text(verbatim: String(name[start..<range.lowerBound]))
      let matched = Text(verbatim: String(name[range])).bold().foregroundStyle(.white)
      title = Text("\(title)\(unmatched)\(matched)")
      start = range.upperBound
    }
    let suffix = Text(verbatim: String(name[start...]))
    return Text("\(title)\(suffix)")
  }
}

extension EnvironmentValues {
  @Entry var launcherResultNumbers: [LauncherResultID: Int] = [:]
  @Entry var launcherSearchQuery = SearchQuery("")
}
