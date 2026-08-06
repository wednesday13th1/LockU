import SwiftUI

struct PeekView: View {
    @State private var code = ""
    @State private var hasStarted = false
    @State private var submittedCode: String?

    var body: some View {
        ZStack {
            LockUPageBackground()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Label("Peek", systemImage: "eye.fill")
                            .font(LockUDesign.Typography.screenTitle)
                        Text("今日のロッカーをのぞいてみよう")
                            .font(LockUDesign.Typography.body)
                    }
                    .foregroundStyle(LockUDesign.Color.schoolNavy)
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
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var invitationCard: some View {
        SummerGlassCard {
            VStack(spacing: 18) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LockUDesign.Color.ramuneBlue)
                Text("誰かの青春を\n少しだけ覗いてみる")
                    .font(LockUDesign.Typography.screenTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LockUDesign.Color.schoolNavy)
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
        SummerGlassCard {
            VStack(spacing: 16) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(LockUDesign.Color.ramuneBlue)
                Text("友だちから届いたコードを入力してね")
                    .font(LockUDesign.Typography.sectionTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LockUDesign.Color.schoolNavy)
                TextField("LOCK-24", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.title3.monospaced())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.75)))
                    .accessibilityLabel("Locker Code")
                Button("ロッカーをのぞく") {
                    submittedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .buttonStyle(LockUPrimaryButtonStyle())
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("コードは友だちの共有画面に表示されています")
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.softInkSecondary)
            }
            .padding(24)
        }
    }

    private func preview(code: String) -> some View {
        SummerGlassCard {
            VStack(spacing: 15) {
                Image(systemName: "eye.fill")
                    .font(.title2)
                    .foregroundStyle(LockUDesign.Color.ramuneBlue)
                Text("TODAY’S PREVIEW")
                    .font(LockUDesign.Typography.caption)
                    .tracking(2)
                Text("Locker \(code)")
                    .font(LockUDesign.Typography.screenTitle)
                Text("by Haru")
                    .font(LockUDesign.Typography.body)
                    .foregroundStyle(LockUDesign.Color.softInkSecondary)
                VStack(spacing: 8) {
                    LinearGradient(
                        colors: [
                            LockUDesign.Color.summerSkyTop,
                            LockUDesign.Color.sunsetPeach.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 68))
                            .foregroundStyle(.white.opacity(0.78))
                            .padding()
                    }
                    .aspectRatio(4 / 3, contentMode: .fit)
                    Text("夏休みまであと3日")
                        .font(LockUDesign.Typography.caption)
                        .foregroundStyle(LockUDesign.Color.softInk)
                }
                .padding(10)
                .background(LockUDesign.Color.notebookPaper)
                .rotationEffect(.degrees(-1))
                .shadow(color: LockUDesign.Color.schoolNavy.opacity(0.1), radius: 8, y: 4)
                Button("このロッカーをのぞく") {}
                    .buttonStyle(LockUPrimaryButtonStyle())
                Button("別のコードを試す") {
                    submittedCode = nil
                    self.code = ""
                }
                .buttonStyle(LockUSecondaryButtonStyle())
            }
            .foregroundStyle(LockUDesign.Color.schoolNavy)
            .padding(24)
        }
    }
}
