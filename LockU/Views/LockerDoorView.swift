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
                        .frame(width: 40, height: 40)
                        .background(LockUDesign.Color.surface.opacity(0.9), in: Circle())
                        .overlay(Circle().stroke(.black.opacity(0.06)))
                        .foregroundStyle(LockUDesign.Color.textPrimary)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
                .position(x: proxy.size.width - 20, y: 20)
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
                            LockUDesign.Color.lockerSummerBlueLight,
                            LockUDesign.Color.lockerSummerBlue,
                            LockUDesign.Color.lockerSummerBlueDark
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            LinearGradient(
                colors: [.white.opacity(0.26), .clear, .black.opacity(0.12)],
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
                .frame(width: min(124, size.width * 0.44), height: 64)
                HandwrittenMemoView(text: "放課後、またね")
                    .frame(width: min(142, size.width * 0.46))
                    .rotationEffect(.degrees(-1.5))
                Spacer()
                HStack {
                    Capsule()
                        .fill(LockUDesign.Color.lockerEdge)
                        .frame(width: 10, height: 48)
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

        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(LockUDesign.Color.lockerEdge.opacity(0.24)))
        .overlay(alignment: .leading) {
            Rectangle().fill(.white.opacity(0.22)).frame(width: 2).padding(.vertical, 8)
        }
        .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.12), radius: 20, y: 10)
    }

    private var ventilationSlits: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { _ in
                Capsule().fill(LockUDesign.Color.lockerEdge.opacity(0.48)).frame(width: 18, height: 3)
            }
        }
    }

    private var hinge: some View {
        Capsule()
            .fill(
                LockUDesign.Color.lockerEdge.opacity(0.7)
            )
            .frame(width: 10, height: 30)
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

private struct HandwrittenMemoView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(LockUDesign.Color.softInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(LockUDesign.Color.notebookPaper)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(LockUDesign.Color.sunlight.opacity(0.52))
                    .frame(width: 48, height: 10)
                    .offset(y: -5)
            }
            .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.08), radius: 4, y: 2)
    }
}

struct LockerDoorInteriorView: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [LockUDesign.Color.lockerBodyLight, LockUDesign.Color.lockerBody],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            VStack(spacing: 18) {
                Circle()
                    .fill(.white.opacity(0.75))
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 4))
                    .frame(width: 86, height: 86)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
                VStack(spacing: 5) {
                    Text("MON  TUE  WED  THU  FRI")
                    Text(" 1    2    3    4    5")
                }
                .font(.system(size: 8, design: .monospaced))
                .padding(9)
                .background(LockUDesign.Color.paperCream, in: RoundedRectangle(cornerRadius: 3))
                HStack(spacing: 5) {
                    ForEach(["person.crop.square", "photo"], id: \.self) { symbol in
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
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
            }
            .foregroundStyle(LockUDesign.Color.ink)
            .padding(30)
        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.08), lineWidth: 1))
    }
}
