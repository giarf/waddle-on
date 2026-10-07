import SwiftUI

@MainActor
struct ChatBarView: View {
    @ObservedObject var model: ChatViewModel
    @FocusState private var isInputFocused: Bool

    private let ocean = Color(red: 0.06, green: 0.36, blue: 0.68)

    var body: some View {
        VStack(spacing: 8) {
            if model.isHistoryExpanded {
                history
                    .frame(height: 342)
            }
            composer
                .frame(height: 84)
        }
        .padding(8)
        .frame(width: 660, height: model.isHistoryExpanded ? 450 : 100, alignment: .bottom)
        .preferredColorScheme(.dark)
    }

    private var composer: some View {
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                Button {
                    model.isHistoryExpanded.toggle()
                } label: {
                    Image(systemName: model.isHistoryExpanded ? "chevron.down" : "chevron.up")
                        .frame(width: 28, height: 28)
                }
                .help(model.isHistoryExpanded ? "Ocultar conversación" : "Ver conversación")
                .accessibilityLabel(model.isHistoryExpanded ? "Ocultar conversación" : "Ver conversación")

                TextField("Escribe a tu pingüino…", text: $model.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.black.opacity(0.17), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.22)))
                    .focused($isInputFocused)
                    .onSubmit { model.send() }
                    .accessibilityLabel("Mensaje para tu pingüino")

                if model.isSending {
                    Button { model.onCancel?() } label: {
                        Image(systemName: "stop.fill").frame(width: 32, height: 32)
                    }
                    .help("Cancelar respuesta")
                    .accessibilityLabel("Cancelar respuesta")
                } else {
                    Button { model.send(); isInputFocused = true } label: {
                        Image(systemName: "paperplane.fill").frame(width: 32, height: 32)
                    }
                    .disabled(!model.canSend)
                    .help("Enviar mensaje (Intro)")
                    .accessibilityLabel("Enviar mensaje")
                }

                Button { model.onOpenSettings?() } label: {
                    Image(systemName: "gearshape.fill").frame(width: 28, height: 28)
                }
                .help("Abrir ajustes")
                .accessibilityLabel("Abrir ajustes")
            }
            HStack(spacing: 6) {
                if let error = model.error, !error.isEmpty {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.yellow)
                    Text(error).lineLimit(1).help(error)
                } else if model.isSending {
                    ProgressView().controlSize(.mini)
                    Text("Tu pingüino está pensando…")
                } else {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Waddle On · Un amigo en tu escritorio")
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 5)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 23)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 23)
                        .fill(LinearGradient(colors: [ocean.opacity(0.92), ocean.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                }
        }
        .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.white.opacity(0.32)))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    private var history: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                Text("Nuestra conversación").fontWeight(.semibold)
                Spacer()
                Text("Waddle On").foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
            .padding(14)
            Divider().overlay(Color.white.opacity(0.1))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if model.messages.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "snowflake").font(.system(size: 28))
                                Text("¡Hola! Qué bueno verte por aquí.").fontWeight(.semibold)
                                Text("Escribe un mensaje y empecemos a charlar.")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        }
                        ForEach(model.messages) { message in
                            messageBubble(message)
                        }
                        Color.clear.frame(height: 1).id("conversation-bottom")
                    }
                    .padding(14)
                }
                .onAppear { proxy.scrollTo("conversation-bottom", anchor: .bottom) }
                .onChange(of: model.messages.count) { _ in
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                }
                .onChange(of: model.messages.last?.content) { _ in
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.22)))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == "user"
        return HStack(alignment: .top) {
            if isUser { Spacer(minLength: 50) }
            VStack(alignment: .leading, spacing: 5) {
                Text(isUser ? "Tú" : "Tu pingüino")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(message.content)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .background(isUser ? ocean.opacity(0.8) : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
            if !isUser { Spacer(minLength: 50) }
        }
    }
}
