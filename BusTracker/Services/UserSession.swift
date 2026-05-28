import Foundation

struct UserProfile: Codable {
    let userID: String
    let memberID: String
    let name: String
    let appleUserID: String
    let role: MemberRole

    let groupIDs: [String]
    let activeGroupIDs: [String]

    let groupID: String?
    let groupCode: String?
    let groupName: String?

    var primaryGroupID: String {
        activeGroupIDs.first ?? groupIDs.first ?? groupID ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case userID, memberID, name, appleUserID, phoneNumber, role
        case groupIDs, activeGroupIDs, groupID, groupCode, groupName
    }

    init(
        userID: String,
        memberID: String,
        name: String,
        appleUserID: String,
        role: MemberRole,
        groupIDs: [String],
        activeGroupIDs: [String],
        groupID: String?,
        groupCode: String?,
        groupName: String?
    ) {
        self.userID = userID
        self.memberID = memberID
        self.name = name
        self.appleUserID = appleUserID
        self.role = role
        self.groupIDs = groupIDs
        self.activeGroupIDs = activeGroupIDs
        self.groupID = groupID
        self.groupCode = groupCode
        self.groupName = groupName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        memberID = try container.decode(String.self, forKey: .memberID)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(MemberRole.self, forKey: .role)
        groupIDs = try container.decode([String].self, forKey: .groupIDs)
        activeGroupIDs = try container.decode([String].self, forKey: .activeGroupIDs)
        groupID = try container.decodeIfPresent(String.self, forKey: .groupID)
        groupCode = try container.decodeIfPresent(String.self, forKey: .groupCode)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)

        if let apple = try container.decodeIfPresent(String.self, forKey: .appleUserID) {
            appleUserID = apple
        } else if let legacyPhone = try container.decodeIfPresent(String.self, forKey: .phoneNumber) {
            appleUserID = "legacy:\(legacyPhone)"
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.appleUserID,
                .init(codingPath: decoder.codingPath, debugDescription: "appleUserID missing")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userID, forKey: .userID)
        try container.encode(memberID, forKey: .memberID)
        try container.encode(name, forKey: .name)
        try container.encode(appleUserID, forKey: .appleUserID)
        try container.encode(role, forKey: .role)
        try container.encode(groupIDs, forKey: .groupIDs)
        try container.encode(activeGroupIDs, forKey: .activeGroupIDs)
        try container.encodeIfPresent(groupID, forKey: .groupID)
        try container.encodeIfPresent(groupCode, forKey: .groupCode)
        try container.encodeIfPresent(groupName, forKey: .groupName)
    }
}

@MainActor
@Observable
final class UserSession {
    static let shared = UserSession()

    private(set) var profile: UserProfile?
    private(set) var isLoadingProfile = false

    var isLoggedIn: Bool { profile != nil }
    var hasGroup: Bool { profile != nil }

    private let storageKey = "userProfile"

    private init() {
        load()
    }

    func save(_ profile: UserProfile) {
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func clearLocalProfile() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func signOut() async {
        clearLocalProfile()
        try? AuthService.shared.signOut()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return }
        self.profile = profile
    }
}
