import SwiftUI

/// Shared text and color tokens so team-identity styling (name, score) stays
/// in sync across the Top panels and the Report view instead of each one
/// picking its own font/color.
enum AppTypography {
    static let teamName = Font.title.bold()
    static let caption = Font.subheadline
    /// App-wide default body size; the system's `.subheadline`/`.caption`
    /// sizes (~15pt/12pt) read as too small, especially in the Report view.
    static let body = Font.system(size: 18)
}

enum AppLayout {
    /// Width of the middle column shared by the top section (goaltenders) and
    /// the penalty screen (period/numpad) so the two line up.
    static let centerColumnWidth: CGFloat = 300

    /// Height of a top-section card (shots, goals, scorer): one action
    /// button plus the card's padding.
    static let sectionPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 10
    static var actionButtonHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight + 16 * 2
    }
    static var sectionHeight: CGFloat { actionButtonHeight + sectionPadding * 2 }

    /// Height of a team panel: the shots card plus the goal card, which
    /// holds two rows (goal buttons and scorer input); the goaltenders card
    /// is sized to match.
    static var teamPanelHeight: CGFloat {
        sectionHeight * 2 + actionButtonHeight + sectionSpacing * 2
    }
}

extension TeamSide {
    var accentColor: Color {
        switch self {
        case .home: return .blue
        case .away: return .orange
        }
    }
}

extension Color {
    /// Screen background: white in light mode, dark grey in dark mode.
    static let appBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.11, alpha: 1) : .systemBackground
    })

    /// Card/panel background: sits one step off `appBackground` in both
    /// directions — slightly darker than white in light mode, slightly
    /// lighter than dark grey in dark mode — so cards read as distinct surfaces.
    static let cardBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.17, alpha: 1) : .secondarySystemBackground
    })
}

/// Persists the user's manual light/dark choice and drives it app-wide via
/// `.preferredColorScheme`, independent of the system setting.
final class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
}

/// A `ButtonStyle` for the app's manually-drawn (`.plain`) buttons, which
/// otherwise give no tap feedback since `.plain` strips the system's own.
/// Squishes down hard while held and pops back with a springy overshoot.
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.72 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.35), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SquishButtonStyle {
    static var squish: SquishButtonStyle { SquishButtonStyle() }
}
