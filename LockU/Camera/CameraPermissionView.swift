import SwiftUI
import UIKit

struct CameraPermissionView: View {
    let isRestricted: Bool
    let onLibraryImage: (UIImage) -> Void
    let onError: (Error) -> Void

    var body: some View {
        ZStack {
            LockUPageBackground()
            LockUSurface {
                VStack(spacing: 16) {
                    Circle()
                        .fill(LockUDesign.Color.accentSoft)
                        .frame(width: 88, height: 88)
                        .overlay {
                            Image(systemName: isRestricted ? "camera.fill" : "camera.badge.ellipsis")
                                .font(.system(size: 38))
                                .foregroundStyle(LockUDesign.Color.textPrimary)
                        }
                    Text(isRestricted ? "カメラを利用できません" : "カメラへのアクセスが必要です")
                        .font(LockUDesign.Typography.screenTitle)
                        .multilineTextAlignment(.center)
                    Text(
                        isRestricted
                            ? "この端末ではカメラが制限されています。\n写真から思い出を選べます。"
                            : "設定でカメラへのアクセスを許可するか、\n写真から思い出を選んでください。"
                    )
                    .font(LockUDesign.Typography.body)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LockUDesign.Color.textSecondary)

                    if !isRestricted {
                        Button("設定を開く") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                        .buttonStyle(LockUPrimaryButtonStyle())
                    }

                    PhotoLibraryPicker(
                        isDisabled: false,
                        style: .labeled,
                        onImage: onLibraryImage,
                        onError: onError
                    )
                }
                .padding(28)
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 20)
        }
        .foregroundStyle(LockUDesign.Color.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Permission Denied") {
    CameraPermissionView(
        isRestricted: false,
        onLibraryImage: { _ in },
        onError: { _ in }
    )
}

#Preview("Permission Restricted") {
    CameraPermissionView(
        isRestricted: true,
        onLibraryImage: { _ in },
        onError: { _ in }
    )
}
