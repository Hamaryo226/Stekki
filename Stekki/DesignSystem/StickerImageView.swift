//
//  StickerImageView.swift
//  Stekki
//
//  透明PNGのシール画像を表示する共通View。読み込めない場合はプレースホルダを表示する。
//

import SwiftUI
import UIKit

struct StickerImageView: View {
    let fileName: String?

    var body: some View {
        if let fileName, let uiImage = StickerImageCache.shared.image(for: fileName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                )
        }
    }
}
