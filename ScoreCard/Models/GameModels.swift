import Foundation

enum TeamSide: String, CaseIterable, Identifiable, Codable {
    case home
    case away

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .home: return "Home"
        case .away: return "Away"
        }
    }

    var opposite: TeamSide {
        switch self {
        case .home: return .away
        case .away: return .home
        }
    }
}

enum GamePeriod: Int, CaseIterable, Identifiable, Codable, Comparable {
    case first = 1
    case second = 2
    case third = 3
    case overtime = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .first: return "1"
        case .second: return "2"
        case .third: return "3"
        case .overtime: return "4+"
        }
    }

    var fullLabel: String {
        switch self {
        case .first: return "Period 1"
        case .second: return "Period 2"
        case .third: return "Period 3"
        case .overtime: return "Period 4+"
        }
    }

    static func < (lhs: GamePeriod, rhs: GamePeriod) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The penalty types selectable from the penalty-entry overlay, grouped into
/// two rows of three buttons.
enum PenaltyType: String, CaseIterable, Identifiable, Codable {
    case minor
    case doubleMinor
    case major
    case match
    case misc
    case gameMisconduct

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minor: return "Minor"
        case .doubleMinor: return "Double Minor"
        case .major: return "Major"
        case .match: return "Match"
        case .misc: return "Misc"
        case .gameMisconduct: return "GM"
        }
    }
}

/// The two rows the penalty-type picker groups its buttons into. Each row
/// is single-select on its own, but a selection from one row combines with a
/// selection from the other (e.g. Minor + GM).
enum PenaltyTypeRow: CaseIterable, Hashable {
    case severity
    case additional

    var types: [PenaltyType] {
        switch self {
        case .severity: return [.minor, .doubleMinor, .major]
        case .additional: return [.match, .misc, .gameMisconduct]
        }
    }
}

extension Set where Element == PenaltyType {
    /// Each `PenaltyTypeRow` is single-select: picking a type clears any other
    /// selection from the same row, while selections from the other row are
    /// left alone so they can combine (e.g. Minor + GM).
    mutating func toggle(_ type: PenaltyType) {
        if contains(type) {
            remove(type)
        } else {
            if let row = PenaltyTypeRow.allCases.first(where: { $0.types.contains(type) }) {
                row.types.forEach { remove($0) }
            }
            insert(type)
        }
    }

    /// The selected types in display order (severity row first, then additional).
    var ordered: [PenaltyType] {
        PenaltyTypeRow.allCases.flatMap { row in row.types.filter { contains($0) } }
    }
}

/// The infractions selectable from the penalty-entry overlay.
enum Infraction: String, CaseIterable, Identifiable, Codable {
    case tripping
    case hooking
    case slashing
    case interference
    case highSticking
    case roughing
    case holding
    case crossChecking
    case boarding
    case charging
    case tooManyMen
    case delayOfGame
    case fighting
    case headContact
    case cfb
    case slewFoot
    case instigator
    case aggressor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tripping: return "Tripping"
        case .hooking: return "Hooking"
        case .slashing: return "Slashing"
        case .interference: return "Interference"
        case .highSticking: return "High-Sticking"
        case .roughing: return "Roughing"
        case .holding: return "Holding"
        case .crossChecking: return "Cross-Checking"
        case .boarding: return "Boarding"
        case .charging: return "Charging"
        case .tooManyMen: return "Too Many Men"
        case .delayOfGame: return "Delay of Game"
        case .fighting: return "Fighting"
        case .headContact: return "Head Contact"
        case .cfb: return "CFB"
        case .slewFoot: return "Slew Foot"
        case .instigator: return "Instigator"
        case .aggressor: return "Aggressor"
        }
    }
}

/// One in-progress row of the penalty-entry screen, before it's submitted
/// into the report as a `PenaltyEntry`.
struct PenaltyDraftRow: Equatable {
    var infraction: Infraction?
    var types: Set<PenaltyType> = []
    var playerNumber = ""
    /// Optional number of the player serving the penalty.
    var servedBy = ""

    static let maxPlayerNumberDigits = 2
    static let rowsPerSide = 5

    var isEmpty: Bool { infraction == nil && types.isEmpty && playerNumber.isEmpty && servedBy.isEmpty }

    /// The numbers as shown in the row: "45", or "45/12" once a serving
    /// player's number is set. `showsSlash` keeps the slash visible while
    /// that second number is being typed.
    func numberDisplay(showsSlash: Bool = false) -> String? {
        guard !playerNumber.isEmpty else { return nil }
        return servedBy.isEmpty && !showsSlash ? playerNumber : "\(playerNumber)/\(servedBy)"
    }

