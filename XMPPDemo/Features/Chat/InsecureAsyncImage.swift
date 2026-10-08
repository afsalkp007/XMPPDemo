import SwiftUI
import UIKit

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
            let allowedHosts = LocalDevelopmentTLSDelegate.certificateExceptionHosts(for: url)
            let delegate = LocalDevelopmentTLSDelegate(allowedHosts: allowedHosts)
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
