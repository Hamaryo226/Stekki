//
//  StickerImageView.swift
//  Stekki
//
//  透明PNGのシール画像を表示する共通View。読み込めない場合はプレースホルダを表示する。
//  effect に .whiteOutline を指定すると、白フチ加工済みの画像（キャッシュ生成）を表示する。
//  グローは画像ではなくシャドウで表現するため、呼び出し側（PlacedStickerView等）が担当する。
//

import SwiftUI
import UIKit

struct StickerImageView: View {
    let fileName: String?
    var effect: StickerEffect = .none

    var body: some View {
        if let fileName, let uiImage = resolvedImage(fileName) {
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

    private func resolvedImage(_ fileName: String) -> UIImage? {
        if effect == .whiteOutline, let outlined = StickerEffectRenderer.whiteOutlinedImage(for: fileName) {
            return outlined
        }
        return StickerImageCache.shared.image(for: fileName)
    }
}
