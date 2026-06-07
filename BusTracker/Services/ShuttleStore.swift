import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import Foundation

enum ShuttleStoreError: LocalizedError {
    case notAuthenticated
    case groupNotFound
    case alreadyInGroup
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: L10n.signInRequired
        case .groupNotFound: L10n.shuttleCodeNotFound
        case .alreadyInGroup: L10n.alreadyInShuttle
        case .invalidInput(let message): message
        }
    }
}

@MainActor
@Observable
final class ShuttleStore {
    var members: [ShuttleMember] = []
    var driverLocation: DriverLocation?
    var driverRoute: [CLLocationCoordinate2D] = []
    var morningPickups: [MorningPickup] = []
    var isTripActive = false
    var isLoading = false
    var errorMessage: String?

    private var db: Firestore { Firestore.firestore() }
    private var membersListener: ListenerRegistration?
    private var locationListener: ListenerRegistration?
    private var routeListener: ListenerRegistration?
    private var attendanceListeners: [String: ListenerRegistration] = [:]
    private var morningPickupsListener: ListenerRegistration?
    private var locationUploadTask: Task<Void, Never>?
    private var latestAttendanceResponses: [String: [String: Any]] = [:]
    private var attendanceResponsesByDate: [String: [String: [String: Any]]] = [:]
    private var activeTripGroupID: String?
    private var activeTripDriverName: String?
    private var lastLocationUploadAt: Date?
    private var lastAppendedRoutePoint: CLLocationCoordinate2D?
    private var lastDriverTelemetryLocation: CLLocation?
    private var pickupReachLoggedMemberIDs: Set<String> = []
    private static let pickupReachRadiusMeters: CLLocationDistance = 120
    private var tripAutoStopTask: Task<Void, Never>?
    private static let minRoutePointDistanceMeters: CLLocationDistance = 20
    private(set) var plannedTripEndAt: Date?
    private(set) var attendanceRevision = 0

    private var todayKey: String {
        HolidayMode.dateKey(from: Date())
    }

    func startListening(groupID: String) {
        stopListening()

        Task { @MainActor in
            do {
                try await FirebaseSession.shared.ensureAuthenticated()
            } catch {
                errorMessage = error.localizedDescription
                return
            }

            membersListener = db.collection("groups").document(groupID).collection("members")
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error {
                            self.errorMessage = error.localizedDescription
                            return
                        }
                        let fetched = snapshot?.documents.compactMap { Self.member(from: $0) } ?? []
                        self.mergeMembers(fetched)
                    }
                }

