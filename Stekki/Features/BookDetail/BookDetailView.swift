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
    @State private var isShowingTextStickerCreate = false
    /// 文字を再編集中のテキストシール（フルスクリーンのエディタを開く）
    @State private var editingTextSticker: Sticker?
    @State private var isShowingDeletePageConfirm = false
    @State private var isEditMode = false
    /// "bookCanvas" 座標空間における未貼付トレイの矩形。シールをドラッグでトレイへ
    /// 戻す判定（トレイの上に重なっているか）に使う。トレイが非表示の間は .zero。
    @State private var trayFrame: CGRect = .zero
    /// シールをドラッグ中、指がトレイの高さに達しているか（トレイのハイライト表示用）
    @State private var isTrayDropTargeted = false
    /// ドラッグ中のシールを最前面へ持ち上げて表示するためのドラッグ層。
    /// トレイへ運ぶ間、ページのクリップやトレイのz順序に邪魔されず、シールをトレイの上まで見せる。
    @State private var dragLayer = StickerDragLayerModel()

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
                            trayFrame: trayFrame,
                            onDropSticker: { stickerID, point in
                                viewModel?.place(stickerID: stickerID, onto: page, at: point)
                            },
                            onTapPlacement: { placement in
                                selectedSticker = placement.sticker
                            },
                            onMovePlacement: { placement, x, y in
                                viewModel?.updatePosition(placement, x: x, y: y)
                            },
                            onTransformPlacement: { placement, scale, rotation, center in
                                viewModel?.updateTransform(placement, scale: scale, rotation: rotation, x: center.x, y: center.y)
                            },
                            onBringToFront: { placement in
                                viewModel?.bringToFront(placement)
                            },
                            onFlipPlacement: { placement in
                                viewModel?.toggleFlip(placement)
                            },
                            onToggleShadowPlacement: { placement in
                                viewModel?.toggleShadow(placement)
                            },
                            onCycleEffectPlacement: { placement in
                                viewModel?.cycleEffect(placement)
                            },
                            onEditTextPlacement: { placement in
                                editingTextSticker = placement.sticker
                            },
                            onReturnPlacementToTray: { placement in
                                if let sticker = placement.sticker {
                                    viewModel?.removeToTray(sticker)
                                }
                            },
                            onTrayHoverChanged: { hovering in
                                isTrayDropTargeted = hovering
                            },
                            dragLayer: dragLayer
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
                    isDropTargetActive: isTrayDropTargeted,
                    onImportFromPhotoTapped: { isShowingStickerImport = true },
                    onCreateTextStickerTapped: { isShowingTextStickerCreate = true },
                    onSelectSticker: { sticker in selectedSticker = sticker }
                )
                .background(
                    GeometryReader { trayGeo in
                        Color.clear
                            .preference(key: TrayFramePreferenceKey.self, value: trayGeo.frame(in: .named("bookCanvas")))
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // ドラッグ中のシールを最前面へ持ち上げる層。トレイより手前・ページのクリップ外に
        // 描くことで、トレイへ運ぶ間もシールがトレイの上まで見えたまま追従する。
        .overlay {
            StickerDragLayer(model: dragLayer)
        }
        .coordinateSpace(name: "bookCanvas")
        .onPreferenceChange(TrayFramePreferenceKey.self) { newFrame in
            trayFrame = newFrame
        }
        .onChange(of: isEditMode) { _, newValue in
            if !newValue {
                trayFrame = .zero
                isTrayDropTargeted = false
                dragLayer.preview = nil
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
        // テキストシールの作成・再編集はIGストーリー風のフルスクリーンエディタで行う
        .fullScreenCover(isPresented: $isShowingTextStickerCreate) {
            TextStickerEditorView()
        }
        .fullScreenCover(item: $editingTextSticker) { sticker in
            TextStickerEditorView(editingSticker: sticker)
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
