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
        .padding(.horizontal, 12)
        .frame(maxWidth: 520)
        .frame(height: LockUDesign.bottomBarHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.38), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 7)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabButton(_ tab: LockUTab, title: String, icon: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                Text(title)
                    .font(LockUDesign.Typography.microLabel)
                Circle()
                    .fill(LockUDesign.Color.textPrimary)
                    .frame(width: 4, height: 4)
                    .opacity(selection == tab ? 1 : 0)
            }
            .foregroundStyle(
                selection == tab
                    ? LockUDesign.Color.schoolNavy
                    : LockUDesign.Color.softInkSecondary.opacity(0.75)
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
            ZStack {
                Circle()
                    .fill(LockUDesign.Color.textPrimary)
                    .frame(width: 62, height: 62)
                    .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 2))
                Image(systemName: "camera.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            }
                .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                .scaleEffect(selection == .camera ? 1.04 : 1)
                .animation(LockUDesign.Motion.quick, value: selection)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Camera")
    }
}
