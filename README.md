# Stekki（デジタルシール帳）

写真から作った透明PNGのシールを、複数ページのシール帳に自由に貼り付けて楽しむ iOS アプリです。
アカウント登録やサーバー通信は一切行わず、**すべての機能が端末内（オンデバイス）だけで完結**します。
ローカルのシール帳編集機能（作成・貼付・移動・拡縮・回転・履歴）に加えて、AirDrop 等でシールを「送る」「受け取る」機能（`.stickertrade` ファイル）を搭載しています。

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
  - 「角を丸くする」スライダー（0〜50%）で、四隅を丸めたシールに加工できる。ドラッグ中はプレビューだけを軽量に更新し、指を離した時にだけ保存用データを確定するため滑らかに動く
- テキストシールの作成（写真を使わず、文字だけのシールを作る）。**Instagramストーリーの文字編集と同じ操作感のフルスクリーンエディタ**
  - 画面中央でそのまま文字を入力する。画面の空きスペースをタップすると「入力 ⇔ 実際のシール描画プレビュー」が切り替わる
  - **左端の縦スライダー**（IGと同じ配置。上が太いテーパー形状）で文字サイズを36〜120ptに調整できる。サイズはそのまま描画解像度に反映され、大きくすればくっきり大きなシールになる
  - 上部バーで**行揃えの循環**（左→中央→右。IGの整列ボタンと同じ）と、**「A」ボタンによる背景プレート**（角丸の下地）のON/OFFを切り替えられる
  - 下部のアイコンタブで「フォント／カラー／縁取り／形」のツールを切り替える
    - フォント（標準／丸ゴシック／手書き風／かわいい系／タイプライター）は横スクロールのカルーセルから、そのフォント自身の見た目で選べる
    - カラーは「文字・縁取り・背景」の対象を選んでスウォッチをタップで即切り替え（細かい色はColorPickerで指定）。縁取り・背景の色を選ぶとそれぞれ自動でONになる
    - **文字の形**：「アーチ」「波」「ふくらみ」から選び、強さスライダー（-100%〜+100%）で調整できる。アーチは正で上向き・負で下向き、ふくらみは負にすると中央がくびれる。1文字ずつ位置・回転・サイズを計算して描画している。形・縁取りのタブを開くと自動でキーボードが閉じ、仕上がりプレビューで確認しながら調整できる
  - **作った後・貼った後からの文字の再編集**：テキストシールは元の文字仕様（`TextStickerSpec` のJSON）をシール自体が記憶しているので、IGで文字をタップし直すのと同じ感覚で、後から何度でも編集して画像を作り直せる
    - 編集モードで選択中のテキストシールを**もう一度タップ**、またはミニツールバーの文字編集ボタンでエディタが開く（貼付位置・履歴はそのまま）
    - トレイにあるテキストシールは、詳細画面の「文字を編集」から開ける
