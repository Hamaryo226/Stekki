//
//  PlacedStickerView.swift
//  Stekki
//
//  ページ上に貼られた1枚のシール。編集モード中のみドラッグで移動、ピンチで拡縮、
//  ひねりで回転ができる。移動ドラッグをそのままトレイの上まで運んで離すと、
//  吸い込まれるように縮小・フェードしてトレイへ戻る。タップでの詳細表示は
//  編集モード中は無効（タップは選択に使う）で、閲覧時のみ有効。
//  編集モード中に選択すると、反転・影のON/OFFを切り替える小さなツールバーが出る。
//
//  拡縮・回転はInstagramストーリーの編集操作を参考にしている：
//  - シールの中心ではなく「指の中心（ピンチ開始位置）」を支点に拡縮・回転する。
//    掴んだ点が指の下に留まり続けるため、拡縮しながら自然に位置も決められる。
//  - 回転は 0°/90°/180°/270° の近くで軽く吸着し、ハプティクスで知らせる。
//  - 1本指ドラッグの途中で2本目の指を置くとそのままピンチへ移行でき、
//    移動・拡縮・回転はまとめて1回の操作として確定する（履歴も1件）。
//  - ピンチ中は浮き上がり演出やツールバーを消し、シールが指に1:1で追従する。
//  拡縮の上限・下限を超えた入力にはゴムのような抵抗（ラバーバンド）をかけ、
//  離した瞬間だけ確定値へきっちりクランプする。
//

import SwiftUI

struct PlacedStickerView: View {
    let placement: StickerPlacement
    let pageSize: CGSize
    /// true の間だけ移動・拡縮・回転ジェスチャが有効になる
    let isEditMode: Bool
    /// 編集モード中、このシールが選択されていて反転・影ツールバーが出ているか
    let isSelected: Bool
    /// "bookCanvas" 座標空間における未貼付トレイの矩形（トレイが非表示の間は .zero）
    let trayFrame: CGRect
    /// このシールが属するページの左上の "bookCanvas" 座標。
    /// トレイへ運ぶ際に、シール中心をページ内座標から画面全体（bookCanvas）座標へ変換するのに使う。
    let pageOriginInCanvas: CGPoint
    /// ドラッグ中のシールを最前面へ持ち上げて表示するための共有ドラッグ層。
    let dragLayer: StickerDragLayerModel

    var onSelect: () -> Void
    var onMove: (Double, Double) -> Void
    /// 拡大率・回転・中心位置（正規化座標）をまとめて確定する
    var onTransform: (Double, Double, CGPoint) -> Void
    var onBringToFront: () -> Void
    var onFlip: () -> Void
    var onToggleShadow: () -> Void
    /// エフェクト（なし→白フチ→キラキラ→…）を1つ進める
    var onCycleEffect: () -> Void
    /// テキストシールの文字を再編集する（選択中にもう一度タップ、またはツールバーのAa）
    var onEditText: () -> Void
    var onTap: () -> Void
    /// ドラッグでトレイの上まで運んで離した時に呼ばれる。実際の削除は少し遅らせて、
    /// 縮小・フェードのアニメーションを見せてから確定する。
    var onReturnToTray: () -> Void
    /// ドラッグ中、指がトレイの高さに達したか変化した時に呼ばれる。
    /// ページ外はクリップされてシールが見えなくなるため、トレイ側をハイライトして
    /// 「ここで離すと戻る」ことを伝えるのに使う。
    var onTrayHover: (Bool) -> Void

    @State private var dragTranslation: CGSize = .zero
    /// ピンチ確定後もドラッグが続いた場合に、確定済みの移動量を差し引くための基準値
    @State private var dragRebase: CGSize = .zero
    /// ピンチ確定の直後は、次のドラッグ更新で基準値を取り直す必要がある
    @State private var needsDragRebase = false

