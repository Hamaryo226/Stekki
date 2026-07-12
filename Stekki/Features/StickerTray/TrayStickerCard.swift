//
//  TrayStickerCard.swift
//  Stekki
//
//  未貼付トレイに並ぶシールのカード。draggable によりページへ1:1で追従してドラッグできる。
//

import SwiftUI

struct TrayStickerCard: View {
    let sticker: Sticker

    var body: some View {
        StickerImageView(fileName: sticker.thumbnailFileName ?? sticker.imageFileName)
            .frame(width: 64, height: 64)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.75))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .draggable(StickerTransferItem(stickerID: sticker.id)) {
                StickerImageView(fileName: sticker.thumbnailFileName ?? sticker.imageFileName)
                    .frame(width: 84, height: 84)
            }
            .accessibilityLabel("未貼付のシール")
    }
}
