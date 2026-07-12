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
    /// 貼付済みシールをドラッグ中、指がトレイの高さまで来ているか。
    /// ページ外はクリップされてシールが見えなくなるため、代わりにトレイ側を
    /// ハイライトして「ここで離すとトレイに戻る」ことを伝える。
    var isDropTargetActive: Bool = false
    var onImportFromPhotoTapped: () -> Void
    var onCreateTextStickerTapped: () -> Void
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
                if isDropTargetActive {
                    Label("ここで離すとトレイに戻ります", systemImage: "tray.and.arrow.down.fill")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("未貼付トレイ")
                        .font(.system(.subheadline, design: .rounded).bold())
                    Text("\(trayStickers.count)枚")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button {
                        onImportFromPhotoTapped()
                    } label: {
                        Label("写真から作成", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        onCreateTextStickerTapped()
                    } label: {
                        Label("テキストで作成", systemImage: "textformat")
                    }
                } label: {
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
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2.5)
                .opacity(isDropTargetActive ? 1 : 0)
        )
        .scaleEffect(isDropTargetActive ? 1.02 : 1)
        .animation(StekkiSpring.drag, value: isDropTargetActive)
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
