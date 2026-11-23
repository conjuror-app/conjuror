import CoreGraphics

struct LauncherLayout {
  static let width: CGFloat = 540
  static let commandBarWidth: CGFloat = 660
  static let emojiColumnCount = 9
  static let emojiRowSpacing: CGFloat = 2
  static let emojiRecentHeaderHeight: CGFloat = 16
  static let windowMargin: CGFloat = 8
  static let searchFieldHeight: CGFloat = 38
  static let resultSpacing: CGFloat = 1
  static let resultsVerticalPadding: CGFloat = 4
  static let footerContentHeight: CGFloat = 28
  static let commandBarFooterContentHeight: CGFloat = 38
  static let statusHeight: CGFloat = 26
  static let calculatorCardHeight: CGFloat = 86
  static let sectionHeaderHeight: CGFloat = 24
  static let splitDetailHeight: CGFloat = 276
  static let splitListWidth: CGFloat = 256

  private static let dividerHeight: CGFloat = 1

  static func windowSize(contentHeight: CGFloat) -> CGSize {
    windowSize(width: width, contentHeight: contentHeight)
  }

  static func windowSize(width: CGFloat, contentHeight: CGFloat) -> CGSize {
    CGSize(
      width: width + windowMargin * 2,
      height: contentHeight + windowMargin * 2
    )
  }

  let appearance: LauncherAppearance

  var isCommandBar: Bool { appearance == .commandBar }
  var width: CGFloat { isCommandBar ? Self.commandBarWidth : Self.width }
  var cornerRadius: CGFloat { isCommandBar ? 12 : 16 }
  var searchFieldHeight: CGFloat { isCommandBar ? 44 : Self.searchFieldHeight }
  var searchTopPadding: CGFloat {
    switch appearance {
    case .minimal: 4
    case .standard: 8
    case .commandBar: 4
    }
  }
  var searchBottomPadding: CGFloat {
    switch appearance {
    case .minimal: 2
    case .standard: 6
    case .commandBar: 4
    }
  }
  var searchHeight: CGFloat {
    searchFieldHeight + searchTopPadding + searchBottomPadding
  }
  var collapsedHeight: CGFloat { searchHeight + 2 }
  var resultRowHeight: CGFloat {
    switch appearance {
    case .minimal: 32
    case .standard: 40
    case .commandBar: 38
    }
  }
  var resultIconSize: CGFloat {
    switch appearance {
    case .minimal: 22
    case .standard: 26
    case .commandBar: 22
    }
  }
  var resultFontSize: CGFloat {
    switch appearance {
    case .minimal: 13
    case .standard: 14
    case .commandBar: 13.5
    }
  }
  var fileIconSize: CGFloat {
    switch appearance {
    case .minimal: 22
    case .standard: 30
    case .commandBar: 22
    }
  }
  var shortcutSymbolSize: CGFloat {
    switch appearance {
    case .minimal: 15
    case .standard: 17
    case .commandBar: 14
    }
  }
  var calculatorSymbolSize: CGFloat {
    switch appearance {
    case .minimal: 18
    case .standard: 22
    case .commandBar: 18
    }
  }
  var emojiRowHeight: CGFloat {
    switch appearance {
    case .minimal: 36
    case .standard: 42
    case .commandBar: 40
    }
  }
  var emojiFontSize: CGFloat {
    switch appearance {
    case .minimal: 23
    case .standard: 27
    case .commandBar: 26
    }
  }
  var footerContentHeight: CGFloat {
    isCommandBar ? Self.commandBarFooterContentHeight : Self.footerContentHeight
  }
  var showsFooter: Bool { appearance != .minimal }

  func windowSize(contentHeight: CGFloat) -> CGSize {
    Self.windowSize(width: width, contentHeight: contentHeight)
  }

  func emojiExpandedHeight(
    itemCount: Int,
    hasRecentHeader: Bool,
    hasHotKeyError: Bool,
    maximumVisibleResults: Int
  ) -> CGFloat {
    let rowCount = (itemCount + Self.emojiColumnCount - 1) / Self.emojiColumnCount
    let headerHeight =
      hasRecentHeader ? Self.emojiRecentHeaderHeight + Self.resultSpacing : 0
    return expandedHeight(
      resultCount: rowCount,
      resultRowHeight: emojiRowHeight,
      resultSpacing: Self.emojiRowSpacing,
      resultsHeaderHeight: headerHeight,
      hasCatalogError: false,
      hasHotKeyError: hasHotKeyError,
      hasLaunchError: false,
      maximumVisibleResults: maximumVisibleResults
    )
  }

  func expandedHeight(
    resultCount: Int,
    resultRowHeight: CGFloat? = nil,
    resultSpacing: CGFloat = Self.resultSpacing,
    resultsHeaderHeight: CGFloat = 0,
    extraResultsHeight: CGFloat = 0,
    usesSplitDetail: Bool = false,
    hasCatalogError: Bool,
    hasHotKeyError: Bool,
    hasLaunchError: Bool,
    maximumVisibleResults: Int
  ) -> CGFloat {
    let resultsHeight: CGFloat
    if hasCatalogError {
      resultsHeight = 104
    } else if resultCount == 0 {
      resultsHeight = 72
    } else if usesSplitDetail {
      resultsHeight = Self.splitDetailHeight
    } else {
      let visibleResultCount = min(resultCount, maximumVisibleResults)
      resultsHeight =
        Self.resultsVerticalPadding * 2
        + resultsHeaderHeight
        + extraResultsHeight
        + CGFloat(visibleResultCount) * (resultRowHeight ?? self.resultRowHeight)
        + CGFloat(max(visibleResultCount - 1, 0)) * resultSpacing
    }

    let statusHeight: CGFloat = hasHotKeyError ? Self.statusHeight : 0
    let footerHeight: CGFloat =
      showsFooter && resultCount > 0 && !hasCatalogError
      ? footerContentHeight + Self.dividerHeight : 0
    let launchErrorHeight: CGFloat = hasLaunchError ? Self.statusHeight : 0
    return searchHeight
      + Self.dividerHeight
      + statusHeight
      + resultsHeight
      + footerHeight
      + launchErrorHeight
  }
}
