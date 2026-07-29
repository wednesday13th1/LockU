import SwiftUI
import UIKit

struct CameraReviewView: View {
    let originalImage: UIImage
    let cutoutImage: UIImage?
    @Binding var selectedStyle: MemoryImageStyle
    let captureMode: CaptureMode
    let isExtracting: Bool
    let isSaving: Bool
    let cutoutErrorMessage: String?
    let onClose: () -> Void
    let onExtractSubject: () -> Void
    let onRetake: () -> Void
    let onSave: () -> Void

    private var displayedImage: UIImage {
        selectedStyle == .cutout ? cutoutImage ?? originalImage : originalImage
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LockUDesign.Color.lockerBlueDark.ignoresSafeArea()
                VStack(spacing: 10) {
                    reviewHeader
                    preview
                        .frame(maxHeight: max(180, proxy.size.height * 0.5))
                    editingControls
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveControls
        }
    }

    private var reviewHeader: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("編集を閉じる")
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY'S MEMORY")
                    .font(.caption.bold())
                Text(Date.now.formatted(date: .long, time: .shortened))
                    .font(.caption2)
            }
            Spacer()
            Label(
                captureMode == .camera ? "Camera" : "Library",
                systemImage: captureMode == .camera ? "camera.fill" : "photo.fill"
            )
            .font(.caption)
        }
        .foregroundStyle(.white)
        .frame(minHeight: 44)
    }

    private var preview: some View {
        ZStack {
            if selectedStyle == .cutout {
                CutoutCheckerboardBackground()
            } else {
                Color.black.opacity(0.18)
            }
            Image(uiImage: displayedImage)
                .resizable()
                .scaledToFit()
                .padding(selectedStyle == .cutout ? 22 : 0)

            if isExtracting {
                Rectangle()
                    .fill(.ultraThinMaterial)
                VStack(spacing: 9) {
                    ProgressView().tint(.white)
                    Text("被写体を探しています…")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .combine)
                .accessibilityValue("処理中")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var editingControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                styleButton(.original, title: "写真")
                styleButton(.cutout, title: "切り抜き")
            }
            .padding(3)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            Button(action: onExtractSubject) {
                HStack {
                    if isExtracting {
                        ProgressView()
                    } else {
                        Image(systemName: "person.crop.rectangle")
                    }
                    Text(isExtracting ? "被写体を探しています…" : "被写体を自動切り抜き")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(LockUDesign.Color.cameraCream)
            .disabled(isExtracting || isSaving)
            .accessibilityLabel("被写体を自動切り抜き")
            .accessibilityValue(isExtracting ? "処理中" : "")

            if let cutoutErrorMessage {
                Label(
                    "\(cutoutErrorMessage) 元の写真はそのまま保存できます。",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(LockUDesign.Color.softOrange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(cutoutErrorMessage)
            } else if cutoutImage != nil {
                Label("透明背景のPNGとして保存できます。", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func styleButton(_ style: MemoryImageStyle, title: String) -> some View {
        Button {
            selectedStyle = style
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedStyle == style ? LockUDesign.Color.ink : .white)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    selectedStyle == style
                        ? LockUDesign.Color.cameraCream
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .disabled(isExtracting || isSaving || (style == .cutout && cutoutImage == nil))
        .accessibilityLabel(style == .original ? "元の写真を表示" : "切り抜き画像を表示")
    }

    private var saveControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                retakeButton
                saveButton
            }
            VStack(spacing: 8) {
                saveButton
                retakeButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LockUDesign.Color.paperCream.opacity(0.96))
    }

    private var retakeButton: some View {
        Button("撮り直す", action: onRetake)
            .buttonStyle(ReviewSecondaryButtonStyle())
            .disabled(isSaving || isExtracting)
            .accessibilityLabel("撮り直す")
    }

    private var saveButton: some View {
        Button(action: onSave) {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Label(
                        selectedStyle == .cutout ? "切り抜きを保存" : "写真を保存",
                        systemImage: "checkmark"
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(ReviewPrimaryButtonStyle())
        .disabled(isSaving || isExtracting)
        .accessibilityLabel(selectedStyle == .cutout ? "切り抜きを保存" : "元の写真を保存")
    }
}

private struct ReviewPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .background(LockUDesign.Color.dustBlue, in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct ReviewSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(LockUDesign.Color.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
