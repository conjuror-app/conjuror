import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Keyword quicklinks come first, then apps, name-matched links, and web search last")
  func testQuicklinkResultOrder() async {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    settings.setShowsSystemSettingsItems(false)
    settings.setShowsSystemCommands(false)
    let blog = Quicklink(name: "Ghost Blog", urlTemplate: "https://ghost.example.com")
    #expect(settings.saveQuicklink(blog) == nil)
    let desktop = application("GitHub Desktop", id: "com.github.GitHubClient")
    let opener = RecordingQuicklinkOpener()
    let store = makeStore(
      applications: [desktop],
      settingsStore: settings,
      openQuicklink: opener.open
    )
    store.loadApplications()
    await waitForApplications(store)

    store.updateQuery("gh")

    var order = [store.selectedResultID]
    for _ in 0..<3 {
      store.moveSelection(.down)
      order.append(store.selectedResultID)
    }
    let github = Quicklink.builtIns.first { $0.keyword == "gh" }!
    #expect(
      order == [.quicklink(github.id), .application(desktop.id), .quicklink(blog.id), .webSearch]
    )
    #expect(store.webSearchMatch?.argument == "gh")
    #expect(opener.opened.isEmpty)
  }

  @Test("Return on a bare keyword completes it, then opens the encoded search")
  func testKeywordCompletesThenOpens() async {
    let opener = RecordingQuicklinkOpener()
    var events = [LauncherEvent]()
    let store = makeStore(openQuicklink: opener.open, onEvent: { events.append($0) })

    store.updateQuery("gh")
    store.openSelectedResult()
    #expect(store.query == "gh ")
    #expect(opener.opened.isEmpty)

    store.updateQuery("gh swift testing")
    store.openSelectedResult()
    while events.isEmpty { await Task.yield() }

    #expect(
      opener.opened.map(\.url.absoluteString) == ["https://github.com/search?q=swift%20testing"]
    )
    #expect(opener.opened.map(\.target) == [.defaultApplication])
    #expect(events == [.quicklinkOpened])
    #expect(store.query.isEmpty)
  }

  @Test("Option-Return searches the web from any row, and the row follows the setting")
  func testWebSearchFallback() async {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let safari = application("Safari", id: "com.apple.Safari")
    let opener = RecordingQuicklinkOpener()
    let store = makeStore(
      applications: [safari],
      settingsStore: settings,
      openQuicklink: opener.open
    )
    store.loadApplications()
    await waitForApplications(store)

    store.updateQuery("zzqx")
    #expect(store.selectedResultID == .webSearch)

    store.updateQuery("ddg swift")
    #expect(store.webSearchMatch == nil)

    store.updateQuery("safari")
    #expect(store.selectedResultID == .application(safari.id))
    store.openWebSearch()
    while opener.opened.isEmpty { await Task.yield() }
    #expect(opener.opened.map(\.url.absoluteString) == ["https://duckduckgo.com/?q=safari"])

    settings.setWebSearchQuicklink(id: nil)
    store.updateQuery("safari")
    #expect(store.webSearchMatch == nil)
  }

  @Test("A failed quicklink open shows an error and keeps the query")
  func testFailedQuicklinkOpen() async {
    let opener = RecordingQuicklinkOpener(error: TestError.launchFailed)
    let store = makeStore(openQuicklink: opener.open)

    store.updateQuery("gh swift")
    store.openSelectedResult()
    while store.actionErrorMessage == nil { await Task.yield() }

    #expect(store.actionErrorMessage == "Couldn’t open GitHub. Launch failed")
    #expect(store.query == "gh swift")
  }
}

@MainActor
final class RecordingQuicklinkOpener {
  private(set) var opened = [(url: URL, target: Quicklink.Target)]()
  private let error: Error?

  init(error: Error? = nil) {
    self.error = error
  }

  func open(_ url: URL, target: Quicklink.Target) async throws {
    opened.append((url, target))

    if let error { throw error }
  }
}
