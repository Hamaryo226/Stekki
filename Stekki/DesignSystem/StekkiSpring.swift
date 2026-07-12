//
//  StekkiSpring.swift
//  Stekki
//
//  Apple Fluid Interfaces (WWDC18) の指針に沿ったスプリング定義。
//  ジェスチャで動かせるものは基本 critically-damped、フリック等の勢いを伴う
//  操作の着地だけ僅かにバウンスさせる。
//

import SwiftUI

enum StekkiSpring {
    /// 既定のUIスプリング。オーバーシュートなし、上品に収束する。
    static let standard: Animation = .spring(response: 0.4, dampingFraction: 1.0)

    /// ドラッグ中の追従用（1:1トラッキングの直後、指を離した瞬間の吸着に使う）
    static let drag: Animation = .interactiveSpring(response: 0.35, dampingFraction: 0.86)

    /// トレイ → ページへの貼付が確定した瞬間。フリックの勢いを引き継ぐので軽くバウンドさせる。
    static let placeSettle: Animation = .spring(response: 0.4, dampingFraction: 0.78)

    /// ドロップ対象外で指を離した際、トレイへスナップバックするとき
    static let snapBack: Animation = .spring(response: 0.42, dampingFraction: 0.82)

    /// ページ送り（横スライド）
    static let pageTurn: Animation = .spring(response: 0.45, dampingFraction: 1.0)

    /// シート／モーダルの開閉
    static let sheet: Animation = .spring(response: 0.38, dampingFraction: 0.86)

    /// 軽いフィードバック（ボタン押下など）
    static let tap: Animation = .easeOut(duration: 0.1)

    /// シールをドラッグでトレイへ戻す際、吸い込まれるように縮小・フェードするとき
    static let returnToTray: Animation = .spring(response: 0.26, dampingFraction: 0.9)
}
