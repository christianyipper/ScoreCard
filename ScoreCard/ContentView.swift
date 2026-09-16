import SwiftUI

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @State private var context: NoteContext = .general
    @State private var viewMode: MainViewMode = .notes

    var body: some View {
        VStack(spacing: 12) {
            TopSectionView(context: $context)

            Divider()

            NavSectionView(viewMode: $viewMode)

            Divider()

            Group {
                if viewMode == .notes {
                    NotesView(context: $context)
                } else {
                    ReportView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .environmentObject(gameState)
        .onChange(of: context) { _, newValue in
            if newValue != .general {
                viewMode = .notes
            }
        }
    }
}

#Preview {
    ContentView()
}
