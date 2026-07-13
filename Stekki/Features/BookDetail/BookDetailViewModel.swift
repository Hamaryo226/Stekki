//
//  BookDetailViewModel.swift
//  Stekki
//
//  ページの追加・削除、シールの貼付/移動/拡縮/回転、貼付履歴の記録を担当する。
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class BookDetailViewModel {
    let book: StickerBook
    private let modelContext: ModelContext

    init(book: StickerBook, modelContext: ModelContext) {
        self.book = book
        self.modelContext = modelContext
    }

    // MARK: - ページ操作

    @discardableResult
    func addPage() -> StickerPage {
        let page = StickerPage(
            pageIndex: book.pages.count,
            backgroundColorHex: Color.bookPalette.randomElement() ?? "#FFFDF7",
            book: book
        )
        book.pages.append(page)
        book.updatedAt = .now
        save()
        return page
    }

    func deletePage(_ page: StickerPage) {
        guard book.pages.count > 1 else { return }

        for placement in page.placements {
            if let sticker = placement.sticker {
                logHistory(sticker: sticker, action: .removedToTray, page: page, placement: placement)
                sticker.placement = nil
            }
        }

        modelContext.delete(page)

        let remaining = book.pages
            .filter { $0.id != page.id }
            .sorted { $0.pageIndex < $1.pageIndex }
        for (index, p) in remaining.enumerated() {
            p.pageIndex = index
        }
        book.updatedAt = .now
        save()
    }

    // MARK: - シールの貼付操作

    /// トレイのシールをページ上の正規化座標へ新規に貼り付ける
    func place(stickerID: UUID, onto page: StickerPage, at point: CGPoint) {
        guard let sticker = fetchSticker(id: stickerID) else { return }

        // 既に別の場所に貼ってあった場合は、一旦剥がしてから貼り直す扱いにする
        if let existing = sticker.placement {
            modelContext.delete(existing)
            sticker.placement = nil
        }

        let placement = StickerPlacement(
            x: Double(point.x),
            y: Double(point.y),
            scale: 1.0,
            rotation: 0,
            zIndex: page.nextZIndex,
            sticker: sticker,
            page: page
        )
        modelContext.insert(placement)
        sticker.placement = placement
        page.placements.append(placement)

        logHistory(sticker: sticker, action: .placed, page: page, placement: placement)
        save()
    }

    /// 同一ページ内での位置変更
    func updatePosition(_ placement: StickerPlacement, x: Double, y: Double) {
        placement.x = x.clamped(to: 0...1)
        placement.y = y.clamped(to: 0...1)
        placement.placedAt = .now
        if let sticker = placement.sticker {
            logHistory(sticker: sticker, action: .moved, page: placement.page, placement: placement)
        }
        save()
    }

    /// 拡大縮小・回転・位置の変更を1回の操作として確定する。
    /// ピンチは指の中心を支点に拡縮・回転するため中心位置も同時に動く。
    /// 別々にコミットすると履歴が2件に分かれ、保存も2回走るため、まとめて受け取る。
    func updateTransform(_ placement: StickerPlacement, scale: Double, rotation: Double, x: Double, y: Double) {
        placement.scale = scale.clamped(to: StickerPlacement.scaleRange)
        placement.rotation = rotation
        placement.x = x.clamped(to: 0...1)
        placement.y = y.clamped(to: 0...1)
        placement.placedAt = .now
        if let sticker = placement.sticker {
            logHistory(sticker: sticker, action: .moved, page: placement.page, placement: placement)
        }
        save()
    }

    /// 最前面に移動
    func bringToFront(_ placement: StickerPlacement) {
        guard let page = placement.page else { return }
        let top = page.nextZIndex
        guard placement.zIndex != top - 1 else { return }
        placement.zIndex = top
        save()
    }

    /// 左右反転をトグルする
    func toggleFlip(_ placement: StickerPlacement) {
        placement.isFlippedHorizontally.toggle()
        placement.placedAt = .now
        if let sticker = placement.sticker {
            logHistory(sticker: sticker, action: .moved, page: placement.page, placement: placement)
        }
        save()
    }

    /// 影のON/OFFをトグルする
    func toggleShadow(_ placement: StickerPlacement) {
        placement.hasShadow.toggle()
        placement.placedAt = .now
        if let sticker = placement.sticker {
            logHistory(sticker: sticker, action: .moved, page: placement.page, placement: placement)
        }
        save()
    }

    /// エフェクトを次のものへ切り替える（なし→白フチ→キラキラ→なし…）
    func cycleEffect(_ placement: StickerPlacement) {
        placement.effect = placement.effect.next
        placement.placedAt = .now
        if let sticker = placement.sticker {
            logHistory(sticker: sticker, action: .moved, page: placement.page, placement: placement)
        }
        save()
    }

    /// ページから剥がしてトレイへ戻す
    func removeToTray(_ sticker: Sticker) {
        guard let placement = sticker.placement else { return }
        logHistory(sticker: sticker, action: .removedToTray, page: placement.page, placement: placement)
        sticker.placement = nil
        modelContext.delete(placement)
        save()
    }

    // MARK: - 履歴

    private func logHistory(sticker: Sticker, action: PlacementAction, page: StickerPage?, placement: StickerPlacement) {
        let entry = PlacementHistory(
            action: action,
            bookTitleSnapshot: page?.book?.title,
            pageDisplaySnapshot: page?.displayName,
            x: placement.x,
            y: placement.y,
            scale: placement.scale,
            rotation: placement.rotation,
            zIndex: placement.zIndex,
            isFlippedHorizontally: placement.isFlippedHorizontally,
            hasShadow: placement.hasShadow,
            sticker: sticker
        )
        modelContext.insert(entry)
        sticker.history.append(entry)
    }

    // MARK: - 内部ユーティリティ

    private func fetchSticker(id: UUID) -> Sticker? {
        let predicate = #Predicate<Sticker> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func save() {
        try? modelContext.save()
    }
}
