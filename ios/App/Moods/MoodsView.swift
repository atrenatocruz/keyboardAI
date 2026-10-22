import SwiftUI
import KeyboardCore

struct MoodsView: View {
    let onReplayOnboarding: () -> Void
    @State private var expanded: Mood? = .natural
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Escolhe o mood no teclado com um toque longo em ✨.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    ForEach(Mood.allCases, id: \.self) { mood in
                        card(mood)
                    }
                    // Required by the CC BY-SA 4.0 licence of the bundled word list.
                    Text("Sugestões de palavras com base em FrequencyWords de Hermit Dave (CC BY-SA 4.0), a partir de legendas do OpenSubtitles.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 12)
                }
                .padding(20)
            }
            .navigationTitle("Moods")
            .toolbar {
                Button("Configurar teclado", action: onReplayOnboarding)
            }
        }
    }

    private func card(_ mood: Mood) -> some View {
        let isOpen = expanded == mood
        return Button {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 1)) {
                expanded = isOpen ? nil : mood
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mood.displayName).font(.headline)
                        Text(mood.summary).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .foregroundStyle(.tertiary)
                }
                if isOpen {
                    ExampleCard(before: Mood.exampleInput, after: mood.exampleOutput)
                        .transition(.opacity)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen ? "Esconder exemplo" : "Mostrar exemplo")
    }
}
