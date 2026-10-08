import Foundation

/// Accepts the self-signed certificate used only by the local ejabberd server.
/// All non-local hosts retain normal URLSession certificate validation.
final class LocalDevelopmentTLSDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let allowedHosts: Set<String>

    init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }

    static func certificateExceptionHosts(for url: URL) -> Set<String> {
        guard let host = url.host?.lowercased(), isLocalDevelopmentHost(host) else { return [] }
        return [host]
    }

    private static func isLocalDevelopmentHost(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local")
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handle(challenge: challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handle(challenge: challenge, completionHandler: completionHandler)
    }

    private func handle(
        challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           allowedHosts.contains(challenge.protectionSpace.host.lowercased()),
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
