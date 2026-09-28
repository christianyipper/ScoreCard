import Foundation

/// Downloads the league rosters published by this repo's Update rosters
/// workflow and caches them on disk so they're still available at a rink
/// with no signal.
@MainActor
final class RosterStore: ObservableObject {
    @Published private(set) var league: LeagueData?
    @Published private(set) var isRefreshing = false

    private static let sourceURL = URL(string: "https://raw.githubusercontent.com/christianyipper/ScoreCard/main/rosters/rosters.json")!

    private static var cacheURL: URL {
        URL.applicationSupportDirectory.appending(path: "rosters.json")
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(string)"))
        }
        return decoder
    }

    init() {
        if let data = try? Data(contentsOf: Self.cacheURL) {
            league = try? Self.decoder().decode(LeagueData.self, from: data)
        }
        Task { await refresh() }
    }

    /// Fetches the latest rosters; on any failure the cached copy is kept.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var request = URLRequest(url: Self.sourceURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? Self.decoder().decode(LeagueData.self, from: data) else { return }

        league = decoded
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.cacheURL, options: .atomic)
    }
}
