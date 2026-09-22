import Foundation

struct FileSearchResult: Identifiable, Equatable, Sendable {
  let url: URL
  let displayName: String
  let isDirectory: Bool
  let modificationDate: Date?

  var id: String {
    url.standardizedFileURL.path
  }

  var parentPath: String {
    let homePath = FileManager.default.homeDirectoryForCurrentUser.path
    let path = url.deletingLastPathComponent().path

    if path == homePath {
      return "~"
    }

    if path.hasPrefix(homePath + "/") {
      return "~" + path.dropFirst(homePath.count)
    }

    return path
  }
}
