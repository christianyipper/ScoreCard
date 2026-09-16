import Foundation

/// What kind of entry the notepad is currently drafting.
enum NoteContext: Equatable, Identifiable {
    case goal(TeamSide)
    case penalty(TeamSide)
    case general

    var id: String {
        switch self {
        case .goal(let team): return "goal-\(team.rawValue)"
        case .penalty(let team): return "penalty-\(team.rawValue)"
        case .general: return "general"
        }
    }

    var team: TeamSide? {
        switch self {
        case .goal(let team), .penalty(let team): return team
        case .general: return nil
        }
    }

    var title: String {
        switch self {
        case .goal(let team): return "New Goal — \(team.defaultName)"
        case .penalty(let team): return "New Penalty — \(team.defaultName)"
        case .general: return "General Note"
        }
    }
}
