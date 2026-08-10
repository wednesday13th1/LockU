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
        .padding(.horizontal, 10)
        .frame(maxWidth: 520)
        .frame(height: 74)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.32), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 7)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func tabButton(_ tab: LockUTab, title: String, icon: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(
                selection == tab
                    ? Color(red: 41/255, green: 70/255, blue: 93/255)
                    : Color(red: 125/255, green: 147/255, blue: 158/255).opacity(0.72)
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
                    .fill(Color(red: 37/255, green: 45/255, blue: 49/255))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(.white.opacity(0.70), lineWidth: 1.5))
                Image(systemName: "camera.fill")
                    .font(.system(size: 25, weight: .semibold))
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
