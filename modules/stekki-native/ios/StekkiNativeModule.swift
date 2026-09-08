import ExpoModulesCore
import SwiftData
import SwiftUI
import UIKit

public final class StekkiNativeModule: Module {
    // Every access is dispatched to the main queue, including SwiftData and presentation.
    private var container: ModelContainer?
    private weak var activeScreen: UIViewController?

    public func definition() -> ModuleDefinition {
        Name("StekkiNative")

        AsyncFunction("listBooks") { () throws -> [[String: Any]] in
            return try MainActor.assumeIsolated {
                let context = try self.store().mainContext
                return try context.fetch(FetchDescriptor<StickerBook>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
                    .map { book in
                        ["id": book.id.uuidString, "title": book.title,
                         "color": book.coverColorHex, "pageCount": book.pages.count,
                         "stickerCount": book.totalPlacedStickerCount]
                    }
            }
        }.runOnQueue(.main)

        AsyncFunction("createBook") { (title: String) throws -> String in
            return try MainActor.assumeIsolated {
                let context = try self.store().mainContext
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let book = StickerBook(title: trimmed.isEmpty ? "新しいシール帳" : String(trimmed.prefix(120)),
                                       coverColorHex: Color.bookPalette.randomElement() ?? "#FFB6C1")
                let page = StickerPage(pageIndex: 0, book: book)
                book.pages.append(page)
                context.insert(book)
                do { try context.save() } catch { context.rollback(); throw error }
                return book.id.uuidString
            }
        }.runOnQueue(.main)

        AsyncFunction("renameBook") { (id: String, title: String) throws in
            try MainActor.assumeIsolated {
                let context = try self.store().mainContext
                let book = try self.book(id)
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { throw self.failure("名前を入力してください。") }
                book.title = String(trimmed.prefix(120))
                book.updatedAt = .now
                do { try context.save() } catch { context.rollback(); throw error }
            }
        }.runOnQueue(.main)

        AsyncFunction("deleteBook") { (id: String) throws in
            try MainActor.assumeIsolated {
                let context = try self.store().mainContext
                let book = try self.book(id)
                // Explicitly retain stickers and snapshot their last location before cascading pages.
                for page in book.pages {
                    for placement in page.placements {
                        guard let sticker = placement.sticker else { continue }
                        let entry = PlacementHistory(action: .removedToTray,
                            bookTitleSnapshot: book.title, pageDisplaySnapshot: page.displayName,
                            x: placement.x, y: placement.y, scale: placement.scale,
                            rotation: placement.rotation, zIndex: placement.zIndex,
                            isFlippedHorizontally: placement.isFlippedHorizontally,
                            hasShadow: placement.hasShadow, sticker: sticker)
                        context.insert(entry)
                        sticker.history.append(entry)
                        sticker.placement = nil
                    }
                }
                context.delete(book)
                do { try context.save() } catch { context.rollback(); throw error }
            }
        }.runOnQueue(.main)

        AsyncFunction("openBook") { (id: String, promise: Promise) in
            MainActor.assumeIsolated {
                do {
                    let book = try self.book(id)
                    try self.present(EditorScreen(book: book), promise: promise)
                } catch { promise.reject(error) }
            }
        }.runOnQueue(.main)

        AsyncFunction("createSticker") { (kind: String, promise: Promise) in
            MainActor.assumeIsolated {
                do {
                    switch kind {
                    case "photo": try self.present(StickerImportView(), promise: promise)
                    case "text": try self.present(TextStickerCreateView(), promise: promise)
                    default: throw self.failure("作成方法が不正です。")
                    }
                } catch { promise.reject(error) }
            }
        }.runOnQueue(.main)

        AsyncFunction("receiveFile") { (uri: String, promise: Promise) in
            MainActor.assumeIsolated {
                do {
                    guard let url = URL(string: uri), url.isFileURL,
                          url.pathExtension.lowercased() == StickerTradeFormat.fileExtension else {
                        throw self.failure("シール交換ファイルを選んでください。")
                    }
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    // Bound the read itself, not just the later archive validation.
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    let data = try handle.read(upToCount: StickerTradeFormat.maxArchiveBytes + 1) ?? Data()
                    guard data.count <= StickerTradeFormat.maxArchiveBytes else {
                        throw StickerTradeImportError.archiveTooLarge
                    }
                    let payload = try StickerTradeImporter.importArchive(data)
                    try self.present(StickerTradeReceiveView(payload: payload), promise: promise)
                    // Never remove an arbitrary external file or a folder merely named Inbox.
                    let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Inbox", isDirectory: true).resolvingSymlinksInPath().standardizedFileURL
                    if url.resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent() == inbox {
                        try? FileManager.default.removeItem(at: url)
                    }
                } catch { promise.reject(error) }
            }
        }.runOnQueue(.main)
    }

    @MainActor
    private func store() throws -> ModelContainer {
        if let container { return container }
        // Keep the original schema, default store location and Swift module name (Stekki).
        let schema = Schema([StickerBook.self, StickerPage.self, Sticker.self,
                             StickerPlacement.self, PlacementHistory.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let created = try ModelContainer(for: schema, configurations: [configuration])
        container = created
        return created
    }

    @MainActor
    private func book(_ value: String) throws -> StickerBook {
        guard let id = UUID(uuidString: value) else { throw failure("シール帳IDが不正です。") }
        let descriptor = FetchDescriptor<StickerBook>(predicate: #Predicate { $0.id == id })
        guard let book = try store().mainContext.fetch(descriptor).first else {
            throw failure("シール帳が見つかりませんでした。")
        }
        return book
    }

    @MainActor
    private func present<Content: View>(_ content: Content, promise: Promise) throws {
        guard activeScreen == nil else { throw failure("開いている画面を閉じてください。") }
        guard let presenter = appContext?.utilities?.currentViewController(),
              presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed else {
            throw failure("画面を開けませんでした。もう一度お試しください。")
        }
        let root = AnyView(content.modelContainer(try store()))
        let host = CompletionHostingController(rootView: root)
        host.modalPresentationStyle = .fullScreen
        host.onClose = { [weak self] in
            self?.activeScreen = nil
            promise.resolve(nil)
        }
        activeScreen = host
        presenter.present(host, animated: true)
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "Stekki", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private struct EditorScreen: View {
    let book: StickerBook
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            BookDetailView(book: book)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("シール帳") { dismiss() }
                    }
                }
        }
    }
}

private final class CompletionHostingController: UIHostingController<AnyView> {
    var onClose: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // A child full-screen preview must not complete the parent's JS operation.
        if presentingViewController == nil || isBeingDismissed {
            let completion = onClose
            onClose = nil
            completion?()
        }
    }
}