    var isComplete: Bool { infraction != nil && !types.isEmpty && !playerNumber.isEmpty }
}

/// Identifies one draft row: which side's column and which of its rows.
struct PenaltyRowID: Equatable {
    var side: TeamSide
    var index: Int
}

/// The three player-number fields under a team's goal buttons.
enum GoalField: CaseIterable {
    case scorer
    case assist1
    case assist2

    var placeholder: String {
        switch self {
        case .scorer: return "Scorer"
        case .assist1: return "Primary Assist"
        case .assist2: return "Secondary Assist"
        }
    }
}

/// Identifies one goal field: which side's panel and which of its fields.
struct GoalFieldID: Equatable {
    var side: TeamSide
    var field: GoalField
}

/// The strength buttons above a side's scorer input; one must be selected
/// before its goal can be submitted.
enum GoalStrength: CaseIterable {
    case even
    case powerPlay
    case shortHanded

    var label: String {
        switch self {
        case .even: return "Goal"
        case .powerPlay: return "PP Goal"
        case .shortHanded: return "SH Goal"
        }
    }

    /// Marks the goal's strength in the report; empty for an even-strength goal.
    var prefix: String {
        switch self {
        case .even: return ""
        case .powerPlay: return "PP"
        case .shortHanded: return "SH"
        }
    }
}

/// The scorer/assist numbers typed for a side's next goal.
struct GoalDraft: Equatable {
    private var numbers: [GoalField: String] = [:]

    static let maxNumberDigits = 2

    subscript(field: GoalField) -> String {
        get { numbers[field] ?? "" }
        set { numbers[field] = newValue }
    }

    var isEmpty: Bool { GoalField.allCases.allSatisfy { self[$0].isEmpty } }

    /// e.g. "(G: 12, A: 5, A: 7)"; empty when no numbers are filled in.
    var summary: String {
        let parts = [
            self[.scorer].isEmpty ? "" : "G: \(self[.scorer])",
            self[.assist1].isEmpty ? "" : "A: \(self[.assist1])",
            self[.assist2].isEmpty ? "" : "A: \(self[.assist2])"
        ]
        .filter { !$0.isEmpty }
        return parts.isEmpty ? "" : "(\(parts.joined(separator: ", ")))"
    }
}

/// The three inputs under each side's goaltender column, filled from the
/// numpad on the Penalties tab.
enum GoaltenderField: String, CaseIterable, Codable {
    case starter
    case backup
    case time

    var placeholder: String {
        switch self {
        case .starter: return "Starter"
        case .backup: return "Backup"
        case .time: return "Time"
        }
    }

    /// Jersey numbers are two digits; the time is MMSS.
    var maxDigits: Int { self == .time ? 4 : 2 }
}

/// Identifies one goaltender input: which side's column and which field.
struct GoaltenderFieldID: Equatable {
    var side: TeamSide
    var field: GoaltenderField
}

/// The digits typed into a side's goaltender inputs.
struct GoaltenderDraft: Codable, Equatable {
    private var digits: [GoaltenderField: String] = [:]

    subscript(field: GoaltenderField) -> String {
        get { digits[field] ?? "" }
        set { digits[field] = newValue }
    }

    /// The field's text as shown: the time gets its colon (MM:SS).
    func display(_ field: GoaltenderField) -> String {
        let value = self[field]
        guard field == .time, value.count > 2 else { return value }
        return "\(value.prefix(2)):\(value.dropFirst(2))"
    }
}

