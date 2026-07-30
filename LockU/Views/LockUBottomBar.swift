import SwiftUI
import UIKit

struct LockUBottomBar: View {
    @Binding var selection: LockUTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.locker, title: "Locker", icon: "cabinet.fill")
            tabButton(.book, title: "Memories", icon: "book.closed.fill")
            cameraButton
            tabButton(.peek, title: "Peek", icon: "eye.fill")
        }
        .padding(.horizontal, LockUDesign.Spacing.small)
        .frame(maxWidth: 520)
        .frame(height: LockUDesign.bottomBarHeight)
        .background(LockUDesign.Color.surfaceTranslucent, in: RoundedRectangle(cornerRadius: 24))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 12, y: -2)
        .padding(.horizontal, LockUDesign.Spacing.medium)
        .padding(.bottom, LockUDesign.Spacing.small)
    }

    private func tabButton(_ tab: LockUTab, title: String, icon: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(title)
                    .font(LockUDesign.Typography.microLabel)
                Circle()
                    .fill(LockUDesign.Color.textPrimary)
                    .frame(width: 3, height: 3)
                    .opacity(selection == tab ? 1 : 0)
            }
            .foregroundStyle(
                selection == tab
                    ? LockUDesign.Color.textPrimary
                    : LockUDesign.Color.textSecondary
            )
            .scaleEffect(selection == tab ? 1.03 : 1)
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(title)
    }

    private var cameraButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selection = .camera
        } label: {
            Image(systemName: "camera.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(LockUDesign.Color.cream)
                .frame(width: 58, height: 58)
                .background(LockUDesign.Color.accent, in: Circle())
                .overlay(Circle().stroke(LockUDesign.Color.cameraCream, lineWidth: 3))
                .scaleEffect(selection == .camera ? 1.04 : 1)
                .animation(LockUDesign.Motion.quick, value: selection)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Camera")
    }
}
