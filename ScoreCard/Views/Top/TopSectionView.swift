import SwiftUI

struct TopSectionView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                TeamNameField(team: .home)
                scoreContainer
                    .frame(width: AppLayout.centerColumnWidth)
                TeamNameField(team: .away)
            }

            HStack(spacing: 16) {
                TeamPanelView(team: .home)
                GoaltenderPanelView()
                    .frame(width: AppLayout.centerColumnWidth)
                TeamPanelView(team: .away)
            }
        }
    }

    private var scoreContainer: some View {
        HStack(spacing: 8) {
            scoreNumber(for: .home)

            Text("Score")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()

            scoreNumber(for: .away)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 140)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func scoreNumber(for team: TeamSide) -> some View {
        Text("\(gameState.goalCount(for: team))")
            .font(AppTypography.teamName)
            .foregroundStyle(gameState.accentColor(for: team))
            .frame(width: 32, alignment: .center)
    }
}
