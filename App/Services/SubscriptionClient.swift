import Foundation
import VPNCore

private final class HTTPSPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let value = request.url?.absoluteString, (try? SubscriptionParser.validateURL(value)) != nil else {
            completionHandler(nil); return
        }
        completionHandler(request)
    }
}

enum SubscriptionClient {
    static func fetch(_ text: String) async throws -> ImportResult {
        let url = try SubscriptionParser.validateURL(text)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration, delegate: HTTPSPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("Velora/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/plain, application/octet-stream", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ClientError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard response.expectedContentLength <= SubscriptionParser.maximumBytes else { throw VPNError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < SubscriptionParser.maximumBytes else { throw VPNError.tooLarge }
            data.append(byte)
        }
        guard let body = String(data: data, encoding: .utf8) else { throw VPNError.invalidSubscription }
        return try SubscriptionParser.parse(body)
    }

    enum ClientError: LocalizedError {
        case http(Int)
        var errorDescription: String? {
            if case .http(let code) = self { return "Сервер подписки вернул HTTP \(code). Сохранённые профили не изменены." }
            return nil
        }
    }
}
