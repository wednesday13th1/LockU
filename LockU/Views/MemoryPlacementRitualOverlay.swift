import SwiftUI
import UIKit

struct MemoryPlacementRitualOverlay: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            if let ritual = appModel.placementRitual {
                let destination = ritual.destination
                let finalFrame = destination?.frame ?? CGRect(
                    x: proxy.size.width * 0.285,
                    y: proxy.size.height * 0.30,
                    width: proxy.size.width * 0.43,
                    height: proxy.size.width * 0.52
                )
                let isAtDestination = reduceMotion || ritual.phase == .moving || ritual.phase == .settling || ritual.phase == .completed
                let startWidth = min(proxy.size.width * 0.78, 520)
                let startHeight = min(proxy.size.height * 0.56, startWidth * 1.18)

                ritualPrint(ritual, frameStyle: destination?.frameStyle ?? .polaroid)
                    .frame(
                        width: isAtDestination ? finalFrame.width : startWidth,
                        height: isAtDestination ? finalFrame.height : startHeight
                    )
                    .rotationEffect(.degrees(isAtDestination ? destination?.rotationDegrees ?? 0 : 0))
                    .scaleEffect(ritual.phase == .moving ? 1.015 : 1)
                    .position(
                        x: isAtDestination ? finalFrame.midX : proxy.size.width / 2,
                        y: isAtDestination ? finalFrame.midY : proxy.size.height / 2
                    )
                    .opacity(reduceMotion && ritual.phase == .preparing ? 0.25 : 1)
                    .shadow(
                        color: .black.opacity(ritual.phase == .moving ? 0.16 : 0.09),
                        radius: ritual.phase == .moving ? 7 : 4,
                        y: ritual.phase == .moving ? 4 : 2
                    )
                    .allowsHitTesting(false)
                    .task(id: ritual.id) { await run(sessionID: ritual.id) }
            }
        }
        .ignoresSafeArea()
        .background(Color.clear.contentShape(Rectangle()))
        .allowsHitTesting(true)
        .accessibilityHidden(true)
    }

    private func ritualPrint(_ ritual: MemoryPlacementRitualSession, frameStyle: LockerFrameStyle) -> some View {
        ZStack(alignment: .topLeading) {
            if ritual.phase != .preparing, frameStyle != .borderless {
                Color(red: 247/255, green: 244/255, blue: 236/255)
            }
            Image(uiImage: ritual.image)
                .resizable()
                .scaledToFill()
                .padding(ritual.phase == .preparing || frameStyle == .borderless ? 0 : frameStyle == .polaroid || frameStyle == .mixed ? 7 : 3)
                .padding(.bottom, ritual.phase == .preparing ? 0 : frameStyle == .polaroid || frameStyle == .mixed ? 24 : 0)
                .clipped()
            if ritual.phase != .preparing {
                if let emoji = ritual.moodEmoji {
                    Text(emoji)
                        .font(.system(size: 17))
                        .opacity(0.92)
                        .shadow(color: .black.opacity(0.07), radius: 1, y: 0.5)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                Text(ritual.createdAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits)))
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(frameStyle == .borderless ? Color.white.opacity(0.86) : LockUDesign.Color.schoolNavy.opacity(0.62))
                    .padding(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ritual.phase == .preparing ? 18 : 3, style: .continuous))
    }

    @MainActor private func run(sessionID: UUID) async {
        do {
            try await waitForDestination(sessionID: sessionID)
            guard appModel.placementRitual?.id == sessionID else { return }
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.16)) { appModel.setPlacementRitualPhase(.paperizing, sessionID: sessionID) }
                try await Task.sleep(for: .milliseconds(160))
                withAnimation(.easeOut(duration: 0.22)) { appModel.setPlacementRitualPhase(.settling, sessionID: sessionID) }
                try await Task.sleep(for: .milliseconds(220))
            } else {
                withAnimation(.easeOut(duration: 0.18)) { appModel.setPlacementRitualPhase(.paperizing, sessionID: sessionID) }
                try await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeInOut(duration: 0.34)) { appModel.setPlacementRitualPhase(.moving, sessionID: sessionID) }
                try await Task.sleep(for: .milliseconds(340))
                withAnimation(.easeOut(duration: 0.12)) { appModel.setPlacementRitualPhase(.settling, sessionID: sessionID) }
                try await Task.sleep(for: .milliseconds(120))
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            UIAccessibility.post(notification: .announcement, argument: "今日のMemoryをロッカーに残しました")
            appModel.setPlacementRitualPhase(.completed, sessionID: sessionID)
            try await Task.sleep(for: .milliseconds(100))
            appModel.completePlacementRitual(sessionID: sessionID)
        } catch {
            appModel.completePlacementRitual(sessionID: sessionID)
        }
    }

    @MainActor private func waitForDestination(sessionID: UUID) async throws {
        for _ in 0..<12 {
            guard appModel.placementRitual?.id == sessionID else { throw CancellationError() }
            if appModel.placementRitual?.destination != nil { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw CancellationError()
    }
}
