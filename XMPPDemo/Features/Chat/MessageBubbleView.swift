import SwiftUI

/// Single chat message bubble.
struct MessageBubbleView: View {
    let message: Message

    private var isOutgoing: Bool { message.isOutgoing }

    private var isImageURL: Bool {
        if let url = URL(string: message.body.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme == "http" || url.scheme == "https" {
            let ext = url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(ext)
        }
        return false
    }

    private var displayURL: URL? {
        URL(string: message.body.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                // Bubble
                if isImageURL, let url = displayURL {
                    imageView(for: url)
                    .clipShape(BubbleShape(isOutgoing: isOutgoing))
                } else {
                    Text(message.body)
                        .font(.messageBubble)
                        .foregroundStyle(isOutgoing ? .white : .textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(bubbleBackground)
                        .clipShape(BubbleShape(isOutgoing: isOutgoing))
                }

                // Timestamp + delivery status
                HStack(spacing: 4) {
                    Text(message.timestamp.timeString)
                        .font(.appTimestamp)
                        .foregroundStyle(.textTertiary)

                    if isOutgoing {
                        Image(systemName: message.deliveryStatus.systemImage)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(deliveryColor)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isOutgoing { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: Helpers

    private var bubbleBackground: some View {
        Group {
            if isOutgoing {
                LinearGradient.brand
            } else {
                Color.bubbleIn
            }
        }
    }

    @ViewBuilder
    private func imageView(for url: URL) -> some View {
        if !LocalDevelopmentTLSDelegate.certificateExceptionHosts(for: url).isEmpty {
            InsecureAsyncImage(url: url)
        } else {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(isOutgoing ? .white : .brandCyan)
                        .frame(width: 200, height: 200)
                        .background(bubbleBackground)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 320)
                        .clipped()
                case .failure:
                    imageLoadFailure
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    private var imageLoadFailure: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title)
            Text("Failed to load")
                .font(.appCaption)
        }
        .foregroundStyle(isOutgoing ? .white : .textSecondary)
        .frame(width: 200, height: 200)
        .background(bubbleBackground)
    }

    private var deliveryColor: Color {
        switch message.deliveryStatus {
        case .sending:   return .textTertiary
        case .sent:      return .textSecondary
        case .delivered: return .textSecondary
        case .read:      return .brandCyan
        case .failed:    return .errorRed
        }
    }
}

// MARK: - Bubble Shape

/// Rounded rectangle with one sharp corner indicating direction.
struct BubbleShape: Shape {
    let isOutgoing: Bool
    private let radius: CGFloat = 18
    private let tailRadius: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = CGPoint(x: rect.minX, y: rect.minY)
        let tr = CGPoint(x: rect.maxX, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        let bl = CGPoint(x: rect.minX, y: rect.maxY)

        if isOutgoing {
            // Sharp bottom-right
            path.move(to: CGPoint(x: tl.x + radius, y: tl.y))
            path.addLine(to: CGPoint(x: tr.x - radius, y: tr.y))
            path.addArc(center: CGPoint(x: tr.x - radius, y: tr.y + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: br.x, y: br.y - tailRadius))
            path.addArc(center: CGPoint(x: br.x - tailRadius, y: br.y - tailRadius), radius: tailRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: bl.x + radius, y: bl.y))
            path.addArc(center: CGPoint(x: bl.x + radius, y: bl.y - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: tl.x, y: tl.y + radius))
            path.addArc(center: CGPoint(x: tl.x + radius, y: tl.y + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            // Sharp bottom-left
            path.move(to: CGPoint(x: tl.x + radius, y: tl.y))
            path.addLine(to: CGPoint(x: tr.x - radius, y: tr.y))
            path.addArc(center: CGPoint(x: tr.x - radius, y: tr.y + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: br.x, y: br.y - radius))
            path.addArc(center: CGPoint(x: br.x - radius, y: br.y - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: bl.x + tailRadius, y: bl.y))
            path.addArc(center: CGPoint(x: bl.x + tailRadius, y: bl.y - tailRadius), radius: tailRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: tl.x, y: tl.y + radius))
            path.addArc(center: CGPoint(x: tl.x + radius, y: tl.y + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        path.closeSubpath()
        return path
    }
}
