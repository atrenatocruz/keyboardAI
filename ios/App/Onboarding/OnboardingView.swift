import SwiftUI
import KeyboardCore

struct OnboardingView: View {
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable { case welcome, addKeyboard, fullAccess, moods }
    @State private var step: Step = .welcome
    @State private var keyboardAdded = KeyboardStatus.isKeyboardAdded()
    @State private var testText = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                .tint(.primary)
            Group {
                switch step {
                case .welcome: welcome
                case .addKeyboard: addKeyboard
                case .fullAccess: fullAccess
                case .moods: moods
                }
            }
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                               removal: .move(edge: .leading).combined(with: .opacity)))
            Spacer()
        }
        .padding(24)
        .animation(.spring(response: 0.4, dampingFraction: 1), value: step)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            keyboardAdded = KeyboardStatus.isKeyboardAdded()
            if step == .addKeyboard && keyboardAdded { step = .fullAccess }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escreve como sempre.\nA IA dá o toque final.")
                .font(.largeTitle.weight(.bold))
            Text("O Tecl.ai melhora as tuas mensagens em português de Portugal, sem saíres da conversa.")
                .font(.body)
                .foregroundStyle(.secondary)
            ExampleCard(before: Mood.exampleInput, after: Mood.natural.exampleOutput)
            primaryButton("Começar") { step = .addKeyboard }
        }
    }

    private var addKeyboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adiciona o teclado").font(.title.weight(.bold))
            VStack(alignment: .leading, spacing: 8) {
                Label("Abre as Definições", systemImage: "1.circle")
                Label("Toca em Teclados", systemImage: "2.circle")
                Label("Ativa o Tecl.ai", systemImage: "3.circle")
            }
            .font(.body)
            primaryButton("Abrir Definições") { openSettings() }
            Button("Já adicionei") { step = .fullAccess }
                .font(.body)
                .opacity(keyboardAdded ? 0 : 1)
        }
    }

    private var fullAccess: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permite o Acesso total").font(.title.weight(.bold))
            Text("A IA precisa de internet para melhorar o texto. O iOS chama a isto \"Acesso total\".")
                .foregroundStyle(.secondary)
            Label("Os teus textos não são guardados. São enviados apenas quando tocas em ✨ e descartados logo a seguir.",
                  systemImage: "lock.shield")
                .font(.callout)
            primaryButton("Abrir Definições") { openSettings() }
            Text("Experimenta aqui: muda para o Tecl.ai com 🌐, escreve e toca em ✨.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("boas, consegues me mandar isso?", text: $testText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            primaryButton("Continuar") { step = .moods }
        }
    }

    private var moods: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escolhe o teu mood").font(.title.weight(.bold))
            Text("Faz um toque longo em ✨ no teclado para mudar de mood a qualquer momento.")
                .foregroundStyle(.secondary)
            primaryButton("Ver os moods") { onFinish() }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.primary)
        .foregroundStyle(Color(uiColor: .systemBackground))
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

struct ExampleCard: View {
    let before: String
    let after: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(before).foregroundStyle(.secondary)
            Image(systemName: "arrow.down").foregroundStyle(.tertiary)
            Text(after).fontWeight(.medium)
        }
        .font(.body)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
