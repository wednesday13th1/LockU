import SwiftUI

struct InteractiveLocker: View {
    @Binding var isOpen: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LockerInterior()
                LockerDoor(isOpen: isOpen)
            }
            .frame(width: min(size.width * 0.82, 310), height: size.height * 0.94)
            .position(x: size.width / 2, y: size.height / 2)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                    isOpen.toggle()
                }
            }
        }
    }
}
