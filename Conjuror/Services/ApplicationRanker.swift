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
    ) -> MatchRank? {
        guard !query.isEmpty else {
            return MatchRank(category: 6)
        }

        let normalizedName = normalized(name)
        if normalizedName == query {
            return MatchRank(category: 0)
        }
        if normalizedName.hasPrefix(query) {
            return MatchRank(category: 1)
        }

        let nameTokens = tokens(in: normalizedName)
        let queryTokens = tokens(in: query)
        if !queryTokens.isEmpty,
           queryTokens.allSatisfy({ queryToken in
               nameTokens.contains(where: { $0.hasPrefix(queryToken) })
           }) {
            return MatchRank(category: 2)
        }

        let acronym = nameTokens.compactMap(\.first).map(String.init).joined()
        let compactQuery = queryTokens.joined()
        if !compactQuery.isEmpty, acronym.hasPrefix(compactQuery) {
            return MatchRank(category: 3)
        }

        let compactName = nameTokens.joined()
        let normalizedBundleIdentifier = normalized(bundleIdentifier ?? "")
        if normalizedName.contains(query)
            || compactName.contains(compactQuery)
            || normalizedBundleIdentifier.contains(query) {
            return MatchRank(category: 4)
        }

        if let score = subsequenceScore(of: compactQuery, in: compactName) {
            return MatchRank(category: 5, score: score)
        }

        return nil
    }

    private static func tokens(in value: String) -> [String] {
        value.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    private static func subsequenceScore(of query: String, in target: String) -> Int? {
        guard !query.isEmpty else {
            return nil
        }

        let queryCharacters = Array(query)
        let targetCharacters = Array(target)
        var matchedPositions = [Int]()
        var searchStart = 0

        for queryCharacter in queryCharacters {
            guard searchStart < targetCharacters.count,
                  let position = targetCharacters[searchStart...]
                    .firstIndex(of: queryCharacter)
            else {
                return nil
            }

            matchedPositions.append(position)
            searchStart = position + 1
        }

        guard let firstPosition = matchedPositions.first,
              let lastPosition = matchedPositions.last
        else {
            return nil
        }

        let skippedCharacters = lastPosition - firstPosition + 1 - queryCharacters.count
        return skippedCharacters * 1_000 + firstPosition
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

private struct MatchRank: Equatable, Comparable {
    let category: Int
    var score = 0

    static func < (lhs: MatchRank, rhs: MatchRank) -> Bool {
        if lhs.category != rhs.category {
            return lhs.category < rhs.category
        }
        return lhs.score < rhs.score
    }
}

private struct RankedApplication {
    let application: InstalledApplication
    let matchRank: MatchRank
    let lastLaunch: Date?
}
