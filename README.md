# Stekki（デジタルシール帳）

写真から作った透明PNGのシールを、複数ページのシール帳に自由に貼り付けて楽しむ iOS アプリです。
アカウント登録やサーバー通信は一切行わず、**すべての機能が端末内（オンデバイス）だけで完結**します。
このバージョンでは、AirDrop によるシール交換機能は未実装で、まずローカルのシール帳編集機能（作成・貼付・移動・拡縮・回転・履歴）が一通り動く状態にしてあります。

## 起動方法

1. `Stekki.xcodeproj` を Xcode（26系を推奨。プロジェクトは iOS 17.0 以降をターゲットにしています）で開く。
2. 実行ターゲットを `Stekki` に、シミュレータまたは実機を選択する。
3. `Cmd + R` でビルド＆実行する。
   - 初回ビルド時、`Stekki/` フォルダ以下は Xcode 16 以降の「Synchronized Group」機能で自動的にターゲットへ追加されるため、`.pbxproj` を手動編集する必要はありません。新しく `.swift` ファイルを `Stekki/` 配下に追加した場合も同様に自動で拾われます。
4. 実機で「写真からシールを作成」を試す場合、初回のみシステムの写真選択ピッカーが表示されます（`PhotosPicker` は別プロセスで動作するため、`Info.plist` に写真ライブラリの利用許可キーは不要です）。

### テスト

`StekkiTests`（Swift Testing）に、シール帳作成・シールの貼付／トレイへの取り出し・座標のクランプ処理に対する基本的な単体テストを用意しています。`Cmd + U` で実行できます。

> **ビルド確認について**：本リポジトリの開発環境には Xcode（macOS）がないため、`xcodebuild` による実機ビルド確認はできていません。コードは型・API シグネチャ・インポート漏れ・SwiftUI の `@ViewBuilder` 要件などを重点的に手動レビューし、コンパイルが通るよう整えていますが、**実際に Xcode で一度ビルドして動作確認してください**。もしビルドエラーが出た場合は、エラーメッセージを共有してもらえれば修正します。

## できること（v1 スコープ）

- シール帳の作成・削除・複数ページの追加／削除
- 写真ライブラリからシールを作成
  - 「背景を自動で透明にする」トグルをONにするとVisionの被写体検出でオンデバイス背景除去（iOSシミュレータでは失敗しやすいので注意）、OFFにすると写真をそのままPNG化してシールにする
  - 「角を丸くする」スライダー（0〜50%）で、四隅を丸めたシールに加工できる
- ページ右上の「編集」ボタンで編集モードに切り替えたときだけ、未貼付トレイが表示され、シールの貼付・移動・拡大縮小・回転ができる（閲覧時に誤って動かしてしまうことを防止）
  - 未貼付トレイに並んだシールを、ページへドラッグ＆ドロップで貼付
  - 貼ったシールをドラッグで移動、ピンチで拡大縮小、ひねりで回転、タップで最前面に
- シール詳細画面で、作成日時・作成者表示名・受取日時／受取元・現在のページと位置・貼付履歴を確認／編集
  - 写真をタップするとフルスクリーンでプレビュー表示（ピンチズーム、下スワイプで閉じる）
- シールをページから剥がしてトレイへ戻す、シール自体を完全削除

### v1 スコープ外（今後）

- AirDrop によるシール交換（意図的に未実装）
- iCloud同期（要件により非搭載。すべてオンデバイスのApplication Support配下に保存）

## アーキテクチャ

Feature 単位のディレクトリ構成 + 各 Feature 内は View / ViewModel（MVVM）で分離しています。

```
Stekki/
├── StekkiApp.swift          … エントリポイント、ModelContainer（SwiftData）のスキーマ定義
├── Models/                  … SwiftData の @Model 定義
│   ├── StickerBook.swift
│   ├── StickerPage.swift
│   ├── Sticker.swift
│   ├── StickerPlacement.swift
│   ├── PlacementHistory.swift
│   └── PlacementAction.swift  … 履歴のアクション種別 (enum)
├── Persistence/
│   └── StickerFileStore.swift … 透明PNGをApplication Support配下に保存・読込・削除
├── DesignSystem/             … Apple Design（Fluid Interfaces）準拠のスプリング・マテリアル・画像キャッシュ
│   ├── StekkiSpring.swift
│   ├── Color+Hex.swift
│   ├── MaterialBackground.swift
│   ├── StickerImageCache.swift
│   └── StickerImageView.swift
└── Features/
    ├── BookList/             … シール帳一覧（作成・削除・グリッド表示）
    ├── BookDetail/           … シール帳詳細（ページ送り、キャンバス、ドラッグ&ドロップ受け皿）
    ├── StickerTray/          … 未貼付トレイ（横スクロール、draggableなシールカード）
    ├── StickerDetail/        … シール詳細（メタデータ編集・貼付履歴タイムライン）
    └── StickerImport/        … 写真選択→背景除去→トレイへ保存
```

