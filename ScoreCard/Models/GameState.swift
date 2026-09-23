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

    /// Set once this game has been saved or loaded as a `GameSheet`, so a
    /// later Save updates that same sheet instead of creating a new one.
    @Published var currentSheetID: UUID?

    /// Scratchpad notes shared between the Notes tab and the Add Goal/Add
    /// Penalty buttons, split one per side: whatever's written on a side
    /// becomes that side's next entry's text, then clears for the next
    /// note.
    @Published var draftNotes: [TeamSide: String] = [.home: "", .away: ""]

    /// Whichever side's notepad was most recently typed in. Back and Undo
    /// share one set of controls for both notepads, so they act on
    /// whichever one changed last.
    private var lastEditedNotepadSide: TeamSide = .home

    private var draftNotesUndoBuffer: [TeamSide: String]?

    var canUndoDraftNoteText: Bool { draftNotesUndoBuffer != nil }

    var isDraftNoteTextEmpty: Bool {
        (draftNotes[.home] ?? "").isEmpty && (draftNotes[.away] ?? "").isEmpty
    }

    var canBackspaceDraftNoteText: Bool {
        !(draftNotes[lastEditedNotepadSide] ?? "").isEmpty
    }

    func draftNoteText(for side: TeamSide) -> String {
        draftNotes[side] ?? ""
    }

    /// Updates a side's notepad text (used by the split notepad view, which
    /// binds each side directly).
    func setDraftNoteText(_ text: String, for side: TeamSide) {
        draftNotes[side] = text
        lastEditedNotepadSide = side
    }

    /// Removes the last character from whichever notepad was edited most
    /// recently.
    func backspaceDraftNoteText() {
        guard canBackspaceDraftNoteText else { return }
        draftNotes[lastEditedNotepadSide]?.removeLast()
    }

    /// Clears both notepads, stashing their text so it can be restored with
    /// `undoDraftNoteTextClear()`.
    func clearDraftNoteText() {
        draftNotesUndoBuffer = draftNotes
        draftNotes = [.home: "", .away: ""]
    }

    func undoDraftNoteTextClear() {
        guard let previous = draftNotesUndoBuffer else { return }
        draftNotes = previous
        draftNotesUndoBuffer = nil
    }

    /// Called once a side's notepad text has been turned into a goal/penalty
    /// entry: clears just that side's notepad.
    func consumeDraftNote(for side: TeamSide) {
        draftNotes[side] = ""
        draftNotesUndoBuffer = nil
    }

    // MARK: - Penalty entry

    /// The clock time (MM:SS) stamped onto penalties when they're submitted.
    @Published var periodTime = "00:00"
    @Published var isEditingPeriodTime = false
    /// Digits typed so far while editing the period time (0–4 of them).
    @Published var periodTimeInput = ""

    @Published var penaltyDrafts: [TeamSide: [PenaltyDraftRow]] = GameState.emptyPenaltyDrafts()
    @Published var activePenaltyRow: PenaltyRowID? {
        didSet {
            if activePenaltyRow != oldValue { isEditingServedBy = false }
        }
    }
    /// True while the numpad is filling the active row's optional "served
    /// by" number instead of its player number.
    @Published var isEditingServedBy = false

    @Published var goalDrafts: [TeamSide: GoalDraft] = [.home: GoalDraft(), .away: GoalDraft()]
    @Published var activeGoalField: GoalFieldID?
    @Published var goalStrengths: [TeamSide: GoalStrength] = [:]

    @Published var goaltenderDrafts: [TeamSide: GoaltenderDraft] = [.home: GoaltenderDraft(), .away: GoaltenderDraft()]
    @Published var activeGoaltenderField: GoaltenderFieldID?

    private static func emptyPenaltyDrafts() -> [TeamSide: [PenaltyDraftRow]] {
        Dictionary(uniqueKeysWithValues: TeamSide.allCases.map {
            ($0, Array(repeating: PenaltyDraftRow(), count: PenaltyDraftRow.rowsPerSide))
        })
    }

    /// What's shown in the period-time box: the committed time, or while
    /// editing the typed digits in `MM:SS` with `_` for unfilled positions.
    var periodTimeDisplay: String {
        guard isEditingPeriodTime else { return periodTime }
        let digits = Array(periodTimeInput) + Array(repeating: Character("_"), count: 4 - periodTimeInput.count)
        return "\(String(digits[0...1])):\(String(digits[2...3]))"
    }

    /// The numpad feeds the period time while it's being edited, otherwise
    /// the active goal field or penalty row's player number; with none of
    /// them, its keys are disabled.
    var isNumpadEnabled: Bool {
        isEditingPeriodTime || activeGoalField != nil || activeGoaltenderField != nil || activePenaltyRow != nil
    }

    var canBackspaceNumpad: Bool {
        if isEditingPeriodTime { return !periodTimeInput.isEmpty }
        if let goalField = activeGoalField {
            // Backspace can reach back into the fields before the active one.
            let draft = goalDrafts[goalField.side]!
            let fields = GoalField.allCases
            let upTo = (fields.firstIndex(of: goalField.field) ?? fields.count - 1) + 1
            return fields.prefix(upTo).contains { !draft[$0].isEmpty }
        }
        if let field = activeGoaltenderField { return !goaltenderDrafts[field.side]![field.field].isEmpty }
        guard let row = activePenaltyRow else { return false }
        return !penaltyDrafts[row.side]![row.index].playerNumber.isEmpty
    }

    func isEditingServedBy(_ row: PenaltyRowID) -> Bool {
        isEditingServedBy && activePenaltyRow == row
    }

    func draftRows(for side: TeamSide) -> [PenaltyDraftRow] {
        penaltyDrafts[side] ?? []
    }

    func canSubmitPenalties(for side: TeamSide) -> Bool {
        draftRows(for: side).contains { $0.isComplete }
    }

    /// A goal needs both a strength button and a scorer.
    func canSubmitGoal(for side: TeamSide) -> Bool {
        goalStrengths[side] != nil && !goalDraft(for: side)[.scorer].isEmpty
    }

    func canSubmit(for side: TeamSide) -> Bool {
        canSubmitPenalties(for: side) || canSubmitGoal(for: side)
    }

    /// Submits whatever on `side` is ready: its complete penalty rows and
    /// its goal.
    func submit(for side: TeamSide) {
        if canSubmitPenalties(for: side) { submitPenalties(for: side) }
        if canSubmitGoal(for: side) { submitGoal(for: side) }
    }

    /// Tapping a strength selects it; tapping the selected one deselects it.
    func selectGoalStrength(_ strength: GoalStrength, for side: TeamSide) {
        goalStrengths[side] = (goalStrengths[side] == strength) ? nil : strength
    }

    /// Tapping a row activates it; tapping the active row again deactivates it.
    func selectPenaltyRow(_ row: PenaltyRowID) {
        isEditingPeriodTime = false
        periodTimeInput = ""
        activeGoalField = nil
        activeGoaltenderField = nil
        activePenaltyRow = (activePenaltyRow == row) ? nil : row
    }

    /// Tapping a side's goal input activates it starting at the scorer;
    /// tapping it again deactivates it. Typing then moves through the
    /// fields (see `advanceNumpad()`).
    func selectGoalInput(for side: TeamSide) {
        isEditingPeriodTime = false
        periodTimeInput = ""
        activePenaltyRow = nil
        activeGoaltenderField = nil
        activeGoalField = (activeGoalField?.side == side) ? nil : GoalFieldID(side: side, field: .scorer)
    }

    /// Tapping a goaltender field activates just that field; tapping it
    /// again deactivates it.
    func selectGoaltenderField(_ id: GoaltenderFieldID) {
        isEditingPeriodTime = false
        periodTimeInput = ""
        activePenaltyRow = nil
        activeGoalField = nil
        activeGoaltenderField = (activeGoaltenderField == id) ? nil : id
    }

    func goaltenderDraft(for side: TeamSide) -> GoaltenderDraft {
        goaltenderDrafts[side] ?? GoaltenderDraft()
    }

    private func updateActiveGoaltenderField(_ change: (inout String) -> Void) {
        guard let id = activeGoaltenderField else { return }
        change(&goaltenderDrafts[id.side]![id.field])
    }

    func goalDraft(for side: TeamSide) -> GoalDraft {
        goalDrafts[side] ?? GoalDraft()
    }

    private func updateActiveGoalField(_ change: (inout String) -> Void) {
        guard let id = activeGoalField else { return }
        change(&goalDrafts[id.side]![id.field])
    }

    private func updateActiveRow(_ change: (inout PenaltyDraftRow) -> Void) {
        guard let row = activePenaltyRow else { return }
        change(&penaltyDrafts[row.side]![row.index])
    }

    /// Selecting the infraction that's already set clears it.
    func setInfraction(_ infraction: Infraction) {
        updateActiveRow { $0.infraction = ($0.infraction == infraction) ? nil : infraction }
    }

    func togglePenaltyType(_ type: PenaltyType) {
        updateActiveRow { $0.types.toggle(type) }
    }

    func activeRowTypes(for side: TeamSide) -> Set<PenaltyType> {
        guard let row = activePenaltyRow, row.side == side else { return [] }
        return penaltyDrafts[side]![row.index].types
    }

    /// The numpad's return key moves to the next goal field, or to the next
    /// penalty row on the same side; it does nothing while the period time
    /// is being edited or when nothing is active.
    var canAdvanceNumpad: Bool {
        !isEditingPeriodTime && (activeGoalField != nil || activeGoaltenderField != nil || activePenaltyRow != nil)
    }

    /// Past the last goal field or penalty row there's nothing further to
    /// fill, so the active field is deselected.
    func advanceNumpad() {
        guard canAdvanceNumpad else { return }
        if let id = activeGoalField {
            let fields = GoalField.allCases
            let next = fields.firstIndex(of: id.field).map { $0 + 1 } ?? fields.count
            activeGoalField = next < fields.count ? GoalFieldID(side: id.side, field: fields[next]) : nil
        } else if let id = activeGoaltenderField {
            let fields = GoaltenderField.allCases
            let next = fields.firstIndex(of: id.field).map { $0 + 1 } ?? fields.count
            activeGoaltenderField = next < fields.count ? GoaltenderFieldID(side: id.side, field: fields[next]) : nil
        } else if let row = activePenaltyRow {
            // With a player number in, return moves on to the optional
            // "served by" number before leaving the row.
            if !isEditingServedBy && !penaltyDrafts[row.side]![row.index].playerNumber.isEmpty {
                isEditingServedBy = true
                return
            }
            let next = row.index + 1
            activePenaltyRow = next < PenaltyDraftRow.rowsPerSide ? PenaltyRowID(side: row.side, index: next) : nil
        }
    }

    func beginEditingPeriodTime() {
        periodTimeInput = ""
        activeGoalField = nil
        activeGoaltenderField = nil
        isEditingPeriodTime = true
    }

    func pressNumpadDigit(_ digit: Int) {
        if isEditingPeriodTime {
            periodTimeInput.append(String(digit))
            if periodTimeInput.count == 4 {
                let digits = periodTimeInput
                periodTime = "\(digits.prefix(2)):\(digits.suffix(2))"
                periodTimeInput = ""
                isEditingPeriodTime = false
            }
        } else if activeGoalField != nil {
            updateActiveGoalField { number in
                if number.count < GoalDraft.maxNumberDigits {
                    number.append(String(digit))
                }
            }
            // A full number moves on to the next field on its own.
            if let id = activeGoalField, goalDrafts[id.side]![id.field].count == GoalDraft.maxNumberDigits {
                advanceNumpad()
            }
        } else if activeGoaltenderField != nil {
            updateActiveGoaltenderField { value in
                if let id = activeGoaltenderField, value.count < id.field.maxDigits {
                    value.append(String(digit))
                }
            }
            // A full field moves on to the next one on its own.
            if let id = activeGoaltenderField, goaltenderDrafts[id.side]![id.field].count == id.field.maxDigits {
                advanceNumpad()
            }
        } else {
            // A digit typed after a full player number starts the "served
            // by" number.
            if let row = activePenaltyRow,
               penaltyDrafts[row.side]![row.index].playerNumber.count == PenaltyDraftRow.maxPlayerNumberDigits {
                isEditingServedBy = true
            }
            let editingServedBy = isEditingServedBy
            updateActiveRow { row in
                if editingServedBy {
                    if row.servedBy.count < PenaltyDraftRow.maxPlayerNumberDigits {
                        row.servedBy.append(String(digit))
                    }
                } else if row.playerNumber.count < PenaltyDraftRow.maxPlayerNumberDigits {
                    row.playerNumber.append(String(digit))
                }
            }
        }
    }

    /// Deletes the last digit of the active goal field; if that field is
    /// empty, moves back to the nearest earlier field that has digits and
    /// deletes from it (e.g. scorer 46, assist 32: three presses leave the
    /// scorer as 4).
    private func backspaceGoalField() {
        guard var id = activeGoalField else { return }
        let fields = GoalField.allCases
        while goalDrafts[id.side]![id.field].isEmpty {
            guard let index = fields.firstIndex(of: id.field), index > 0 else { return }
            id.field = fields[index - 1]
        }
        goalDrafts[id.side]![id.field].removeLast()
        activeGoalField = id
    }

    func numpadBackspace() {
        if isEditingPeriodTime {
            if !periodTimeInput.isEmpty { periodTimeInput.removeLast() }
        } else if activeGoalField != nil {
            backspaceGoalField()
        } else if activeGoaltenderField != nil {
            updateActiveGoaltenderField { if !$0.isEmpty { $0.removeLast() } }
        } else {
            // Backspacing an empty "served by" number steps back into the
            // player number.
            var steppedBack = false
            let editingServedBy = isEditingServedBy
            updateActiveRow { row in
                if editingServedBy && !row.servedBy.isEmpty {
                    row.servedBy.removeLast()
                } else if !row.playerNumber.isEmpty {
                    row.playerNumber.removeLast()
                    steppedBack = true
                }
            }
            if steppedBack { isEditingServedBy = false }
        }
    }

    /// Turns every complete draft row on `side` into a report penalty stamped
    /// with the current period and period time, and empties those rows.
    /// Incomplete rows are left as they are.
    func submitPenalties(for side: TeamSide) {
        var rows = draftRows(for: side)
        for index in rows.indices where rows[index].isComplete {
            let row = rows[index]
            addPenalty(PenaltyEntry(
                team: side,
                period: currentPeriod,
                types: row.types.ordered,
                time: periodTime,
                infraction: row.infraction,
                playerNumber: row.playerNumber,
                servedBy: row.servedBy.isEmpty ? nil : row.servedBy
            ))
            rows[index] = PenaltyDraftRow()
        }
        penaltyDrafts[side] = rows
        activePenaltyRow = nil
    }

    /// Records a goal for `side` from its selected strength, typed
    /// scorer/assist numbers (stamped with the period time) and the
    /// notepad, then clears them.
    private func submitGoal(for side: TeamSide) {
        guard let strength = goalStrengths[side] else { return }
        let text = [
            periodTime,
            strength.prefix,
            goalDraft(for: side).summary,
            draftNoteText(for: side)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        addGoal(GoalEntry(team: side, period: currentPeriod, text: text))
        consumeDraftNote(for: side)
        goalDrafts[side] = GoalDraft()
        goalStrengths[side] = nil
        if activeGoalField?.side == side { activeGoalField = nil }
    }

    private func resetPenaltyEntry() {
        periodTime = "00:00"
        isEditingPeriodTime = false
        periodTimeInput = ""
        penaltyDrafts = GameState.emptyPenaltyDrafts()
        activePenaltyRow = nil
        goalDrafts = [.home: GoalDraft(), .away: GoalDraft()]
        goalStrengths = [:]
        activeGoalField = nil
        activeGoaltenderField = nil
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

    /// Report goals/penalties the user has tapped to mark green. Not saved
    /// with the gamesheet.
    @Published var highlightedEventIDs: Set<UUID> = []

    func toggleEventHighlight(_ id: UUID) {
        if highlightedEventIDs.contains(id) {
            highlightedEventIDs.remove(id)
        } else {
            highlightedEventIDs.insert(id)
        }
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
        highlightedEventIDs = []
        teamNames = [.home: "Home", .away: "Away"]
        currentPeriod = .first
        shots = [.home: [:], .away: [:]]
        goals = []
        penalties = []
        generalNotes = []
        goaltenderDrafts = [.home: GoaltenderDraft(), .away: GoaltenderDraft()]
        draftNotes = [.home: "", .away: ""]
        lastEditedNotepadSide = .home
        draftNotesUndoBuffer = nil
        currentSheetID = nil
        colorsSwapped = false
        resetPenaltyEntry()
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
        draftNotes = Dictionary(uniqueKeysWithValues: draftNotes.map { (side, notes) in (side.opposite, notes) })
        lastEditedNotepadSide = lastEditedNotepadSide.opposite
        penaltyDrafts = Dictionary(uniqueKeysWithValues: penaltyDrafts.map { (side, rows) in (side.opposite, rows) })
        activePenaltyRow = activePenaltyRow.map { PenaltyRowID(side: $0.side.opposite, index: $0.index) }
        goalDrafts = Dictionary(uniqueKeysWithValues: goalDrafts.map { (side, draft) in (side.opposite, draft) })
        goalStrengths = Dictionary(uniqueKeysWithValues: goalStrengths.map { (side, strength) in (side.opposite, strength) })
        activeGoalField = activeGoalField.map { GoalFieldID(side: $0.side.opposite, field: $0.field) }
        goaltenderDrafts = Dictionary(uniqueKeysWithValues: goaltenderDrafts.map { (side, draft) in (side.opposite, draft) })
        activeGoaltenderField = activeGoaltenderField.map { GoaltenderFieldID(side: $0.side.opposite, field: $0.field) }
        colorsSwapped.toggle()
    }

    func loadGameSheet(_ sheet: GameSheet) {
        highlightedEventIDs = []
        teamNames = sheet.teamNames
        shots = sheet.shots
        goals = sheet.goals
        penalties = sheet.penalties
        generalNotes = sheet.generalNotes
        goaltenderDrafts = [.home: GoaltenderDraft(), .away: GoaltenderDraft()]
            .merging(sheet.goaltenderDrafts) { _, saved in saved }
        currentPeriod = sheet.currentPeriod
        draftNotes = [.home: "", .away: ""]
        lastEditedNotepadSide = .home
        draftNotesUndoBuffer = nil
        currentSheetID = sheet.id
        colorsSwapped = false
        resetPenaltyEntry()
    }
}
