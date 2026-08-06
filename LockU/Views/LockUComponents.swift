import SwiftUI

struct LockUPageBackground: View {
    var body: some View {
        SummerSkyBackground()
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .background(LockUDesign.Color.glassWhite, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.58), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.045), radius: 3, y: 1)
            .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.08), radius: 20, y: 9)
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
