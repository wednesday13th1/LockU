import SwiftUI

struct LockerInteriorContent: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lightOn = false
    @State private var shelfVisible = false

    var body: some View {
        GeometryReader { proxy in
            let topShelfHeight = max(54.0, proxy.size.height * 0.14)
            let bottomShelfHeight = max(78.0, proxy.size.height * 0.17)

            VStack(spacing: 0) {
                LockerTopShelfView()
                    .frame(height: topShelfHeight)
                    .opacity(shelfVisible ? 1 : 0)
                    .offset(y: shelfVisible ? 0 : 5)

                LockerMemoryBoardView()
                    .frame(maxHeight: .infinity)

                LockerBottomShelfView()
                    .frame(height: bottomShelfHeight)
                    .opacity(shelfVisible ? 1 : 0)
                    .offset(y: shelfVisible ? 0 : 7)
            }
            .overlay(alignment: .top) {
                LockerLightView(isOn: lightOn)
                    .frame(width: min(proxy.size.width * 0.62, 290), height: proxy.size.height * 0.34)
                    .allowsHitTesting(false)
            }
            .onAppear {
                updateVisibility(for: appModel.lockerDoorState)
            }
            .onChange(of: appModel.lockerDoorState) { _, state in
                updateVisibility(for: state)
            }
        }
    }

    private func updateVisibility(for state: LockerDoorState) {
        let visible = state.isOpenOrOpening
        if reduceMotion {
            lightOn = visible
            shelfVisible = visible
        } else {
            withAnimation(.easeOut(duration: 0.3).delay(visible ? 0.16 : 0)) {
                lightOn = visible
            }
            withAnimation(.easeOut(duration: 0.36).delay(visible ? 0.2 : 0)) {
                shelfVisible = visible
            }
        }
    }
}

private struct LockerLightView: View {
    let isOn: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.clear).frame(height: 2)
            RadialGradient(
                colors: [
                    .white.opacity(isOn ? 0.15 : 0),
                    LockUDesign.Color.sunlight.opacity(isOn ? 0.055 : 0),
                    .clear
                ],
                center: .top,
                startRadius: 8,
                endRadius: 180
            )
        }
        .opacity(isOn ? 1 : 0.35)
    }
}

struct LockerTopShelfView: View {
    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: max(5, proxy.size.width * 0.018)) {
                miniBook("MEMORY", color: Color(red: 104/255, green: 112/255, blue: 116/255))
                    .rotationEffect(.degrees(-1.2))
                miniBook("NOTES", color: Color(red: 129/255, green: 137/255, blue: 139/255))
                    .frame(height: 41, alignment: .bottom)
                    .rotationEffect(.degrees(1.6))
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                shelf
            }
        }
        .accessibilityHidden(true)
    }

    private func miniBook(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white.opacity(0.78))
            .frame(width: 20, height: 46)
            .background(color, in: RoundedRectangle(cornerRadius: 1))
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color(red: 229/255, green: 226/255, blue: 216/255)).frame(width: 3).padding(.vertical, 3)
            }
            .overlay(alignment: .leading) { Rectangle().fill(.black.opacity(0.18)).frame(width: 2) }
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            TrapezoidTopShelf().fill(Color(red: 169/255, green: 176/255, blue: 178/255)).frame(height: 5)
            Rectangle().fill(Color(red: 115/255, green: 124/255, blue: 128/255)).frame(height: 6)
            Rectangle().fill(.black.opacity(0.20)).frame(height: 7).blur(radius: 3)
        }
        .padding(.horizontal, 1.5)
    }
}

private struct TrapezoidTopShelf: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: 2, y: 0)); p.addLine(to: CGPoint(x: r.width-2, y: 0)); p.addLine(to: CGPoint(x: r.width, y: r.height)); p.addLine(to: CGPoint(x: 0, y: r.height)); p.closeSubpath() } }
}
