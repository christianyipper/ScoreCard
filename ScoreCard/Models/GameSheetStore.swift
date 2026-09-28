import Foundation

/// Persists saved `GameSheet`s to `UserDefaults` so they survive relaunches,
/// and offers them back to the hamburger menu's gamesheet list.
@MainActor
final class GameSheetStore: ObservableObject {
    @Published private(set) var sheets: [GameSheet] = []

    private let storageKey = "ScoreCard.SavedGameSheets"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([GameSheet].self, from: data) else { return }
        sheets = decoded.sorted { $0.savedAt > $1.savedAt }
    }

    /// Saves `gameState` as a gamesheet: updates the sheet it was loaded
    /// from (or last saved to) if it has one, otherwise creates a new one.
    @discardableResult
    func save(_ gameState: GameState) -> GameSheet {
        let id = gameState.currentSheetID ?? UUID()
        let sheet = GameSheet(
            id: id,
            name: gameState.reportTitle,
            savedAt: Date(),
            teamNames: gameState.teamNames,
            shots: gameState.shots,
            goals: gameState.goals,
            penalties: gameState.penalties,
            generalNotes: gameState.generalNotes,
            currentPeriod: gameState.currentPeriod,
            goaltenderDrafts: gameState.goaltenderDrafts,
            teamRosters: gameState.teamRosters
        )
        if let index = sheets.firstIndex(where: { $0.id == id }) {
            sheets[index] = sheet
        } else {
            sheets.append(sheet)
        }
        sheets.sort { $0.savedAt > $1.savedAt }
        gameState.currentSheetID = id
        persist()
        return sheet
    }

    /// Goals per scorer number (normalized) for `team` from saved gamesheets
    /// the league hasn't posted yet, so season totals include them until the
    /// daily roster scrape does.
    ///
    /// Each sheet keeps the roster as it was when the team was picked, so its
    /// games played then tells us which game number the sheet was: one past
    /// that, or one past the previous saved game if that's later. The league
    /// has posted it once `team.gamesPlayed` reaches that number. The sheet
    /// `excluding` (the game currently open) holds its place in that order but
    /// its goals are left out, since the open game counts its own.
    func unpostedGoals(for team: RosterTeam, excluding sheetID: UUID?) -> [String: Int] {
        let games = sheets.compactMap { sheet -> (sheet: GameSheet, side: TeamSide, snapshot: RosterTeam)? in
            guard let side = TeamSide.allCases.first(where: { sheet.teamRosters[$0]?.id == team.id }),
                  let snapshot = sheet.teamRosters[side] else { return nil }
            return (sheet, side, snapshot)
        }
        .sorted { $0.sheet.savedAt < $1.sheet.savedAt }

        var counts: [String: Int] = [:]
        var gameNumber = 0
        for game in games {
            gameNumber = max(game.snapshot.gamesPlayed + 1, gameNumber + 1)
            guard team.gamesPlayed < gameNumber, game.sheet.id != sheetID else { continue }
            for goal in game.sheet.goals where goal.team == game.side {
                if let scorer = goal.scorer, !scorer.isEmpty {
                    counts[RosterPlayer.normalized(scorer), default: 0] += 1
                }
            }
        }
        return counts
    }

    func delete(_ sheet: GameSheet) {
        sheets.removeAll { $0.id == sheet.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sheets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
