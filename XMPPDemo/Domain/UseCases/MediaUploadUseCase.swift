import Foundation
import UIKit

nonisolated struct MediaUploadUseCase {
    typealias UploadPerformer = @Sendable (URLRequest, Data, Set<String>) async throws -> (Data, URLResponse)

    private let xmpp: any XMPPUploadSlotRequesting
    private let performUpload: UploadPerformer

    init(xmpp: any XMPPUploadSlotRequesting, performUpload: UploadPerformer? = nil) {
        self.xmpp = xmpp
        self.performUpload = performUpload ?? Self.defaultUpload
    }

    /// Compresses an image, requests an XEP-0363 slot, and uploads it via HTTP PUT.
    func execute(image: UIImage, quality: CGFloat = 0.7) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw XMPPError.connectionFailed("Failed to compress image")
        }
        
        let filename = "\(UUID().uuidString).jpg"
        let size = data.count
        
        // 1. Request slot from XMPP server
        let slot = try await xmpp.requestUploadSlot(filename: filename, size: size, mimeType: "image/jpeg")
        
        // 2. HTTP PUT to the slot
        var request = URLRequest(url: slot.putURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        // The bundled ejabberd config uses a self-signed certificate for its
        // local HTTPS upload endpoint. Keep that exception scoped to local hosts.
        let allowedHosts = LocalDevelopmentTLSDelegate.certificateExceptionHosts(for: slot.putURL)
        let (responseData, response) = try await performUpload(request, data, allowedHosts)
        
        guard let httpRes = response as? HTTPURLResponse else {
            throw XMPPError.connectionFailed("Upload server returned an invalid response")
        }
        guard (200...299).contains(httpRes.statusCode) else {
            let serverMessage = String(data: responseData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = serverMessage?.isEmpty == false ? ": \(serverMessage!)" : ""
            throw XMPPError.connectionFailed("HTTP Upload failed with status: \(httpRes.statusCode)\(detail)")
        }
        
        // 3. Return the public URL for the message body
        return slot.getURL
    }

    private static func defaultUpload(
        request: URLRequest,
        data: Data,
        allowedHosts: Set<String>
    ) async throws -> (Data, URLResponse) {
        let delegate = LocalDevelopmentTLSDelegate(allowedHosts: allowedHosts)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        return try await session.upload(for: request, from: data, delegate: delegate)
    }
}
