import SwiftUI

struct CornerPositionPicker: View {
    @Binding var selection: OverlayPosition
    var isEnabled: Bool = true

    private let size = CGSize(width: 64, height: 40)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    dot(for: .topLeft)
                    Spacer(minLength: 0)
                    dot(for: .topRight)
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    dot(for: .bottomLeft)
                    Spacer(minLength: 0)
                    dot(for: .bottomRight)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func dot(for position: OverlayPosition) -> some View {
        let isSelected = selection == position
        return Button {
            selection = position
        } label: {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                .frame(width: isSelected ? 14 : 8, height: isSelected ? 14 : 8)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(position.title)
    }
}
