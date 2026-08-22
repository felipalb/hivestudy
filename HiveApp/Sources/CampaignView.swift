import SwiftUI
import HiveEngine

#if canImport(UIKit)
import UIKit
#endif

/// Screen for exploring and selecting chapters in "A Jornada da Colmeia" (Campaign Mode).
struct CampaignView: View {
    let onBack: () -> Void
    let onSelectLevel: (CampaignLevel) -> Void

    @State private var unlockedLevel: Int = 1
    @State private var earnedStars: [Int: Int] = [:]
    @State private var selectedLevelID: Int = 1

    private let levels = CampaignLevel.allLevels

    var body: some View {
        ZStack {
            // Ambient natural backdrop
            BoardAtmosphereView()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Scrollable Level Cards
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(levels) { level in
                            levelCard(for: level)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            refreshProgress()
        }
    }

    private func refreshProgress() {
        unlockedLevel = CampaignPersistence.unlockedLevel
        earnedStars = CampaignPersistence.earnedStars
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundStyle(.white)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")

            Spacer()

            VStack(spacing: 2) {
                Text("A JORNADA DA COLMEIA")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(HiveTheme.selection)

                Text("Modo Campanha")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Stars total
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.28))
                Text("\(totalStars)/18")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var totalStars: Int {
        earnedStars.values.reduce(0, +)
    }

    // MARK: - Level Card

    private func levelCard(for level: CampaignLevel) -> some View {
        let isUnlocked = level.id <= unlockedLevel
        let stars = earnedStars[level.id] ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            // Card Header: Chapter tag + Stars + Difficulty
            HStack {
                HStack(spacing: 6) {
                    Text("CAPÍTULO \(level.chapterNumber)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(isUnlocked ? HiveTheme.selection : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.4)))
                .overlay(Capsule().stroke(isUnlocked ? HiveTheme.selection.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))

                Spacer()

                if isUnlocked {
                    // Star rating
                    HStack(spacing: 3) {
                        ForEach(1...3, id: \.self) { s in
                            Image(systemName: s <= stars ? "star.fill" : "star")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(s <= stars ? Color(red: 1.0, green: 0.82, blue: 0.28) : Color.white.opacity(0.2))
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Bloqueado")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            // Title and Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(level.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(isUnlocked ? .white : .white.opacity(0.5))

                Text(level.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isUnlocked ? HiveTheme.selection.opacity(0.9) : .secondary)
            }

            // Focus bug chip
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(HiveTheme.selection)

                    Text(level.isPuzzleScenario ? "Enigma Tático • \(level.focusBug.displayName)" : "Batalha Completa")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isUnlocked ? .white : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.35)))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }

            // Narrative text
            Text(level.narrative)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(isUnlocked ? .white.opacity(0.85) : .white.opacity(0.4))
                .lineSpacing(2)

            // Tip badge
            if isUnlocked {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(HiveTheme.selection)
                        .padding(.top, 2)

                    Text(level.tip)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
            }

            // Play CTA
            if isUnlocked {
                Button {
                    Haptics.selection()
                    onSelectLevel(level)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: stars > 0 ? "arrow.clockwise" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(stars > 0 ? "Jogar Novamente" : "Iniciar Capítulo")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(stars > 0 ? Color.white.opacity(0.12) : HiveTheme.selection)
                    )
                    .foregroundStyle(stars > 0 ? .white : .black)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isUnlocked ? (stars > 0 ? Color(red: 1.0, green: 0.82, blue: 0.28).opacity(0.4) : HiveTheme.selection.opacity(0.5)) : Color.white.opacity(0.08), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
        )
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}
