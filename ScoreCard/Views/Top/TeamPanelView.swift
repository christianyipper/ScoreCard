import SwiftUI

struct TeamPanelView: View {
    @EnvironmentObject var gameState: GameState
    let team: TeamSide
    @Binding var context: NoteContext

    private var teamNameBinding: Binding<String> {
        Binding(
            get: { gameState.teamNames[team] ?? team.defaultName },
            set: { gameState.teamNames[team] = $0 }
        )
    }

    private var accent: Color { team == .home ? .blue : .orange }

    var body: some View {
        VStack(spacing: 10) {
            TextField(team.defaultName, text: teamNameBinding)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)

            Text("\(gameState.goalCount(for: team))")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)

            shotsRow

            HStack(spacing: 10) {
                Button {
                    context = .goal(team)
                } label: {
                    Label("Add Goal", systemImage: "star.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    context = .penalty(team)
                } label: {
                    Label("Add Penalty", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var shotsRow: some View {
        HStack {
            Text("Shots")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                gameState.addShot(for: team, delta: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text("\(gameState.shotCount(for: team, period: gameState.currentPeriod))")
                .font(.title3.monospacedDigit().bold())
                .frame(minWidth: 32)

            Button {
                gameState.addShot(for: team, delta: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(accent)

            Spacer()

            Text("Total: \(gameState.shotTotal(for: team))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
