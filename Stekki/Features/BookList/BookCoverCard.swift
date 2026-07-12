//
//  BookCoverCard.swift
//  Stekki
//
//  シール帳一覧のグリッドに並ぶ表紙カード。
//

import SwiftUI

struct BookCoverCard: View {
    let book: StickerBook

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: book.coverColorHex), Color(hex: book.coverColorHex).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)

                Image(systemName: "seal.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(book.pages.count)ページ・\(book.totalPlacedStickerCount)枚")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(StekkiSpring.tap, value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}
