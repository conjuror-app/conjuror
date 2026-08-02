import Foundation

struct ApplicationRanker {
    static func ranked(
        applications: [InstalledApplication],
        query: String,
        recentLaunches: [String: Date]
    ) -> [InstalledApplication] {
        let normalizedQuery = normalized(query)

        return applications
            .compactMap { application -> RankedApplication? in
                guard let matchRank = matchRank(
                    name: application.displayName,
                    bundleIdentifier: application.bundleIdentifier,
                    query: normalizedQuery
                ) else {
                    return nil
                }

                return RankedApplication(
                    application: application,
                    matchRank: matchRank,
                    lastLaunch: recentLaunches[application.persistenceKey]
                )
            }
            .sorted(by: rankedApplicationOrder)
            .map(\.application)
    }

    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func matchRank(
        name: String,
        bundleIdentifier: String?,
        query: String
    ) -> Int? {
        guard !query.isEmpty else {
            return 5
        }

        let normalizedName = normalized(name)
        if normalizedName == query {
            return 0
        }
        if normalizedName.hasPrefix(query) {
            return 1
        }

        let nameTokens = tokens(in: normalizedName)
        let queryTokens = tokens(in: query)
        if !queryTokens.isEmpty,
           queryTokens.allSatisfy({ queryToken in
               nameTokens.contains(where: { $0.hasPrefix(queryToken) })
           }) {
            return 2
        }

        let acronym = nameTokens.compactMap(\.first).map(String.init).joined()
        let compactQuery = queryTokens.joined()
        if !compactQuery.isEmpty, acronym.hasPrefix(compactQuery) {
            return 3
        }

        let compactName = nameTokens.joined()
        let normalizedBundleIdentifier = normalized(bundleIdentifier ?? "")
        if normalizedName.contains(query)
            || compactName.contains(compactQuery)
            || normalizedBundleIdentifier.contains(query) {
            return 4
        }

        return nil
    }

    private static func tokens(in value: String) -> [String] {
        value.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    private static func rankedApplicationOrder(
        _ lhs: RankedApplication,
        _ rhs: RankedApplication
    ) -> Bool {
        if lhs.matchRank != rhs.matchRank {
            return lhs.matchRank < rhs.matchRank
        }

        if lhs.lastLaunch != rhs.lastLaunch {
            return (lhs.lastLaunch ?? .distantPast) > (rhs.lastLaunch ?? .distantPast)
        }

        let lhsName = normalized(lhs.application.displayName)
        let rhsName = normalized(rhs.application.displayName)
        if lhsName != rhsName {
            return lhsName < rhsName
        }

        return lhs.application.url.path < rhs.application.url.path
    }
}

private struct RankedApplication {
    let application: InstalledApplication
    let matchRank: Int
    let lastLaunch: Date?
}
