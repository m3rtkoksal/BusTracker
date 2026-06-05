import FirebaseAnalytics

/// Firebase Analytics — PII/konum yok; yolcu + sürücü ürün olayları.
enum BusTrackerAnalytics {

    static func attendanceSelected(status: String) {
        log("attendance_selected", ["status": status])
    }

    static func pickupSaved() {
        log("pickup_saved")
    }

    static func holidayModeSaved() {
        log("holiday_mode_saved")
    }

    static func holidayModeEnded() {
        log("holiday_mode_ended")
    }

    static func sparseModePrompt(action: String) {
        log("sparse_mode_prompt", ["action": action])
    }

    static func tripStarted(durationHours: Double) {
        log("trip_started", ["duration_hours": durationHours])
    }

    private static func log(_ name: String, _ params: [String: Any] = [:]) {
        Analytics.setAnalyticsCollectionEnabled(true)
        Analytics.logEvent(name, parameters: params.isEmpty ? nil : params)
        #if DEBUG
        if params.isEmpty {
            print("📊 [Analytics] \(name)")
        } else {
            print("📊 [Analytics] \(name) \(params)")
        }
        #endif
    }
}
