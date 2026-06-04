import FirebaseFirestore
import Foundation

/// Yolcunun açık yoklama seçimlerini (Geliyorum / Gelmiyorum) yerelde tutar.
enum AttendanceUsageTracker {
    private static let retainDays = 90

    struct WindowStats {
        var coming: Int
        var notComing: Int
        var explicit: Int { coming + notComing }
    }

    private struct Entry: Codable {
        let dateKey: String
        let status: String
    }

    static func record(memberID: String, dateKey: String, status: AttendanceStatus) {
        guard !memberID.isEmpty, !dateKey.isEmpty else { return }
        guard status == .coming || status == .notComing else { return }

        var entries = loadEntries(memberID: memberID)
        if let index = entries.firstIndex(where: { $0.dateKey == dateKey }) {
            entries[index] = Entry(dateKey: dateKey, status: status.rawValue)
        } else {
            entries.append(Entry(dateKey: dateKey, status: status.rawValue))
        }
        saveEntries(prune(entries, reference: Date()), memberID: memberID)
    }

    static func statsForWindowWithFirestoreSync(
        groupID: String,
        memberID: String,
        windowDays: Int,
        reference: Date = Date()
    ) async -> WindowStats {
        if !groupID.isEmpty {
            await syncFromFirestore(groupID: groupID, memberID: memberID, windowDays: windowDays)
        }
        return statsForWindow(memberID: memberID, windowDays: windowDays, reference: reference)
    }

    private static func syncFromFirestore(groupID: String, memberID: String, windowDays: Int) async {
        let db = Firestore.firestore()
        for dateKey in SparseModeSuggestion.dateKeysForWindow(windowDays) {
            let snapshot: DocumentSnapshot
            do {
                snapshot = try await db.collection("groups").document(groupID)
                    .collection("attendance").document(dateKey)
                    .getDocument()
            } catch {
                continue
            }
            guard snapshot.exists,
                  let responses = snapshot.data()?["responses"] as? [String: [String: Any]],
                  let member = responses[memberID],
                  let statusRaw = member["status"] as? String,
                  let status = AttendanceStatus(rawValue: statusRaw),
                  status == .coming || status == .notComing
            else { continue }
            record(memberID: memberID, dateKey: dateKey, status: status)
        }
    }

    static func statsForWindow(memberID: String, windowDays: Int, reference: Date = Date()) -> WindowStats {
        guard !memberID.isEmpty else { return WindowStats(coming: 0, notComing: 0) }

        let entries = prune(loadEntries(memberID: memberID), reference: reference)
        let cutoff = startOfWindow(reference: reference, windowDays: windowDays)

        var coming = 0
        var notComing = 0
        for entry in entries {
            guard let day = HolidayMode.date(fromKey: entry.dateKey)?.timeIntervalSince1970 else { continue }
            if day < cutoff { continue }
            switch AttendanceStatus(rawValue: entry.status) {
            case .coming: coming += 1
            case .notComing: notComing += 1
            default: break
            }
        }
        return WindowStats(coming: coming, notComing: notComing)
    }

    private static func entriesKey(_ memberID: String) -> String { "entries_\(memberID)" }

    private static func loadEntries(memberID: String) -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: entriesKey(memberID)) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private static func saveEntries(_ entries: [Entry], memberID: String) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: entriesKey(memberID))
    }

    private static func prune(_ entries: [Entry], reference: Date) -> [Entry] {
        let cutoff = startOfWindow(reference: reference, windowDays: retainDays)
        return entries.filter { entry in
            guard let day = HolidayMode.date(fromKey: entry.dateKey)?.timeIntervalSince1970 else { return false }
            return day >= cutoff
        }
    }

    private static func startOfWindow(reference: Date, windowDays: Int) -> TimeInterval {
        let endDate = HolidayMode.date(fromKey: HolidayMode.dateKey(from: reference)) ?? reference
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        cal.locale = Locale(identifier: "tr_TR")
        let start = cal.date(byAdding: .day, value: -(windowDays - 1), to: cal.startOfDay(for: endDate)) ?? endDate
        return start.timeIntervalSince1970
    }
}
