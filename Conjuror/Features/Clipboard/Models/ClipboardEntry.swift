import Foundation

struct ClipboardEntry: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  let text: String
  let capturedAt: Date

  init(id: UUID = UUID(), text: String, capturedAt: Date = Date()) {
    self.id = id
    self.text = text
    self.capturedAt = capturedAt
  }
}
