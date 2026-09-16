import Foundation
import Combine
import SwiftUI

@MainActor
final class GameState: ObservableObject {
    @Published var teamNames: [TeamSide: String] = [.home: "Home", .away: "Away"]
    @Published var currentPeriod: GamePeriod = .first

    /// Toggled by `flipSides()` so each team's accent color (score, shots
    /// button, report text) travels with it across the flip instead of
    /// staying pinned to the home/away slot.
    @Published var colorsSwapped = false

    func accentColor(for team: TeamSide) -> Color {
        (colorsSwapped ? team.opposite : team).accentColor
    }

    @Published var shots: [TeamSide: [GamePeriod: Int]] = [
        .home: [:],
        .away: [:]
    ]

    @Published var goals: [GoalEntry] = []
    @Published var penalties: [PenaltyEntry] = []
    @Published var generalNotes: [GeneralNote] = []

    /// Free-form, manually-edited goaltender notes shown at the bottom of
    /// the report, one per side.
    @Published var goaltenderNotes: [TeamSide: String] = [.home: "", .away: ""]

    /// Set once this game has been saved or loaded as a `GameSheet`, so a
    /// later Save updates that same sheet instead of creating a new one.
    @Published var currentSheetID: UUID?

    /// Scratchpad notepads shared between the Notes tab and the Add Goal/Add
    /// Penalty buttons: whatever's written on the current page becomes the
    /// new entry's text. Users can swipe forward to a fresh blank notepad
    /// once the current one has text, up to `maxNotepads` at a time, so
    /// several notes can be drafted before any of them is submitted.
    @Published var draftNotepads: [String] = [""]
    @Published var currentNotepadIndex: Int = 0

    static let maxNotepads = 5

    private var draftNoteTextUndoBuffer: String?

    var canUndoDraftNoteText: Bool { draftNoteTextUndoBuffer != nil }

    /// The text on the currently visible notepad page.
    var draftNoteText: String {
        get { draftNotepads.indices.contains(currentNotepadIndex) ? draftNotepads[currentNotepadIndex] : "" }
        set { setNotepadText(newValue, at: currentNotepadIndex) }
    }

    /// Updates a specific notepad page's text (used by the paged notepad
    /// view, which binds each page directly by index) and keeps a trailing
    /// blank page available to swipe to whenever there's room.
    func setNotepadText(_ text: String, at index: Int) {
        guard draftNotepads.indices.contains(index) else { return }
        draftNotepads[index] = text
        growTrailingNotepadIfNeeded()
    }

    private func growTrailingNotepadIfNeeded() {
        if let last = draftNotepads.last, !last.isEmpty, draftNotepads.count < Self.maxNotepads {
            draftNotepads.append("")
        }
    }

    /// Clears the current notepad's text, stashing the previous text so it
    /// can be restored with `undoDraftNoteTextClear()`.
    func clearDraftNoteText() {
        draftNoteTextUndoBuffer = draftNoteText
        draftNoteText = ""
    }

    func undoDraftNoteTextClear() {
        guard let previous = draftNoteTextUndoBuffer else { return }
        draftNoteText = previous
        draftNoteTextUndoBuffer = nil
    }

    /// Called once a notepad's text has been turned into a goal/penalty
    /// entry: removes that notepad so the rest shift up, unless it's the
    /// only one left, in which case it just resets to blank for the next
    /// note.
    func consumeDraftNotepad() {
        if draftNotepads.count > 1 {
            draftNotepads.remove(at: currentNotepadIndex)
            currentNotepadIndex = min(currentNotepadIndex, draftNotepads.count - 1)
        } else {
            draftNotepads[0] = ""
        }
        draftNoteTextUndoBuffer = nil
        growTrailingNotepadIfNeeded()
    }

    // MARK: - Shots

    func shotCount(for team: TeamSide, period: GamePeriod) -> Int {
        shots[team]?[period] ?? 0
    }

    func shotTotal(for team: TeamSide) -> Int {
        GamePeriod.allCases.reduce(0) { $0 + shotCount(for: team, period: $1) }
    }

    func addShot(for team: TeamSide, delta: Int = 1) {
        let current = shots[team]?[currentPeriod] ?? 0
        let updated = max(0, current + delta)
        shots[team, default: [:]][currentPeriod] = updated
    }

    // MARK: - Goals & Penalties

    func addGoal(_ goal: GoalEntry) {
        goals.append(goal)
    }

    func addPenalty(_ penalty: PenaltyEntry) {
        penalties.append(penalty)
    }

    func addGeneralNote(_ note: GeneralNote) {
        generalNotes.append(note)
    }

    func deleteGoal(_ goal: GoalEntry) {
        goals.removeAll { $0.id == goal.id }
    }

    func deletePenalty(_ penalty: PenaltyEntry) {
        penalties.removeAll { $0.id == penalty.id }
    }

    func goalCount(for team: TeamSide, period: GamePeriod? = nil) -> Int {
        goals.filter { $0.team == team && (period == nil || $0.period == period) }.count
    }

    func penaltyCount(for team: TeamSide, period: GamePeriod? = nil) -> Int {
        penalties.filter { $0.team == team && (period == nil || $0.period == period) }.count
    }

    // MARK: - Gamesheets

    var reportTitle: String {
        "\(teamNames[.home] ?? TeamSide.home.defaultName) Vs \(teamNames[.away] ?? TeamSide.away.defaultName)"
    }

    /// Clears everything back to a blank game, ready for a fresh gamesheet.
    func reset() {
        teamNames = [.home: "Home", .away: "Away"]
        currentPeriod = .first
        shots = [.home: [:], .away: [:]]
        goals = []
        penalties = []
        generalNotes = []
        goaltenderNotes = [.home: "", .away: ""]
        draftNotepads = [""]
        currentNotepadIndex = 0
        draftNoteTextUndoBuffer = nil
        currentSheetID = nil
        colorsSwapped = false
    }

    /// Swaps which physical side is "home" vs "away" across every piece of
    /// recorded data, so the two team columns trade places everywhere they
    /// appear (main entry screen and report alike), and swaps each team's
    /// accent color along with it.
    func flipSides() {
        teamNames = Dictionary(uniqueKeysWithValues: teamNames.map { (side, name) in (side.opposite, name) })
        shots = Dictionary(uniqueKeysWithValues: shots.map { (side, counts) in (side.opposite, counts) })
        goals = goals.map { goal in
            var flipped = goal
            flipped.team = flipped.team.opposite
            return flipped
        }
        penalties = penalties.map { penalty in
            var flipped = penalty
            flipped.team = flipped.team.opposite
            return flipped
        }
        goaltenderNotes = Dictionary(uniqueKeysWithValues: goaltenderNotes.map { (side, notes) in (side.opposite, notes) })
        colorsSwapped.toggle()
    }

    func loadGameSheet(_ sheet: GameSheet) {
        teamNames = sheet.teamNames
        shots = sheet.shots
        goals = sheet.goals
        penalties = sheet.penalties
        generalNotes = sheet.generalNotes
        goaltenderNotes = sheet.goaltenderNotes
        currentPeriod = sheet.currentPeriod
        draftNotepads = [""]
        currentNotepadIndex = 0
        draftNoteTextUndoBuffer = nil
        currentSheetID = sheet.id
        colorsSwapped = false
    }
}
