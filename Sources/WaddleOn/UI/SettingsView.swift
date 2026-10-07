import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var baseURL: String
    @Published var model: String
    @Published var apiKey: String
    @Published var systemPrompt: String
    @Published var error: String?

    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?

    init(
        baseURL: String = "https://api.openai.com/v1",
        model: String = "",
        apiKey: String = "",
        systemPrompt: String = "Eres un pingüino amigable que acompaña al usuario en su escritorio. Responde en español de forma cálida y breve."
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.systemPrompt = systemPrompt
    }

    func save() {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else {
            error = "Introduce una URL válida que empiece por https:// o http://."
            return
        }
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            error = "Escribe el nombre del modelo que quieres usar."
            return
        }
        baseURL = trimmedURL
        model = trimmedModel
        error = nil
        onSave?()
    }
}

@MainActor
struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "snowflake")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ajustes de Waddle On").font(.title2.bold())
                    Text("Dale voz y personalidad a tu pingüino.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Form {
                Section {
                    TextField("URL base", text: $model.baseURL, prompt: Text("https://api.openai.com/v1"))
                        .help("Dirección base de una API compatible con OpenAI, incluyendo /v1 si corresponde.")
                    TextField("Modelo", text: $model.model, prompt: Text("Nombre del modelo"))
                    SecureField("Clave API", text: $model.apiKey, prompt: Text("Opcional para servidores locales"))
                        .accessibilityLabel("Clave API")
                } header: {
                    Text("Conexión")
                } footer: {
                    Text("Usa un proveedor compatible con OpenAI o tu servidor local. La clave se oculta mientras escribes.")
                        .font(.caption)
                }

                Section("Personalidad") {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Instrucciones del sistema").font(.callout)
                        TextEditor(text: $model.systemPrompt)
                            .font(.system(size: 12))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .frame(height: 112)
                            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.25)))
                            .accessibilityLabel("Instrucciones del sistema para tu pingüino")
                    }
                }
            }
            .formStyle(.grouped)

            if let error = model.error, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Error: \(error)")
            }

            HStack {
                Spacer()
                Button("Cancelar") { model.onCancel?() }
                    .keyboardShortcut(.cancelAction)
                Button("Guardar ajustes") { model.save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 550, height: 570)
    }
}
