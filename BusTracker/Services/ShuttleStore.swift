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
        case .notAuthenticated: "Giriş yapmanız gerekiyor."
        case .groupNotFound: "Bu servis kodu bulunamadı."
        case .alreadyInGroup: "Zaten bir servise kayıtlısınız."
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
    private var attendanceListener: ListenerRegistration?
    private var morningPickupsListener: ListenerRegistration?
    private var locationUploadTask: Task<Void, Never>?
    private var latestAttendanceResponses: [String: [String: Any]] = [:]
    private var activeTripGroupID: String?
    private var activeTripDriverName: String?
    private var lastLocationUploadAt: Date?
    private var lastAppendedRoutePoint: CLLocationCoordinate2D?
    private var tripAutoStopTask: Task<Void, Never>?
    private static let minRoutePointDistanceMeters: CLLocationDistance = 20
    private(set) var plannedTripEndAt: Date?

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    func startListening(groupID: String) {
        stopListening()

        Task {
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

            attendanceListener = db.collection("groups").document(groupID)
                .collection("attendance").document(todayKey)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.applyAttendance(from: snapshot?.data())
                    }
                }

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

    func stopListening() {
        membersListener?.remove()
        locationListener?.remove()
        routeListener?.remove()
        attendanceListener?.remove()
        morningPickupsListener?.remove()
        membersListener = nil
        locationListener = nil
        routeListener = nil
        attendanceListener = nil
        morningPickupsListener = nil
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

    func createGroup(name: String, driverName: String) async throws -> UserProfile {
        try await FirebaseSession.shared.ensureAuthenticated()
        guard let user = Auth.auth().currentUser else { throw ShuttleStoreError.notAuthenticated }
        let appleUserID = try requireAppleUserID(from: user)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDriver = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ShuttleStoreError.invalidInput("Servis adı boş olamaz.") }
        guard !trimmedDriver.isEmpty else { throw ShuttleStoreError.invalidInput("Adınız boş olamaz.") }

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

    /// Yolcu kaydı: kod Firestore'da var mı (Apple oturumu açıldıktan sonra).
    func validatePassengerGroupCode(_ code: String) async throws {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmedCode.isEmpty {
            throw ShuttleStoreError.invalidInput("Servis kodu girmedin.")
        }
        if trimmedCode.count < 4 {
            throw ShuttleStoreError.invalidInput("Servis kodu en az 4 karakter olmalı.")
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
        guard trimmedCode.count >= 4 else { throw ShuttleStoreError.invalidInput("Servis kodu en az 4 karakter olmalı.") }
        guard !trimmedName.isEmpty else { throw ShuttleStoreError.invalidInput("Adınız boş olamaz.") }

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
        let groupName = groupData["name"] as? String ?? "Servis"
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

    func startTrip(
        groupID: String,
        driverName: String,
        durationHours: Double,
        locationTracker: LocationTracker
    ) async throws {
        guard !isTripActive else { return }
        guard durationHours > 0 else {
            throw ShuttleStoreError.invalidInput("Servis süresi seçin.")
        }
        guard locationTracker.canDriverStartTrip else {
            throw ShuttleStoreError.invalidInput(
                "Servisi başlatmak için Ayarlar'dan \"Her zaman\" konum iznini açmanız gerekir."
            )
        }
        try await FirebaseSession.shared.ensureAuthenticated()

        let endsAt = Date().addingTimeInterval(durationHours * 3600)
        plannedTripEndAt = endsAt

        try await db.collection("groups").document(groupID)
            .collection("attendance").document(todayKey).delete()

        latestAttendanceResponses = [:]
        members = members.map { member in
            var updated = member
            if member.role == .passenger { updated.attendance = .unknown }
            return updated
        }

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

        isTripActive = true
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
            throw ShuttleStoreError.invalidInput("Apple hesap kimliği bulunamadı.")
        }
        return appleUserID
    }

    func setAttendance(groupID: String, memberID: String, name: String, status: AttendanceStatus) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        let ref = db.collection("groups").document(groupID)
            .collection("attendance").document(todayKey)

        try await ref.setData([
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        try await ref.updateData([
            FieldPath(["responses", memberID, "status"]): status.rawValue,
            FieldPath(["responses", memberID, "name"]): name,
            FieldPath(["responses", memberID, "updatedAt"]): FieldValue.serverTimestamp()
        ])

        var response = latestAttendanceResponses[memberID] ?? [:]
        response["status"] = status.rawValue
        response["name"] = name
        latestAttendanceResponses[memberID] = response
        applyAttendance(from: ["responses": latestAttendanceResponses])
        // Gelmiyorum: biniş noktası silinmez; sürücü haritasında katılıma göre gizlenir.
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
            lastLocationUploadAt = now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadLocation(groupID: String, driverName: String, location: CLLocation, isActive: Bool) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        try await db.collection("groups").document(groupID)
            .collection("live").document("current")
            .setData([
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
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
        try await db.collection("users").document(profile.userID).setData([
            "memberID": profile.memberID,
            "name": profile.name,
            "appleUserID": profile.appleUserID,
            "role": profile.role.rawValue,
            "groupID": profile.groupID,
            "groupCode": profile.groupCode,
            "groupName": profile.groupName,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    /// Kullanıcının hesabıyla ilgili verileri Firestore'dan siler.
    /// Not: Auth kullanıcısını silmek için AuthService.deleteCurrentUser() çağrılmalıdır.
    func deleteUserData(profile: UserProfile) async throws {
        try await FirebaseSession.shared.ensureAuthenticated()

        let userID = profile.userID
        let memberID = profile.memberID

        // 1. users koleksiyonundaki belgeyi sil
        try await db.collection("users").document(userID).delete()

        // 2. Kullanıcının dahil olduğu gruplardaki member kaydını sil
        let groupsToCheck = (profile.groupIDs + [profile.groupID].compactMap { $0 }).filter { !$0.isEmpty }

        for groupID in Set(groupsToCheck) {
            // Member kaydını sil
            try await db.collection("groups").document(groupID)
                .collection("members").document(memberID).delete()

            // Kullanıcının morningPickup kaydını sil (varsa)
            try await db.collection("groups").document(groupID)
                .collection("morningPickups").document(memberID).delete()
        }

        // Not: Attendance kayıtlarını tamamen temizlemek güvenlik kuralları nedeniyle
        // Cloud Function ile daha güvenli yapılır. Şimdilik ana veriler siliniyor.
    }

    private func mergeMembers(_ fetched: [ShuttleMember]) {
        let attendanceByID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.attendance) })
        members = fetched.map { member in
            var updated = member
            updated.attendance = attendanceByID[member.id] ?? member.attendance
            return updated
        }
        applyAttendance(from: ["responses": latestAttendanceResponses])
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

    private func applyAttendance(from data: [String: Any]?) {
        guard let data else {
            latestAttendanceResponses = [:]
            resetPassengerAttendance()
            return
        }

        let parsed = Self.parseAttendanceResponses(from: data)
        if !parsed.isEmpty {
            latestAttendanceResponses = parsed
        }

        guard !latestAttendanceResponses.isEmpty else { return }

        members = members.map { member in
            var updated = member
            guard member.role == .passenger else { return updated }

            if let response = latestAttendanceResponses[member.id],
               let status = Self.attendanceStatus(from: response) {
                updated.attendance = status
            } else {
                updated.attendance = .unknown
            }
            return updated
        }
    }

    private func resetPassengerAttendance() {
        members = members.map { member in
            var updated = member
            if member.role == .passenger { updated.attendance = .unknown }
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

        return ShuttleMember(id: document.documentID, name: name, role: role)
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
        let driverName = data["driverName"] as? String ?? "Şoför"
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
