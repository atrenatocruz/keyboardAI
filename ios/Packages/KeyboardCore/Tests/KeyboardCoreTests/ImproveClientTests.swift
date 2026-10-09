import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import KeyboardCore

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

private func bodyData(_ request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open(); defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let n = stream.read(&buffer, maxLength: buffer.count)
        if n <= 0 { break }
        data.append(buffer, count: n)
    }
    return data
}

final class ImproveClientTests: XCTestCase {
    private let base = URL(string: "https://api.example.com")!
    private let id = "3f2b8c1e-4a5d-4e6f-8a9b-0c1d2e3f4a5b"

    private func makeClient() -> ImproveClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return ImproveClient(baseURL: base, installID: id, session: URLSession(configuration: config))
    }

    private func respond(_ status: Int, _ json: String) {
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
             Data(json.utf8))
        }
    }

    override func tearDown() { MockURLProtocol.handler = nil }

    func testSuccessSendsContractAndParsesResult() async throws {
        var captured: URLRequest?
        MockURLProtocol.handler = { request in
            captured = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"text":"Boas!","remaining":199}"#.utf8))
        }
        let result = try await makeClient().improve(text: "boas", mood: .simpatico)
        XCTAssertEqual(result, ImproveResult(text: "Boas!", remaining: 199))

        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/improve")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Install-ID"), id)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try JSONSerialization.jsonObject(with: bodyData(request)) as? [String: String]
        XCTAssertEqual(body, ["text": "boas", "mood": "simpatico"])
    }

    func testStatusCodesMapToErrors() async {
        let cases: [(Int, String, ImproveError)] = [
            (429, #"{"error":"daily_limit"}"#, .dailyLimit),
            (400, #"{"error":"invalid_request"}"#, .server),
            (502, #"{"error":"upstream"}"#, .server),
            (200, "not json", .server),
        ]
        for (status, json, expected) in cases {
            respond(status, json)
            do {
                _ = try await makeClient().improve(text: "a", mood: .natural)
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? ImproveError, expected, "status \(status)")
            }
        }
    }

    func testNetworkErrorsMapToOfflineAndTimeout() async {
        for (code, expected) in [(URLError.timedOut, ImproveError.timeout),
                                 (.notConnectedToInternet, .offline),
                                 (.cannotFindHost, .offline)] {
            MockURLProtocol.handler = { _ in throw URLError(code) }
            do {
                _ = try await makeClient().improve(text: "a", mood: .natural)
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? ImproveError, expected)
            }
        }
    }

    func testErrorToStatusMessage() {
        XCTAssertEqual(AIStatusMessage(ImproveError.offline), .offline)
        XCTAssertEqual(AIStatusMessage(ImproveError.timeout), .timeout)
        XCTAssertEqual(AIStatusMessage(ImproveError.dailyLimit), .dailyLimit)
        XCTAssertEqual(AIStatusMessage(ImproveError.server), .server)
    }
}
