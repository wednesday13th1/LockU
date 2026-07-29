import SwiftUI

struct LockUBottomBar: View {
    @Binding var selection: LockUTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.locker, title: "Locker", icon: "cabinet.fill")
            tabButton(.book, title: "Book", icon: "book.closed.fill")
            cameraButton
            tabButton(.peek, title: "Peek", icon: "eye.fill")
        }
        .padding(.horizontal, LockUDesign.Spacing.small)
        .frame(maxWidth: 520)
        .frame(height: LockUDesign.bottomBarHeight)
        .background(LockUDesign.Color.paperCream.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: LockUDesign.Shadow.floating, radius: 16, y: 7)
        .padding(.horizontal, LockUDesign.Spacing.medium)
        .padding(.bottom, LockUDesign.Spacing.small)
    }

    private func tabButton(_ tab: LockUTab, title: String, icon: String) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(selection == tab ? LockUDesign.Color.ink : .secondary)
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(title)
    }

    private var cameraButton: some View {
        Button {
            selection = .camera
        } label: {
            Image(systemName: "camera.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(LockUDesign.Color.cream)
                .frame(width: 56, height: 56)
                .background(LockUDesign.Color.lockerBlue, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                .scaleEffect(selection == .camera ? 1.08 : 1)
                .animation(.snappy, value: selection)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Camera")
    }
}