/// A penalty entry's display text is its selected penalty type(s) (e.g.
/// "Minor + GM") plus an optional free-form note. Entries submitted from the
/// penalty-entry screen also carry the period time, infraction and player
/// number (plus the serving player's, if any), and display as
/// "02:45 (Tripping: Major + GM) #45 (Served by #12)".
struct PenaltyEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var team: TeamSide
    var period: GamePeriod
    var types: [PenaltyType]
    var text: String
    var time: String?
    var infraction: Infraction?
    var playerNumber: String?
    var servedBy: String?

    init(
        id: UUID = UUID(),
        team: TeamSide,
        period: GamePeriod,
        types: [PenaltyType] = [],
        text: String = "",
        time: String? = nil,
        infraction: Infraction? = nil,
        playerNumber: String? = nil,
        servedBy: String? = nil
    ) {
        self.id = id
        self.team = team
        self.period = period
        self.types = types
        self.text = text
        self.time = time
        self.infraction = infraction
        self.playerNumber = playerNumber
        self.servedBy = servedBy
    }

    private enum CodingKeys: String, CodingKey {
        case id, team, period, types, text, time, infraction, playerNumber, servedBy
    }

    /// Custom decoding so gamesheets saved before `types` (or the
    /// time/infraction/playerNumber fields) existed still decode instead of
    /// failing the whole saved-gamesheets array.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        team = try container.decode(TeamSide.self, forKey: .team)
        period = try container.decode(GamePeriod.self, forKey: .period)
        types = try container.decodeIfPresent([PenaltyType].self, forKey: .types) ?? []
        text = try container.decode(String.self, forKey: .text)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        // `try?` so a previously saved infraction that no longer exists (e.g. "misc") doesn't fail the whole decode.
        infraction = (try? container.decodeIfPresent(Infraction.self, forKey: .infraction)) ?? nil
        playerNumber = try container.decodeIfPresent(String.self, forKey: .playerNumber)
        servedBy = try container.decodeIfPresent(String.self, forKey: .servedBy)
    }

    var displayText: String {
        let typeText = types.map(\.label).joined(separator: " + ")
        guard let infraction else {
            return [text, typeText].filter { !$0.isEmpty }.joined(separator: " - ")
        }
        let detail = [infraction.label, typeText].filter { !$0.isEmpty }.joined(separator: ": ")
        return [
            time ?? "",
            "(\(detail))",
            playerNumber.map { "#\($0)" } ?? "",
            servedBy.map { "(Served by #\($0))" } ?? "",
            text
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }
}

struct GoalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var team: TeamSide
    var period: GamePeriod
    var text: String

    init(id: UUID = UUID(), team: TeamSide, period: GamePeriod, text: String = "") {
        self.id = id
        self.team = team
        self.period = period
        self.text = text
    }
}

/// A free-form note submitted from the Quick Note field that isn't tied to
/// a specific goal or penalty (e.g. a general observation).
struct GeneralNote: Identifiable, Codable, Equatable {
    let id: UUID
    var period: GamePeriod
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), period: GamePeriod, text: String, createdAt: Date = Date()) {
        self.id = id
        self.period = period
        self.text = text
        self.createdAt = createdAt
    }
}

/// A saved snapshot of a `GameState`, persisted so a game can be closed and
/// reopened later from the hamburger menu's gamesheet list.
struct GameSheet: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var savedAt: Date
    var teamNames: [TeamSide: String]
    var shots: [TeamSide: [GamePeriod: Int]]
    var goals: [GoalEntry]
    var penalties: [PenaltyEntry]
    var generalNotes: [GeneralNote]
    var currentPeriod: GamePeriod
    var goaltenderDrafts: [TeamSide: GoaltenderDraft]

    init(
        id: UUID,
        name: String,
        savedAt: Date,
        teamNames: [TeamSide: String],
        shots: [TeamSide: [GamePeriod: Int]],
        goals: [GoalEntry],
        penalties: [PenaltyEntry],
        generalNotes: [GeneralNote],
        currentPeriod: GamePeriod,
        goaltenderDrafts: [TeamSide: GoaltenderDraft]
    ) {
        self.id = id
        self.name = name
        self.savedAt = savedAt
        self.teamNames = teamNames
        self.shots = shots
        self.goals = goals
        self.penalties = penalties
        self.generalNotes = generalNotes
        self.currentPeriod = currentPeriod
        self.goaltenderDrafts = goaltenderDrafts
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, savedAt, teamNames, shots, goals, penalties, generalNotes, currentPeriod, goaltenderDrafts
    }

    /// Custom decoding so gamesheets saved before `goaltenderDrafts` existed
    /// (which lack that key entirely) still decode instead of failing the
    /// whole saved-gamesheets array.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        teamNames = try container.decode([TeamSide: String].self, forKey: .teamNames)
        shots = try container.decode([TeamSide: [GamePeriod: Int]].self, forKey: .shots)
        goals = try container.decode([GoalEntry].self, forKey: .goals)
        penalties = try container.decode([PenaltyEntry].self, forKey: .penalties)
        generalNotes = try container.decode([GeneralNote].self, forKey: .generalNotes)
        currentPeriod = try container.decode(GamePeriod.self, forKey: .currentPeriod)
        goaltenderDrafts = try container.decodeIfPresent([TeamSide: GoaltenderDraft].self, forKey: .goaltenderDrafts) ?? [:]
    }
}
