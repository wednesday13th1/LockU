import SwiftUI

struct CutoutCheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 18
            let columns = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            for row in 0..<rows {
                for column in 0..<columns {
                    let color = (row + column).isMultiple(of: 2)
                        ? LockUDesign.Color.paperCream
                        : LockUDesign.Color.dustBlue.opacity(0.11)
                    context.fill(
                        Path(
                            CGRect(
                                x: CGFloat(column) * tile,
                                y: CGFloat(row) * tile,
                                width: tile,
                                height: tile
                            )
                        ),
                        with: .color(color)
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}
