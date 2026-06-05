import CoreMotion
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Açılış izinleri: yolcu → (harita sekmesinde konum; bildirim/hareket aksiyon zincirinde);
/// sürücü → yalnızca bildirim. Sürücü konum/hareket → Servisi başlat bottom sheet zinciri.
struct AppPermissionsHandlerModifier: ViewModifier {
    var enabled: Bool = true
    let profile: UserProfile?
    let notificationsOnly: Bool

    @Environment(LocationTracker.self) private var locationTracker

    @State private var cycleToken = 0
    @State private var flowBusy = false
    @State private var showNotificationGuide = false
    @State private var notificationGuidePhase: DriverNotificationGuidePhase = .guide
    @State private var notificationGuidePresentationTask: Task<Void, Never>?

    private var isDriverNotificationLaunchOnly: Bool {
        notificationsOnly && profile?.role == .driver
    }

    private var taskKey: String {
        "\(enabled)-\(profile?.memberID ?? "guest")-\(notificationsOnly)-\(cycleToken)"
    }

    func body(content: Content) -> some View {
        content
            .task(id: taskKey) {
                guard enabled else { return }
                await runSinglePermissionStep()
            }
            .overlay {
                ZStack(alignment: .bottom) {
                    if showNotificationGuide {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .onTapGesture { dismissNotificationGuide() }

                        DriverNotificationGuideSheet(
                            phase: notificationGuidePhase,
                            onOpenSettings: {
                                notificationGuidePhase = .waitingSettingsReturn
                                NotificationService.shared.openSystemSettings()
                            },
                            onDismiss: dismissNotificationGuide
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: showNotificationGuide)
                .allowsHitTesting(showNotificationGuide)
                .ignoresSafeArea(edges: .bottom)
            }
#if canImport(UIKit)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification
                )
            ) { _ in
                guard enabled else { return }
                if !isDriverNotificationLaunchOnly {
                    locationTracker.refreshAuthorizationStatus()
                }
                Task { @MainActor in
                    await refreshNotificationGuideAfterSettingsReturn()
                }
                resumePermissionFlow()
            }
            .onChange(of: locationTracker.authorizationStatus) { old, new in
                guard enabled else { return }
                guard !isDriverNotificationLaunchOnly else { return }
                guard old != new else { return }
                locationTracker.refreshAuthorizationStatus()
                resumePermissionFlow()
            }
#endif
    }

    private func resumePermissionFlow() {
        Task { @MainActor in
            guard enabled else { return }
            guard !isDriverNotificationLaunchOnly else { return }
            for _ in 0..<8 {
                locationTracker.refreshAuthorizationStatus()
                let locationReady: Bool
                if profile?.role == .driver {
                    locationReady = locationTracker.canDriverStartTrip
                } else {
                    locationReady = locationTracker.hasWhenInUseAuthorization
                }
                if locationReady { break }
                try? await Task.sleep(for: .milliseconds(250))
            }
            try? await Task.sleep(for: .milliseconds(400))
            flowBusy = false
            cycleToken += 1
        }
    }

    @MainActor
    private func runSinglePermissionStep() async {
        guard !flowBusy else { return }

        switch await nextMissingStep() {
        case .location:
            await promptLocationOnly()
        case .motion:
            await promptMotionOnly()
        case .notifications:
            await promptNotificationsOnly()
        case .done:
            await syncNotificationTokenIfPossible()
            flowBusy = false
        }
    }

    @MainActor
    private func nextMissingStep() async -> PermissionStep {
        let isPassenger = profile?.role == .passenger

        if !notificationsOnly, !isPassenger {
            locationTracker.refreshAuthorizationStatus()
            if PermissionPromptSession.mayPromptLocation, needsLocationPrompt {
                return .location
            }

            let motion = MotionActivityService.shared
            if motion.canRequestAuthorization {
                motion.refreshAuthorization()
                if PermissionPromptSession.mayPromptMotion,
                   motion.authorizationStatus == .notDetermined {
                    return .motion
                }
            }
        }

        NotificationService.shared.configure()
        let snapshot = await NotificationService.shared.authorizationSnapshot()
        if !snapshot.isEnabled,
           PermissionPromptSession.mayPromptNotifications,
           let profile,
           profile.role != .passenger {
            return .notifications
        }
        return .done
    }

    private var needsLocationPrompt: Bool {
        switch locationTracker.authorizationStatus {
        case .notDetermined:
            return true
        case .authorizedWhenInUse:
            return profile?.role == .driver && !locationTracker.canDriverStartTrip
        case .denied, .restricted, .authorizedAlways:
            return false
        @unknown default:
            return false
        }
    }

