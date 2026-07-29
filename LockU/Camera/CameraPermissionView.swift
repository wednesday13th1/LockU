import SwiftUI
import UIKit

struct CameraPermissionView: View {
    let isRestricted: Bool
    let onLibraryImage: (UIImage) -> Void
    let onError: (Error) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isRestricted ? "camera.fill" : "camera.badge.ellipsis")
                .font(.system(size: 44))
            Text(isRestricted ? "カメラを利用できません" : "カメラへのアクセスが必要です")
                .font(.title2.bold())
            Text(
                isRestricted
                    ? "この端末ではカメラが制限されています。写真ライブラリから選択できます。"
                    : "設定でカメラへのアクセスを許可するか、写真ライブラリから選択してください。"
            )
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            if !isRestricted {
                Button("設定を開く") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }

            PhotoLibraryPicker(
                isDisabled: false,
                style: .labeled,
                onImage: onLibraryImage,
                onError: onError
            )
        }
        .padding(28)
        .foregroundStyle(LockUDesign.Color.ink)
        .frame(maxWidth: 430)
        .accessibilityElement(children: .contain)
    }
}
