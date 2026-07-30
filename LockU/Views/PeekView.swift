import SwiftUI

struct PeekView: View {
    @State private var code = ""
    @State private var hasStarted = false
    @State private var submittedCode: String?

    var body: some View {
        ZStack {
            LockUPageBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Text("Peek")
                        .font(LockUDesign.Typography.screenTitle)
                        .foregroundStyle(LockUDesign.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)

                    if let submittedCode {
                        preview(code: submittedCode)
                    } else if hasStarted {
                        codeEntry
                    } else {
                        invitationCard
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var invitationCard: some View {
        LockUSurface(cornerRadius: 22) {
            VStack(spacing: 18) {
                Text("New!")
                    .font(LockUDesign.Typography.microLabel)
                    .foregroundStyle(LockUDesign.Color.accentDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(LockUDesign.Color.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                Text("ともだちのロッカーを\nのぞいてみよう")
                    .font(LockUDesign.Typography.screenTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LockUDesign.Color.textPrimary)
                avatarStack
                Button("はじめる") {
                    withAnimation(.easeInOut(duration: 0.22)) { hasStarted = true }
                }
                .buttonStyle(LockUPrimaryButtonStyle())
            }
            .padding(24)
        }
    }

    private var avatarStack: some View {
        HStack(spacing: -9) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(avatarColor(index))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(LockUDesign.Color.textSecondary)
                    )
                    .overlay(Circle().stroke(LockUDesign.Color.surface, lineWidth: 3))
            }
        }
        .accessibilityLabel("友達3人")
    }

    private func avatarColor(_ index: Int) -> Color {
        switch index {
        case 0: return LockUDesign.Color.accentSoft
        case 1: return LockUDesign.Color.mutedLavender.opacity(0.55)
        default: return LockUDesign.Color.warmAccent.opacity(0.35)
        }
    }

    private var codeEntry: some View {
        LockUSurface(cornerRadius: 22) {
            VStack(spacing: 16) {
                Text("Locker Code")
                    .font(LockUDesign.Typography.sectionTitle)
                TextField("コードを入力", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.title3.monospaced())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        LockUDesign.Color.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityLabel("Locker Code")
                Button("ロッカーをのぞく") {
                    submittedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .buttonStyle(LockUPrimaryButtonStyle())
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
        }
    }

    private func preview(code: String) -> some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            LockUDesign.Color.accentSoft,
                            LockUDesign.Color.backgroundPrimary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "eye.fill").font(.title)
                        Text("Today’s preview")
                            .font(LockUDesign.Typography.screenTitle)
                        Text("Locker \(code)")
                            .font(.subheadline.monospaced())
                    }
                    .foregroundStyle(LockUDesign.Color.textPrimary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.black.opacity(0.05), lineWidth: 0.8)
                }
            Button("別のコードを試す") {
                submittedCode = nil
                self.code = ""
            }
            .buttonStyle(LockUSecondaryButtonStyle())
        }
    }
}