- ページ右上の「編集」ボタンで編集モードに切り替えたときだけ、未貼付トレイが表示され、シールの貼付・移動・拡大縮小・回転ができる（閲覧時に誤って動かしてしまうことを防止）
  - 未貼付トレイに並んだシールを、ページへドラッグ＆ドロップで貼付
  - 貼ったシールをドラッグで移動、ピンチで拡大縮小、ひねりで回転、タップで最前面に
  - 拡縮・回転はInstagramストーリーの編集操作を参考にした挙動：シールの中心ではなく**指の中心を支点**に拡縮・回転する（掴んだ点が指の下に留まる）、回転は0°/90°/180°/270°付近で軽く吸着してハプティクスで知らせる、ドラッグ途中に2本目の指を置くとそのままピンチへ移行できる
  - 貼ったシールを下のトレイまでドラッグして離すと、トレイへ戻る（詳細画面の「トレイに戻す」ボタンも引き続き利用可）。指がトレイの高さまで来るとトレイが「ここで離すとトレイに戻ります」表示に切り替わってハイライトされ、シール自体も最前面へ「持ち上がって」トレイの上まで見えたまま運べる（離すと吸い込まれるようにトレイへ戻る）
  - シールがページの範囲外へはみ出した部分は、本物のシール帳のようにページの縁で切り取られて見えなくなる（ページ矩形の角丸でクリップ）。ただしトレイへドラッグしている間だけは、上記の「持ち上げ」により最前面のドラッグ層へ描かれるので、クリップやトレイの重なりに隠れず運べる
  - 編集モード中はシールをタップしても詳細画面は開かない（タップは選択に使う。詳細を見るには編集モードを終了してからタップ）
  - シールを選択（左上のハンドルをタップ、またはドラッグ開始）すると出るミニツールバーから、左右反転・影のON/OFF・**エフェクト**を切り替え可能。テキストシールの場合は文字の再編集ボタンも並ぶ
  - **エフェクト**はIGのステッカーをタップして見た目を切り替えるのと同じように、ボタンを押すたびに「なし → 白フチ → キラキラ → なし…」と循環する
    - **白フチ**：被写体の形に沿った白い縁取り（IGのステッカー風）。Core Imageのモルフォロジー膨張でアルファを外側へ広げて生成し、結果はメモリキャッシュされる
    - **キラキラ**：白＋淡い黄色の2重グローで光っているような見た目にする
- シール詳細画面で、作成日時・作成者表示名・受取日時／受取元・現在のページと位置（反転・影・エフェクトの状態を含む）・貼付履歴を確認／編集
  - 写真をタップするとフルスクリーンでプレビュー表示（ピンチズーム、下スワイプで閉じる）
- シールをページから剥がしてトレイへ戻す（ドラッグ、または詳細画面のボタン）、シール自体を完全削除
- **AirDrop等でシールを「送る」「受け取る」**（詳細は後述の「AirDropでシールを送る・受け取る」参照）
  - シール詳細画面の「このシールを送る」から `.stickertrade` ファイルを共有シート（`UIActivityViewController`）で送信
  - 受け取った側はプレビュー画面で内容を確認し、「トレイに追加」を押したときにだけ未貼付トレイへ保存（自動保存はしない）

### v1 スコープ外（今後）

- iCloud同期（要件により非搭載。すべてオンデバイスのApplication Support配下に保存）
- シールの原子的な「交換」（送ったら手元から消え、確実に相手へ渡る保証）。AirDrop は相手アプリが受信処理を完了したかどうかを送信側アプリから確認できないため、意図的に「送る」「受け取る」という一方向の機能名・設計にしています（送っても手元のシールは残る）

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
│   ├── PlacementAction.swift  … 履歴のアクション種別 (enum)
│   └── StickerEffect.swift    … 貼付エフェクト（なし／白フチ／キラキラ）の種別 (enum)
├── Persistence/
│   └── StickerFileStore.swift … 透明PNGをApplication Support配下に保存・読込・削除
├── DesignSystem/             … Apple Design（Fluid Interfaces）準拠のスプリング・マテリアル・画像キャッシュ
│   ├── StekkiSpring.swift
│   ├── Color+Hex.swift
│   ├── MaterialBackground.swift
│   ├── StickerImageCache.swift
│   ├── StickerImageView.swift
│   └── StickerEffectRenderer.swift … 白フチ画像の生成（Core Imageモルフォロジー膨張）とキャッシュ
└── Features/
    ├── BookList/             … シール帳一覧（作成・削除・グリッド表示）
    ├── BookDetail/           … シール帳詳細（ページ送り、キャンバス、ドラッグ&ドロップ受け皿）
    ├── StickerTray/          … 未貼付トレイ（横スクロール、draggableなシールカード）
    ├── StickerDetail/        … シール詳細（メタデータ編集・貼付履歴タイムライン・フルスクリーンプレビュー・「送る」）
    ├── StickerImport/        … 写真選択→背景除去/角丸→トレイへ保存、IG風テキストシールエディタ（TextStickerEditorView / TextStickerSpec）
    └── StickerTrade/         … AirDrop等での送受信（.stickertradeフォーマット定義、ZIP読み書き、検証、受け取りプレビュー）
        ├── StickerTradeFormat.swift    … フォーマット定義（UTType・エントリ名・容量/画像サイズ上限・manifest/integrityのCodable）
        ├── ZipArchive.swift            … 依存なしの最小ZIP実装（書き込みは無圧縮、読み込みはstored/deflate対応）
        ├── StickerTradeExporter.swift  … Sticker → .stickertrade 書き出し（SHA-256計算を含む）
        ├── StickerTradeImporter.swift  … 受信ファイルの多段検証（後述）と読み込み
        ├── ActivityShareSheet.swift    … UIActivityViewController のSwiftUIラッパー
        └── StickerTradeReceiveView.swift … 受け取りプレビュー（「トレイに追加」で初めて保存）
