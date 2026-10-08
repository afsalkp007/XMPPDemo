import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

/// Multi-line text input bar pinned to the bottom of ChatView.
struct ChatInputBar: View {
    @Binding var text: String
    var isDisabled: Bool = false
    var onSend: () -> Void
    var onImageSelected: ((UIImage) -> Void)? = nil
    var onTextChange: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var selectedItem: PhotosPickerItem? = nil
    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isDisabled }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            
            // Attachment Button
            if let onImageSelected {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isDisabled ? .textTertiary : .brandCyan)
                        .frame(width: 40, height: 44)
                }
                .disabled(isDisabled)
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            onImageSelected(image)
                        }
                        selectedItem = nil
                    }
                }
            }

            // Text field
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Message…")
                        .font(.messageInput)
                        .foregroundStyle(.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                TextField("", text: $text, axis: .vertical)
                    .font(.messageInput)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .focused($isFocused)
                    .onChange(of: text) { _, _ in onTextChange?() }
            }
            .background(Color.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.brandCyan.opacity(0.5) : Color.bgBorder,
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            // Send button
            Button(action: {
                onSend()
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }) {
                ZStack {
                    Circle()
                        .fill(canSend ? LinearGradient.brand : LinearGradient(colors: [Color.bgElevated], startPoint: .top, endPoint: .bottom))
                        .frame(width: 44, height: 44)
                        .shadow(color: canSend ? Color.brandCyan.opacity(0.4) : .clear, radius: 8)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canSend ? .white : .textTertiary)
                }
            }
            .disabled(!canSend)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color.bgSurface
                .shadow(color: .black.opacity(0.25), radius: 12, y: -4)
        )
    }
}
