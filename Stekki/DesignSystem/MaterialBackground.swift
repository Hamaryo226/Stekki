//
//  MaterialBackground.swift
//  Stekki
//
//  半透明マテリアル・タイポグラフィのヘルパー（Apple Design原則: 素材が階層を語る）。
//

import SwiftUI

/// トレイやツールバーなど、コンテンツの上に浮くフローティング層に使う共通マテリアル。
struct FloatingMaterialBackground: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
            )
    }
}

extension View {
    func floatingMaterial(cornerRadius: CGFloat = 24) -> some View {
        modifier(FloatingMaterialBackground(cornerRadius: cornerRadius))
    }
}

/// 大見出し用のタイポグラフィ（大きいサイズほどトラッキングを締める）
struct DisplayTitleStyle: ViewModifier {
    var size: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .bold, design: .rounded))
            .tracking(-0.3)
            .lineSpacing(size * 0.05)
    }
}

extension View {
    func displayTitle(size: CGFloat = 28) -> some View {
        modifier(DisplayTitleStyle(size: size))
    }
}
