//
//  StickerDragLayer.swift
//  Stekki
//
//  シールをトレイへ戻すためにドラッグしている間、そのシールを最前面へ「持ち上げて」表示する層。
//
//  ページ上のシールは PageCanvasView のクリップ（ページ範囲外は非表示）と、
//  トレイが下に重なるz順序のせいで、そのままでは下方向へドラッグするとトレイの裏に隠れてしまい、
//  トレイまで運べない。そこで、指がトレイの高さに達している間だけシールの実体を隠し、
//  代わりにこの層（"bookCanvas" 全体を覆う最前面のオーバーレイ）へ同じ見た目のシールを描く。
//  これによりクリップやトレイに邪魔されず、シールがトレイの上まで見えたまま運べる。
//

import SwiftUI

/// ドラッグ層に表示する、持ち上げ中のシール1枚の情報（座標は "bookCanvas" 空間）。
struct DraggedStickerPreview: Equatable {
    /// どの貼付を持ち上げているか（複数シール中の同定用）
    let placementID: UUID
    var fileName: String?
    /// シール中心の "bookCanvas" 座標
    var center: CGPoint
    var scale: CGFloat
    var rotation: Angle
    var flipped: Bool
    /// 貼付に適用中のエフェクト（持ち上げ中も同じ見た目で運ぶ）
    var effect: StickerEffect
    /// トレイの上にあり「離すと戻る」状態か（縮小表示にする）
    var overTray: Bool
}

/// ドラッグ層の状態。@Observable にすることで、値を更新しても
/// この層を読んでいるビュー（StickerDragLayer）だけが再描画され、
/// BookDetailView 本体や TabView 全体は再評価されない（ドラッグ中の負荷を抑える）。
@Observable
final class StickerDragLayerModel {
    var preview: DraggedStickerPreview?
}

/// "bookCanvas" 全体を覆い、preview があればその位置にシールを最前面で描くオーバーレイ。
struct StickerDragLayer: View {
    let model: StickerDragLayerModel

    /// PlacedStickerView.baseSize と一致させること（持ち上げ前後で大きさを揃えるため）。
    private let baseSize: CGFloat = 96

    var body: some View {
        GeometryReader { _ in
            if let preview = model.preview {
                StickerImageView(fileName: preview.fileName, effect: preview.effect)
                    .frame(width: baseSize, height: baseSize)
                    .scaleEffect(x: (preview.flipped ? -1 : 1) * preview.scale, y: preview.scale)
                    .rotationEffect(preview.rotation)
                    // トレイの上では吸い込まれるように少し縮める
                    .scaleEffect(preview.overTray ? 0.6 : 1.0)
                    .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 10)
                    .position(preview.center)
                    .animation(StekkiSpring.drag, value: preview.overTray)
            }
        }
        .allowsHitTesting(false)
    }
}
