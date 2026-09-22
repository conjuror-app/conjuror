import CoreServices
import Foundation

@MainActor
final class ApplicationDirectoryMonitor {
  private let onChange: @MainActor () -> Void
  private var stream: FSEventStreamRef?
  private var watchedPaths = [String]()

  init(onChange: @escaping @MainActor () -> Void) {
    self.onChange = onChange
  }

  isolated deinit {
    stop()
  }

  @discardableResult
  func start(directories: [URL]) -> Bool {
    let paths = directories.map { $0.standardizedFileURL.resolvingSymlinksInPath().path }.sorted()

    if stream != nil, paths == watchedPaths { return true }
    stop()

    guard !paths.isEmpty else { return false }

    var context = FSEventStreamContext(
      version: 0,
      info: Unmanaged.passUnretained(self).toOpaque(),
      retain: nil,
      release: nil,
      copyDescription: nil
    )

    guard
      let stream = FSEventStreamCreate(
        nil,
        { _, info, _, _, _, _ in
          guard let info else { return }

          // The stream delivers callbacks on the main queue and stops before deallocation.
          MainActor.assumeIsolated {
            Unmanaged<ApplicationDirectoryMonitor>.fromOpaque(info).takeUnretainedValue().onChange()
          }
        },
        &context,
        paths as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        0.5,
        FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot)
      )
    else { return false }

    FSEventStreamSetDispatchQueue(stream, .main)

    guard FSEventStreamStart(stream) else {
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)

      return false
    }

    self.stream = stream
    watchedPaths = paths

    return true
  }

  func stop() {
    guard let stream else { return }

    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    self.stream = nil
    watchedPaths = []
  }
}