    /// ジェスチャ中の一時的な拡大率（モデル値に対する倍率）
    @State private var liveScale: CGFloat = 1
    /// ジェスチャの生の回転量
    @State private var liveRotation: Angle = .zero
    /// スナップ適用後の回転量（表示・確定にはこちらを使う）
    @State private var liveSnappedRotation: Angle = .zero
    /// 回転が 0°/90°/180°/270° に吸着中か
    @State private var isRotationSnapped = false
    /// 吸着した瞬間にハプティクスを鳴らすためのトリガ
    @State private var rotationSnapCount = 0
    /// ピンチ開始時の指の中心（ページ座標）。この点を支点に拡縮・回転する。
    @State private var pinchAnchor: CGPoint?
    /// ピンチ開始時点でのドラッグ移動量。ドラッグ途中でピンチへ移行した場合、
    /// 支点計算の基準となる中心は「モデル上の位置＋ここまでのドラッグ量」になる。
    @State private var pinchBaseTranslation: CGSize = .zero
    /// 支点固定の拡縮・回転によって生じる、中心位置の一時的な移動量
    @State private var pinchTranslation: CGSize = .zero

    @State private var isInteracting = false
    /// 2本指の拡縮・回転ジェスチャが進行中かどうか（同時に1本指ドラッグが誤反応しないように使う）
    @State private var isPinching = false
    /// ドラッグ中、指がトレイの上にあるか（離すとトレイへ戻る合図としての見た目フィードバック）
    @State private var isOverTray = false
    /// トレイ方向へ運ぶためにシールをドラッグ層へ持ち上げ、実体を隠している間 true。
    /// 指がトレイの高さに達している間だけ true になり、それ以外の通常のページ内移動では
    /// 従来どおりページ上でそのまま動かす。
    @State private var isLifted = false

    private let baseSize: CGFloat = 96
    /// 回転スナップの吸着範囲（約4°）
    private static let rotationSnapThreshold = 0.07

    /// placement.scale (Double, モデル保存値) とジェスチャ中の一時倍率をかけ合わせた表示用スケール。
    /// 上限・下限を超えた分はゴムのように抵抗をかけて伸ばし、指を離した瞬間に確定値へ
    /// きっちりクランプすることで、ジェスチャ中に急に突っかかる／離した瞬間に飛ぶ、を防ぐ。
    private var displayScale: CGFloat {
        let raw = Double(placement.scale) * Double(liveScale)
        return CGFloat(Self.rubberBanded(raw))
    }

    /// placement.rotation (Double・ラジアン, モデル保存値) とスナップ適用済みの一時回転を足した表示用角度
    private var displayRotation: Angle {
        .radians(placement.rotation) + liveSnappedRotation
    }

    private var flipMultiplier: CGFloat {
        placement.isFlippedHorizontally ? -1 : 1
    }

    private var shadowOpacity: Double {
        isInteracting ? 0.22 : (placement.hasShadow ? 0.25 : 0)
    }

    private var shadowRadius: CGFloat {
        isInteracting ? 10 : (placement.hasShadow ? 6 : 0)
    }

    private var shadowYOffset: CGFloat {
        isInteracting ? 6 : (placement.hasShadow ? 4 : 0)
    }

    private var isGlowing: Bool {
        placement.effect == .glow
    }

    /// このシールが文字から作られたもの（再編集できる）か
    private var isTextSticker: Bool {
        placement.sticker?.isTextSticker == true
    }

