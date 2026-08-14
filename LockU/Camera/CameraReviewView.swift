import SwiftUI
import UIKit

struct CameraReviewView: View {
    let originalImage: UIImage
    let cutoutImage: UIImage?
    @Binding var selectedStyle: MemoryImageStyle
    @Binding var selectedMoodEmoji: MemoryMoodEmoji?
    @Binding var memoryNote: String
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
                LockUPageBackground()
                VStack(spacing: 0) {
                    reviewHeader.padding(.horizontal, 16)
                    ScrollView {
                        VStack(spacing: 12) {
                            preview
                                .frame(minHeight: 220, maxHeight: max(250, proxy.size.height * 0.48))
                            editingControls
                            MemoryExpressionEditor(
                                selectedMoodEmoji: $selectedMoodEmoji,
                                memoryNote: $memoryNote
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
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
            }
            .buttonStyle(LockUIconButtonStyle())
            .accessibilityLabel("編集を閉じる")
            Spacer()
            VStack(spacing: 2) {
                Text("今日の思い出")
                    .font(LockUDesign.Typography.bodyEmphasized)
                Text(Date.now.formatted(date: .long, time: .shortened))
                    .font(LockUDesign.Typography.microLabel)
            }
            Spacer()
            Image(systemName: captureMode == .camera ? "camera.fill" : "photo.fill")
                .frame(width: 44, height: 44)
                .accessibilityLabel(captureMode == .camera ? "Camera" : "Library")
        }
        .foregroundStyle(LockUDesign.Color.textPrimary)
        .frame(minHeight: 52)
    }

    private var preview: some View {
        ZStack {
            if selectedStyle == .cutout {
                CutoutCheckerboardBackground()
            } else {
                Color.black.opacity(0.03)
            }
            Image(uiImage: displayedImage)
                .resizable()
                .scaledToFit()
                .padding(selectedStyle == .cutout ? 14 : 0)
                .shadow(
                    color: selectedStyle == .cutout ? .black.opacity(0.18) : .clear,
                    radius: 7,
                    y: 4
                )

            if isExtracting {
                Rectangle()
                    .fill(.ultraThinMaterial)
                VStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.86))
                            .frame(width: 68, height: 68)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                        ProgressView()
                            .tint(LockUDesign.Color.accentDark)
                        Image(systemName: "wand.and.stars")
                            .font(.caption)
                            .foregroundStyle(LockUDesign.Color.accentDark)
                            .offset(y: 19)
                    }
                    Text("被写体を探しています…")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(LockUDesign.Color.textPrimary)
                .accessibilityElement(children: .combine)
                .accessibilityValue("処理中")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.black.opacity(0.05), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .shadow(color: .black.opacity(0.06), radius: 14, y: 8)
    }

    private var editingControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                styleButton(.original, title: "写真")
                styleButton(.cutout, title: "切り抜き")
            }
            .padding(3)
            .frame(height: 44)
            .background(LockUDesign.Color.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black.opacity(0.05), lineWidth: 0.5)
            }

            if let cutoutErrorMessage {
                LockUStatusCard(
                    kind: .warning,
                    text: "切り抜けませんでした。写真のまま保存できます。"
                )
                .onTapGesture(perform: onExtractSubject)
                .accessibilityLabel("\(cutoutErrorMessage) 写真のまま保存できます。")
            } else if cutoutImage != nil {
                LockUStatusCard(
                    kind: .success,
                    text: "透明背景のPNGとしてロッカーに追加されます。"
                )
            }
        }
    }

    private func styleButton(_ style: MemoryImageStyle, title: String) -> some View {
        Button {
            if style == .cutout, cutoutImage == nil {
                onExtractSubject()
            } else {
                selectedStyle = style
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    selectedStyle == style
                        ? LockUDesign.Color.textPrimary
                        : LockUDesign.Color.textSecondary
                )
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    selectedStyle == style
                        ? LockUDesign.Color.surface
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .shadow(
                    color: selectedStyle == style ? .black.opacity(0.06) : .clear,
                    radius: 4,
                    y: 2
                )
        }
        .disabled(isExtracting || isSaving)
        .opacity(style == .cutout && cutoutImage == nil ? 0.72 : 1)
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
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var retakeButton: some View {
        Button("撮り直す", action: onRetake)
            .buttonStyle(LockUSecondaryButtonStyle())
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
                        "ロッカーに残す",
                        systemImage: "checkmark"
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(LockUPrimaryButtonStyle())
        .disabled(isSaving || isExtracting)
        .accessibilityLabel("Memoryをロッカーに残す")
    }
}

struct MemoryExpressionEditor: View {
    @Binding var selectedMoodEmoji: MemoryMoodEmoji?
    @Binding var memoryNote: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日の気分をひとつ")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LockUDesign.Color.textPrimary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(MemoryMoodEmoji.allCases) { mood in
                    Button {
                        selectedMoodEmoji = selectedMoodEmoji == mood ? nil : mood
                    } label: {
                        Text(mood.rawValue)
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                selectedMoodEmoji == mood
                                    ? LockUDesign.Color.cameraCream.opacity(0.78)
                                    : Color.clear,
                                in: Circle()
                            )
                            .overlay {
                                Circle().stroke(
                                    LockUDesign.Color.schoolNavy.opacity(selectedMoodEmoji == mood ? 0.14 : 0),
                                    lineWidth: 0.8
                                )
                            }
                            .scaleEffect(selectedMoodEmoji == mood ? 1.06 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mood.accessibilityLabel)
                    .accessibilityAddTraits(selectedMoodEmoji == mood ? .isSelected : [])
                }
            }

            Text("今日の自分にひとこと")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LockUDesign.Color.textPrimary)

            VStack(alignment: .trailing, spacing: 4) {
                TextField("例：今日めっちゃ笑った", text: $memoryNote, axis: .vertical)
                    .lineLimit(1...2)
                    .font(LockUDesign.Typography.body)
                    .foregroundStyle(LockUDesign.Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(
                        LockUDesign.Color.notebookPaper.opacity(0.88),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .onChange(of: memoryNote) { _, value in
                        if value.count > MemoryNotePolicy.maximumLength {
                            memoryNote = String(value.prefix(MemoryNotePolicy.maximumLength))
                        }
                    }
                    .accessibilityLabel("今日の自分へのひとこと")

                Text("\(memoryNote.count) / \(MemoryNotePolicy.maximumLength)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LockUDesign.Color.textSecondary)
            }
        }
        .padding(14)
        .background(
            LockUDesign.Color.surface.opacity(0.84),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}
