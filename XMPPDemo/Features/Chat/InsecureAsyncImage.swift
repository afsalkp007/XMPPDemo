import SwiftUI
import Foundation
import UIKit

/// Allows the self-signed certificate used by the local ejabberd development server.
///
/// This must never trust arbitrary hosts: production upload URLs continue through
/// URLSession's normal certificate validation.
final class InsecureURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let allowedHosts: Set<String>

    init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }

    static func allowsLocalCertificateException(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local")
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handle(challenge: challenge, completionHandler: completionHandler)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handle(challenge: challenge, completionHandler: completionHandler)
    }
    
    private func handle(challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           allowedHosts.contains(challenge.protectionSpace.host.lowercased()),
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

struct InsecureAsyncImage: View {
    let url: URL
    
    @State private var phase: AsyncImagePhase = .empty
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                ProgressView().frame(width: 200, height: 200)
            case .success(let image):
                image.resizable().scaledToFill().frame(maxWidth: 240, maxHeight: 320).clipped()
            case .failure:
                VStack {
                    Image(systemName: "photo.badge.exclamationmark").font(.title)
                    Text("Failed to load").font(.caption)
                }.frame(width: 200, height: 200).foregroundStyle(.secondary)
            @unknown default:
                EmptyView()
            }
        }
        .task { await load() }
    }
    
    private func load() async {
        do {
            let request = URLRequest(url: url)
            let allowedHosts = InsecureURLSessionDelegate.allowsLocalCertificateException(for: url)
                ? Set([url.host?.lowercased()].compactMap { $0 })
                : []
            let delegate = InsecureURLSessionDelegate(allowedHosts: allowedHosts)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let uiImage = UIImage(data: data) {
                phase = .success(Image(uiImage: uiImage))
            } else {
                phase = .failure(URLError(.badServerResponse))
            }
        } catch {
            phase = .failure(error)
        }
    }
}
