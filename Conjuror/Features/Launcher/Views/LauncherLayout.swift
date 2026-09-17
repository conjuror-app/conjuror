import CoreGraphics

struct LauncherLayout {
  static let width: CGFloat = 540
  static let emojiColumnCount = 9
  static let emojiRowSpacing: CGFloat = 2
  static let emojiRecentHeaderHeight: CGFloat = 16
  static let windowMargin: CGFloat = 8
  static let searchFieldHeight: CGFloat = 38
  static let resultSpacing: CGFloat = 1
  static let resultsVerticalPadding: CGFloat = 4
  static let footerContentHeight: CGFloat = 28
  static let statusHeight: CGFloat = 26

  private static let dividerHeight: CGFloat = 1

  static func windowSize(contentHeight: CGFloat) -> CGSize {
    CGSize(
      width: width + windowMargin * 2,
      height: contentHeight + windowMargin * 2
    )
  }

  let appearance: LauncherAppearance

  var searchTopPadding: CGFloat { appearance == .minimal ? 4 : 8 }
  var searchBottomPadding: CGFloat { appearance == .minimal ? 2 : 6 }
  var searchHeight: CGFloat {
    Self.searchFieldHeight + searchTopPadding + searchBottomPadding
  }
  var collapsedHeight: CGFloat { searchHeight + 2 }
  var resultRowHeight: CGFloat { appearance == .minimal ? 32 : 40 }
  var resultIconSize: CGFloat { appearance == .minimal ? 22 : 26 }
  var resultFontSize: CGFloat { appearance == .minimal ? 13 : 14 }
  var fileIconSize: CGFloat { appearance == .minimal ? 22 : 30 }
  var shortcutSymbolSize: CGFloat { appearance == .minimal ? 15 : 17 }
  var calculatorSymbolSize: CGFloat { appearance == .minimal ? 18 : 22 }
  var emojiRowHeight: CGFloat { appearance == .minimal ? 36 : 42 }
  var emojiFontSize: CGFloat { appearance == .minimal ? 23 : 27 }
  var showsFooter: Bool { appearance == .standard }

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
    } else {
      let visibleResultCount = min(resultCount, maximumVisibleResults)
      resultsHeight =
        Self.resultsVerticalPadding * 2
        + resultsHeaderHeight
        + CGFloat(visibleResultCount) * (resultRowHeight ?? self.resultRowHeight)
        + CGFloat(max(visibleResultCount - 1, 0)) * resultSpacing
    }

    let statusHeight: CGFloat = hasHotKeyError ? Self.statusHeight : 0
    let footerHeight: CGFloat =
      showsFooter && resultCount > 0 && !hasCatalogError
      ? Self.footerContentHeight + Self.dividerHeight : 0
    let launchErrorHeight: CGFloat = hasLaunchError ? Self.statusHeight : 0
    return searchHeight
      + Self.dividerHeight
      + statusHeight
      + resultsHeight
      + footerHeight
      + launchErrorHeight
  }
}
