import XCTest
@testable import WaddleOn

final class AIClientTests: XCTestCase {
    func testEndpointNormalization() throws {
        for (input, expected) in [
            ("https://example.com", "https://example.com/v1/chat/completions"),
            ("http://localhost:1234/v1/", "http://localhost:1234/v1/chat/completions"),
            ("https://example.com/chat/completions/", "https://example.com/chat/completions"),
            ("https://example.com/api/v1", "https://example.com/api/v1/chat/completions")
        ] {
            XCTAssertEqual(try OpenAIClient.completionURL(for: input).absoluteString, expected)
        }
        for input in ["invalid", "ftp://example.com", "https://user:secret@example.com", "https://example.com?key=secret", "https://example.com/#fragment"] {
            XCTAssertThrowsError(try OpenAIClient.completionURL(for: input))
        }
    }

    func testRequestPreservesHistoryAndAddsSystemPrompt() async throws {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        MockAIProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try Self.requestBody(request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "test-model")
            XCTAssertEqual(json["stream"] as? Bool, false)
            let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
            XCTAssertEqual(messages, [
                ["role": "system", "content": "Be helpful"],
                ["role": "user", "content": "Hello"],
                ["role": "assistant", "content": "Hi"],
                ["role": "user", "content": "Again"]
            ])
            return (200, Data(#"{"choices":[{"message":{"role":"assistant","content":"Waddle!"}}]}"#.utf8))
        }
        let text = try await client.complete(messages: [
            AIMessage(role: "user", content: "Hello"), AIMessage(role: "assistant", content: "Hi"),
            AIMessage(role: "user", content: "Again")
        ], configuration: AIConfiguration(baseURL: "https://example.com", model: "test-model", systemPrompt: "Be helpful"), apiKey: "test-token")
        XCTAssertEqual(text, "Waddle!")
    }

    func testHTTPErrorDoesNotExposeResponseOrKey() async throws {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        MockAIProtocol.handler = { _ in (401, Data("secret-token and private message".utf8)) }
        do {
            _ = try await client.complete(messages: [], configuration: AIConfiguration(), apiKey: "secret-token")
            XCTFail("Expected HTTP failure")
        } catch {
            XCTAssertEqual(error as? AIClientError, .httpStatus(401))
            XCTAssertFalse(error.localizedDescription.contains("secret-token"))
            XCTAssertFalse(error.localizedDescription.contains("private message"))
        }
    }

    func testInvalidAndEmptyResponses() async throws {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        for (body, expected) in [("not-json", AIClientError.invalidResponse), (#"{"choices":[]}"#, .emptyResponse), (#"{"choices":[{"message":{"content":null}}]}"#, .emptyResponse)] {
            MockAIProtocol.handler = { _ in (200, Data(body.utf8)) }
            do {
                _ = try await client.complete(messages: [], configuration: AIConfiguration(), apiKey: "")
                XCTFail("Expected response failure")
            } catch { XCTAssertEqual(error as? AIClientError, expected) }
        }
    }

    func testTransportErrorsAreRedactedAndCancellationIsPreserved() async throws {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        MockAIProtocol.handler = { _ in
            throw NSError(domain: "secret", code: 1, userInfo: [NSLocalizedDescriptionKey: "private-token"])
        }
        do {
            _ = try await client.complete(messages: [], configuration: AIConfiguration(), apiKey: "")
            XCTFail("Expected transport failure")
        } catch { XCTAssertEqual(error as? AIClientError, .transport) }

        MockAIProtocol.handler = { _ in throw URLError(.cancelled) }
        do {
            _ = try await client.complete(messages: [], configuration: AIConfiguration(), apiKey: "")
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testLocalServiceWithoutKeyOrSystemPrompt() async throws {
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }
        MockAIProtocol.handler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.requestBody(request)) as? [String: Any])
            XCTAssertEqual((json["messages"] as? [[String: String]])?.count, 1)
            return (200, Data(#"{"choices":[{"message":{"content":"OK"}}]}"#.utf8))
        }
        _ = try await client.complete(messages: [AIMessage(role: "user", content: "Hello")], configuration: AIConfiguration(systemPrompt: ""), apiKey: "")
    }

    func testSettingsConfigurationRoundTrip() throws {
        let suite = "WaddleOnTests.AI.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.loadConfiguration(), AIConfiguration())
        let config = AIConfiguration(baseURL: "http://localhost:1234", model: "local", systemPrompt: "")
        store.saveConfiguration(config)
        XCTAssertEqual(SettingsStore(defaults: defaults).loadConfiguration(), config)
        XCTAssertEqual(Set(defaults.persistentDomain(forName: suite)?.keys.map { $0 } ?? []), ["ai.baseURL", "ai.model", "ai.systemPrompt"])
    }

    private func makeClient() -> (OpenAIClient, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockAIProtocol.self]
        let session = URLSession(configuration: configuration)
        return (OpenAIClient(session: session), session)
    }

    private static func requestBody(_ request: URLRequest) throws -> Data {
        if let data = request.httpBody { return data }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? URLError(.unknown) }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class MockAIProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (status, data) = try handler(request)
            let response = try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
