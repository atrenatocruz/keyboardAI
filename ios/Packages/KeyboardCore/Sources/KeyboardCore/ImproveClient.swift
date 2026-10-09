import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ImproveResult: Equatable, Sendable {
    public let text: String
    public let remaining: Int

    public init(text: String, remaining: Int) {
        self.text = text
        self.remaining = remaining
    }
}

public enum ImproveError: Error, Equatable {
    case offline, timeout, dailyLimit, server
}

extension AIStatusMessage {
    public init(_ error: ImproveError) {
        switch error {
        case .offline: self = .offline
        case .timeout: self = .timeout
        case .dailyLimit: self = .dailyLimit
        case .server: self = .server
        }
    }
}

public final class ImproveClient {
    private struct RequestBody: Encodable { let text: String; let mood: String }
    private struct ResponseBody: Decodable { let text: String; let remaining: Int }

    private let endpoint: URL
    private let installID: String
    private let session: URLSession
    private let timeout: TimeInterval

    public init(baseURL: URL, installID: String, session: URLSession = .shared, timeout: TimeInterval = 8) {
        self.endpoint = baseURL.appendingPathComponent("v1/improve")
        self.installID = installID
        self.session = session
        self.timeout = timeout
    }

    public func improve(text: String, mood: Mood) async throws -> ImproveResult {
        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(installID, forHTTPHeaderField: "X-Install-ID")
        request.httpBody = try JSONEncoder().encode(RequestBody(text: text, mood: mood.rawValue))

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw ImproveError.server }
        switch http.statusCode {
        case 200:
            guard let body = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
                throw ImproveError.server
            }
            return ImproveResult(text: body.text, remaining: body.remaining)
        case 429:
            throw ImproveError.dailyLimit
        default:
            throw ImproveError.server
        }
    }

    // dataTask + continuation works on every Foundation (Apple and swift-corelibs).
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error = error as? URLError {
                    continuation.resume(throwing: error.code == .timedOut ? ImproveError.timeout : ImproveError.offline)
                } else if error != nil {
                    continuation.resume(throwing: ImproveError.offline)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: ImproveError.server)
                }
            }.resume()
        }
    }
}