    var body: some View {
        StickerImageView(
            fileName: placement.sticker?.thumbnailFileName ?? placement.sticker?.imageFileName,
            effect: placement.effect
        )
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(x: flipMultiplier * displayScale, y: displayScale)
            .rotationEffect(displayRotation)
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowYOffset)
            // キラキラ（グロー）エフェクト：白＋淡い黄色の2重シャドウで光らせる
            .shadow(color: isGlowing ? .white.opacity(0.85) : .clear, radius: isGlowing ? 10 : 0)
            .shadow(color: isGlowing ? .yellow.opacity(0.5) : .clear, radius: isGlowing ? 18 : 0)
            // 浮き上がり演出は1本指ドラッグの時だけ。ピンチ中は指の下の点と表示が
            // ずれないよう等倍のまま1:1で追従させる（Instagramの編集と同じ挙動）。
            .scaleEffect(isInteracting && !isPinching ? 1.06 : 1.0)
            // 指がトレイの高さに達している間は、実体を隠して最前面のドラッグ層に描く
            // （ページのクリップとトレイのz順序に邪魔されずトレイの上まで見せるため）。
            .opacity(isLifted ? 0 : 1)
            .overlay(editModeIndicator)
            .overlay(alignment: .topLeading) { selectionHandle }
            .overlay(alignment: .top) { editToolbar }
            .position(
                x: CGFloat(placement.x) * pageSize.width + dragTranslation.width + pinchTranslation.width,
                y: CGFloat(placement.y) * pageSize.height + dragTranslation.height + pinchTranslation.height
            )
            .zIndex(isSelected ? 9999 : Double(placement.zIndex))
            .animation(StekkiSpring.drag, value: isInteracting)
            .animation(StekkiSpring.standard, value: isEditMode)
            .animation(StekkiSpring.standard, value: isSelected)
            .sensoryFeedback(.impact(weight: .light), trigger: rotationSnapCount)
            .gesture(dragGesture, including: isEditMode ? .all : .none)
            .simultaneousGesture(transformGesture, including: isEditMode ? .all : .none)
            .onTapGesture {
                // 編集中はタップを選択に使い、詳細シートは開かない。
                // 選択済みのテキストシールをもう一度タップすると文字の再編集へ
                // （IGで文字をタップすると編集に入るのと同じ流れ）。
                // 閲覧時のみタップで詳細を表示する。
                if isEditMode {
                    if isSelected, isTextSticker {
                        onEditText()
                    } else {
                        onSelect()
                    }
                } else {
                    onTap()
                }
            }
            .accessibilityLabel("貼り付けられたシール")
            .accessibilityAddTraits(.isButton)
    }

    /// 編集モード中であることを示す、うっすらとした点線の枠
    @ViewBuilder
    private var editModeIndicator: some View {
        if isEditMode {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(isSelected ? Color.accentColor : .white.opacity(0.9))
                .scaleEffect(x: flipMultiplier * displayScale, y: displayScale)
                .rotationEffect(displayRotation)
                .allowsHitTesting(false)
        }
    }

    /// 編集モード中、タップでこのシールを選択できる小さなハンドル。
    /// 操作中は消してシール本体だけが指に追従して見えるようにする。
    @ViewBuilder
    private var selectionHandle: some View {
        if isEditMode, !isInteracting {
            Button(action: onSelect) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(isSelected ? Color.accentColor : Color.black.opacity(0.55), in: Circle())
            }
            .offset(x: -6, y: -6)
        }
    }

    /// 選択中のシールの上に浮かぶ、反転・影のミニツールバー（操作中は非表示）。
    /// ページはページ矩形でクリップされるため、シールがページ上端の近くにあるときは
    /// ツールバーが見切れないよう、シールの下側へ回り込ませる。
    @ViewBuilder
    private var editToolbar: some View {
        if isEditMode, isSelected, !isInteracting {
            let isNearPageTop = CGFloat(placement.y) * pageSize.height < baseSize / 2 + 60
            HStack(spacing: 4) {
                Button(action: onFlip) {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                }
                Divider().frame(height: 14)
                Button(action: onToggleShadow) {
                    Image(systemName: placement.hasShadow ? "sun.max.fill" : "sun.max")
                }
                Divider().frame(height: 14)
                // エフェクトはIGのステッカーと同じくタップのたびに切り替わる
                Button(action: onCycleEffect) {
                    Image(systemName: placement.effect.iconName)
                        .opacity(placement.effect == StickerEffect.none ? 0.6 : 1)
                }
                if isTextSticker {
                    Divider().frame(height: 14)
                    Button(action: onEditText) {
                        Image(systemName: "character.cursor.ibeam")
                    }
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.7), in: Capsule())
            .offset(y: isNearPageTop ? baseSize / 2 + 56 : -baseSize / 2 - 26)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }

    // MARK: - 移動（1本指ドラッグ）

    /// 指がトレイに達したかの判定。トレイはページの下に全幅で表示されるため、
    /// 矩形との厳密な交差ではなく「トレイの上端より少し上より下に指がある」ことで判定する
    /// （ページ下端とトレイの間の余白でも拾えるよう、上端より少し手前から有効にする）。
    private func isLocationOverTray(_ location: CGPoint) -> Bool {
        trayFrame != .zero && location.y >= trayFrame.minY - 24
    }

    /// ドラッグ中のシール中心の "bookCanvas" 座標。
    /// ドラッグ層（画面全体）に持ち上げて描くために、ページ内座標を画面全体座標へ変換する。
    private func draggedCenterInCanvas() -> CGPoint {
        CGPoint(
            x: pageOriginInCanvas.x + CGFloat(placement.x) * pageSize.width + dragTranslation.width,
            y: pageOriginInCanvas.y + CGFloat(placement.y) * pageSize.height + dragTranslation.height
        )
    }

    /// ドラッグ層に、いま持ち上げているシールの見た目を反映する
    private func updateDragLayer(overTray: Bool) {
        dragLayer.preview = DraggedStickerPreview(
            placementID: placement.id,
            fileName: placement.sticker?.thumbnailFileName ?? placement.sticker?.imageFileName,
            center: draggedCenterInCanvas(),
            scale: displayScale,
            rotation: displayRotation,
            flipped: placement.isFlippedHorizontally,
            effect: placement.effect,
            overTray: overTray
        )
    }

    /// 自分が持ち上げているプレビューを片付ける（他シールのプレビューは触らない）
    private func clearDragLayerIfMine() {
        if dragLayer.preview?.placementID == placement.id {
            dragLayer.preview = nil
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("bookCanvas"))
            .onChanged { value in
                // 2本指でのピンチ・回転中は、1本指ドラッグの位置更新を無視する
                // （両方のジェスチャが同時に認識され、シールが暴れるのを防ぐ）。
                guard !isPinching else { return }
                if !isInteracting {
                    isInteracting = true
                    onSelect()
                    onBringToFront()
                }
                // ピンチ確定の直後にドラッグが続いている場合、ピンチ側で確定済みの
                // 移動量を二重に加算しないよう、ここまでの移動量を基準値として差し引く。
                if needsDragRebase {
                    dragRebase = value.translation
                    needsDragRebase = false
                }
                dragTranslation = CGSize(
                    width: value.translation.width - dragRebase.width,
                    height: value.translation.height - dragRebase.height
                )
                let overTray = isLocationOverTray(value.location)
                if overTray != isOverTray {
                    isOverTray = overTray
                    onTrayHover(overTray)
                }
                // トレイの高さに来たらシールを最前面へ持ち上げて追従表示する。
                // 離れたらページ上の実体表示に戻す。
                if overTray {
                    isLifted = true
                    updateDragLayer(overTray: true)
                } else if isLifted {
                    isLifted = false
                    clearDragLayerIfMine()
                }
            }
            .onEnded { value in
                // ピンチ中にドラッグが終わった場合は、ピンチ側の確定処理に任せる
                guard !isPinching else { return }
                onTrayHover(false)
                let droppedOnTray = isLocationOverTray(value.location)
                if droppedOnTray {
                    returnToTray()
                } else {
                    isLifted = false
                    clearDragLayerIfMine()
                    let effectiveTranslation: CGSize = needsDragRebase
                        ? .zero  // ピンチ確定後、一度も動いていなければ移動なし
                        : CGSize(
                            width: value.translation.width - dragRebase.width,
                            height: value.translation.height - dragRebase.height
                        )
                    // ピンチ側で位置確定済みなど、動いていない場合はコミットしない
                    // （同じ値で onMove を呼ぶと履歴に余計な1件が追加されてしまう）
                    if effectiveTranslation != .zero {
                        let deltaX = Double(effectiveTranslation.width / max(pageSize.width, 1))
                        let deltaY = Double(effectiveTranslation.height / max(pageSize.height, 1))
                        let newX = (placement.x + deltaX).clamped(to: 0...1)
                        let newY = (placement.y + deltaY).clamped(to: 0...1)
                        onMove(newX, newY)
                    }
                    dragTranslation = .zero
                    isInteracting = false
                }
                dragRebase = .zero
                needsDragRebase = false
                isOverTray = false
            }
    }

    /// トレイの上でドラッグを離した時、ドラッグ層のシールをトレイへ吸い込まれるように
    /// 縮小・移動させてから、実際にモデルから取り除く（見た目が先、データの確定はそのあと）。
    private func returnToTray() {
        isInteracting = false
        isOverTray = false
        onTrayHover(false)
        dragRebase = .zero
        needsDragRebase = false
        // 実体はドラッグ層に持ち上がったままなので、実体は隠したままにしておく。
        isLifted = true

        // ドラッグ層のシールをトレイの中央へ吸い込む
        let target = CGPoint(x: trayFrame.midX, y: trayFrame.minY + trayFrame.height * 0.4)
        withAnimation(StekkiSpring.returnToTray) {
            dragLayer.preview?.center = target
            dragLayer.preview?.overTray = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 240_000_000)
            clearDragLayerIfMine()
            isLifted = false
            dragTranslation = .zero
            onReturnToTray()
        }
    }

    // MARK: - 拡縮・回転（2本指）

    /// 拡縮・回転を1つのジェスチャとして扱い、指を離した瞬間に両方の値を同時に確定する。
    /// MagnifyGesture / RotateGesture（iOS 17）は開始位置を報告してくれるため、
    /// 指の中心を支点にした拡縮・回転ができる（従来のシール中心固定と違い、
    /// 掴んだ点が指の下に留まり続ける）。
    private var transformGesture: some Gesture {
        SimultaneousGesture(MagnifyGesture(), RotateGesture())
            .onChanged { value in
                if !isInteracting {
                    isInteracting = true
                    onSelect()
                    onBringToFront()
                }
                isPinching = true
                if pinchAnchor == nil {
                    // トレイ上で持ち上げ中に2本目の指が来た場合は、持ち上げを解除して
                    // 通常のページ上ピンチに戻す（ドラッグ層に置き去りにしない）。
                    if isLifted {
                        isLifted = false
                        isOverTray = false
                        onTrayHover(false)
                        clearDragLayerIfMine()
                    }
                    // このビューは .position 適用後にジェスチャが付くためページ全体に
                    // 広がっており、startLocation はそのままページ座標として使える
                    pinchAnchor = value.first?.startLocation ?? value.second?.startLocation
                    // ドラッグ途中からピンチへ移行した場合は、ここまでの移動量込みの
                    // 位置を基準にする（ドラッグ量はピンチ中凍結される）
                    pinchBaseTranslation = dragTranslation
                    // すでに吸着角度で貼られているシールをつまんだ瞬間に
                    // ハプティクスが鳴らないよう、開始時の吸着状態を先に反映しておく
                    let snapUnit = Double.pi / 2
                    let nearest = (placement.rotation / snapUnit).rounded() * snapUnit
                    isRotationSnapped = abs(placement.rotation - nearest) < Self.rotationSnapThreshold
                }
                if let magnification = value.first?.magnification {
                    liveScale = magnification
                }
                if let rotation = value.second?.rotation {
                    liveRotation = rotation
                }
                updateLiveTransform()
            }
            .onEnded { value in
                if let magnification = value.first?.magnification {
                    liveScale = magnification
                }
                if let rotation = value.second?.rotation {
                    liveRotation = rotation
                }
                updateLiveTransform()

                // 確定値はラバーバンドではなくクランプ。位置も確定スケールで計算し直すことで、
                // 上限を超えてつまんだ状態で離した時に表示と保存値がずれないようにする。
                // anchoredCenter はピンチ開始前のドラッグ移動量も基準に含んでいるため、
                // 移動・拡縮・回転がこの1回でまとめて確定する（履歴も1件）。
                let finalScale = (placement.scale * Double(liveScale)).clamped(to: StickerPlacement.scaleRange)
                let finalRotation = placement.rotation + liveSnappedRotation.radians
                let finalCenter = anchoredCenter(totalScale: finalScale, totalRotation: finalRotation)
                let newCenter = CGPoint(
                    x: Double(finalCenter.x / max(pageSize.width, 1)).clamped(to: 0...1),
                    y: Double(finalCenter.y / max(pageSize.height, 1)).clamped(to: 0...1)
                )
                onTransform(finalScale, finalRotation, newCenter)

                liveScale = 1
                liveRotation = .zero
                liveSnappedRotation = .zero
                pinchAnchor = nil
                pinchBaseTranslation = .zero
                pinchTranslation = .zero
                dragTranslation = .zero
                needsDragRebase = true  // ドラッグがまだ続いていれば、次の更新で基準を取り直す
                isRotationSnapped = false
                isInteracting = false
                isPinching = false
                isOverTray = false
                onTrayHover(false)
            }
    }

    /// ジェスチャの生値から、スナップ適用後の回転と支点補正の移動量を更新する
    private func updateLiveTransform() {
        // 回転スナップ: 合計角度が 0°/90°/180°/270° に近ければ吸着し、
        // 吸着した瞬間だけ軽いハプティクスを鳴らす（Instagramの編集と同じ挙動）
        let totalRotation = placement.rotation + liveRotation.radians
        let snapUnit = Double.pi / 2
        let nearest = (totalRotation / snapUnit).rounded() * snapUnit
        if abs(totalRotation - nearest) < Self.rotationSnapThreshold {
            liveSnappedRotation = .radians(nearest - placement.rotation)
            if !isRotationSnapped {
                isRotationSnapped = true
                rotationSnapCount += 1
            }
        } else {
            liveSnappedRotation = liveRotation
            isRotationSnapped = false
        }

        // 指の中心（支点）が動かないよう、拡縮・回転に応じた中心位置の移動量を計算する。
        // pinchTranslation は「基準中心（モデル位置＋凍結中のドラッグ量）」からの差分。
        // 表示側では dragTranslation と pinchTranslation の両方が加算されるため、
        // ここで基準中心を引いておくことで二重加算にならない。
        let displayTotalScale = Self.rubberBanded(Double(placement.scale) * Double(liveScale))
        let center = anchoredCenter(
            totalScale: displayTotalScale,
            totalRotation: placement.rotation + liveSnappedRotation.radians
        )
        pinchTranslation = CGSize(
            width: center.x - (CGFloat(placement.x) * pageSize.width + pinchBaseTranslation.width),
            height: center.y - (CGFloat(placement.y) * pageSize.height + pinchBaseTranslation.height)
        )
    }

    /// 支点（ピンチ開始時の指の中心）を固定して拡縮・回転した場合の、シール中心のページ座標。
    /// 支点Pの周りに拡大率比k・回転差Δθを適用すると、中心Cは P + R(Δθ)·(k·(C-P)) へ移る。
    /// 基準の中心Cは「モデル上の位置＋ピンチ開始時点のドラッグ移動量」。
    /// 左右反転はシール自身の描画にだけ効き、中心位置の計算には影響しない。
    private func anchoredCenter(totalScale: Double, totalRotation: Double) -> CGPoint {
        let baseCenter = CGPoint(
            x: CGFloat(placement.x) * pageSize.width + pinchBaseTranslation.width,
            y: CGFloat(placement.y) * pageSize.height + pinchBaseTranslation.height
        )
        guard let anchor = pinchAnchor else { return baseCenter }
        let scaleRatio = CGFloat(totalScale / max(placement.scale, 0.0001))
        let deltaRotation = CGFloat(totalRotation - placement.rotation)
        let v = CGPoint(x: baseCenter.x - anchor.x, y: baseCenter.y - anchor.y)
        let rotated = CGPoint(
            x: v.x * cos(deltaRotation) - v.y * sin(deltaRotation),
            y: v.x * sin(deltaRotation) + v.y * cos(deltaRotation)
        )
        return CGPoint(
            x: anchor.x + rotated.x * scaleRatio,
            y: anchor.y + rotated.y * scaleRatio
        )
    }

    /// 上限・下限をわずかに超えた入力に対して、抵抗をかけながら伸ばす
    /// （現実の物のように、急に止まるのではなく徐々に重くなる）。
    /// ジェスチャ中の一時的な見た目にのみ使い、確定値は呼び出し側で必ずクランプする。
    private static func rubberBanded(
        _ raw: Double,
        min minValue: Double = StickerPlacement.scaleRange.lowerBound,
        max maxValue: Double = StickerPlacement.scaleRange.upperBound
    ) -> Double {
        if raw < minValue {
            let overflow = minValue - raw
            return minValue - overflow / (1 + overflow * 3)
        } else if raw > maxValue {
            let overflow = raw - maxValue
            return maxValue + overflow / (1 + overflow * 3)
        }
        return raw
    }
}
