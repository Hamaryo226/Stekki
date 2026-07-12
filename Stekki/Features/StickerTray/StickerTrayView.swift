//
//  StickerTrayView.swift
//  Stekki
//
//  未貼付のシールを横並びに表示するトレイ。どのシール帳を開いていても
//  端末内にある「まだどこにも貼っていないシール」が一覧できる。
//

import SwiftUI
import SwiftData

struct StickerTrayView: View {
    var onImportTapped: () -> Void
    var onSelectSticker: (Sticker) -> Void

    @Query(
        filter: #Predicate<Sticker> { $0.placement == nil && $0.isArchived == false },
        sort: \Sticker.createdAt,
        order: .reverse
    )
    private var trayStickers: [Sticker]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("未貼付トレイ")
                    .font(.system(.subheadline, design: .rounded).bold())
                Text("\(trayStickers.count)枚")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onImportTapped) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding(.horizontal, 16)

            if trayStickers.isEmpty {
                emptyTray
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(trayStickers) { sticker in
                            TrayStickerCard(sticker: sticker)
                                .onTapGesture { onSelectSticker(sticker) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 14)
        .floatingMaterial(cornerRadius: 28)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var emptyTray: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            Text("トレイは空です。右上の＋から写真でシールを作ろう")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
    }
}
