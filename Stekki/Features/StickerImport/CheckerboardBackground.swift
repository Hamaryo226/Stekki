//
//  CheckerboardBackground.swift
//  Stekki
//
//  透明PNGのプレビューで透過部分がわかるように敷く市松模様。
//

import SwiftUI

struct CheckerboardBackground: View {
    var tile: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let columns = max(1, Int(ceil(size.width / tile)))
            let rows = max(1, Int(ceil(size.height / tile)))
            for row in 0..<rows {
                for col in 0..<columns {
                    guard (row + col).isMultiple(of: 2) else { continue }
                    let rect = CGRect(x: CGFloat(col) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(.gray.opacity(0.18)))
                }
            }
        }
    }
}
