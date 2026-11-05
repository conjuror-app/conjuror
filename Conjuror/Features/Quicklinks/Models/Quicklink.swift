import Foundation

/// A saved URL that opens from the launcher, optionally filled in with search text.
struct Quicklink: Codable, Hashable, Identifiable {
  enum Target: Codable, Hashable {
    /// The app macOS uses for the URL's scheme, such as the default browser for `https`.
    case defaultApplication
    case application(path: String)
  }

  static let placeholder = "{query}"
  static let defaultWebSearchID = UUID(uuidString: "4C488844-A7DF-4046-B89B-6C6B9F8860ED")!

  static let builtIns = [
    Quicklink(
      id: UUID(uuidString: "F86BACDA-9481-4A3E-B74D-37E32EBDE67E")!,
      name: "Google",
      keyword: "g",
      urlTemplate: "https://www.google.com/search?q={query}"
    ),
    Quicklink(
      id: defaultWebSearchID,
      name: "DuckDuckGo",
      keyword: "ddg",
      urlTemplate: "https://duckduckgo.com/?q={query}"
    ),
    Quicklink(
      id: UUID(uuidString: "B59F6AB0-1B27-43C2-BDE1-4DED499348EC")!,
      name: "GitHub",
      keyword: "gh",
      urlTemplate: "https://github.com/search?q={query}"
    ),
    Quicklink(
      id: UUID(uuidString: "048C3437-B706-41C1-9E29-97FF141F8D7D")!,
      name: "Wikipedia",
      keyword: "wiki",
      urlTemplate: "https://en.wikipedia.org/w/index.php?search={query}"
    ),
  ]

  /// RFC 3986 unreserved characters, so encoded text is safe in a path or a query.
  private static let unreservedCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  )

  /// Returns why the quicklink can't be saved alongside the existing ones, or `nil` if it can.
  static func validationError(for quicklink: Quicklink, among existing: [Quicklink]) -> String? {
    if quicklink.name.isEmpty { return "Enter a name." }

    if let keyword = quicklink.keyword {
      if keyword.contains(where: \.isWhitespace) { return "Keywords can’t contain spaces." }

      if let prefix = keyword.first, LauncherMode.requested(byPrefix: prefix) != nil {
        return "Keywords can’t start with ;, >, :, /, ! or @."
      }

      if existing.contains(where: {
        $0.id != quicklink.id && $0.keyword?.lowercased() == keyword.lowercased()
      }) {
        return "Another quicklink already uses “\(keyword)”."
      }
    }

    if quicklink.urlTemplate.isEmpty { return "Enter a URL." }

    if quicklink.url(argument: "test") == nil {
      return "Enter a URL that starts with a scheme such as https://."
    }

    return nil
  }

  let id: UUID
  let name: String
  let keyword: String?
  let urlTemplate: String
  let target: Target

  var acceptsQuery: Bool {
    urlTemplate.contains(Self.placeholder)
  }

  init(
    id: UUID = UUID(),
    name: String,
    keyword: String? = nil,
    urlTemplate: String,
    target: Target = .defaultApplication
  ) {
    let keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines)

    self.id = id
    self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    self.keyword = keyword?.isEmpty == false ? keyword : nil
    self.urlTemplate = urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
    self.target = target
  }

  /// The URL with every placeholder replaced by the percent-encoded argument. Templates without a
  /// placeholder ignore the argument. Returns `nil` when the result has no scheme.
  func url(argument: String) -> URL? {
    let encodedArgument =
      argument
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .addingPercentEncoding(withAllowedCharacters: Self.unreservedCharacters) ?? ""
    let string = urlTemplate.replacingOccurrences(of: Self.placeholder, with: encodedArgument)

    guard let url = URL(string: string), url.scheme?.isEmpty == false else { return nil }

    return url
  }
}

extension Quicklink: SearchIndexable {
  var searchCandidate: SearchIndex<Quicklink>.Candidate {
    SearchIndex.Candidate(
      item: self,
      name: name,
      secondaryText: keyword ?? "",
      recencyKey: id.uuidString,
      stableKey: id.uuidString
    )
  }
}
