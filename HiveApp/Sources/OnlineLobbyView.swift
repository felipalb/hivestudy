import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

/// The Multiplayer Online Lobby view: Quick Matchmaking & Private Room by code.
struct OnlineLobbyView: View {
    let onBack: () -> Void
    let onMatchStarted: () -> Void

    @State private var onlineService = OnlineGameService.shared
    @State private var authService = AuthService.shared

    @State private var selectedTab: LobbyTab = .quickMatch
    @State private var privateRoomMode: PrivateRoomMode = .create
    @State private var inputCode: String = ""
    @State private var tournamentOpening: Bool = false
    @State private var isEditingName = false
    @State private var editedName: String = ""
    @State private var copiedCode = false

    enum LobbyTab: String, CaseIterable, Identifiable {
        case quickMatch = "Partida Rápida"
        case privateRoom = "Sala Privada"
        var id: String { rawValue }
    }

    enum PrivateRoomMode: String, CaseIterable, Identifiable {
        case create = "Criar Sala"
        case join = "Entrar com Código"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            // Ambient background
            Color(red: 0.07, green: 0.08, blue: 0.10).ignoresSafeArea()
            backgroundDecorations

            VStack(spacing: 0) {
                // Top header
                topHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                if onlineService.isSearchingMatch || (onlineService.isHostingPrivateRoom && onlineService.activeMatch?.status == .waitingForOpponent) {
                    // Matchmaking in progress radar screen
                    searchingScreen
                } else {
                    // Main lobby tabs & forms
                    tabSelector
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            if selectedTab == .quickMatch {
                                quickMatchCard
                            } else {
                                privateRoomCard
                            }

                            if let error = onlineService.connectionError {
                                errorPill(error)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .task {
            _ = try? await authService.ensureAuthenticated()
            editedName = authService.playerDisplayName
        }
        .onChange(of: onlineService.activeMatch?.status) { _, newStatus in
            if newStatus == .active {
                Haptics.success()
                onMatchStarted()
            }
        }
    }

    // MARK: - Top Header

    private var topHeader: some View {
        HStack(spacing: 12) {
            Button {
                onlineService.leaveMatch()
                onBack()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("MULTIPLAYER ONLINE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(HiveTheme.selection)

                Text("Jogue com amigos ou no mundo")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Player Profile Pill
            Button {
                isEditingName.toggle()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text(authService.playerDisplayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)

                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isEditingName) {
                nameEditSheet
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(LobbyTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(selectedTab == tab ? .black : .white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? HiveTheme.selection : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.3)))
    }

    // MARK: - Quick Match Card

    private var quickMatchCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(HiveTheme.selection)
                    .padding(.top, 8)

                Text("Pareamento Rápido 1v1")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Encontre um oponente online aleatório em segundos. As cores são sorteadas automaticamente.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Tournament toggle
            Toggle(isOn: $tournamentOpening) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Abertura de Torneio")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Proíbe colocar a Rainha no primeiro turno")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .tint(HiveTheme.selection)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))

            // Find match button
            Button {
                Task {
                    await onlineService.findQuickMatch(tournamentOpening: tournamentOpening)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .heavy))
                    Text("BUSCAR PARTIDA")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(HiveTheme.selection)
                        .shadow(color: HiveTheme.selection.opacity(0.4), radius: 16, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.12, green: 0.13, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Private Room Card

    private var privateRoomCard: some View {
        VStack(spacing: 20) {
            // Sub-mode switch
            Picker("Modo da Sala", selection: $privateRoomMode) {
                ForEach(PrivateRoomMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if privateRoomMode == .create {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(HiveTheme.selection)

                    Text("Criar Sala com Código")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Gere um código de 6 letras para convidar um amigo diretamente para o seu jogo.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)

                    Button {
                        Task {
                            _ = await onlineService.createPrivateRoom(tournamentOpening: tournamentOpening)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .heavy))
                            Text("GERAR CÓDIGO DA SALA")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .tracking(1.0)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(HiveTheme.selection)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(HiveTheme.selection)

                    Text("Entrar com Código")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    // Code text field
                    TextField("Ex: HIVE7X", text: $inputCode)
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HiveTheme.selection.opacity(0.4), lineWidth: 1)
                        )
                        .onChange(of: inputCode) { _, val in
                            if val.count > 6 {
                                inputCode = String(val.prefix(6))
                            }
                        }

                    Button {
                        Task {
                            await onlineService.joinPrivateRoom(code: inputCode)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 14, weight: .heavy))
                            Text("ENTRAR NA PARTIDA")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .tracking(1.0)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(inputCode.count == 6 ? HiveTheme.selection : Color.white.opacity(0.2))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(inputCode.count != 6)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.12, green: 0.13, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Searching / Radar Screen

    private var searchingScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Radar rings
                Circle()
                    .stroke(HiveTheme.selection.opacity(0.2), lineWidth: 2)
                    .frame(width: 180, height: 180)

                Circle()
                    .stroke(HiveTheme.selection.opacity(0.4), lineWidth: 2)
                    .frame(width: 120, height: 120)

                RegularHexagon()
                    .fill(HiveTheme.selection)
                    .frame(width: 60, height: 60)
                    .shadow(color: HiveTheme.selection.opacity(0.6), radius: 20)

                Image(systemName: onlineService.isHostingPrivateRoom ? "key.fill" : "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
            }

            VStack(spacing: 8) {
                Text(onlineService.isHostingPrivateRoom ? "SALA CRIADA!" : "BUSCANDO OPONENTE...")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(HiveTheme.selection)

                if let code = onlineService.privateRoomCode {
                    VStack(spacing: 12) {
                        Text("Compartilhe o código abaixo com seu amigo:")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 12) {
                            Text(code)
                                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                                .tracking(4)
                                .foregroundStyle(.white)

                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = code
                                #endif
                                copiedCode = true
                                Haptics.success()
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    copiedCode = false
                                }
                            } label: {
                                Image(systemName: copiedCode ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(copiedCode ? .green : HiveTheme.selection)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                } else {
                    Text("Aguardando um jogador livre entrar na fila...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            Button {
                onlineService.leaveMatch()
            } label: {
                Text("CANCELAR BUSCA")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(HiveTheme.danger)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().stroke(HiveTheme.danger.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Name Edit Sheet

    private var nameEditSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Escolha seu apelido online:")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Seu nome", text: $editedName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))

                Spacer()

                Button {
                    authService.updateDisplayName(editedName)
                    isEditingName = false
                } label: {
                    Text("SALVAR NOME")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(HiveTheme.selection))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(red: 0.07, green: 0.08, blue: 0.10).ignoresSafeArea())
            .navigationTitle("Apelido do Jogador")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.fraction(0.35)])
    }

    private func errorPill(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(HiveTheme.danger)
            Text(error)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(HiveTheme.danger.opacity(0.15)))
    }

    private var backgroundDecorations: some View {
        ZStack {
            RadialGradient(
                colors: [HiveTheme.selection.opacity(0.06), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }
}
