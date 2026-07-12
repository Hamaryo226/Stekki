//
//  PageCanvasView.swift
//  Stekki
//
//  シール帳の1ページ分のキャンバス。編集モード中のみトレイからのドロップを受け付け、
//  貼られているシールを正規化座標から実座標へ変換して描画する。
//

import SwiftUI

struct PageCanvasView: View {
    let page: StickerPage
    let isEditMode: Bool

    var onDropSticker: (UUID, CGPoint) -> Void
    var onTapPlacement: (StickerPlacement) -> Void
    var onMovePlacement: (StickerPlacement, Double, Double) -> Void
    var onTransformPlacement: (StickerPlacement, Double, Double) -> Void
    var onBringToFront: (StickerPlacement) -> Void

    @State private var isTargeted = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hex: page.backgroundColorHex))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                isTargeted ? Color.accentColor.opacity(0.8) : Color.black.opacity(0.06),
                                lineWidth: isTargeted ? 3 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                if page.placements.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text(
                            isEditMode
                                ? "下のトレイからシールをドラッグして貼り付けよう"
                                : "「編集」をタップするとシールを貼り付けられます"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .allowsHitTesting(false)
                }

                ForEach(page.sortedPlacements) { placement in
                    PlacedStickerView(
                        placement: placement,
                        pageSize: size,
                        isEditMode: isEditMode,
                        onMove: { x, y in onMovePlacement(placement, x, y) },
                        onTransform: { scale, rotation in onTransformPlacement(placement, scale, rotation) },
                        onBringToFront: { onBringToFront(placement) },
                        onTap: { onTapPlacement(placement) }
                    )
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .dropDestination(for: StickerTransferItem.self) { items, location in
                guard isEditMode, let item = items.first, size.width > 0, size.height > 0 else { return false }
                let normalized = CGPoint(
                    x: (location.x / size.width).clamped(to: 0...1),
                    y: (location.y / size.height).clamped(to: 0...1)
                )
                onDropSticker(item.stickerID, normalized)
                return true
            } isTargeted: { targeted in
                withAnimation(StekkiSpring.tap) {
                    isTargeted = isEditMode && targeted
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }
}
