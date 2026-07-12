//
//  TrayFramePreferenceKey.swift
//  Stekki
//
//  未貼付トレイの画面上の矩形（"bookCanvas" 座標空間）を子から親へ伝えるためのキー。
//  シールをドラッグでトレイへ戻す判定（トレイの上にドロップされたか）に使う。
//

import SwiftUI

struct TrayFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
