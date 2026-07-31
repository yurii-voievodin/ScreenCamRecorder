import SwiftUI
import AppKit

struct StatusRow: View {
    let isRecording: Bool
    let statusText: String
    let lastRecordingURL: URL?

    var body: some View {
        HStack(spacing: 6) {
            Label {
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } icon: {
                Image(systemName: isRecording ? "record.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isRecording ? .red : .secondary)
            }

            Spacer(minLength: 8)

            if let lastRecordingURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
                } label: {
                    Label("Показати у Finder", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .layoutPriority(1)
            }
        }
    }
}
