import Foundation

/// Process başına sürücü/kayıt bildirimi en fazla bir kez; yolcu aksiyonları ayrı akışta sorulur.
enum PermissionPromptSession {
    private(set) static var locationPromptHandledThisLaunch = false
    private(set) static var motionPromptHandledThisLaunch = false
    private(set) static var notificationPromptHandledThisLaunch = false

    static var mayPromptLocation: Bool { !locationPromptHandledThisLaunch }
    static var mayPromptMotion: Bool { !motionPromptHandledThisLaunch }
    static var mayPromptNotifications: Bool { !notificationPromptHandledThisLaunch }

    static func markLocationPromptHandled() {
        locationPromptHandledThisLaunch = true
    }

    static func markMotionPromptHandled() {
        motionPromptHandledThisLaunch = true
    }

    static func markNotificationPromptHandled() {
        notificationPromptHandledThisLaunch = true
    }
}
