//
//  BookListView.swift
//  Stekki
//
//  アプリのルート画面。シール帳の一覧・新規作成・削除。
//

import SwiftUI
import SwiftData

struct BookListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StickerBook.createdAt, order: .reverse) private var books: [StickerBook]

    @State private var viewModel: BookListViewModel?
    @State private var isPresentingNewBookSheet = false
    @State private var newBookTitle = ""

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if books.isEmpty {
                    emptyState
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(books) { book in
                            NavigationLink(value: book) {
                                BookCoverCard(book: book)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel?.delete(book)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("シール帳")
            .navigationDestination(for: StickerBook.self) { book in
                BookDetailView(book: book)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newBookTitle = ""
                        isPresentingNewBookSheet = true
                    } label: {
                        Label("新しいシール帳", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewBookSheet) {
                NewBookSheet(title: $newBookTitle) {
                    viewModel?.createBook(title: newBookTitle)
                    isPresentingNewBookSheet = false
                }
                .presentationDetents([.height(220)])
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BookListViewModel(modelContext: modelContext)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "seal")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("まだシール帳がありません")
                .font(.system(.title3, design: .rounded).bold())
            Text("右上の + から最初のシール帳を作ってみましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NewBookSheet: View {
    @Binding var title: String
    var onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("シール帳の名前") {
                    TextField("例: 小学生時代のシール帳", text: $title)
                }
            }
            .navigationTitle("新しいシール帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") { onCreate() }
                }
            }
        }
    }
}

#Preview {
    BookListView()
        .modelContainer(
            for: [StickerBook.self, StickerPage.self, Sticker.self, StickerPlacement.self, PlacementHistory.self],
            inMemory: true
        )
}