```

## データ構造（SwiftData）

5つの `@Model` が以下の関係で構成されています。

```
StickerBook 1 ── * StickerPage 1 ── * StickerPlacement 1 ── 1 Sticker 1 ── * PlacementHistory
   (シール帳)         (ページ)          (現在の貼付状態)         (シール本体)      (貼付履歴ログ)
```

- **StickerBook**：シール帳そのもの。`title` / `coverColorHex` / `createdAt` / `updatedAt` と、複数の `StickerPage`（cascade削除）を保持。
- **StickerPage**：シール帳の1ページ。`pageIndex`（並び順）/ `backgroundColorHex` と、そのページに貼られた `StickerPlacement` の配列（cascade削除）を保持。
- **Sticker**：シール本体（写真から作った透明PNG）。`imageFileName` / `thumbnailFileName` はファイル名のみを保持し、実体は `StickerFileStore` が管理する `Application Support/Stickers/` 配下に保存（絶対パスは保存しない）。`createdAt`（作成日時）・`authorDisplayName`（作成者表示名）・`receivedAt` / `receivedFrom`（受取日時・受取元、自分で作った場合は両方 `nil`）を持つ。テキストシールの場合は `textSpecJSON`（`TextStickerSpec` のJSON）も持ち、これがあるシールだけ文字の再編集ができる（写真シールでは `nil`）。
- **StickerPlacement**：シールの「現在の」貼付状態。`Sticker` と `StickerPage` の両方に対する1:1〜多対1の関係で、正規化座標 `x` / `y`（0.0〜1.0、ページ左上が原点）、`scale`（拡大率）、`rotation`（ラジアン）、`zIndex`（重なり順）、`isFlippedHorizontally`（左右反転）、`hasShadow`（影の有無）、`effectRawValue`（エフェクト。`StickerEffect` の rawValue）を保持。`Sticker.placement` が `nil` の場合は「未貼付トレイにある」ことを意味する。
- **PlacementHistory**：貼付操作のログ（`placed` / `moved` / `movedToPage` / `removedToTray`）。操作時点の座標・拡縮・回転・重なり順と、削除されたページでも読めるようページ名／シール帳名のスナップショット文字列を保持。`Sticker` に対して1対多。

### 貼付フロー

1. トレイのシールを `draggable(StickerTransferItem)` でドラッグ開始（Transferableな最小ペイロードとしてシールIDのみを運ぶ、アプリ内完結）。
2. ページ側は `dropDestination(for: StickerTransferItem.self)` でドロップ位置（View内座標）を受け取り、ページのサイズで割って正規化座標に変換。
3. `BookDetailViewModel.place(stickerID:onto:at:)` が `StickerPlacement` を新規作成し、`Sticker.placement` に紐付け、`PlacementHistory` に `.placed` を追記。
4. 貼付後の移動・拡縮・回転もそれぞれ `updatePosition` / `updateTransform` が呼ばれ、都度 `PlacementHistory` に `.moved` を追記。
5. 「トレイに戻す」操作で `removeToTray` が呼ばれ、`StickerPlacement` を削除して `Sticker.placement` を `nil` に戻し、`.removedToTray` を追記。

## AirDropでシールを送る・受け取る

### 使い方

- **送る**：シールをタップして詳細画面を開き、「このシールを送る」→ 共有シート（`UIActivityViewController`）から AirDrop（またはメッセージ・メール等）で送信します。送っても手元のシールはそのまま残ります。
- **受け取る**：AirDrop で受信すると受け入れ先アプリの選択肢に Stekki が表示され、開くとプレビュー画面が出ます。シール画像・作成者・作成日時を確認し、**「トレイに追加」を押したときにだけ**未貼付トレイへ保存されます（自動保存はしません）。「受け取らない」で閉じれば何も残りません。受取元の名前はその場で編集でき、シール詳細の「受取日時／受取元」に記録されます。

### .stickertrade フォーマット

実体はZIPで、以下の4ファイルを**ちょうど4つ**含みます（それ以外の構成は受信時に拒否）。

| ファイル | 内容 |
|---|---|
| `manifest.json` | フォーマットバージョン・送信元でのシールID・作成者表示名・作成日時・書き出し日時 |
| `sticker.png` | シール本体（透明PNG） |
| `thumbnail.png` | サムネイルPNG（保存済みがなければ書き出し時に生成） |
| `integrity.json` | 上記3ファイルの SHA-256（16進）。アルゴリズム名 `"SHA-256"` を明記 |

ZIPの読み書きは外部ライブラリを使わず `ZipArchive.swift` で実装しています（書き込みは無圧縮stored。PNGは既に圧縮済みのため。読み込みはstored/deflate両対応で、暗号化・ZIP64・データディスクリプタ付きは拒否）。

受信側では ID の衝突（同じシールが往復して戻ってきた場合など）を避けるため、`manifest.json` の `stickerID` はそのまま使わず**必ず新しいIDを採番**します。既存のSwiftDataモデル（`Sticker` の `receivedAt` / `receivedFrom` など）をそのまま使うため、スキーマ変更はありません。

### 受信時の検証（StickerTradeImporter）

受信ファイルは信頼できない入力として、**ZIP展開の前後**で多段に検証します。1つでも失敗するとエラー表示のみで何も保存しません。

- **展開前**（ZIPのセントラルディレクトリの宣言値だけで判断）
  - アーカイブ全体が 25MB 以下
  - エントリ数がちょうど4、名前（＝拡張子 `.json` / `.png`）が上記4ファイルに完全一致
  - 各エントリの宣言サイズが上限内（JSON 64KB / sticker.png 15MB / thumbnail.png 2MB）
- **展開後**
  - 実際の展開サイズ・CRC32 が宣言値と一致（ZIPリーダー内で照合）
  - `integrity.json` の SHA-256 と実データのハッシュが一致（改ざん・破損検出）
  - `manifest.json` のフォーマットバージョンが対応範囲内
  - PNGシグネチャを持ち、実際にデコードでき、ピクセルサイズが上限内（本体4096px / サムネイル2048px）

### Info.plist の設定（設定済み）

受信ファイルを Stekki で開けるようにするため、`Stekki/Info.plist` に以下を追加してあります（`GENERATE_INFOPLIST_FILE = YES` のプロジェクトでも、`INFOPLIST_FILE` で指定したこのplistの内容はビルド時にマージされます）。

- **`UTExportedTypeDeclarations`**：独自UTI `jp.hamaryo.stekki.stickertrade` を宣言。`public.data` に準拠し、拡張子 `stickertrade`・MIMEタイプ `application/vnd.stekki.stickertrade+zip` を紐付け。コード側の `UTType.stickerTrade`（`StickerTradeFormat.swift`）と識別子を一致させています。
- **`CFBundleDocumentTypes`**：上記UTIを `LSItemContentTypes` に持つDocument Typeを宣言（`CFBundleTypeRole = Viewer`、`LSHandlerRank = Owner`）。これによりAirDrop受信時・Filesアプリの共有メニューに Stekki が現れます。
- **`LSSupportsOpeningDocumentsInPlace = false`**：受信ファイルはアプリの `Documents/Inbox` へコピーされてから `onOpenURL` に渡されます（読み込み後にアプリがInbox内のコピーを削除して掃除します）。

バンドルIDやUTI識別子を変更する場合は、`Info.plist` と `StickerTradeFormat.swift` の両方を揃えて変更してください。

### 実機テスト手順（AirDropは実機2台が必要）

AirDrop はシミュレータでは動作しないため、iOS 17 以降の実機2台で確認します。

1. 2台の実機（A: 送信側、B: 受信側）それぞれに同じ Stekki をビルド・インストールする（Signing & Capabilities で自分のTeamを設定）。
2. 両端末で Wi-Fi / Bluetooth をON、AirDrop の受信設定を「連絡先のみ」または「すべての人（10分間のみ）」にする（設定 > 一般 > AirDrop）。
3. **送信（A）**：シールを1枚作成 → シールをタップして詳細画面 → 「このシールを送る」→ 共有シートで B を選択。
4. **受信（B）**：AirDrop の受け入れダイアログで「受け入れる」→ アプリ選択で「Stekki」を選ぶ（初回は候補一覧に出る。Stekki が起動していなくても自動起動する）。
5. B で「シールを受け取る」プレビューが表示されることを確認：画像・作成者・作成日時が送信側と一致していること。
6. **「受け取らない」で閉じた場合**：トレイに何も追加されていないことを確認（自動保存されない）。この場合、同じシールが必要ならもう一度送ってもらう。
7. もう一度送り、**「トレイに追加」を押した場合**：未貼付トレイにシールが現れ、詳細画面の「受取日時」が現在時刻、「受取元」が入力した名前になっていることを確認。
8. **異常系**：`.stickertrade` を展開して中身を差し替え・削除・追加してから再ZIPしてBへ送ると、エラー表示のみで何も保存されないことを確認。エラー内容はZIPの作り方で変わります：Finderの「圧縮」は `__MACOSX` などの付加エントリを含むため「読み込めませんでした／中身が想定と異なります」となり、ターミナルの `zip -X archive.zip manifest.json sticker.png thumbnail.png integrity.json` のように4ファイルだけを圧縮し直した場合は、改ざん箇所に応じて「SHA-256が一致しません」等になります（deflate圧縮の読み込み自体は対応済み）。
9. **シミュレータでの代替確認**：AirDrop の代わりに、書き出した `.stickertrade` を Files アプリ経由（またはMacからシミュレータへのドラッグ&ドロップ）で開いても同じ受信フローを確認できます。

単体テスト（`StekkiTests/StickerTradeTests.swift`）では、ZIPのラウンドトリップ、SHA-256改ざん検出、エントリ数・エントリ名・フォーマットバージョン・非PNGの拒否を `Cmd + U` で確認できます。

## 補足

- 画像の背景除去には `Vision` の `VNGenerateForegroundInstanceMaskRequest`（iOS 17〜）を使用しており、完全にオンデバイスで処理されます（ネットワーク通信なし）。このAPIはNeural Engineに依存しており、**iOSシミュレータでは失敗しやすい**ことが知られているため、シール作成画面には「背景を自動で透明にする」のON/OFFトグルを用意しています。OFFにすると `BackgroundRemover.makeOpaqueSticker` が写真をそのままPNG化するため、Visionを使わずシミュレータでも常に成功します。実機であればONのまま試すのがおすすめです。
- ドラッグ操作は SwiftUI 標準の `draggable` / `dropDestination` を使用し、システムのドラッグプレビューが指の動きに1:1で追従します。貼付済みシールの移動・拡縮・回転は独自のジェスチャで実装し、Apple の Fluid Interfaces の指針（押した瞬間に反応する・ジェスチャ中は1:1で追従・離した瞬間だけ軽くスプリングで収束）に沿っています。
- 貼付済みシールをドラッグでトレイへ戻す判定のために、`BookDetailView` に `"bookCanvas"` という名前付き座標空間 (`coordinateSpace(name:)`) を定義し、`PreferenceKey`（`TrayFramePreferenceKey`）でトレイの矩形を子から親へ伝えています。`PlacedStickerView` のドラッグはこの共通座標空間上の指の位置とトレイの上端を比較し、トレイの高さに達したら離した瞬間にモデルを更新します（見た目のアニメーションを先に見せ、データの確定を少し遅らせて自然な「吸い込まれる」動きにしています）。
- ページは「ページ範囲外を隠す」ためにページ矩形でクリップしており、さらにトレイはページの下（`TabView` の外側）に重なって描かれます。この2つのため、シールをそのまま下へドラッグするとページ下端で切り取られ、かつトレイの背面へ回り込んで見えなくなり、トレイまで運べません。これを解消するために **ドラッグ層**（`StickerDragLayer` / `StickerDragLayerModel`）を用意しました。指がトレイの高さに達している間だけ、`PlacedStickerView` はページ上の実体を隠し、同じ見た目のシールを `bookCanvas` 全体を覆う最前面のオーバーレイ（`BookDetailView` の `.overlay`）へ描きます。ページ内座標のシール中心は、`PageCanvasView` が測ったページ左上の `bookCanvas` 座標（`geo.frame(in:.named("bookCanvas")).origin`）を足して画面全体座標へ変換します。ドラッグ層の状態は `@Observable` にしてあり、値を更新してもこの層だけが再描画され、`TabView` 全体は再評価されない（ドラッグ中の負荷を抑える）ようにしています。
- 拡大縮小（ピンチ）と回転（ひねり）は `SimultaneousGesture` 全体に対して1組の `onChanged`/`onEnded` を付けることで、両方の値を必ず同時に確定させています（個別に `onEnded` を付けると、片方が確定した瞬間にもう片方の値がリセット済みで食い違うことがあったため）。また、2本指ジェスチャの最中は1本指ドラッグの更新を無視するようにし、ピンチ中にシールの位置がずれる問題を防いでいます。拡縮の上限・下限（`StickerPlacement.scaleRange` = 0.25〜4.0）を超えた入力にはゴムのような抵抗（ラバーバンド）をかけ、離した瞬間だけ確定値へきっちりクランプします。
- ピンチによる拡縮・回転はInstagramストーリーの編集を参考に、**指の中心（ピンチ開始位置）を支点**として行います。iOS 17の `MagnifyGesture` / `RotateGesture` が報告する `startLocation` を支点Pとして、中心Cを `P + R(Δθ)·(k·(C−P))` へ動かす補正を毎フレームかけることで、掴んだ点が指の下に留まり続けます（従来のシール中心固定のピンチは、シールの端を掴むと大きくずれて感じられたための変更）。支点補正で位置も一緒に動くため、確定は拡大率・回転・中心位置をまとめて1回で行い、履歴も1件だけ追記します（`BookDetailViewModel.updateTransform`）。回転は合計角度が0°/90°/180°/270°の±4°以内に入ると吸着し、吸着した瞬間に `sensoryFeedback(.impact)` で軽いハプティクスを鳴らします（確定値も吸着後の角度）。1本指ドラッグの途中で2本目の指を置くとそのままピンチへ移行でき、それまでのドラッグ移動量は支点計算の基準に取り込んでまとめて確定します。ピンチ中は浮き上がり演出（1.06倍）とミニツールバーを消し、表示が指に1:1で追従するようにしています。
