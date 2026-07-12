//
//  PlacementAction.swift
//  Stekki
//
//  シールの貼付履歴に記録されるアクション種別。
//

import Foundation

/// PlacementHistory に記録される、シールに対して行われた操作の種類。
enum PlacementAction: String, Codable, CaseIterable, Hashable {
    /// トレイからページへ新規に貼り付けた
    case placed
    /// 同一ページ内で位置・拡大縮小・回転・重なり順を変更した
    case moved
    /// 別のページへ移動した
    case movedToPage
    /// ページから剥がしてトレイに戻した
    case removedToTray

    /// UI表示用のラベル
    var displayLabel: String {
        switch self {
        case .placed: return "貼り付け"
        case .moved: return "位置を変更"
        case .movedToPage: return "ページを移動"
        case .removedToTray: return "トレイに戻した"
        }
    }

    /// 履歴タイムラインに表示するSF Symbol
    var symbolName: String {
        switch self {
        case .placed: return "hand.tap.fill"
        case .moved: return "arrow.up.and.down.and.arrow.left.and.right"
        case .movedToPage: return "arrow.turn.up.right"
        case .removedToTray: return "tray.and.arrow.down.fill"
        }
    }
}
