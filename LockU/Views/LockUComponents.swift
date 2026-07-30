import SwiftUI

struct LockUPageBackground: View {
    var body: some View {
        ZStack {
            LockUDesign.Color.backgroundPrimary
            RadialGradient(
                colors: [.white.opacity(0.72), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            LinearGradient(
                colors: [.clear, LockUDesign.Color.warmAccent.opacity(0.035)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [LockUDesign.Color.accent.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

struct LockUSurface<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat = LockUDesign.Radius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                LockUDesign.Color.surface,
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.black.opacity(0.055), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.045), radius: 3, y: 1)
            .shadow(color: .black.opacity(0.08), radius: 14, y: 7)
    }
}

struct LockUStatusCard: View {
    enum Kind {
        case success, warning
    }

    let kind: Kind
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind == .success ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(
                    kind == .success
                        ? LockUDesign.Color.accentDark
                        : LockUDesign.Color.warningBorder
                )
            Text(text)
                .font(LockUDesign.Typography.caption)
                .foregroundStyle(LockUDesign.Color.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            kind == .success
                ? LockUDesign.Color.surface
                : LockUDesign.Color.warningBackground,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    kind == .success
                        ? LockUDesign.Color.accent.opacity(0.15)
                        : LockUDesign.Color.warningBorder.opacity(0.65),
                    lineWidth: 0.8
                )
        }
    }
}

struct LockUPhotoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.black.opacity(0.05), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}
