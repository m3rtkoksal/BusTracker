import CoreMotion
import Foundation

enum MotionActivityRole: String {
    case driver
    case passenger
}

/// Hareket sensörü — araçta mı? (konum paylaşımı olmadan özet).
@MainActor
@Observable
final class MotionActivityService {
    static let shared = MotionActivityService()

    private(set) var isMonitoring = false
    private(set) var isAuthorized = false
    private(set) var authorizationStatus: CMAuthorizationStatus = .notDetermined

    private let manager = CMMotionActivityManager()
    private let uploadIntervalSeconds: TimeInterval = 45
    private let segmentRetentionSeconds: TimeInterval = 8 * 60

    private var role: MotionActivityRole?
    private var groupID: String?
    private var memberID: String?
    private var store: ShuttleStore?

    private var openAutomotiveStartedAt: Date?
    private var segments: [MotionActivitySegment] = []
    private var uploadLoopTask: Task<Void, Never>?
    private var permissionProbeActive = false

    private init() {}

    /// CMMotionActivityManager ile canlı aktivite takibi mümkün mü?
    var isAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    /// Hareket & Fitness izni istenebilir mi? (Activity veya Pedometer)
    var canRequestAuthorization: Bool {
        isAvailable || CMPedometer.isStepCountingAvailable()
    }

    func updateMonitoring(
        isEnabled: Bool,
        role: MotionActivityRole,
        groupID: String,
        memberID: String,
        store: ShuttleStore
    ) {
        guard isEnabled, !groupID.isEmpty, !memberID.isEmpty else {
            stopMonitoring()
            return
        }

        if isMonitoring,
           self.role == role,
           self.groupID == groupID,
           self.memberID == memberID {
            return
        }

        stopMonitoring()
        self.role = role
        self.groupID = groupID
        self.memberID = memberID
        self.store = store
        startMonitoring()
    }

    func stopMonitoring() {
        uploadLoopTask?.cancel()
        uploadLoopTask = nil
        if isMonitoring || permissionProbeActive {
            manager.stopActivityUpdates()
        }
        permissionProbeActive = false
        isMonitoring = false
        openAutomotiveStartedAt = nil
        segments = []
        role = nil
        groupID = nil
        memberID = nil
        store = nil
    }

    func refreshAuthorization() {
        guard canRequestAuthorization else {
            authorizationStatus = .notDetermined
            isAuthorized = false
            return
        }
        if #available(iOS 11.0, *) {
            authorizationStatus = CMMotionActivityManager.authorizationStatus()
            isAuthorized = authorizationStatus == .authorized
        } else {
            authorizationStatus = .authorized
            isAuthorized = true
        }
    }

    /// Sistem diyaloğunu tetikler ve kullanıcı yanıtını bekler.
    func requestAuthorizationIfNeeded() async {
        refreshAuthorization()
        guard authorizationStatus == .notDetermined else { return }
        guard canRequestAuthorization else { return }

        let triggered = await triggerSystemAuthorizationPrompt()
        guard triggered else { return }

        await waitUntilAuthorizationDetermined(timeout: 60)
        stopPermissionProbeIfNeeded()
        refreshAuthorization()
    }

    private func triggerSystemAuthorizationPrompt() async -> Bool {
        if isAvailable {
            permissionProbeActive = true
            manager.startActivityUpdates(to: OperationQueue.main) { _ in }
            try? await Task.sleep(for: .milliseconds(350))
            return true
        }

        if CMPedometer.isStepCountingAvailable() {
            let pedometer = CMPedometer()
            await withCheckedContinuation { continuation in
                pedometer.queryPedometerData(
                    from: Date().addingTimeInterval(-3600),
                    to: Date()
                ) { _, _ in
                    continuation.resume()
                }
            }
            return true
        }

        return false
    }

    private func waitUntilAuthorizationDetermined(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            refreshAuthorization()
            if authorizationStatus != .notDetermined { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func stopPermissionProbeIfNeeded() {
        guard permissionProbeActive, !isMonitoring else { return }
        manager.stopActivityUpdates()
        permissionProbeActive = false
    }

    private func startMonitoring() {
        guard isAvailable else { return }
        refreshAuthorization()
        guard isAuthorized else { return }

        manager.queryActivityStarting(
            from: Date().addingTimeInterval(-60),
            to: Date(),
            to: OperationQueue.main
        ) { [weak self] activities, _ in
            Task { @MainActor in
                guard let self, let last = activities?.last else { return }
                self.applyActivity(last)
            }
        }

        manager.startActivityUpdates(to: OperationQueue.main) { [weak self] activity in
            Task { @MainActor in
                guard let self, let activity else { return }
                self.applyActivity(activity)
            }
        }

        isMonitoring = true
        startUploadLoop()
    }

    private func applyActivity(_ activity: CMMotionActivity) {
        let automotive = Self.isAutomotive(activity)
        let now = Date()

        if automotive {
            if openAutomotiveStartedAt == nil {
                openAutomotiveStartedAt = now
            }
        } else if let started = openAutomotiveStartedAt {
            segments.append(MotionActivitySegment(startedAt: started, endedAt: now, isAutomotive: true))
            openAutomotiveStartedAt = nil
        }

        pruneSegments(now: now)
    }

    private static func isAutomotive(_ activity: CMMotionActivity) -> Bool {
        activity.automotive && !activity.stationary
    }

    private func pruneSegments(now: Date) {
        let cutoff = now.addingTimeInterval(-segmentRetentionSeconds)
        segments = segments.filter { $0.endedAt >= cutoff }
    }

    private func startUploadLoop() {
        uploadLoopTask?.cancel()
        uploadLoopTask = Task {
            await uploadSnapshot()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(uploadIntervalSeconds))
                guard !Task.isCancelled else { break }
                await uploadSnapshot()
            }
        }
    }

    private func uploadSnapshot() async {
        guard let role, let groupID, let memberID, let store else { return }

        let now = Date()
        pruneSegments(now: now)

        var workingSegments = segments
        if let openStart = openAutomotiveStartedAt {
            workingSegments.append(
                MotionActivitySegment(startedAt: openStart, endedAt: now, isAutomotive: true)
            )
        }

        let automotiveSeconds = workingSegments
            .filter(\.isAutomotive)
            .reduce(0.0) { partial, segment in
                partial + segment.endedAt.timeIntervalSince(segment.startedAt)
            }

        try? await store.uploadMotionActivitySnapshot(
            groupID: groupID,
            role: role,
            memberID: memberID,
            automotiveSecondsInWindow: Int(automotiveSeconds.rounded()),
            segments: workingSegments
        )
    }
}

struct MotionActivitySegment: Equatable {
    let startedAt: Date
    let endedAt: Date
    let isAutomotive: Bool
}
