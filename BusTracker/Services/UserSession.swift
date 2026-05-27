import Foundation

struct UserProfile: Codable {
    let userID: String
    let memberID: String
    let name: String
    let phoneNumber: String
    let role: MemberRole

    // Yeni çoklu grup desteği
    let groupIDs: [String]
    let activeGroupIDs: [String]

    // Geriye uyumluluk için (geçici)
    let groupID: String?
    let groupCode: String?
    let groupName: String?

    // Kolay erişim için
    var primaryGroupID: String {
        activeGroupIDs.first ?? groupIDs.first ?? groupID ?? ""
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
