import SwiftUI

struct LockerInteriorContent: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lightOn = false
    @State private var shelfVisible = false

    var body: some View {
        GeometryReader { proxy in
            let topShelfHeight = max(72.0, proxy.size.height * 0.17)
            let bottomShelfHeight = max(104.0, proxy.size.height * 0.22)

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
                        colors: [.white, LockUDesign.Color.warmLight, .black.opacity(0.25)],
                        center: .center,
                        startRadius: 1,
                        endRadius: 10
                    )
                )
                .frame(width: 20, height: 20)
                .shadow(color: LockUDesign.Color.warmLight.opacity(isOn ? 0.8 : 0), radius: 10)
            RadialGradient(
                colors: [
                    LockUDesign.Color.warmLight.opacity(isOn ? 0.28 : 0),
                    LockUDesign.Color.warmLight.opacity(isOn ? 0.08 : 0),
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
                miniBook("MEMORY", color: LockUDesign.Color.mutedLavender)
                miniBook("NOTES", color: LockUDesign.Color.paperCream)
                Spacer(minLength: 4)
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(LockUDesign.Color.ink)
                    .padding(7)
                    .background(LockUDesign.Color.paperCream, in: RoundedRectangle(cornerRadius: 2))
                    .rotationEffect(.degrees(2))
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green.opacity(0.65))
                    .frame(width: 34, height: 35)
                    .background(LockUDesign.Color.shelfCream.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
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
                    colors: [LockUDesign.Color.shelfCream, .black.opacity(0.32)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 8)
            .shadow(color: .black.opacity(0.35), radius: 5, y: 4)
    }
}
