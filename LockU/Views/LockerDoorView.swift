import SwiftUI
import UIKit

struct LockerDoorView: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @EnvironmentObject private var editingCoordinator: LockerCanvasEditingCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var customizationCoordinator: LockerCustomizationCoordinator
    @State private var doorAngle = 0.0
    @State private var doorForwardOffset = 0.0

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
                LinearGradient(colors: [.black.opacity(0.34), .black.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                    .opacity(isOpen ? 0.08 : 0.72)
                    .offset(x: isOpen ? proxy.size.width * 0.32 : 0)
                    .animation(.easeOut(duration: 0.52), value: isOpen)
                    .allowsHitTesting(false)
                doorFront(size: proxy.size)
                    .opacity(isOpen ? 0 : 1)
            }
            .padding(.horizontal, proxy.size.width * 0.03)
            .padding(.vertical, 9)
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : doorAngle),
                axis: (x: 0, y: 1, z: 0),
                anchor: .trailing,
                anchorZ: doorForwardOffset,
                perspective: 0.52
            )
            .offset(x: doorForwardOffset)
            .opacity(reduceMotion && isOpen ? 0 : 1)
            .allowsHitTesting(appModel.lockerDoorState.acceptsInput && !editingCoordinator.isEditing)
            .contentShape(Rectangle())
            .gesture(
                !editingCoordinator.isEditing && !customizationCoordinator.isEditing
                    ? TapGesture().onEnded { toggleDoor() }
                    : nil
            )
            .accessibilityLabel(isOpen ? "ロッカーを閉じる" : "ロッカーを開く")
            .accessibilityAddTraits(.isButton)
            .onAppear { doorAngle = isOpen ? -96 : 0 }
            .onChange(of: isOpen) { _, opening in
                animateDoor(opening: opening)
            }

            if appModel.lockerDoorState == .open
                && !editingCoordinator.isEditing
                && !customizationCoordinator.isEditing {
                Button {
                    toggleDoor()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 40, height: 40)
                        .background(.thinMaterial, in: Circle())
                        .background(.white.opacity(0.78), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.40), lineWidth: 0.5))
                        .foregroundStyle(LockUDesign.Color.textPrimary)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                }
                .position(x: proxy.size.width - 20, y: 20)
                .accessibilityLabel("ロッカーを閉じる")
            }
        }
    }

    private func doorFront(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(lockerColor)
            LinearGradient(
                colors: [.white.opacity(0.18), .clear, Color.blue.opacity(0.025), .black.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LockerMetalTexture()
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .clear, LockUDesign.Color.lockerWornEdge.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .padding(5)
            VStack {
                pressedSeam
                Spacer()
                pressedSeam
            }
            .padding(.vertical, 15)
            HStack {
                screwColumn
                Spacer()
                screwColumn
            }
            .padding(.horizontal, 9)
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
                    RoundedRectangle(cornerRadius: 2)
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

            LockerDecorationLayer(
                isEditing: customizationCoordinator.isEditing && customizationCoordinator.mode == .door
            )
            .padding(18)

        }
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(LockUDesign.Color.lockerEdge.opacity(0.24)))
        .overlay(alignment: .leading) {
            Rectangle().fill(.white.opacity(0.22)).frame(width: 2).padding(.vertical, 8)
        }
        .overlay(alignment: .trailing) {
            HStack(spacing: 0) {
                Rectangle().fill(.black.opacity(0.20)).frame(width: 2)
                LinearGradient(colors: [LockUDesign.Color.deepMetal, LockUDesign.Color.darkCavity], startPoint: .leading, endPoint: .trailing).frame(width: 6)
            }.padding(.vertical, 3)
        }
        .shadow(color: .black.opacity(0.20), radius: 13, y: 10)
    }

    private var ventilationSlits: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { _ in
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 1).fill(Color(red: 65/255, green: 72/255, blue: 75/255)).frame(width: 18, height: 3)
                    Rectangle().fill(.white.opacity(0.22)).frame(width: 16, height: 0.5)
                }
            }
        }
    }

    private var hinge: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(LinearGradient(colors: [.white.opacity(0.35), LockUDesign.Color.midMetal, LockUDesign.Color.deepMetal], startPoint: .leading, endPoint: .trailing))
            .frame(width: 10, height: 30)
            .overlay(alignment: .bottom) {
                Ellipse()
                    .fill(SwiftUI.Color(red: 0.34, green: 0.29, blue: 0.26).opacity(0.07))
                    .frame(width: 8, height: 4)
            }
    }

    private var pressedSeam: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        LockUDesign.Color.lockerWornEdge.opacity(0.38),
                        .white.opacity(0.2),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 2)
            .padding(.horizontal, 12)
    }

    private var screwColumn: some View {
        VStack {
            metalScrew
            Spacer()
            metalScrew
        }
        .padding(.vertical, 4)
    }

    private var metalScrew: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white.opacity(0.78), LockUDesign.Color.lockerWornEdge],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 4
                )
            )
            .frame(width: 4, height: 4)
            .overlay(Rectangle().fill(.black.opacity(0.32)).frame(width: 2.5, height: 0.5))
            .overlay {
                Circle()
                    .stroke(
                        SwiftUI.Color(red: 0.34, green: 0.29, blue: 0.26).opacity(0.06),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.28), radius: 1, y: 1)
    }

    private func toggleDoor() {
        guard !editingCoordinator.isEditing, !customizationCoordinator.isEditing else { return }
        guard appModel.lockerDoorState.acceptsInput else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let opening = appModel.lockerDoorState == .closed
        appModel.lockerDoorState = opening ? .opening : .closing

        Task {
            let delay: UInt64 = reduceMotion ? 180_000_000 : 520_000_000
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            guard !editingCoordinator.isEditing else {
                appModel.lockerDoorState = .open
                return
            }
            appModel.lockerDoorState = opening ? .open : .closed
        }
    }

    private func animateDoor(opening: Bool) {
        guard !reduceMotion else {
            doorAngle = opening ? -96 : 0
            doorForwardOffset = 0
            return
        }
        withAnimation(.easeOut(duration: opening ? 0.52 : 0.48)) {
            doorAngle = opening ? -96 : 0
            doorForwardOffset = 0
        }
    }
}

