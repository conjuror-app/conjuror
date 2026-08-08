import Foundation

struct ApplicationRanker {
    struct Index {
        private let applications: [SearchableApplication]

        init(applications: [InstalledApplication]) {
            self.applications = applications.map { application in
                let normalizedName = ApplicationRanker.normalized(application.displayName)
                let nameTokens = ApplicationRanker.tokens(in: normalizedName)
                return SearchableApplication(
                    application: application,
                    normalizedName: normalizedName,
                    normalizedBundleIdentifier: ApplicationRanker.normalized(
                        application.bundleIdentifier ?? ""
                    ),
                    nameTokens: nameTokens,
                    compactName: nameTokens.joined()
                )
            }
        }

        func ranked(
            query: String,
            recentLaunches: [String: Date]
        ) -> [InstalledApplication] {
            let normalizedQuery = ApplicationRanker.normalized(query)
            let queryTokens = ApplicationRanker.tokens(in: normalizedQuery)
            let matchQuery = MatchQuery(
                normalized: normalizedQuery,
                tokens: queryTokens,
                compact: queryTokens.joined()
            )

            return applications
                .compactMap { application -> RankedApplication? in
                    guard let matchRank = ApplicationRanker.matchRank(
                        application: application,
                        query: matchQuery
                    ) else {
                        return nil
                    }

                    return RankedApplication(
                        searchableApplication: application,
                        matchRank: matchRank,
                        lastLaunch: recentLaunches[application.application.persistenceKey]
                    )
                }
                .sorted(by: ApplicationRanker.rankedApplicationOrder)
                .map(\.searchableApplication.application)
        }
    }

    static func ranked(
        applications: [InstalledApplication],
        query: String,
        recentLaunches: [String: Date]
    ) -> [InstalledApplication] {
        Index(applications: applications).ranked(
            query: query,
            recentLaunches: recentLaunches
        )
    }

    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func matchRank(
        application: SearchableApplication,
        query: MatchQuery
    ) -> MatchRank? {
        guard !query.normalized.isEmpty else {
            return MatchRank(category: 6)
        }

        if application.normalizedName == query.normalized {
            return MatchRank(category: 0)
        }
        if application.normalizedName.hasPrefix(query.normalized) {
            return MatchRank(category: 1)
        }

        if !query.tokens.isEmpty,
           query.tokens.allSatisfy({ queryToken in
               application.nameTokens.contains(where: { $0.hasPrefix(queryToken) })
           }) {
            return MatchRank(category: 2)
        }

        let acronym = application.nameTokens.compactMap(\.first).map(String.init).joined()
        if !query.compact.isEmpty, acronym.hasPrefix(query.compact) {
            return MatchRank(category: 3)
        }

        if application.normalizedName.contains(query.normalized)
            || application.compactName.contains(query.compact)
            || application.normalizedBundleIdentifier.contains(query.normalized) {
            return MatchRank(category: 4)
        }

        if let score = subsequenceScore(
            of: query.compact,
            in: application.compactName
        ) {
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

        if lhs.searchableApplication.normalizedName
            != rhs.searchableApplication.normalizedName
        {
            return lhs.searchableApplication.normalizedName
                < rhs.searchableApplication.normalizedName
        }

        return lhs.searchableApplication.application.url.path
            < rhs.searchableApplication.application.url.path
    }
}

private struct MatchRank: Equatable, Comparable {
    static func < (lhs: MatchRank, rhs: MatchRank) -> Bool {
        if lhs.category != rhs.category {
            return lhs.category < rhs.category
        }
        return lhs.score < rhs.score
    }

    let category: Int
    var score = 0
}

private struct RankedApplication {
    let searchableApplication: SearchableApplication
    let matchRank: MatchRank
    let lastLaunch: Date?
}

private struct SearchableApplication {
    let application: InstalledApplication
    let normalizedName: String
    let normalizedBundleIdentifier: String
    let nameTokens: [String]
    let compactName: String
}

private struct MatchQuery {
    let normalized: String
    let tokens: [String]
    let compact: String
}
