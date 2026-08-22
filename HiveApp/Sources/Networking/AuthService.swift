import Foundation
import FirebaseAuth

/// Handles player identity with persistent device UID and background Firebase session.
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var currentUserID: String
    private(set) var isAuthenticated = false
    private(set) var playerDisplayName: String = "Jogador"

    private init() {
        // Retrieve or generate a persistent local player UID
        if let savedUID = UserDefaults.standard.string(forKey: "hive_player_uid"), !savedUID.isEmpty {
            self.currentUserID = savedUID
        } else {
            let newUID = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
            self.currentUserID = String(newUID)
            UserDefaults.standard.set(String(newUID), forKey: "hive_player_uid")
        }

        let savedName = UserDefaults.standard.string(forKey: "online_display_name")
        let name = savedName ?? "Jogador \(String(self.currentUserID.prefix(4)).uppercased())"
        self.playerDisplayName = name
        if savedName == nil {
            UserDefaults.standard.set(name, forKey: "online_display_name")
        }

        // Check existing Firebase session if available
        if let user = Auth.auth().currentUser {
            self.isAuthenticated = true
            self.currentUserID = user.uid
        }
    }

    /// Ensures the player has a stable identifier.
    func ensureAuthenticated() async -> String {
        if !isAuthenticated {
            do {
                let result = try await Auth.auth().signInAnonymously()
                self.currentUserID = result.user.uid
                self.isAuthenticated = true
                UserDefaults.standard.set(result.user.uid, forKey: "hive_player_uid")
            } catch {
                print("ℹ️ [AuthService] Firebase anonymous sign-in skipped, using persistent UID: \(currentUserID). (\(error.localizedDescription))")
                self.isAuthenticated = true
            }
        }
        return currentUserID
    }

    func updateDisplayName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.playerDisplayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: "online_display_name")
    }
}
