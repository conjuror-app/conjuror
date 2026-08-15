import CoreGraphics

enum LauncherLayout {
  static let width: CGFloat = 540
  static let collapsedHeight: CGFloat = 54
  static let emojiColumnCount = 9
  static let emojiRowHeight: CGFloat = 42
  static let emojiRowSpacing: CGFloat = 2
  static let emojiRecentHeaderHeight: CGFloat = 16
  static let windowMargin: CGFloat = 8

  private static let searchHeight: CGFloat = 52
  private static let dividerHeight: CGFloat = 1
  private static let defaultResultRowHeight: CGFloat = 40
  private static let defaultResultSpacing: CGFloat = 1
  private static let resultsVerticalPadding: CGFloat = 8
  private static let footerHeight: CGFloat = 29

  static func windowSize(contentHeight: CGFloat) -> CGSize {
    CGSize(
      width: width + windowMargin * 2,
      height: contentHeight + windowMargin * 2
    )
  }

  static func emojiExpandedHeight(
    itemCount: Int,
    hasRecentHeader: Bool,
    hasHotKeyError: Bool,
    maximumVisibleResults: Int
  ) -> CGFloat {
    let rowCount = (itemCount + emojiColumnCount - 1) / emojiColumnCount
    let headerHeight =
      hasRecentHeader ? emojiRecentHeaderHeight + defaultResultSpacing : 0
    return expandedHeight(
      resultCount: rowCount,
      resultRowHeight: emojiRowHeight,
      resultSpacing: emojiRowSpacing,
      resultsHeaderHeight: headerHeight,
      hasCatalogError: false,
      hasHotKeyError: hasHotKeyError,
      hasLaunchError: false,
      maximumVisibleResults: maximumVisibleResults
    )
  }

  static func expandedHeight(
    resultCount: Int,
    resultRowHeight: CGFloat = defaultResultRowHeight,
    resultSpacing: CGFloat = defaultResultSpacing,
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
        resultsVerticalPadding
        + resultsHeaderHeight
        + CGFloat(visibleResultCount) * resultRowHeight
        + CGFloat(max(visibleResultCount - 1, 0)) * resultSpacing
    }

    let statusHeight: CGFloat = hasHotKeyError ? 26 : 0
    let footerHeight: CGFloat = resultCount > 0 && !hasCatalogError ? Self.footerHeight : 0
    let launchErrorHeight: CGFloat = hasLaunchError ? 26 : 0
    return searchHeight
      + dividerHeight
      + statusHeight
      + resultsHeight
      + footerHeight
      + launchErrorHeight
  }
}
