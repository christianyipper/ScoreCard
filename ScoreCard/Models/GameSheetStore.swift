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
            goaltenderDrafts: gameState.goaltenderDrafts
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

    func delete(_ sheet: GameSheet) {
        sheets.removeAll { $0.id == sheet.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sheets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