private struct LockerMetalTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<32 {
                let y = CGFloat((index * 41) % 97) / 97 * size.height
                let width = CGFloat(10 + (index * 17) % 42)
                let x = CGFloat((index * 61) % 100) / 100 * max(size.width - width, 1)
                var stroke = Path()
                stroke.move(to: CGPoint(x: x, y: y))
                stroke.addLine(to: CGPoint(x: x + width, y: y + CGFloat(index % 3 - 1)))
                context.stroke(
                    stroke,
                    with: .color(index.isMultiple(of: 3) ? .white.opacity(0.055) : .black.opacity(0.035)),
                    lineWidth: 0.6
                )
            }
            for index in 0..<18 {
                let x = CGFloat((index * 37) % 93) / 93 * size.width
                let y = CGFloat((index * 59) % 91) / 91 * size.height
                var handScratch = Path()
                handScratch.move(to: CGPoint(x: x, y: y))
                handScratch.addLine(
                    to: CGPoint(
                        x: x + CGFloat(index.isMultiple(of: 4) ? 9 : 2),
                        y: y + CGFloat(index.isMultiple(of: 4) ? 1 : 14)
                    )
                )
                context.stroke(
                    handScratch,
                    with: .color(LockUDesign.Color.lockerEdgeHighlight.opacity(0.075)),
                    lineWidth: 0.65
                )
            }
            for index in 0..<7 {
                let x = CGFloat((index * 67) % 91) / 91 * size.width
                let y = CGFloat((index * 43) % 89) / 89 * size.height
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 2.2, height: 1.2)),
                    with: .color(.black.opacity(0.045))
                )
            }
            for index in 0..<8 {
                let onRightEdge = index.isMultiple(of: 2)
                let x = onRightEdge ? size.width - 3 : 2
                let y = 18 + CGFloat(index) * max((size.height - 36) / 8, 1)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.8, height: 1.2)),
                    with: .color(LockUDesign.Color.lockerEdgeHighlight.opacity(0.38))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HandwrittenMemoView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(LockUDesign.Color.softInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(LockUDesign.Color.notebookPaper)
            .overlay(alignment: .top) {
                UnevenTapeShape()
                    .fill(LockUDesign.Color.sunlight.opacity(0.52))
                    .frame(width: 48, height: 10)
                    .offset(y: -5)
            }
            .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.08), radius: 4, y: 2)
    }
}

private struct UnevenTapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct LockerDoorInteriorView: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(colors: [LockUDesign.Color.lockerBodyLight, LockUDesign.Color.lockerSilver, LockUDesign.Color.deepMetal], startPoint: .topLeading, endPoint: .bottomTrailing)
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
