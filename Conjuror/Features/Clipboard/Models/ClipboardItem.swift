import Foundation

struct ClipboardItem: Codable, Equatable, Identifiable, Sendable {
  private static let previewLength = 300

  let id: UUID
  let text: String
  let source: ClipboardSource?
  let firstCopiedAt: Date
  var lastCopiedAt: Date

  var preview: String {
    String(
      text.prefix(Self.previewLength * 2)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
        .prefix(Self.previewLength)
    )
  }
}

struct ClipboardSource: Codable, Equatable, Sendable {
  let name: String?
  let bundleIdentifier: String?
}
