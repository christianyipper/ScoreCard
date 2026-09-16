import SwiftUI

enum MainViewMode: String, CaseIterable, Identifiable {
    case notes = "Notes"
    case report = "Report"

    var id: String { rawValue }
}

struct NavSectionView: View {
    @EnvironmentObject var gameState: GameState
    @Binding var viewMode: MainViewMode

    var body: some View {
        HStack(spacing: 20) {
            Picker("Period", selection: $gameState.currentPeriod) {
                ForEach(GamePeriod.allCases) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            Spacer()

            Picker("View", selection: $viewMode) {
                ForEach(MainViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .padding(.vertical, 4)
    }
}
