import SwiftUI

struct PeekView: View {
    @State private var code = ""
    @State private var submittedCode: String?

    var body: some View {
        ScrollView {
            VStack(spacing: LockUDesign.Spacing.large) {
                VStack(spacing: 8) {
                    Text("Peek").font(.largeTitle.bold())
                    Text("A small window into a friend's today.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let submittedCode {
                    preview(code: submittedCode)
                } else {
                    VStack(spacing: 18) {
                        TextField("Locker Code", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.title3.monospaced())
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityLabel("Locker Code")
                        Button("Open Preview") {
                            submittedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(LockUDesign.Color.ink)
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(24)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: LockUDesign.Radius.medium))
                }
            }
            .padding(LockUDesign.Spacing.large)
        }
    }

    private func preview(code: String) -> some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: LockUDesign.Radius.medium)
                .fill(
                    LinearGradient(
                        colors: [LockUDesign.Color.lavender, LockUDesign.Color.softOrange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles").font(.largeTitle)
                        Text("Today's preview")
                            .font(.title2.bold())
                        Text("Locker \(code)")
                            .font(.subheadline.monospaced())
                    }
                    .foregroundStyle(LockUDesign.Color.ink)
                }
            Text("Phase 1 preview")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Try another code") {
                submittedCode = nil
                self.code = ""
            }
        }
    }
}
