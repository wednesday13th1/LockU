import SwiftUI
import UIKit

struct LockerBottomShelfView: View {
    @EnvironmentObject private var appModel: LockUAppModel

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: max(7, proxy.size.width * 0.02)) {
                VStack(spacing: 5) {
                    LockerBookSpineView(title: monthTitle, color: LockUDesign.Color.mutedLavender)
                    LockerBookSpineView(title: "OUR MOMENTS", color: LockUDesign.Color.paperCream)
                    LockerBookSpineView(title: "MEMORY BOOK", color: LockUDesign.Color.dustBlue)
                }
                .frame(maxWidth: proxy.size.width * 0.63)
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appModel.selectedTab = .book
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Open Memory Book")

                Spacer(minLength: 4)

                LockerCameraButton {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appModel.selectedTab = .camera
                }
                .frame(width: min(82, proxy.size.width * 0.24))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [LockUDesign.Color.shelfCream, .black.opacity(0.38)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 11)
                    .shadow(color: .black.opacity(0.42), radius: 6, y: 4)
            }
        }
    }

    private var monthTitle: String {
        Date.now.formatted(.dateTime.month(.wide).year()).uppercased()
    }
}

struct LockerBookSpineView: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Rectangle().fill(.black.opacity(0.14)).frame(width: 5)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 2)
        }
        .foregroundStyle(LockUDesign.Color.ink)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 28)
        .background(color, in: RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.45)).frame(height: 2).padding(.horizontal, 5)
        }
        .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
    }
}

struct LockerCameraButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LockUDesign.Color.paperCream)
                    .aspectRatio(1.18, contentMode: .fit)
                Circle()
                    .fill(LockUDesign.Color.lockerBlueDark)
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 4))
                Circle()
                    .fill(LockUDesign.Color.warmLight)
                    .frame(width: 9, height: 9)
                    .offset(x: 24, y: -20)
                Capsule()
                    .fill(LockUDesign.Color.ink.opacity(0.7))
                    .frame(width: 18, height: 5)
                    .offset(x: -22, y: -23)
            }
            .shadow(color: .black.opacity(0.28), radius: 5, y: 4)
        }
        .buttonStyle(LockerPressStyle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Camera")
        .accessibilityHint("Opens Camera tab")
    }
}
