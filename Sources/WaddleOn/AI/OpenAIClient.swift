import Foundation

struct AIMessage: Codable, Equatable, Sendable {
    var role: String
    var content: String
}

struct AIConfiguration: Equatable, Sendable {
    var baseURL: String = "https://api.openai.com/v1"
    var model: String = "gpt-4o-mini"
    var systemPrompt: String = "Eres Waddle, un pingüino de escritorio amable y servicial. Responde en español de forma breve y clara."
}

enum AIClientError: Error, LocalizedError, Equatable {
    case invalidEndpoint
    case missingModel
    case invalidAPIKey
    case transport
    case httpStatus(Int)
    case invalidResponse
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Introduce una URL HTTP o HTTPS válida, sin credenciales, parámetros ni fragmentos."
        case .missingModel: return "Introduce el nombre del modelo de IA."
        case .invalidAPIKey: return "La clave API contiene caracteres no válidos."
        case .transport: return "No se pudo conectar al servicio de IA. Revisa la URL y tu conexión."
        case .httpStatus(let status): return "El servicio de IA devolvió HTTP \(status). Revisa la configuración e inténtalo de nuevo."
        case .invalidResponse: return "El servicio de IA devolvió una respuesta no compatible."
        case .emptyResponse: return "El servicio de IA no devolvió texto."
        }
    }
}

final class OpenAIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Root URLs use /v1; custom provider prefixes and complete endpoints are preserved.
    static func completionURL(for baseURL: String) throws -> URL {
        let input = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: input),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else {
            throw AIClientError.invalidEndpoint
        }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.isEmpty { path = "/v1" }
        if !path.hasSuffix("/chat/completions") { path += "/chat/completions" }
        components.path = path
        guard let url = components.url else { throw AIClientError.invalidEndpoint }
        return url
    }

    func complete(messages: [AIMessage], configuration: AIConfiguration, apiKey: String) async throws -> String {
        try Task.checkCancellation()
        let url = try Self.completionURL(for: configuration.baseURL)
        let model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { throw AIClientError.missingModel }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw AIClientError.invalidAPIKey
        }
        var history = messages
        if !configuration.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            history.insert(AIMessage(role: "system", content: configuration.systemPrompt), at: 0)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Local OpenAI-compatible services often do not require authentication.
        if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(CompletionRequest(model: model, messages: history))
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled || error is CancellationError {
                throw CancellationError()
            }
            // Underlying errors may contain URLs or server-provided secrets.
            throw AIClientError.transport
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIClientError.httpStatus(http.statusCode) }
        guard let completion = try? JSONDecoder().decode(CompletionResponse.self, from: data) else {
            throw AIClientError.invalidResponse
        }
        guard let text = completion.choices.first?.message.content,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.emptyResponse
        }
        return text
    }
}

private struct CompletionRequest: Encodable {
    let model: String
    let messages: [AIMessage]
    let stream = false
}

private struct CompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}
