import SwiftUI
import AppKit

struct StatusRow: View {
    let isRecording: Bool
    let statusText: String
    let lastRecordingURL: URL?
    let exportProgress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                        Label {
                            Text(.showInFinder)
                        } icon: {
                            Image(systemName: "folder")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .layoutPriority(1)
                }
            }

            if let exportProgress {
                ProgressView(value: exportProgress)
                    .progressViewStyle(.linear)
            }
        }
    }
}
