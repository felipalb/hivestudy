import Foundation
import FirebaseFirestore
import HiveEngine

/// Service handling matchmaking (random pool & private code rooms) and real-time Firestore sync.
@MainActor
@Observable
final class OnlineGameService {
    static let shared = OnlineGameService()

    private let db = Firestore.firestore()
    private var activeListener: ListenerRegistration?
    private var matchmakingListener: ListenerRegistration?

    private(set) var activeMatch: OnlineMatch?
    private(set) var localPlayerColor: PlayerColor?
    private(set) var isSearchingMatch = false
    private(set) var isHostingPrivateRoom = false
    private(set) var privateRoomCode: String?
    private(set) var connectionError: String?
    private(set) var opponentAbandoned = false

    private init() {}

    // MARK: - Quick Match (Random Matchmaking)

    /// Joins the matchmaking queue to find any available player.
    func findQuickMatch(tournamentOpening: Bool = false) async {
        let auth = AuthService.shared
        let myUID = await auth.ensureAuthenticated()
        let myName = auth.playerDisplayName

        isSearchingMatch = true
        connectionError = nil
        privateRoomCode = nil
        isHostingPrivateRoom = false

        let waitingRef = db.collection("waitingPool")

        do {
            // 1. Check if there's someone already waiting in the pool
            let snapshot = try await waitingRef
                .whereField("status", isEqualTo: "waiting")
                .limit(to: 10)
                .getDocuments()

            let validWaiters = snapshot.documents.filter { $0.documentID != myUID }

            if let otherDoc = validWaiters.first {
                // Found a waiting opponent! Create the match or join it.
                let opponentUID = otherDoc.documentID
                let opponentData = otherDoc.data()
                let opponentName = (opponentData["displayName"] as? String) ?? "Oponente"

                // Coin toss for colors
                let hostIsWhite = Bool.random()
                let matchID = UUID().uuidString

                let match = OnlineMatch(
                    id: matchID,
                    roomCode: nil,
                    hostPlayerID: opponentUID,
                    hostDisplayName: opponentName,
                    guestPlayerID: myUID,
                    guestDisplayName: myName,
                    playerWhiteID: hostIsWhite ? opponentUID : myUID,
                    playerBlackID: hostIsWhite ? myUID : opponentUID,
                    status: .active,
                    moves: [],
                    config: GameConfig(tournamentOpening: tournamentOpening)
                )

                // Save match document
                let matchDoc = db.collection("matches").document(matchID)
                let encodedData = try Firestore.Encoder().encode(match)
                try await matchDoc.setData(encodedData)

                // Inform opponent by updating their waiting pool entry with the matchID
                try await waitingRef.document(opponentUID).setData([
                    "status": "matched",
                    "matchID": matchID
                ], merge: true)

                // Clean up my waiting pool entry if any
                try? await waitingRef.document(myUID).delete()

                self.isSearchingMatch = false
                self.activeMatch = match
                self.localPlayerColor = match.color(for: myUID)
                self.listenToMatch(matchID: matchID, myUID: myUID)
            } else {
                // No opponent yet -> register in waiting pool and listen for someone pairing with us
                try await waitingRef.document(myUID).setData([
                    "displayName": myName,
                    "status": "waiting",
                    "joinedAt": FieldValue.serverTimestamp()
                ])

                matchmakingListener?.remove()
                matchmakingListener = waitingRef.document(myUID).addSnapshotListener { [weak self] snapshot, error in
                    guard let self else { return }
                    if let error {
                        print("⚠️ [Matchmaking] Listener error: \(error.localizedDescription)")
                        self.connectionError = error.localizedDescription
                        self.isSearchingMatch = false
                        return
                    }

                    guard let data = snapshot?.data(),
                          let status = data["status"] as? String,
                          status == "matched",
                          let matchID = data["matchID"] as? String else {
                        return
                    }

                    // Opponent paired with us!
                    self.matchmakingListener?.remove()
                    self.matchmakingListener = nil
                    self.isSearchingMatch = false

                    // Clean up waiting pool entry
                    Task {
                        try? await waitingRef.document(myUID).delete()
                    }

                    self.listenToMatch(matchID: matchID, myUID: myUID)
                }
            }
        } catch {
            print("❌ [Matchmaking] Error searching match: \(error.localizedDescription)")
            self.connectionError = error.localizedDescription
            self.isSearchingMatch = false
        }
    }

    // MARK: - Private Rooms (Room Code)

    /// Creates a new private room and returns a 6-character room code.
    func createPrivateRoom(tournamentOpening: Bool = false) async -> String? {
        let auth = AuthService.shared
        let myUID = await auth.ensureAuthenticated()
        let myName = auth.playerDisplayName

        isSearchingMatch = false
        connectionError = nil

        let code = generateRoomCode()
        let matchID = UUID().uuidString
        let hostIsWhite = true

        let match = OnlineMatch(
            id: matchID,
            roomCode: code,
            hostPlayerID: myUID,
            hostDisplayName: myName,
            guestPlayerID: nil,
            guestDisplayName: nil,
            playerWhiteID: hostIsWhite ? myUID : "",
            playerBlackID: hostIsWhite ? nil : myUID,
            status: .waitingForOpponent,
            moves: [],
            config: GameConfig(tournamentOpening: tournamentOpening)
        )

        do {
            let matchDoc = db.collection("matches").document(matchID)
            let encodedData = try Firestore.Encoder().encode(match)
            try await matchDoc.setData(encodedData)

            self.privateRoomCode = code
            self.isHostingPrivateRoom = true
            self.activeMatch = match
            self.localPlayerColor = hostIsWhite ? .white : .black

            // Listen for guest joining
            listenToMatch(matchID: matchID, myUID: myUID)

            return code
        } catch {
            print("❌ [PrivateRoom] Error creating room: \(error.localizedDescription)")
            self.connectionError = error.localizedDescription
            return nil
        }
    }

