import SwiftUI

/// Each period's goals written out as an announcer's script.
struct ScriptView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var gameSheetStore: GameSheetStore
    @EnvironmentObject var rosterStore: RosterStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Goal Script")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                if gameState.goals.isEmpty {
                    Text("No goals yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                ForEach(GamePeriod.allCases) { period in
                    let goals = gameState.goals.filter { $0.period == period }
                    if !goals.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(period.fullLabel)
                                .font(AppTypography.body.bold())
                                .foregroundStyle(.secondary)
                            ForEach(goals) { goal in
                                goalScript(goal)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
    }

    private func goalScript(_ goal: GoalEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scoringLine(goal))
                .fontWeight(.bold)
                .foregroundStyle(gameState.accentColor(for: goal.team))
            if let assistLine = assistLine(goal) {
                Text(assistLine)
            }
            if let time = goal.time, !time.isEmpty {
                Text("Time of the goal, \(time).")
            }
        }
        .font(AppTypography.body)
        .textSelection(.enabled)
    }

    private func scoringLine(_ goal: GoalEntry) -> String {
        let team = gameState.teamNames[goal.team] ?? goal.team.defaultName
        var sentences = ["\(team) goal."]
        if let scorer = goal.scorer, !scorer.isEmpty {
            let count = gameState.seasonGoalNumber(for: goal, league: rosterStore.league, savedSheets: gameSheetStore)
            let player = playerReference(scorer, side: goal.team)
            if let count {
                sentences.append("His \(Self.ordinal(count)) of the season, scored by \(player).")
            } else {
                sentences.append("Scored by \(player).")
            }
        }
        return sentences.joined(separator: " ")
    }

    private func assistLine(_ goal: GoalEntry) -> String? {
        let assists = [goal.assist1, goal.assist2]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .map { playerReference($0, side: goal.team) }
        switch assists.count {
        case 0: return nil
        case 1: return "The assist to \(assists[0])."
        default: return "The assist to \(assists[0]),\nAnd to \(assists[1])."
        }
    }

    /// "number 12, John Smith", or just "number 12" when the name is unknown.
    private func playerReference(_ number: String, side: TeamSide) -> String {
        let name = gameState.rosterPlayer(number: number, side: side, league: rosterStore.league)?.name
        return ["number \(number)", name].compactMap { $0 }.joined(separator: ", ")
    }

    private static let ordinalWords = [
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
        "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth",
        "eighteenth", "nineteenth", "twentieth"
    ]

    /// "first" through "twentieth" spelled out, then "21st", "22nd", ...
    static func ordinal(_ n: Int) -> String {
        if (1...ordinalWords.count).contains(n) { return ordinalWords[n - 1] }
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}
