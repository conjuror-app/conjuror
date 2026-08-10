import CoreGraphics

enum LauncherLayout {
  static let width: CGFloat = 540
  static let collapsedHeight: CGFloat = 54

  private static let searchHeight: CGFloat = 52
  private static let dividerHeight: CGFloat = 1
  private static let resultRowHeight: CGFloat = 40
  private static let resultSpacing: CGFloat = 1
  private static let resultsVerticalPadding: CGFloat = 8

  static func expandedHeight(
    resultCount: Int,
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
        + CGFloat(visibleResultCount) * resultRowHeight
        + CGFloat(max(visibleResultCount - 1, 0)) * resultSpacing
    }

    let statusHeight: CGFloat = hasHotKeyError ? 26 : 0
    let launchErrorHeight: CGFloat = hasLaunchError ? 26 : 0
    return searchHeight
      + dividerHeight
      + statusHeight
      + resultsHeight
      + launchErrorHeight
  }
}
