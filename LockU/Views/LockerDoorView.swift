import SwiftUI
import UIKit

struct LockerDoorView: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOpen: Bool { appModel.lockerDoorState.isOpenOrOpening }
    private var lockerColor: Color {
        Color(
            lockUHex: settingsRepository.settings.lockerColorHex,
            fallback: LockUDesign.Color.dustBlue
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LockerDoorInteriorView(color: lockerColor)
                    .opacity(isOpen ? 1 : 0)
                doorFront(size: proxy.size)
                    .opacity(isOpen ? 0 : 1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (isOpen ? -92 : 0)),
                axis: (x: 0, y: 1, z: 0),
                anchor: .trailing,
                anchorZ: 0,
                perspective: 0.75
            )
            .opacity(reduceMotion && isOpen ? 0 : 1)
            .animation(reduceMotion ? LockUDesign.Motion.soft : LockUDesign.Motion.door, value: isOpen)
            .allowsHitTesting(appModel.lockerDoorState.acceptsInput)
            .contentShape(Rectangle())
            .onTapGesture { toggleDoor() }
            .accessibilityLabel(isOpen ? "ロッカーを閉じる" : "ロッカーを開く")
            .accessibilityAddTraits(.isButton)

            if appModel.lockerDoorState == .open {
                Button {
                    toggleDoor()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                        .foregroundStyle(.white)
                }
                .position(x: proxy.size.width - 38, y: 38)
                .accessibilityLabel("ロッカーを閉じる")
            }
        }
    }

    private func doorFront(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [
                            lockerColor.opacity(0.84),
                            lockerColor,
                            lockerColor.opacity(0.68)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            LinearGradient(
                colors: [.white.opacity(0.2), .clear, .black.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack {
                ventilationSlits
                Spacer()
                LockerNamePlateView(
                    number: settingsRepository.settings.lockerNumber,
                    ownerName: settingsRepository.settings.ownerName
                )
                .frame(width: min(154, size.width * 0.38))
                Spacer()
                HStack {
                    VStack(spacing: 7) {
                        Circle()
                            .fill(LockUDesign.Color.ink.opacity(0.78))
                            .frame(width: 47, height: 47)
                            .overlay {
                                Circle().stroke(.white.opacity(0.45), lineWidth: 2)
                                Text("0")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                        Capsule()
                            .fill(LockUDesign.Color.ink.opacity(0.75))
                            .frame(width: 12, height: 54)
                    }
                    Spacer()
                    VStack(spacing: 32) {
                        hinge
                        hinge
                        hinge
                    }
                }
                .padding(.horizontal, 18)
                Spacer()
                ventilationSlits
            }
            .padding(.vertical, 24)

            sticker(symbol: "star.fill", color: LockUDesign.Color.warmLight)
                .position(x: size.width * 0.25, y: size.height * 0.7)
            sticker(symbol: "heart.fill", color: LockUDesign.Color.softOrange)
                .position(x: size.width * 0.72, y: size.height * 0.3)
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.17)))
        .shadow(color: LockUDesign.Shadow.deep, radius: 10, x: -3, y: 7)
    }

    private var ventilationSlits: some View {
        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { _ in
                Capsule().fill(.black.opacity(0.28)).frame(width: 25, height: 4)
            }
        }
    }

    private var hinge: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.45), .black.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 10, height: 30)
    }

    private func sticker(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    private func toggleDoor() {
        guard appModel.lockerDoorState.acceptsInput else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let opening = appModel.lockerDoorState == .closed
        appModel.lockerDoorState = opening ? .opening : .closing

        Task {
            let delay: UInt64 = reduceMotion ? 180_000_000 : 560_000_000
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            appModel.lockerDoorState = opening ? .open : .closed
        }
    }
}

struct LockerDoorInteriorView: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.72), color.opacity(0.52)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            VStack(spacing: 18) {
                Circle()
                    .fill(.white.opacity(0.75))
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 4))
                    .frame(width: 86, height: 86)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 3)
                VStack(spacing: 5) {
                    Text("MON  TUE  WED  THU  FRI")
                    Text(" 1    2    3    4    5")
                }
                .font(.system(size: 8, design: .monospaced))
                .padding(9)
                .background(LockUDesign.Color.paperCream, in: RoundedRectangle(cornerRadius: 3))
                HStack(spacing: 5) {
                    ForEach(["person.crop.square", "heart.fill", "star.fill"], id: \.self) { symbol in
                        Image(systemName: symbol)
                            .frame(width: 34, height: 44)
                            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 2))
                    }
                }
                Spacer()
                HStack {
                    Image(systemName: "pencil.and.scribble")
                    Spacer()
                    Image(systemName: "key.fill")
                        .rotationEffect(.degrees(28))
                }
                .font(.title2)
                .padding()
                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            }
            .foregroundStyle(LockUDesign.Color.ink)
            .padding(30)
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.22), lineWidth: 2))
    }
}
