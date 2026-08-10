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
        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.35), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.055), radius: 12, y: 5)
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
                    .fill(Color(red: 34/255, green: 137/255, blue: 232/255))
                    .frame(width: 62, height: 62)
                Image(systemName: "camera.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            }
                .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
                .scaleEffect(selection == .camera ? 1.04 : 1)
                .animation(LockUDesign.Motion.quick, value: selection)
        }
        .frame(maxWidth: .infinity)
        .offset(y: -12)
        .accessibilityLabel("Camera")
    }
}
