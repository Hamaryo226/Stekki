//
//  BookDetailView.swift
//  Stekki
//
//  1冊のシール帳を開いた画面。複数ページをページ送りで表示し、
//  下部の未貼付トレイからドラッグ&ドロップでシールを貼り付けられる。
//

import SwiftUI
import SwiftData

struct BookDetailView: View {
    let book: StickerBook

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BookDetailViewModel?
    @State private var currentPageIndex = 0
    @State private var selectedSticker: Sticker?
    @State private var isShowingStickerImport = false
    @State private var isShowingDeletePageConfirm = false
    @State private var isEditMode = false

    var body: some View {
        VStack(spacing: 0) {
            if book.pages.isEmpty {
                Spacer()
            } else {
                TabView(selection: $currentPageIndex) {
                    ForEach(Array(book.sortedPages.enumerated()), id: \.element.id) { index, page in
                        PageCanvasView(
                            page: page,
                            isEditMode: isEditMode,
                            onDropSticker: { stickerID, point in
                                viewModel?.place(stickerID: stickerID, onto: page, at: point)
                            },
                            onTapPlacement: { placement in
                                selectedSticker = placement.sticker
                            },
                            onMovePlacement: { placement, x, y in
                                viewModel?.updatePosition(placement, x: x, y: y)
                            },
                            onTransformPlacement: { placement, scale, rotation in
                                viewModel?.updateTransform(placement, scale: scale, rotation: rotation)
                            },
                            onBringToFront: { placement in
                                viewModel?.bringToFront(placement)
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                PageIndicatorView(count: book.pages.count, current: $currentPageIndex)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
            }

            if isEditMode {
                StickerTrayView(
                    onImportTapped: { isShowingStickerImport = true },
                    onSelectSticker: { sticker in selectedSticker = sticker }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(StekkiSpring.sheet, value: isEditMode)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(StekkiSpring.sheet) {
                        isEditMode.toggle()
                    }
                } label: {
                    Label(
                        isEditMode ? "完了" : "編集",
                        systemImage: isEditMode ? "checkmark.circle.fill" : "pencil.circle"
                    )
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        withAnimation(StekkiSpring.pageTurn) {
                            let newPage = viewModel?.addPage()
                            if let newPage {
                                currentPageIndex = newPage.pageIndex
                            }
                        }
                    } label: {
                        Label("ページを追加", systemImage: "plus.square.on.square")
                    }

                    Button(role: .destructive) {
                        isShowingDeletePageConfirm = true
                    } label: {
                        Label("このページを削除", systemImage: "trash")
                    }
                    .disabled(book.pages.count <= 1)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "このページを削除しますか？貼ってあるシールはトレイに戻ります。",
            isPresented: $isShowingDeletePageConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                if let page = book.sortedPages[safe: currentPageIndex] {
                    viewModel?.deletePage(page)
                    currentPageIndex = max(0, currentPageIndex - 1)
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(item: $selectedSticker) { sticker in
            StickerDetailView(
                sticker: sticker,
                onRemoveToTray: {
                    viewModel?.removeToTray(sticker)
                    selectedSticker = nil
                }
            )
        }
        .sheet(isPresented: $isShowingStickerImport) {
            StickerImportView()
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BookDetailViewModel(book: book, modelContext: modelContext)
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