    @MainActor
    private func promptLocationOnly() async {
        PermissionPromptSession.markLocationPromptHandled()
        flowBusy = true
        locationTracker.refreshAuthorizationStatus()

        if profile?.role == .driver {
            await promptDriverLocationAlways()
            return
        }

        switch locationTracker.authorizationStatus {
        case .notDetermined:
            locationTracker.requestWhenInUsePermissionIfNeeded()
        default:
            flowBusy = false
        }
    }

    @MainActor
    private func promptDriverLocationAlways() async {
        switch locationTracker.authorizationStatus {
        case .notDetermined, .authorizedWhenInUse:
            locationTracker.requestDriverAlwaysPermissionIfNeeded()
            _ = await locationTracker.waitForDriverAlwaysAuthorization(maxWaitSeconds: 30.0)
            flowBusy = false
            if locationTracker.canDriverStartTrip {
                resumePermissionFlow()
            }
        case .authorizedAlways:
            flowBusy = false
            resumePermissionFlow()
        default:
            flowBusy = false
        }
    }

    @MainActor
    private func promptMotionOnly() async {
        PermissionPromptSession.markMotionPromptHandled()
        flowBusy = true
        let motion = MotionActivityService.shared
        guard motion.canRequestAuthorization else {
            flowBusy = false
            resumePermissionFlow()
            return
        }
        motion.refreshAuthorization()

        switch motion.authorizationStatus {
        case .authorized:
            flowBusy = false
            resumePermissionFlow()
        case .notDetermined:
            await motion.requestAuthorizationIfNeeded()
            flowBusy = false
            if motion.authorizationStatus == .authorized {
                resumePermissionFlow()
            }
        default:
            flowBusy = false
        }
    }

    @MainActor
    private func promptNotificationsOnly() async {
        guard profile?.role != .passenger else {
            PermissionPromptSession.markNotificationPromptHandled()
            flowBusy = false
            return
        }

        flowBusy = true
        NotificationService.shared.configure()
        let snapshot = await NotificationService.shared.authorizationSnapshot()
        if snapshot.isEnabled {
            PermissionPromptSession.markNotificationPromptHandled()
            await syncNotificationTokenIfPossible()
            flowBusy = false
            return
        }

        if snapshot.status == .notDetermined {
            await NotificationService.shared.requestPermissionAndRegister()
            let updated = await NotificationService.shared.authorizationSnapshot()
            PermissionPromptSession.markNotificationPromptHandled()
            flowBusy = false
            if updated.isEnabled {
                await syncNotificationTokenIfPossible()
            } else if updated.status != .notDetermined {
                presentNotificationGuide(deferred: true)
            }
        } else {
            presentNotificationGuide(deferred: false)
            PermissionPromptSession.markNotificationPromptHandled()
            flowBusy = false
        }
    }

    @MainActor
    private func presentNotificationGuide(deferred: Bool) {
        cancelNotificationGuidePresentation()
        guard deferred else {
            notificationGuidePhase = .guide
            withAnimation(.easeInOut(duration: 0.28)) {
                showNotificationGuide = true
            }
            return
        }

        notificationGuidePresentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            notificationGuidePhase = .guide
            withAnimation(.easeInOut(duration: 0.28)) {
                showNotificationGuide = true
            }
        }
    }

    @MainActor
    private func cancelNotificationGuidePresentation() {
        notificationGuidePresentationTask?.cancel()
        notificationGuidePresentationTask = nil
    }

    @MainActor
    private func dismissNotificationGuide() {
        cancelNotificationGuidePresentation()
        notificationGuidePhase = .guide
        withAnimation(.easeInOut(duration: 0.28)) {
            showNotificationGuide = false
        }
    }

    @MainActor
    private func refreshNotificationGuideAfterSettingsReturn() async {
        guard showNotificationGuide else { return }
        let snapshot = await NotificationService.shared.authorizationSnapshot()
        guard snapshot.isEnabled else { return }
        dismissNotificationGuide()
        await syncNotificationTokenIfPossible()
    }

    @MainActor
    private func syncNotificationTokenIfPossible() async {
        guard let profile else { return }
        let groupID = profile.primaryGroupID.isEmpty
            ? (profile.groupID ?? "")
            : profile.primaryGroupID
        guard !groupID.isEmpty else { return }
        await NotificationService.shared.saveTokenToProfile(
            groupID: groupID,
            memberID: profile.memberID
        )
    }
}

private enum PermissionStep {
    case location
    case motion
    case notifications
    case done
}

extension View {
    func appPermissionsHandler(
        profile: UserProfile?,
        notificationsOnly: Bool = false,
        enabled: Bool = true
    ) -> some View {
        modifier(AppPermissionsHandlerModifier(
            enabled: enabled,
            profile: profile,
            notificationsOnly: notificationsOnly
        ))
    }
}
