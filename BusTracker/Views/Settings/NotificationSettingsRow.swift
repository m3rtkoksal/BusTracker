import SwiftUI
import UserNotifications

#if os(iOS) || os(visionOS)
import UIKit
#endif

/// Ayarlar sekmesinde bildirim durumu (yeşil toggle) + izin / sistem ayarları.
struct NotificationSettingsRow: View {
    @State private var statusLabel = L10n.loadingEllipsis
    @State private var isEnabled = false
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.notifications.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(NeonTheme.onSurfaceVariant)

                Spacer()

                Toggle("", isOn: notificationToggleBinding)
                    .labelsHidden()
                    .tint(NeonTheme.secondary)
            }
            .padding(16)
            .background(NeonTheme.surfaceContainer)
            .overlay {
                Rectangle()
                    .strokeBorder(NeonTheme.outline.opacity(0.3), lineWidth: 1)
            }

            if showsHelperLink {
                Button(action: openSystemOrRequest) {
                    Text(helperLinkTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NeonTheme.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
        }
        .task { await refresh() }
#if os(iOS) || os(visionOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refresh() }
        }
#endif
    }

    private var showsHelperLink: Bool {
        authorizationStatus == .denied || authorizationStatus == .notDetermined
    }

    private var helperLinkTitle: String {
        switch authorizationStatus {
        case .notDetermined: L10n.notificationsTapToEnable
        case .denied: L10n.notificationsOffOpenSettings
        default: ""
        }
    }

    private var notificationToggleBinding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { wantsOn in
                Task {
                    if wantsOn {
                        await enableNotifications()
                    } else {
                        NotificationService.shared.openSystemSettings()
                    }
                    await refresh()
                }
            }
        )
    }

    private func openSystemOrRequest() {
        Task {
            if authorizationStatus == .notDetermined {
                await NotificationService.shared.requestPermissionIfNeeded()
            } else {
                NotificationService.shared.openSystemSettings()
            }
            await refresh()
        }
    }

    private func enableNotifications() async {
        switch authorizationStatus {
        case .notDetermined:
            await NotificationService.shared.requestPermissionIfNeeded()
        case .denied:
            NotificationService.shared.openSystemSettings()
        default:
            break
        }
    }

    private func refresh() async {
        let snapshot = await NotificationService.shared.authorizationSnapshot()
        authorizationStatus = snapshot.status
        isEnabled = snapshot.isEnabled
        statusLabel = snapshot.isEnabled ? L10n.notificationsOn : snapshot.label
    }
}
