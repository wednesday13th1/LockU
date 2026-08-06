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
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(.white.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.08), radius: 24, y: 10)
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
                    .fill(LockUDesign.Color.ramuneBlue)
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
                    .fill(LockUDesign.Color.ramuneBlue.opacity(0.2))
                    .frame(width: 66, height: 66)
                    .blur(radius: 8)
                Circle()
                    .fill(LockUDesign.Color.ramuneBlue)
                    .frame(width: 62, height: 62)
                    .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 2))
                Image(systemName: "camera.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            }
                .shadow(color: LockUDesign.Color.ramuneBlue.opacity(0.22), radius: 10, y: 4)
                .scaleEffect(selection == .camera ? 1.04 : 1)
                .animation(LockUDesign.Motion.quick, value: selection)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Camera")
    }
}