    /// Joins a private room with a given 6-character room code.
    func joinPrivateRoom(code: String) async {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanCode.count == 6 else {
            self.connectionError = "Código de sala deve ter 6 caracteres."
            return
        }

        let auth = AuthService.shared
        let myUID = await auth.ensureAuthenticated()
        let myName = auth.playerDisplayName

        connectionError = nil
        isSearchingMatch = false
        isHostingPrivateRoom = false

        do {
            let query = try await db.collection("matches")
                .whereField("roomCode", isEqualTo: cleanCode)
                .whereField("status", isEqualTo: OnlineMatchStatus.waitingForOpponent.rawValue)
                .limit(to: 1)
                .getDocuments()

            guard let doc = query.documents.first else {
                self.connectionError = "Sala não encontrada ou partida já iniciada."
                return
            }

            var match = try doc.data(as: OnlineMatch.self)
            guard match.hostPlayerID != myUID else {
                // Already the host of this room
                return
            }

            match.guestPlayerID = myUID
            match.guestDisplayName = myName
            match.status = .active

            if match.playerWhiteID.isEmpty {
                match.playerWhiteID = myUID
            } else {
                match.playerBlackID = myUID
            }

            match.updatedAt = Date()

            let matchDoc = db.collection("matches").document(match.id)
            let encodedData = try Firestore.Encoder().encode(match)
            try await matchDoc.setData(encodedData)

            self.activeMatch = match
            self.localPlayerColor = match.color(for: myUID)
            self.listenToMatch(matchID: match.id, myUID: myUID)
        } catch {
            print("❌ [PrivateRoom] Error joining room: \(error.localizedDescription)")
            self.connectionError = error.localizedDescription
        }
    }

    // MARK: - Live Match Observation & Moves

    /// Listens for real-time moves and status updates in the active match.
    private func listenToMatch(matchID: String, myUID: String) {
        activeListener?.remove()
        activeListener = db.collection("matches").document(matchID).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                self.connectionError = error.localizedDescription
                return
            }

            guard let snapshot, snapshot.exists,
                  let updatedMatch = try? snapshot.data(as: OnlineMatch.self) else {
                return
            }

            self.activeMatch = updatedMatch
            if self.localPlayerColor == nil {
                self.localPlayerColor = updatedMatch.color(for: myUID)
            }

            // Check if the opponent abandoned the match
            if updatedMatch.status == .abandoned {
                if let abandonedBy = updatedMatch.abandonedByPlayerID, abandonedBy != myUID {
                    self.opponentAbandoned = true
                }
            }
        }
    }

    /// Submits a move played by the local player to Firestore.
    func submitMove(_ move: Move) async throws {
        guard let match = activeMatch, let localColor = localPlayerColor else {
            throw NSError(domain: "HiveOnline", code: 400, userInfo: [NSLocalizedDescriptionKey: "Nenhuma partida online ativa."])
        }

        let newRecord = OnlineMoveRecord(
            sequence: match.moves.count,
            playerColor: localColor,
            move: move,
            timestamp: Date()
        )

        var updatedMoves = match.moves
        updatedMoves.append(newRecord)

        let matchDoc = db.collection("matches").document(match.id)
        let encodedRecord = try Firestore.Encoder().encode(newRecord)

        try await matchDoc.updateData([
            "moves": FieldValue.arrayUnion([encodedRecord]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Reports that the match finished (winner or draw).
    func finalizeMatch(winner: PlayerColor?, isDraw: Bool) async throws {
        guard let match = activeMatch else { return }
        let matchDoc = db.collection("matches").document(match.id)

        try await matchDoc.updateData([
            "status": OnlineMatchStatus.finished.rawValue,
            "winnerColor": winner?.rawValue as Any,
            "isDraw": isDraw,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Cancels searching or leaves current room/match.
    func leaveMatch() {
        let myUID = AuthService.shared.currentUserID

        if let match = activeMatch, match.status == .active {
            let matchDoc = db.collection("matches").document(match.id)
            let oppColor = localPlayerColor?.opponent
            Task {
                try? await matchDoc.updateData([
                    "status": OnlineMatchStatus.abandoned.rawValue,
                    "abandonedByPlayerID": myUID,
                    "winnerColor": oppColor?.rawValue as Any,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            }
        }

        matchmakingListener?.remove()
        matchmakingListener = nil

        activeListener?.remove()
        activeListener = nil

        if isSearchingMatch {
            Task { [weak self] in
                guard let self else { return }
                try? await self.db.collection("waitingPool").document(myUID).delete()
            }
        }

        activeMatch = nil
        localPlayerColor = nil
        isSearchingMatch = false
        isHostingPrivateRoom = false
        privateRoomCode = nil
        connectionError = nil
        opponentAbandoned = false
    }

    // MARK: - Utilities

    private func generateRoomCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
