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
    /// "bookCanvas" 座標空間における未貼付トレイの矩形（トレイが非表示の間は .zero）
    let trayFrame: CGRect

    var onDropSticker: (UUID, CGPoint) -> Void
    var onTapPlacement: (StickerPlacement) -> Void
    var onMovePlacement: (StickerPlacement, Double, Double) -> Void
    /// 拡大率・回転・中心位置（正規化座標）をまとめて1回で確定する
    var onTransformPlacement: (StickerPlacement, Double, Double, CGPoint) -> Void
    var onBringToFront: (StickerPlacement) -> Void
    var onFlipPlacement: (StickerPlacement) -> Void
    var onToggleShadowPlacement: (StickerPlacement) -> Void
    var onReturnPlacementToTray: (StickerPlacement) -> Void
    /// シールのドラッグ中、指がトレイの高さに達したかどうかの変化（トレイのハイライト用）
    var onTrayHoverChanged: (Bool) -> Void
    /// ドラッグ中のシールを最前面へ持ち上げて表示するための共有ドラッグ層
    let dragLayer: StickerDragLayerModel

    @State private var isTargeted = false
    /// 編集モード中に選択され、反転・影ツールバーが出ているシール
    @State private var selectedPlacementID: UUID?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // このページの左上が画面全体（bookCanvas）座標のどこにあるか。
            // シールをトレイへ運ぶ際の座標変換に使う（ドラッグ中はページは動かないので安定）。
            let pageOrigin = geo.frame(in: .named("bookCanvas")).origin
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
                    .onTapGesture {
                        selectedPlacementID = nil
                    }

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
                        isSelected: selectedPlacementID == placement.id,
                        trayFrame: trayFrame,
                        pageOriginInCanvas: pageOrigin,
                        dragLayer: dragLayer,
                        onSelect: { selectedPlacementID = placement.id },
                        onMove: { x, y in onMovePlacement(placement, x, y) },
                        onTransform: { scale, rotation, center in onTransformPlacement(placement, scale, rotation, center) },
                        onBringToFront: { onBringToFront(placement) },
                        onFlip: { onFlipPlacement(placement) },
                        onToggleShadow: { onToggleShadowPlacement(placement) },
                        onTap: { onTapPlacement(placement) },
                        onReturnToTray: {
                            if selectedPlacementID == placement.id { selectedPlacementID = nil }
                            onReturnPlacementToTray(placement)
                        },
                        onTrayHover: { hovering in onTrayHoverChanged(hovering) }
                    )
                }
            }
            .frame(width: size.width, height: size.height)
            // シールがページの外へはみ出した部分は、本物のシール帳のページと同じように
            // 見えないようにする（ページ背景と同じ角丸でクリップ）。
            // ドラッグでページ外へ運んでいる間もはみ出た部分から順に隠れていくため、
            // トレイへ戻す操作のフィードバックはトレイ側のハイライトで伝える。
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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
        .onChange(of: isEditMode) { _, newValue in
            if !newValue { selectedPlacementID = nil }
        }
    }
}
