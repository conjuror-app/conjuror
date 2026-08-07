import AppKit
import Foundation

struct ApplicationCatalog: ApplicationCatalogLoading {
    static let applicationDirectories = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true),
    ]

    static func filteredAndDeduplicated(
        _ candidates: [ApplicationCatalogCandidate],
        excludingBundleIdentifier: String?
    ) -> [ApplicationCatalogCandidate] {
        let excludedIdentifier = excludingBundleIdentifier?.lowercased()
        var seenBundleIdentifiers = Set<String>()
        var seenURLs = Set<String>()

        return candidates
            .sorted(by: candidateOrder)
            .filter { candidate in
                guard !candidate.isBackgroundOnly, !candidate.isHelper else {
                    return false
                }

                let canonicalPath = canonicalURL(candidate.url).path
                guard seenURLs.insert(canonicalPath).inserted else {
                    return false
                }

                if let bundleIdentifier = candidate.bundleIdentifier?.lowercased() {
                    guard bundleIdentifier != excludedIdentifier else {
                        return false
                    }
                    guard seenBundleIdentifiers.insert(bundleIdentifier).inserted else {
                        return false
                    }
                } else if candidate.displayName.caseInsensitiveCompare("Conjuror") == .orderedSame {
                    return false
                }

                return true
            }
    }

    static func scan(directories: [URL]) throws -> [ApplicationCatalogCandidate] {
        let fileManager = FileManager.default
        var candidates = [ApplicationCatalogCandidate]()

        for (sourcePriority, directory) in directories.enumerated() {
            guard fileManager.fileExists(atPath: directory.path) else {
                continue
            }

            let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
            let topLevelURLs = (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: []
            )) ?? []
            for url in topLevelURLs
            where !url.lastPathComponent.hasPrefix(".")
                && url.pathExtension.caseInsensitiveCompare("app") == .orderedSame
            {
                guard let candidate = candidate(at: url, sourcePriority: sourcePriority) else {
                    continue
                }
                candidates.append(candidate)
            }

            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                guard let candidate = candidate(at: url, sourcePriority: sourcePriority) else {
                    continue
                }
                candidates.append(candidate)
            }
        }

        return candidates
    }

    private static func candidate(at url: URL, sourcePriority: Int) -> ApplicationCatalogCandidate? {
        guard let bundle = Bundle(url: url),
              let info = bundle.infoDictionary,
              (info["CFBundlePackageType"] as? String) == "APPL"
        else {
            return nil
        }

        let displayName = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let pathComponents = Set(url.pathComponents.map { $0.lowercased() })
        let helperDirectories: Set<String> = ["helpers", "xpcservices", "loginitems"]
        let isHelper = !pathComponents.isDisjoint(with: helperDirectories)
            || (bundle.bundleIdentifier?.lowercased().contains(".helper") == true)

        return ApplicationCatalogCandidate(
            displayName: displayName,
            bundleIdentifier: bundle.bundleIdentifier,
            url: canonicalURL(url),
            sourcePriority: sourcePriority,
            isBackgroundOnly: (info["LSUIElement"] as? Bool == true)
                || (info["LSBackgroundOnly"] as? Bool == true),
            isHelper: isHelper
        )
    }

    private static func candidateOrder(
        _ lhs: ApplicationCatalogCandidate,
        _ rhs: ApplicationCatalogCandidate
    ) -> Bool {
        if lhs.sourcePriority != rhs.sourcePriority {
            return lhs.sourcePriority < rhs.sourcePriority
        }

        let lhsName = ApplicationRanker.normalized(lhs.displayName)
        let rhsName = ApplicationRanker.normalized(rhs.displayName)
        if lhsName != rhsName {
            return lhsName < rhsName
        }

        return canonicalURL(lhs.url).path < canonicalURL(rhs.url).path
    }

    private static func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private let directories: [URL]
    private let excludedBundleIdentifier: String?

    init(
        directories: [URL] = Self.applicationDirectories,
        excludedBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        self.directories = directories
        self.excludedBundleIdentifier = excludedBundleIdentifier
    }

    func load() async throws -> [InstalledApplication] {
        let directories = directories
        let excludedBundleIdentifier = excludedBundleIdentifier

        return try await Task.detached(priority: .userInitiated) {
            let candidates = try Self.scan(directories: directories)
            return Self.filteredAndDeduplicated(
                candidates,
                excludingBundleIdentifier: excludedBundleIdentifier
            )
            .map { candidate in
                let icon = NSWorkspace.shared.icon(forFile: candidate.url.path)
                icon.size = NSSize(width: 32, height: 32)

                return InstalledApplication(
                    displayName: candidate.displayName,
                    bundleIdentifier: candidate.bundleIdentifier,
                    url: candidate.url,
                    icon: icon
                )
            }
        }.value
    }
}

struct ApplicationCatalogCandidate: Equatable {
    let displayName: String
    let bundleIdentifier: String?
    let url: URL
    let sourcePriority: Int
    let isBackgroundOnly: Bool
    let isHelper: Bool
}

protocol ApplicationCatalogLoading {
    func load() async throws -> [InstalledApplication]
}
