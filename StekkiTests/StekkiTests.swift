//
//  StekkiTests.swift
//  StekkiTests
//
//  Created by 濵口椋大 on 2026/07/11.
//

import Testing
import SwiftData
import Foundation
import CoreGraphics
@testable import Stekki

struct StekkiTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            StickerBook.self, StickerPage.self, Sticker.self,
            StickerPlacement.self, PlacementHistory.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test @MainActor func creatingBookAddsFirstPage() throws {
        let context = try makeInMemoryContext()
        let viewModel = BookListViewModel(modelContext: context)
        let book = viewModel.createBook(title: "テスト帳")
        #expect(book.pages.count == 1)
        #expect(book.title == "テスト帳")
    }

    @Test @MainActor func placingStickerMovesItOutOfTray() throws {
        let context = try makeInMemoryContext()
        let bookVM = BookListViewModel(modelContext: context)
        let book = bookVM.createBook(title: "帳")
        let page = book.sortedPages[0]

        let sticker = Sticker(imageFileName: "dummy.png", authorDisplayName: "自分")
        context.insert(sticker)

        let detailVM = BookDetailViewModel(book: book, modelContext: context)
        detailVM.place(stickerID: sticker.id, onto: page, at: CGPoint(x: 0.5, y: 0.5))

        #expect(sticker.isPlaced == true)
        #expect(sticker.placement?.x == 0.5)
        #expect(page.placements.count == 1)
        #expect(sticker.history.count == 1)
        #expect(sticker.history.first?.action == .placed)
    }

    @Test @MainActor func removingStickerToTrayLogsHistory() throws {
        let context = try makeInMemoryContext()
        let bookVM = BookListViewModel(modelContext: context)
        let book = bookVM.createBook(title: "帳")
        let page = book.sortedPages[0]

        let sticker = Sticker(imageFileName: "dummy.png", authorDisplayName: "自分")
        context.insert(sticker)

        let detailVM = BookDetailViewModel(book: book, modelContext: context)
        detailVM.place(stickerID: sticker.id, onto: page, at: CGPoint(x: 0.2, y: 0.3))
        detailVM.removeToTray(sticker)

        #expect(sticker.isPlaced == false)
        #expect(sticker.history.contains { $0.action == .removedToTray })
    }

    @Test func placementCoordinatesClampToUnitRange() {
        let placement = StickerPlacement(x: 1.4, y: -0.3)
        #expect(placement.x == 1.0)
        #expect(placement.y == 0.0)
    }

    @Test @MainActor func transformCommitsScaleRotationAndPositionAtOnce() throws {
        let context = try makeInMemoryContext()
        let bookVM = BookListViewModel(modelContext: context)
        let book = bookVM.createBook(title: "帳")
        let page = book.sortedPages[0]

        let sticker = Sticker(imageFileName: "dummy.png", authorDisplayName: "自分")
        context.insert(sticker)

        let detailVM = BookDetailViewModel(book: book, modelContext: context)
        detailVM.place(stickerID: sticker.id, onto: page, at: CGPoint(x: 0.5, y: 0.5))
        let placement = try #require(sticker.placement)
        let historyCountBefore = sticker.history.count

        // ピンチは支点固定のため位置も同時に動く。1回の確定で履歴も1件だけ増えること。
        detailVM.updateTransform(placement, scale: 2.0, rotation: .pi / 2, x: 0.7, y: 0.6)

        #expect(placement.scale == 2.0)
        #expect(placement.rotation == .pi / 2)
        #expect(placement.x == 0.7)
        #expect(placement.y == 0.6)
        #expect(sticker.history.count == historyCountBefore + 1)

        // 拡大率と座標は共通の許容範囲へクランプされること
        detailVM.updateTransform(placement, scale: 100, rotation: 0, x: 1.5, y: -0.2)
        #expect(placement.scale == StickerPlacement.scaleRange.upperBound)
        #expect(placement.x == 1.0)
        #expect(placement.y == 0.0)
    }

    @Test @MainActor func cyclingEffectAdvancesAndWrapsAround() throws {
        let context = try makeInMemoryContext()
        let bookVM = BookListViewModel(modelContext: context)
        let book = bookVM.createBook(title: "帳")
        let page = book.sortedPages[0]

        let sticker = Sticker(imageFileName: "dummy.png", authorDisplayName: "自分")
        context.insert(sticker)

        let detailVM = BookDetailViewModel(book: book, modelContext: context)
        detailVM.place(stickerID: sticker.id, onto: page, at: CGPoint(x: 0.5, y: 0.5))
        let placement = try #require(sticker.placement)

        // 貼った直後はエフェクトなし
        #expect(placement.effect == StickerEffect.none)

        // なし → 白フチ → キラキラ → なし と循環する
        detailVM.cycleEffect(placement)
        #expect(placement.effect == .whiteOutline)
        detailVM.cycleEffect(placement)
        #expect(placement.effect == .glow)
        detailVM.cycleEffect(placement)
        #expect(placement.effect == StickerEffect.none)
    }

    @Test func unknownEffectRawValueFallsBackToNone() {
        let placement = StickerPlacement(x: 0.5, y: 0.5)
        placement.effectRawValue = "future-effect"
        #expect(placement.effect == StickerEffect.none)
    }

    @Test func textStickerIsIdentifiedBySpecJSON() {
        let photo = Sticker(imageFileName: "a.png", authorDisplayName: "自分")
        #expect(photo.isTextSticker == false)

        let text = Sticker(
            imageFileName: "b.png",
            authorDisplayName: "自分",
            textSpecJSON: TextStickerSpec.initial.encodedJSON()
        )
        #expect(text.isTextSticker == true)
    }
}
