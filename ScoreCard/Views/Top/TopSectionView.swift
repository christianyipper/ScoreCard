import SwiftUI

struct TopSectionView: View {
    @Binding var context: NoteContext

    var body: some View {
        HStack(spacing: 16) {
            TeamPanelView(team: .home, context: $context)
            TeamPanelView(team: .away, context: $context)
        }
    }
}
