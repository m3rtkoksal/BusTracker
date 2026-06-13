import SwiftUI

struct TopToastBanner: View {
    let popup: PopupPresentation
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: popup.style.iconName)
                .foregroundStyle(popup.style.tint)
            VStack(alignment: .leading, spacing: 2) {
                if !popup.title.isEmpty {
                    Text(popup.title)
                        .font(.subheadline.weight(.semibold))
                }
                Text(popup.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