## データ構造（SwiftData）

5つの `@Model` が以下の関係で構成されています。

```
StickerBook 1 ── * StickerPage 1 ── * StickerPlacement 1 ── 1 Sticker 1 ── * PlacementHistory
   (シール帳)         (ページ)          (現在の貼付状態)         (シール本体)      (貼付履歴ログ)
```

- **StickerBook**：シール帳そのもの。`title` / `coverColorHex` / `createdAt` / `updatedAt` と、複数の `StickerPage`（cascade削除）を保持。
- **StickerPage**：シール帳の1ページ。`pageIndex`（並び順）/ `backgroundColorHex` と、そのページに貼られた `StickerPlacement` の配列（cascade削除）を保持。
- **Sticker**：シール本体（写真から作った透明PNG）。`imageFileName` / `thumbnailFileName` はファイル名のみを保持し、実体は `StickerFileStore` が管理する `Application Support/Stickers/` 配下に保存（絶対パスは保存しない）。`createdAt`（作成日時）・`authorDisplayName`（作成者表示名）・`receivedAt` / `receivedFrom`（受取日時・受取元、自分で作った場合は両方 `nil`）を持つ。
- **StickerPlacement**：シールの「現在の」貼付状態。`Sticker` と `StickerPage` の両方に対する1:1〜多対1の関係で、正規化座標 `x` / `y`（0.0〜1.0、ページ左上が原点）、`scale`（拡大率）、`rotation`（ラジアン）、`zIndex`（重なり順）を保持。`Sticker.placement` が `nil` の場合は「未貼付トレイにある」ことを意味する。
- **PlacementHistory**：貼付操作のログ（`placed` / `moved` / `movedToPage` / `removedToTray`）。操作時点の座標・拡縮・回転・重なり順と、削除されたページでも読めるようページ名／シール帳名のスナップショット文字列を保持。`Sticker` に対して1対多。

### 貼付フロー

1. トレイのシールを `draggable(StickerTransferItem)` でドラッグ開始（Transferableな最小ペイロードとしてシールIDのみを運ぶ、アプリ内完結）。
2. ページ側は `dropDestination(for: StickerTransferItem.self)` でドロップ位置（View内座標）を受け取り、ページのサイズで割って正規化座標に変換。
3. `BookDetailViewModel.place(stickerID:onto:at:)` が `StickerPlacement` を新規作成し、`Sticker.placement` に紐付け、`PlacementHistory` に `.placed` を追記。
4. 貼付後の移動・拡縮・回転もそれぞれ `updatePosition` / `updateTransform` が呼ばれ、都度 `PlacementHistory` に `.moved` を追記。
5. 「トレイに戻す」操作で `removeToTray` が呼ばれ、`StickerPlacement` を削除して `Sticker.placement` を `nil` に戻し、`.removedToTray` を追記。

## 補足

- 画像の背景除去には `Vision` の `VNGenerateForegroundInstanceMaskRequest`（iOS 17〜）を使用しており、完全にオンデバイスで処理されます（ネットワーク通信なし）。このAPIはNeural Engineに依存しており、**iOSシミュレータでは失敗しやすい**ことが知られているため、シール作成画面には「背景を自動で透明にする」のON/OFFトグルを用意しています。OFFにすると `BackgroundRemover.makeOpaqueSticker` が写真をそのままPNG化するため、Visionを使わずシミュレータでも常に成功します。実機であればONのまま試すのがおすすめです。
- ドラッグ操作は SwiftUI 標準の `draggable` / `dropDestination` を使用し、システムのドラッグプレビューが指の動きに1:1で追従します。貼付済みシールの移動・拡縮・回転は独自のジェスチャで実装し、Apple の Fluid Interfaces の指針（押した瞬間に反応する・ジェスチャ中は1:1で追従・離した瞬間だけ軽くスプリングで収束）に沿っています。
