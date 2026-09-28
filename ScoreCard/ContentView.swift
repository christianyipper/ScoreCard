import SwiftUI

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var gameSheetStore = GameSheetStore()
    @StateObject private var rosterStore = RosterStore()
    @StateObject private var themeManager = ThemeManager()
    @State private var viewMode: MainViewMode = .report
    @State private var isGameSheetListPresented = false

    var body: some View {
        VStack(spacing: 12) {
            TopSectionView()

            Divider()

            NavSectionView(viewMode: $viewMode)

            Divider()

            Group {
                if viewMode == .penalties {
                    PenaltyEntryView()
                } else {
                    ReportView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .font(AppTypography.body)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                themeToggleButton
                hamburgerButton
            }
        }
        .environmentObject(gameState)
        .environmentObject(gameSheetStore)
        .environmentObject(rosterStore)
        // The numpad that fills the goal fields lives on the Penalties tab.
        .onChange(of: gameState.activeGoalField) { _, field in
            if field != nil { viewMode = .penalties }
        }
        .onChange(of: gameState.activeGoaltenderField) { _, field in
            if field != nil { viewMode = .penalties }
        }
        .sheet(isPresented: $isGameSheetListPresented) {
            GameSheetListView()
                .environmentObject(gameState)
                .environmentObject(gameSheetStore)
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }

    private var hamburgerButton: some View {
        Button {
            isGameSheetListPresented = true
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.title2)
                .foregroundStyle(.primary)
                .padding(10)
                .background(Color.cardBackground, in: Circle())
        }
        .buttonStyle(.squish)
        .padding(8)
    }

    private var themeToggleButton: some View {
        Button {
            themeManager.isDarkMode.toggle()
        } label: {
            Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                .font(.title2)
                .foregroundStyle(.primary)
                .padding(10)
                .background(Color.cardBackground, in: Circle())
        }
        .buttonStyle(.squish)
        .padding(.vertical, 8)
        .padding(.leading, 8)
    }
}

#Preview {
    ContentView()
}