            locationListener = db.collection("groups").document(groupID).collection("live").document("current")
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error {
                            self.errorMessage = error.localizedDescription
                            return
                        }
                        let data = snapshot?.data()
                        self.isTripActive = data?["isActive"] as? Bool ?? false
                        self.driverLocation = Self.driverLocation(from: snapshot)
                    }
                }

            routeListener = db.collection("groups").document(groupID).collection("live").document("route")
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error {
                            self.errorMessage = error.localizedDescription
                            return
                        }
                        self.driverRoute = Self.routePoints(from: snapshot?.data())
                    }
                }

            startAttendanceListeners(groupID: groupID)

            morningPickupsListener = db.collection("groups").document(groupID)
                .collection("morningPickups")
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error {
                            self.errorMessage = error.localizedDescription
                            return
                        }
                        self.morningPickups = snapshot?.documents.compactMap { Self.morningPickup(from: $0) } ?? []
                    }
                }
        }
    }

    private func listenAttendance(groupID: String, dateKey: String) -> ListenerRegistration {
        db.collection("groups").document(groupID)
            .collection("attendance").document(dateKey)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.onAttendanceSnapshot(dateKey: dateKey, data: snapshot?.data())
                }
            }
    }

    /// Gerekli tüm attendance dateKey'leri için listener açar
    private func startAttendanceListeners(groupID: String) {
        stopAttendanceListeners()

        var dateKeysToListen: Set<String> = []

        // Yolcu için: sonraki 2 servis
        let nextServices = ServiceSchedule.nextTwoServices()
        for service in nextServices {
            dateKeysToListen.insert(service.dateKey)
        }

        // Sürücü için: şu anki servis
        let driverService = ServiceSchedule.currentDriverSession()
        dateKeysToListen.insert(driverService.dateKey)

        // Bugün sabah ve akşam (her zaman dinle)
        let (todayAm, todayPm) = ServiceSchedule.todayDateKeys()
        dateKeysToListen.insert(todayAm)
        dateKeysToListen.insert(todayPm)

        for dateKey in dateKeysToListen {
            attendanceListeners[dateKey] = listenAttendance(groupID: groupID, dateKey: dateKey)
        }
    }

    private func stopAttendanceListeners() {
        for (_, listener) in attendanceListeners {
            listener.remove()
        }
        attendanceListeners.removeAll()
    }

    func stopListening() {
        membersListener?.remove()
        locationListener?.remove()
        routeListener?.remove()
        stopAttendanceListeners()
        morningPickupsListener?.remove()
        membersListener = nil
        locationListener = nil
        routeListener = nil
        morningPickupsListener = nil
        attendanceResponsesByDate = [:]
        morningPickups = []
        driverRoute = []
        lastAppendedRoutePoint = nil
        locationUploadTask?.cancel()
        locationUploadTask = nil
        tripAutoStopTask?.cancel()
        tripAutoStopTask = nil
        plannedTripEndAt = nil
        isTripActive = false
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile? {
        try await FirebaseSession.shared.ensureAuthenticated()

        let doc = try await db.collection("users").document(userID).getDocument()
        guard let data = doc.data() else { return nil }

        return Self.userProfile(from: data, userID: userID)
    }

    func isUserProfileDeleted(userID: String) async -> Bool {
        do {
            return try await fetchUserProfile(userID: userID) == nil
        } catch {
            return false
        }
    }

    func createGroup(name: String, driverName: String) async throws -> UserProfile {
        try await FirebaseSession.shared.ensureAuthenticated()
        guard let user = Auth.auth().currentUser else { throw ShuttleStoreError.notAuthenticated }
        let appleUserID = try requireAppleUserID(from: user)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDriver = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ShuttleStoreError.invalidInput(L10n.serviceNameEmpty) }
        guard !trimmedDriver.isEmpty else { throw ShuttleStoreError.invalidInput(L10n.nameEmpty) }

        if try await fetchUserProfile(userID: user.uid) != nil {
            throw ShuttleStoreError.alreadyInGroup
        }

        isLoading = true
        defer { isLoading = false }

        let groupID = UUID().uuidString
        let memberID = user.uid
        let code = Self.generateGroupCode()

        let groupRef = db.collection("groups").document(groupID)
        try await groupRef.setData([
            "name": trimmedName,
            "code": code,
            "driverMemberID": memberID,
            "createdAt": FieldValue.serverTimestamp()
        ])

        try await groupRef.collection("members").document(memberID).setData([
            "userID": user.uid,
            "name": trimmedDriver,
            "appleUserID": appleUserID,
            "role": MemberRole.driver.rawValue,
            "joinedAt": FieldValue.serverTimestamp()
        ])

        let profile = UserProfile(
            userID: user.uid,
            memberID: memberID,
            name: trimmedDriver,
            appleUserID: appleUserID,
            role: .driver,
            groupIDs: [groupID],
            activeGroupIDs: [groupID],
            groupID: groupID,
            groupCode: code,
            groupName: trimmedName
        )

        try await saveUserDocument(profile)
        return profile
    }

    /// Davet kodundaki serviste yolcu zaten kayıtlı mı?
    func passengerIsMember(ofServiceCode code: String, profile: UserProfile) async -> Bool {
        guard profile.role == .passenger,
              let groupID = await groupID(forServiceCode: code) else { return false }
        var memberGroupIDs = profile.groupIDs
        if memberGroupIDs.isEmpty, let legacy = profile.groupID, !legacy.isEmpty {
            memberGroupIDs = [legacy]
        }
        return memberGroupIDs.contains(groupID)
    }

    private func groupID(forServiceCode code: String) async -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count >= 4 else { return nil }
        do {
            let snapshot = try await db.collection("groups")
                .whereField("code", isEqualTo: trimmed)
                .limit(to: 1)
                .getDocuments()
            return snapshot.documents.first?.documentID
        } catch {
            return nil
        }
    }

    /// Yolcu kaydı: kod Firestore'da var mı (Apple oturumu açıldıktan sonra).
    func resolveGroupID(forCode code: String) async throws -> String? {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmedCode.count >= 4 else { return nil }
        let snapshot = try await db.collection("groups")
            .whereField("code", isEqualTo: trimmedCode)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.first?.documentID
    }

    func validatePassengerGroupCode(_ code: String) async throws {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmedCode.isEmpty {
            throw ShuttleStoreError.invalidInput(L10n.enterServiceCode)
        }
        if trimmedCode.count < 4 {
            throw ShuttleStoreError.invalidInput(L10n.serviceCodeMinLength)
        }
        let snapshot = try await db.collection("groups")
            .whereField("code", isEqualTo: trimmedCode)
            .limit(to: 1)
            .getDocuments()
        if snapshot.documents.isEmpty {
            throw ShuttleStoreError.groupNotFound
        }
    }

    func joinGroup(code: String, passengerName: String) async throws -> UserProfile {
        try await FirebaseSession.shared.ensureAuthenticated()
        guard let user = Auth.auth().currentUser else { throw ShuttleStoreError.notAuthenticated }
        let appleUserID = try requireAppleUserID(from: user)

        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedName = passengerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.count >= 4 else { throw ShuttleStoreError.invalidInput(L10n.serviceCodeMinLength) }
        guard !trimmedName.isEmpty else { throw ShuttleStoreError.invalidInput(L10n.nameEmpty) }

        if try await fetchUserProfile(userID: user.uid) != nil {
            throw ShuttleStoreError.alreadyInGroup
        }

        isLoading = true
        defer { isLoading = false }

        let snapshot = try await db.collection("groups")
            .whereField("code", isEqualTo: trimmedCode)
            .limit(to: 1)
            .getDocuments()

        guard let groupDoc = snapshot.documents.first else {
            throw ShuttleStoreError.groupNotFound
        }

        let memberID = user.uid
        let groupData = groupDoc.data()
        let groupName = groupData["name"] as? String ?? L10n.service
        let groupCode = groupData["code"] as? String ?? trimmedCode

        try await groupDoc.reference.collection("members").document(memberID).setData([
            "userID": user.uid,
            "name": trimmedName,
            "appleUserID": appleUserID,
            "role": MemberRole.passenger.rawValue,
            "joinedAt": FieldValue.serverTimestamp()
        ])

        let profile = UserProfile(
            userID: user.uid,
            memberID: memberID,
            name: trimmedName,
            appleUserID: appleUserID,
            role: .passenger,
            groupIDs: [groupDoc.documentID],
            activeGroupIDs: [groupDoc.documentID],
            groupID: groupDoc.documentID,
            groupCode: groupCode,
            groupName: groupName
        )

        try await saveUserDocument(profile)
        return profile
    }

    /// Kayıtlı yolcu: servis kodu ile ek servise katılır ve o servisi aktif yapar.
    func joinAdditionalGroup(code: String, currentProfile: UserProfile) async throws -> UserProfile {
        try await FirebaseSession.shared.ensureAuthenticated()
        guard let user = Auth.auth().currentUser else { throw ShuttleStoreError.notAuthenticated }
        guard currentProfile.role == .passenger else {
            throw ShuttleStoreError.invalidInput(L10n.passengersOnlyCanAddShuttle)
        }

        let appleUserID = try requireAppleUserID(from: user)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmedCode.count >= 4 else {
            throw ShuttleStoreError.invalidInput(L10n.serviceCodeMinLength)
        }

        var existingGroupIDs = currentProfile.groupIDs
        if existingGroupIDs.isEmpty, let legacy = currentProfile.groupID, !legacy.isEmpty {
            existingGroupIDs = [legacy]
        }

        isLoading = true
        defer { isLoading = false }

        let snapshot = try await db.collection("groups")
            .whereField("code", isEqualTo: trimmedCode)
            .limit(to: 1)
            .getDocuments()

        guard let groupDoc = snapshot.documents.first else {
            throw ShuttleStoreError.groupNotFound
        }

        let newGroupID = groupDoc.documentID
        if existingGroupIDs.contains(newGroupID) {
            throw ShuttleStoreError.invalidInput(L10n.alreadyRegisteredForShuttle)
        }

        let groupData = groupDoc.data()
        let groupName = groupData["name"] as? String ?? L10n.service
        let groupCode = groupData["code"] as? String ?? trimmedCode
        let passengerName = currentProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)

        try await groupDoc.reference.collection("members").document(user.uid).setData([
            "userID": user.uid,
            "name": passengerName,
            "appleUserID": appleUserID,
            "role": MemberRole.passenger.rawValue,
            "joinedAt": FieldValue.serverTimestamp()
        ], merge: true)

        let mergedGroupIDs = existingGroupIDs + [newGroupID]
        let profile = UserProfile(
            userID: user.uid,
            memberID: user.uid,
            name: passengerName,
            appleUserID: appleUserID,
            role: .passenger,
            groupIDs: mergedGroupIDs,
            activeGroupIDs: [newGroupID],
            groupID: newGroupID,
            groupCode: groupCode,
            groupName: groupName
        )

        try await saveUserDocument(profile)
        return profile
    }

    func startTrip(
        groupID: String,
        driverName: String,
        durationHours: Double,
        locationTracker: LocationTracker
    ) async throws {
        guard !isTripActive else { return }
        guard durationHours > 0 else {
            throw ShuttleStoreError.invalidInput(L10n.selectTripDuration)
        }
        guard locationTracker.canDriverStartTrip else {
            throw ShuttleStoreError.invalidInput(L10n.alwaysLocationRequiredInSettings)
        }
        try await FirebaseSession.shared.ensureAuthenticated()

        let endsAt = Date().addingTimeInterval(durationHours * 3600)
        plannedTripEndAt = endsAt

        try await db.collection("groups").document(groupID).collection("tripEvents").addDocument(data: [
            "type": "started",
            "date": todayKey,
            "driverName": driverName,
            "durationHours": durationHours,
            "plannedEndAt": Timestamp(date: endsAt),
            "createdAt": FieldValue.serverTimestamp()
        ])

        try await db.collection("groups").document(groupID)
            .collection("live").document("current")
            .setData([
                "isActive": true,
                "driverName": driverName,
                "tripDate": todayKey,
                "approachSessionKey": UUID().uuidString,
                "plannedEndAt": Timestamp(date: endsAt),
                "durationHours": durationHours,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

        try await resetDriverRoute(groupID: groupID)
        try await resetTripTelemetry(groupID: groupID)
        try await resetTripActivity(groupID: groupID)

        isTripActive = true
        lastDriverTelemetryLocation = nil
        pickupReachLoggedMemberIDs = []
        activeTripGroupID = groupID
        activeTripDriverName = driverName
        lastLocationUploadAt = nil
        lastAppendedRoutePoint = nil

        locationTracker.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                await self?.handleLocationUpdate(location)
            }
        }
        locationTracker.startTracking()

        if let location = locationTracker.effectiveLocation {
            try? await uploadLocation(
                groupID: groupID,
                driverName: driverName,
                location: location,
                isActive: true
            )
            try? await recordPickupReachIfNeeded(groupID: groupID, driverCoordinate: location.coordinate)
            lastLocationUploadAt = Date()
        }

        scheduleTripAutoStop(
            groupID: groupID,
            driverName: driverName,
            endsAt: endsAt,
            locationTracker: locationTracker
        )
    }

    func stopTrip(groupID: String, driverName: String, locationTracker: LocationTracker) async {
        tripAutoStopTask?.cancel()
        tripAutoStopTask = nil
        plannedTripEndAt = nil
        isTripActive = false
        activeTripGroupID = nil
        activeTripDriverName = nil
        lastLocationUploadAt = nil
        lastAppendedRoutePoint = nil
        locationUploadTask?.cancel()
        locationUploadTask = nil
        locationTracker.onLocationUpdate = nil
        locationTracker.stopTracking()

        try? await FirebaseSession.shared.ensureAuthenticated()
        try? await db.collection("groups").document(groupID)
            .collection("live").document("current")
            .setData([
                "isActive": false,
                "driverName": driverName,
                "plannedEndAt": FieldValue.delete(),
                "durationHours": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

        // Artık attendance reset yapılmıyor - her servis (sabah/akşam) ayrı dateKey'de tutulduğu için
        // yolcuların akşam seçimleri sabah servisi bittiğinde korunuyor
    }

    /// Uygulama açıldığında süresi dolmuş aktif servisi kapatır.
    func reconcileActiveTripIfExpired(
        groupID: String,
        driverName: String,
        locationTracker: LocationTracker
    ) async {
        guard isTripActive else { return }
        if let endsAt = plannedTripEndAt, endsAt <= Date() {
            await stopTrip(groupID: groupID, driverName: driverName, locationTracker: locationTracker)
            return
        }

        try? await FirebaseSession.shared.ensureAuthenticated()
        let doc = try? await db.collection("groups").document(groupID)
            .collection("live").document("current")
            .getDocument()
        guard
            let data = doc?.data(),
            let isActive = data["isActive"] as? Bool,
            isActive,
            let timestamp = data["plannedEndAt"] as? Timestamp
        else { return }

        let endsAt = timestamp.dateValue()
        plannedTripEndAt = endsAt
        if endsAt <= Date() {
            await stopTrip(groupID: groupID, driverName: driverName, locationTracker: locationTracker)
            return
        }

        scheduleTripAutoStop(
            groupID: groupID,
            driverName: driverName,
            endsAt: endsAt,
            locationTracker: locationTracker
        )
    }

    private func scheduleTripAutoStop(
        groupID: String,
        driverName: String,
        endsAt: Date,
        locationTracker: LocationTracker
    ) {
        tripAutoStopTask?.cancel()
        let delay = max(0, endsAt.timeIntervalSinceNow)
        tripAutoStopTask = Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled, isTripActive, activeTripGroupID == groupID else { return }
            await stopTrip(groupID: groupID, driverName: driverName, locationTracker: locationTracker)
        }
    }

    private func requireAppleUserID(from user: User) throws -> String {
        guard let appleUserID = AuthService.resolveAppleUserID(from: user) else {
            throw ShuttleStoreError.invalidInput(L10n.appleUserIDNotFound)
        }
        return appleUserID
    }

    func planningAttendanceDateKey(holidayModeActive: Bool) -> String {
        HolidayMode.attendancePlanningDateKey(holidayModeActive: holidayModeActive)
    }

    func rawAttendance(for memberID: String, dateKey: String) -> AttendanceStatus {
        let response = attendanceResponsesByDate[dateKey]?[memberID]
        return response.flatMap { Self.attendanceStatus(from: $0) } ?? .unknown
    }

    func effectiveAttendance(for memberID: String, dateKey: String) -> AttendanceStatus {
        guard let member = members.first(where: { $0.id == memberID }) else { return .unknown }
        let raw = rawAttendance(for: memberID, dateKey: dateKey)
        var updated = member
        updated.attendance = raw
        return updated.effectiveAttendance
    }

    /// Sürücü: bugünün attendance belgesi (yolcuyla aynı anahtar) + tatil kuralı.
    /// Sürücünün aktif servisi için attendance durumu
    func serviceDayAttendance(for member: ShuttleMember) -> AttendanceStatus {
        let currentService = ServiceSchedule.currentDriverSession()
        let raw = rawAttendance(for: member.id, dateKey: currentService.dateKey)
        var updated = member
        updated.attendance = raw
        return updated.effectiveAttendance
    }

    /// Sürücünün şu an hangi serviste olduğu
    var currentDriverService: UpcomingService {
        ServiceSchedule.currentDriverSession()
    }

    func setAttendance(
        groupID: String,
        memberID: String,
        name: String,
        status: AttendanceStatus,
        dateKey: String? = nil
    ) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        let attendanceKey = dateKey ?? todayKey
        let ref = db.collection("groups").document(groupID)
            .collection("attendance").document(attendanceKey)

        try await ref.setData([
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        try await ref.updateData([
            FieldPath(["responses", memberID, "status"]): status.rawValue,
            FieldPath(["responses", memberID, "name"]): name,
            FieldPath(["responses", memberID, "updatedAt"]): FieldValue.serverTimestamp()
        ])

        var response = attendanceResponsesByDate[attendanceKey]?[memberID] ?? [:]
        response["status"] = status.rawValue
        response["name"] = name
        var dateResponses = attendanceResponsesByDate[attendanceKey] ?? [:]
        dateResponses[memberID] = response
        attendanceResponsesByDate[attendanceKey] = dateResponses
        if attendanceKey == todayKey {
            latestAttendanceResponses = dateResponses
        }
        refreshMembersAttendanceForServiceDay()
        notifyAttendanceChanged()
        // Gelmiyorum: biniş noktası silinmez; sürücü haritasında katılıma göre gizlenir.
    }

    func setHolidayMode(groupID: String, memberID: String, endDate: Date) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        let endKey = HolidayMode.dateKey(from: endDate)
        try await db.collection("groups").document(groupID)
            .collection("members").document(memberID)
            .setData([
                "holidayModeEndDate": endKey,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

        members = members.map { member in
            guard member.id == memberID else { return member }
            var updated = member
            updated.holidayModeEndDate = endKey
            return updated
        }
        try await clearMemberAttendanceStatus(groupID: groupID, memberID: memberID)
    }

    func clearHolidayMode(groupID: String, memberID: String) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        try await db.collection("groups").document(groupID)
            .collection("members").document(memberID)
            .updateData([
                "holidayModeEndDate": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])

        members = members.map { member in
            guard member.id == memberID else { return member }
            var updated = member
            updated.holidayModeEndDate = nil
            return updated
        }
        try await clearMemberAttendanceStatus(groupID: groupID, memberID: memberID)
    }

    func updateMemberName(groupID: String, memberID: String, newName: String) async throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        try await FirebaseSession.shared.ensureAuthenticated()

        try await db.collection("groups").document(groupID)
            .collection("members").document(memberID)
            .updateData([
                "name": trimmedName,
                "updatedAt": FieldValue.serverTimestamp()
            ])

        members = members.map { member in
            guard member.id == memberID else { return member }
            var updated = member
            updated.name = trimmedName
            return updated
        }
    }

    private func clearMemberAttendanceStatus(groupID: String, memberID: String) async throws {
        let dateKeys = [todayKey, HolidayMode.tomorrowDateKey()]
        for dateKey in dateKeys {
            let ref = db.collection("groups").document(groupID)
                .collection("attendance").document(dateKey)
            do {
                try await ref.updateData([
                    FieldPath(["responses", memberID, "status"]): FieldValue.delete(),
                    FieldPath(["responses", memberID, "updatedAt"]): FieldValue.delete()
                ])
            } catch {
                // Belge veya alan yoksa yoksay
            }

            var updated = attendanceResponsesByDate
            var dayMap = updated[dateKey] ?? [:]
            var memberResp = dayMap[memberID] ?? [:]
            memberResp.removeValue(forKey: "status")
            memberResp.removeValue(forKey: "updatedAt")
            if memberResp.isEmpty {
                dayMap.removeValue(forKey: memberID)
            } else {
                dayMap[memberID] = memberResp
            }
            if dayMap.isEmpty {
                updated.removeValue(forKey: dateKey)
            } else {
                updated[dateKey] = dayMap
            }
            attendanceResponsesByDate = updated
        }
        latestAttendanceResponses = attendanceResponsesByDate[todayKey] ?? [:]
        refreshMembersAttendanceForServiceDay()
        notifyAttendanceChanged()
    }

    private func handleLocationUpdate(_ location: CLLocation) async {
        guard isTripActive,
              let groupID = activeTripGroupID,
              let driverName = activeTripDriverName else { return }

        let now = Date()
        if let lastUpload = lastLocationUploadAt, now.timeIntervalSince(lastUpload) < 5 {
            return
        }

        do {
            try await uploadLocation(
                groupID: groupID,
                driverName: driverName,
                location: location,
                isActive: true
            )
            try await recordPickupReachIfNeeded(groupID: groupID, driverCoordinate: location.coordinate)
            try await appendDriverTelemetrySample(groupID: groupID, location: location)
            lastLocationUploadAt = now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func boardedAt(for memberID: String) -> Date? {
        guard let response = latestAttendanceResponses[memberID] else { return nil }
        return (response["boardedAt"] as? Timestamp)?.dateValue()
    }

    func uploadMotionActivitySnapshot(
        groupID: String,
        role: MotionActivityRole,
        memberID: String,
        automotiveSecondsInWindow: Int,
        segments: [MotionActivitySegment]
    ) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        let documentID: String
        switch role {
        case .driver:
            documentID = "activity_driver"
        case .passenger:
            documentID = "activity_passenger_\(memberID)"
        }

        let encodedSegments: [[String: Any]] = segments.map { segment in
            [
                "startedAt": Timestamp(date: segment.startedAt),
                "endedAt": Timestamp(date: segment.endedAt),
                "isAutomotive": segment.isAutomotive
            ]
        }

        try await db.collection("groups").document(groupID)
            .collection("tripActivity").document(documentID)
            .setData([
                "tripDate": todayKey,
                "role": role.rawValue,
                "memberID": memberID,
                "automotiveSecondsInWindow": automotiveSecondsInWindow,
                "segments": encodedSegments,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    private func recordPickupReachIfNeeded(
        groupID: String,
        driverCoordinate: CLLocationCoordinate2D
    ) async throws {
        guard isTripActive else { return }

        let driverLocation = CLLocation(
            latitude: driverCoordinate.latitude,
            longitude: driverCoordinate.longitude
        )

        for pickup in morningPickups {
            guard !pickupReachLoggedMemberIDs.contains(pickup.memberID) else { continue }

            if let member = members.first(where: { $0.id == pickup.memberID }),
               serviceDayAttendance(for: member) == .notComing {
                continue
            }

            let pickupLocation = CLLocation(
                latitude: pickup.latitude,
                longitude: pickup.longitude
            )
            guard driverLocation.distance(from: pickupLocation) <= Self.pickupReachRadiusMeters else {
                continue
            }

            pickupReachLoggedMemberIDs.insert(pickup.memberID)
            try await db.collection("groups").document(groupID)
                .collection("tripActivity").document("pickupReach_\(pickup.memberID)")
                .setData([
                    "tripDate": todayKey,
                    "memberID": pickup.memberID,
                    "latitude": pickup.latitude,
                    "longitude": pickup.longitude,
                    "reachedAt": FieldValue.serverTimestamp()
                ], merge: true)
        }
    }

    private func resetTripActivity(groupID: String) async throws {
        let activity = db.collection("groups").document(groupID).collection("tripActivity")
        let snapshot = try await activity.getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }

    private func appendDriverTelemetrySample(groupID: String, location: CLLocation) async throws {
        let speedMps = TripTelemetry.speedMps(
            from: location,
            previous: lastDriverTelemetryLocation
        )
        lastDriverTelemetryLocation = location
        let sample = TripTelemetry.Sample(
            speedMps: speedMps,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            sampledAt: Date()
        )
        try await writeTelemetrySamples(
            groupID: groupID,
            documentID: "driver",
            appending: sample
        )
    }

    private func writeTelemetrySamples(
        groupID: String,
        documentID: String,
        appending newSample: TripTelemetry.Sample
    ) async throws {
        let ref = db.collection("groups").document(groupID)
            .collection("tripTelemetry").document(documentID)

        let snapshot = try await ref.getDocument()
        var samples = TripTelemetry.samples(from: snapshot.data())
        samples.append(newSample)
        let cutoff = Date().addingTimeInterval(-TripTelemetry.sampleWindowSeconds)
        samples = samples.filter { $0.sampledAt >= cutoff }
        if samples.count > TripTelemetry.maxStoredSamples {
            samples = Array(samples.suffix(TripTelemetry.maxStoredSamples))
        }

        let encoded = samples.map { sample -> [String: Any] in
            var payload = TripTelemetry.firestorePayload(for: sample)
            payload["sampledAt"] = Timestamp(date: sample.sampledAt)
            return payload
        }

        try await ref.setData([
            "tripDate": todayKey,
            "samples": encoded,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func resetTripTelemetry(groupID: String) async throws {
        let telemetry = db.collection("groups").document(groupID).collection("tripTelemetry")
        let snapshot = try await telemetry.getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }

    private func uploadLocation(groupID: String, driverName: String, location: CLLocation, isActive: Bool) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        let speedMps = TripTelemetry.speedMps(
            from: location,
            previous: lastDriverTelemetryLocation
        )

        try await db.collection("groups").document(groupID)
            .collection("live").document("current")
            .setData([
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "speedMps": speedMps,
                "isActive": isActive,
                "driverName": driverName,
                "tripDate": todayKey,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

        if isActive {
            try await appendRoutePoint(groupID: groupID, coordinate: location.coordinate)
        }
    }

    private func resetDriverRoute(groupID: String) async throws {
        driverRoute = []
        lastAppendedRoutePoint = nil
        try await db.collection("groups").document(groupID)
            .collection("live").document("route")
            .setData([
                "tripDate": todayKey,
                "points": []
            ])
    }

    private func appendRoutePoint(groupID: String, coordinate: CLLocationCoordinate2D) async throws {
        if let last = lastAppendedRoutePoint {
            let from = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if from.distance(from: to) < Self.minRoutePointDistanceMeters {
                return
            }
        }

        lastAppendedRoutePoint = coordinate
        driverRoute.append(coordinate)

        try await db.collection("groups").document(groupID)
            .collection("live").document("route")
            .setData([
                "tripDate": todayKey,
                "points": FieldValue.arrayUnion([
                    [
                        "latitude": coordinate.latitude,
                        "longitude": coordinate.longitude
                    ]
                ])
            ], merge: true)
    }

    private static func routePoints(from data: [String: Any]?) -> [CLLocationCoordinate2D] {
        guard let rawPoints = data?["points"] as? [[String: Any]] else { return [] }
        return rawPoints.compactMap { point -> CLLocationCoordinate2D? in
            guard let lat = numericValue(point["latitude"]),
                  let lng = numericValue(point["longitude"]) else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }

    private static func numericValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let double as Double:
            return double
        case let float as Float:
            return Double(float)
        case let int as Int:
            return Double(int)
        default:
            return nil
        }
    }

    private func saveUserDocument(_ profile: UserProfile) async throws {
        var payload: [String: Any] = [
            "memberID": profile.memberID,
            "name": profile.name,
            "appleUserID": profile.appleUserID,
            "role": profile.role.rawValue,
            "groupIDs": profile.groupIDs,
            "activeGroupIDs": profile.activeGroupIDs,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let groupID = profile.groupID { payload["groupID"] = groupID }
        if let groupCode = profile.groupCode { payload["groupCode"] = groupCode }
        if let groupName = profile.groupName { payload["groupName"] = groupName }
        try await db.collection("users").document(profile.userID).setData(payload, merge: true)
    }

    /// Kullanıcının hesabıyla ilgili verileri Firestore'dan siler (kısmi hata olsa da devam eder).
    /// Auth kullanıcısını silmek için `AuthService.removeAccountIfPossible()` çağrılmalıdır.
    func deleteUserData(profile: UserProfile) async {
        guard (try? await FirebaseSession.shared.ensureAuthenticated()) != nil else {
            print("⚠️ [ShuttleStore] deleteUserData — oturum yok, Firestore silme atlandı")
            return
        }

        let userID = profile.userID
        let memberID = profile.memberID
        let groupsToCheck = (profile.groupIDs + [profile.groupID].compactMap { $0 }).filter { !$0.isEmpty }

        do {
            try await db.collection("users").document(userID).delete()
        } catch {
            print("⚠️ [ShuttleStore] users/\(userID) silinemedi: \(error.localizedDescription)")
        }

        for groupID in Set(groupsToCheck) {
            do {
                try await db.collection("groups").document(groupID)
                    .collection("members").document(memberID).delete()
            } catch {
                print("⚠️ [ShuttleStore] members/\(memberID) @ \(groupID): \(error.localizedDescription)")
            }

            do {
                try await db.collection("groups").document(groupID)
                    .collection("morningPickups").document(memberID).delete()
            } catch {
                print("⚠️ [ShuttleStore] morningPickups/\(memberID) @ \(groupID): \(error.localizedDescription)")
            }
        }
    }

    private func mergeMembers(_ fetched: [ShuttleMember]) {
        let attendanceByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.attendance) })
        let boardedByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.boardedAt) })
        members = fetched.map { member in
            var updated = member
            updated.attendance = attendanceByID[member.id] ?? member.attendance
            updated.boardedAt = boardedByID[member.id] ?? member.boardedAt
            return updated
        }
        refreshMembersAttendanceForServiceDay()
    }

    func setMorningPickup(
        groupID: String,
        memberID: String,
        name: String,
        coordinate: CLLocationCoordinate2D
    ) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        try await db.collection("groups").document(groupID)
            .collection("morningPickups").document(memberID)
            .setData([
                "memberID": memberID,
                "name": name,
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    func morningPickup(for memberID: String) -> MorningPickup? {
        morningPickups.first { $0.memberID == memberID }
    }

    private func onAttendanceSnapshot(dateKey: String, data: [String: Any]?) {
        if let data {
            let parsed = Self.parseAttendanceResponses(from: data)
            if !parsed.isEmpty {
                attendanceResponsesByDate[dateKey] = parsed
            }
        } else {
            attendanceResponsesByDate.removeValue(forKey: dateKey)
        }
        refreshMembersAttendanceForServiceDay()
        notifyAttendanceChanged()
    }

    private func notifyAttendanceChanged() {
        attendanceRevision += 1
    }

    private func refreshMembersAttendanceForServiceDay() {
        latestAttendanceResponses = attendanceResponsesByDate[todayKey] ?? [:]
        guard !latestAttendanceResponses.isEmpty || !attendanceResponsesByDate.isEmpty else {
            resetPassengerAttendance()
            return
        }

        members = members.map { member in
            var updated = member
            guard member.role == .passenger else { return updated }

            if let response = latestAttendanceResponses[member.id],
               let status = Self.attendanceStatus(from: response) {
                updated.attendance = status
            } else {
                updated.attendance = .unknown
            }
            if let response = latestAttendanceResponses[member.id] {
                updated.boardedAt = (response["boardedAt"] as? Timestamp)?.dateValue()
            } else {
                updated.boardedAt = nil
            }
            return updated
        }
    }

    private func resetPassengerAttendance() {
        members = members.map { member in
            var updated = member
            if member.role == .passenger {
                updated.attendance = .unknown
                updated.boardedAt = nil
            }
            return updated
        }
    }

    private static func attendanceStatus(from response: [String: Any]) -> AttendanceStatus? {
        guard let statusRaw = stringValue(response["status"]) else { return nil }
        return AttendanceStatus(rawValue: statusRaw)
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            string
        case let number as NSNumber:
            number.stringValue
        default:
            nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            double
        case let number as NSNumber:
            number.doubleValue
        case let int as Int:
            Double(int)
        default:
            nil
        }
    }

    private static func parseAttendanceResponses(from data: [String: Any]) -> [String: [String: Any]] {
        guard let raw = data["responses"] else { return [:] }
        if let typed = raw as? [String: [String: Any]] { return typed }

        guard let dictionary = raw as? [String: Any] else { return [:] }
        var responses: [String: [String: Any]] = [:]
        for (memberID, value) in dictionary {
            if let response = value as? [String: Any] {
                responses[memberID] = response
            }
        }
        return responses
    }

    private static func member(from document: QueryDocumentSnapshot) -> ShuttleMember? {
        let data = document.data()
        guard
            let name = data["name"] as? String,
            let roleRaw = data["role"] as? String,
            let role = MemberRole(rawValue: roleRaw)
        else { return nil }

        let holidayEnd = stringValue(data["holidayModeEndDate"])
        return ShuttleMember(
            id: document.documentID,
            name: name,
            role: role,
            holidayModeEndDate: holidayEnd
        )
    }

    private static func morningPickup(from document: QueryDocumentSnapshot) -> MorningPickup? {
        let data = document.data()
        let memberID = (data["memberID"] as? String) ?? document.documentID
        guard
            let name = data["name"] as? String,
            let latitude = doubleValue(data["latitude"]),
            let longitude = doubleValue(data["longitude"])
        else { return nil }

        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        return MorningPickup(
            memberID: memberID,
            name: name,
            latitude: latitude,
            longitude: longitude,
            updatedAt: updatedAt
        )
    }

    private static func driverLocation(from snapshot: DocumentSnapshot?) -> DriverLocation? {
        guard
            let data = snapshot?.data(),
            let latitude = doubleValue(data["latitude"]),
            let longitude = doubleValue(data["longitude"]),
            let isActive = data["isActive"] as? Bool,
            isActive
        else { return nil }

        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let driverName = data["driverName"] as? String ?? L10n.driverDefaultName
        var coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        #if targetEnvironment(simulator)
        if !MapDefaults.isNearHome(coordinate) {
            coordinate = MapDefaults.homeCoordinate
        }
        #endif

        return DriverLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            updatedAt: updatedAt,
            isActive: isActive,
            driverName: driverName
        )
    }

    private static func userProfile(from data: [String: Any], userID: String) -> UserProfile? {
        guard
            let memberID = data["memberID"] as? String,
            let name = data["name"] as? String,
            let roleRaw = data["role"] as? String,
            let role = MemberRole(rawValue: roleRaw)
        else { return nil }

        let appleUserID = (data["appleUserID"] as? String)
            ?? (data["phoneNumber"] as? String).map { "legacy:\($0)" }
        guard let appleUserID else { return nil }

        // Support both old single-group format and new multi-group format
        let groupIDs: [String]
        let activeGroupIDs: [String]
        let legacyGroupID: String?
        let legacyGroupCode: String?
        let legacyGroupName: String?

        if let ids = data["groupIDs"] as? [String] {
            groupIDs = ids
            activeGroupIDs = data["activeGroupIDs"] as? [String] ?? ids
            legacyGroupID = data["groupID"] as? String
            legacyGroupCode = data["groupCode"] as? String
            legacyGroupName = data["groupName"] as? String
        } else if let groupID = data["groupID"] as? String {
            // Old format migration
            groupIDs = [groupID]
            activeGroupIDs = [groupID]
            legacyGroupID = groupID
            legacyGroupCode = data["groupCode"] as? String
            legacyGroupName = data["groupName"] as? String
        } else {
            return nil
        }

        return UserProfile(
            userID: userID,
            memberID: memberID,
            name: name,
            appleUserID: appleUserID,
            role: role,
            groupIDs: groupIDs,
            activeGroupIDs: activeGroupIDs,
            groupID: legacyGroupID,
            groupCode: legacyGroupCode,
            groupName: legacyGroupName
        )
    }

    private static func generateGroupCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}
