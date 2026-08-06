import SwiftUI

struct LockerInteriorContent: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lightOn = false
    @State private var shelfVisible = false

    var body: some View {
        GeometryReader { proxy in
            let topShelfHeight = max(54.0, proxy.size.height * 0.15)
            let bottomShelfHeight = max(82.0, proxy.size.height * 0.19)

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
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, LockUDesign.Color.warmLight.opacity(0.7)],
                        center: .center,
                        startRadius: 1,
                        endRadius: 10
                    )
                )
                .frame(width: 20, height: 20)
                .shadow(color: LockUDesign.Color.warmLight.opacity(isOn ? 0.18 : 0), radius: 6)
            RadialGradient(
                colors: [
                    LockUDesign.Color.warmLight.opacity(isOn ? 0.18 : 0),
                    LockUDesign.Color.warmLight.opacity(isOn ? 0.04 : 0),
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
                miniBook("MEMORY", color: LockUDesign.Color.mutedLavender.opacity(0.8))
                miniBook("NOTES", color: LockUDesign.Color.paper)
                Spacer(minLength: 4)
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(LockUDesign.Color.ink)
                    .padding(7)
                    .background(LockUDesign.Color.paperCream, in: RoundedRectangle(cornerRadius: 2))
                    .rotationEffect(.degrees(2))
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
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(LockUDesign.Color.ink)
            .frame(width: 24, height: 45)
            .background(color, in: RoundedRectangle(cornerRadius: 2))
    }

    private var shelf: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [LockUDesign.Color.paper, LockUDesign.Color.shelfWarm],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 8)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
    }
}
