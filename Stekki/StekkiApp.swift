//
//  StekkiApp.swift
//  Stekki
//
//  デジタルシール帳アプリのエントリポイント。
//  アカウント登録やサーバー通信は行わず、SwiftDataによるオンデバイス永続化のみで完結する。
//  AirDrop等で受け取った .stickertrade ファイルは onOpenURL で受け取り、
//  検証に通った場合のみプレビュー画面（StickerTradeReceiveView）を表示する。
//

import SwiftUI
import SwiftData

@main
struct StekkiApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StickerBook.self,
            StickerPage.self,
            Sticker.self,
            StickerPlacement.self,
            PlacementHistory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// 検証に通った受信シール。セットするとプレビューシートが開く。
    @State private var receivedPayload: StickerTradePayload?
    @State private var receiveErrorMessage: String?

    var body: some Scene {
        WindowGroup {
            BookListView()
                .onOpenURL { url in
                    handleIncomingFile(at: url)
                }
                .sheet(item: $receivedPayload) { payload in
                    StickerTradeReceiveView(payload: payload)
                }
                .alert(
                    "シールを受け取れませんでした",
                    isPresented: Binding(
                        get: { receiveErrorMessage != nil },
                        set: { if !$0 { receiveErrorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(receiveErrorMessage ?? "")
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// AirDrop・Files等から開かれた .stickertrade を読み込んで検証する。
    /// ここでは保存はせず、検証済みペイロードをプレビュー画面に渡すだけ。
    private func handleIncomingFile(at url: URL) {
        guard url.isFileURL,
              url.pathExtension.lowercased() == StickerTradeFormat.fileExtension else { return }

        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let archiveData: Data
        do {
            archiveData = try Data(contentsOf: url)
        } catch {
            receiveErrorMessage = "ファイルを読み込めませんでした: \(error.localizedDescription)"
            return
        }
        // AirDrop受信ファイルは Documents/Inbox にコピーされて残り続けるため、読み込み後に削除する
        removeInboxCopyIfNeeded(url)

        // 検証はサイズ上限（25MB）内のメモリ処理で、体感できる遅延はほぼないため同期的に行う
        do {
            receivedPayload = try StickerTradeImporter.importArchive(archiveData)
        } catch {
            receiveErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "シール交換ファイルとして読み込めませんでした。"
        }
    }

    /// 自アプリのサンドボックス内 Documents/Inbox に置かれた受信ファイルだけを掃除する
    private func removeInboxCopyIfNeeded(_ url: URL) {
        guard url.pathComponents.contains("Inbox") else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
