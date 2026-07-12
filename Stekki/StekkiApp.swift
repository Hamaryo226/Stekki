//
//  StekkiApp.swift
//  Stekki
//
//  デジタルシール帳アプリのエントリポイント。
//  アカウント登録やサーバー通信は行わず、SwiftDataによるオンデバイス永続化のみで完結する。
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

    var body: some Scene {
        WindowGroup {
            BookListView()
        }
        .modelContainer(sharedModelContainer)
    }
}
