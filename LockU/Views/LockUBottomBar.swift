import SwiftUI
import UIKit

struct LockUBottomBar: View {
    @Binding var selection: LockUTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.locker, title: "Locker", icon: "cabinet.fill")
            cameraButton
            tabButton(.peek, title: "Peek", icon: "eye.fill")
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: 520)
        .frame(height: 60)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
        .background(Color(red: 247/255, green: 247/255, blue: 243/255).opacity(0.90), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.35), lineWidth: 0.5)
        }
        .shadow(color: Color(red: 42/255, green: 52/255, blue: 58/255).opacity(0.045), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func tabButton(_ tab: LockUTab, title: String, icon: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(
                selection == tab
                    ? Color(red: 49/255, green: 67/255, blue: 76/255).opacity(0.92)
                    : Color(red: 125/255, green: 136/255, blue: 141/255).opacity(0.58)
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
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(Color(red: 49/255, green: 67/255, blue: 76/255))
                        .frame(width: 38, height: 38)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color(red: 248/255, green: 247/255, blue: 242/255).opacity(0.94))
                }
                Text("Camera")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(red: 49/255, green: 67/255, blue: 76/255).opacity(0.78))
            }
                .shadow(color: .black.opacity(0.09), radius: 6, y: 3)
                .scaleEffect(selection == .camera ? 1.04 : 1)
                .animation(LockUDesign.Motion.quick, value: selection)
        }
        .frame(maxWidth: .infinity)
        .offset(y: -3)
        .accessibilityLabel("カメラ")
    }
}
