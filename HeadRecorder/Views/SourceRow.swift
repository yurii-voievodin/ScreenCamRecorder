import SwiftUI

struct SourceRow<Content: View>: View {
    let icon: String
    let help: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            content
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(help)
    }
}
