import SwiftUI

struct LockerDoor: View {
    let isOpen: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LockUDesign.Color.dustBlue.gradient)
                VStack {
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { _ in
                            Capsule().fill(.black.opacity(0.2)).frame(width: 22, height: 4)
                        }
                    }
                    Spacer()
                    Text("24")
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(LockUDesign.Color.ink.opacity(0.75))
                            .frame(width: 9, height: 46)
                            .padding(.trailing, 18)
                    }
                    Spacer()
                }
                .padding(.vertical, 28)
            }
            .shadow(color: .black.opacity(0.18), radius: 10, x: 2, y: 8)
            .rotation3DEffect(
                .degrees(isOpen ? -104 : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.45
            )
            .opacity(isOpen ? 0.92 : 1)
            .accessibilityHint("Double tap to open or close")
        }
    }
}
