import SwiftUI

/// Placeholder until the iOS player (libmpv through MPVKit, drawn with
/// Metal) lands: the shared views open it with the same destination.
struct PlayerView: View {
    let destination: PlayerDestination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle").font(.system(size: 44)).foregroundStyle(Theme.Palette.accent)
            Text("Lecteur iOS : en cours de portage").foregroundStyle(.white)
            Button("Retour") { dismiss() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
