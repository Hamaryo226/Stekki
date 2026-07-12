//
//  PageIndicatorView.swift
//  Stekki
//
//  ページ送り用のドットインジケータ。タップで該当ページへジャンプできる。
//

import SwiftUI

struct PageIndicatorView: View {
    let count: Int
    @Binding var current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 8 : 6, height: index == current ? 8 : 6)
                    .onTapGesture {
                        withAnimation(StekkiSpring.pageTurn) {
                            current = index
                        }
                    }
            }
        }
        .animation(StekkiSpring.standard, value: current)
    }
}
