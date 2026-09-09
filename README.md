# Stekki — Expo Go

写真や文字からシールを作り、複数ページのシール帳に貼って楽しむアプリです。**iPhoneのExpo Goで動作する構成**で、Mac・Xcode・署名・Development Buildは不要です。

アプリの画面と編集はReact Native / TypeScript、保存は端末内のSQLiteとPNGファイルです。シール画像や履歴をサーバーへ送る処理はありません。

## iPhoneだけで起動する

開発サーバーはGitHub Codespaces（クラウド）で実行します。iPhone上だけでNode.jsを実行する方式ではありません。

1. iPhoneに [Expo Go](https://expo.dev/go) をインストールします（SDK 57対応版）。
2. Safariで [このブランチをCodespacesで開く](https://codespaces.new/Hamaryo226/Stekki/tree/codex/migrate-to-expo) → GitHubにログインしてCodespaceを作成します。
3. 初回の `npm ci` が完了したら、ブラウザー内のターミナルで実行します。

   ```sh
   npm run start:phone
   ```

4. ターミナルに表示される `exp://…` のURLをiPhoneで開き、Expo Goに移動します。同じiPhoneなので、QRコードのスキャンは不要です。リンクを開けない場合は [詳細手順](docs/expo-migration.md) を参照してください。
5. 作業後はCodespaceを停止します。再開時は同じCodespaceで `npm run start:phone` を再実行します。

Codespacesの利用可否・利用枠はGitHubアカウントの設定に依存します。iPhone Safariでの一連の実操作は未検証です。

## できること

- シール帳の作成・名前変更・削除、ページ追加・削除
- 写真・透明PNGの取り込み、角丸加工
- 文字シール（5つのフォント候補、文字色・縁取り・背景プレート、アーチ・波・ふくらみ）
- トレイのシールをタップして貼付。ドラッグ移動、2本指の拡縮・回転、反転、影、重なり順の変更
- ドラッグまたはボタンでトレイへ戻す、メタデータ・貼付履歴の表示、完全削除
- `.stickertrade` の共有、ファイル選択からの受信、確認後の保存

## Swift版との違い

| 項目 | Expo Go版 |
|---|---|
| 自動背景除去（Vision） | 非対応。透明PNGの取り込みは可能 |
| AirDrop受信からの直接起動 | 非対応。「ファイル」に保存後、アプリ内の「ファイルから受け取る」で選択 |
| 既存SwiftDataの読み込み | 不可。旧版からシールを `.stickertrade` で書き出して取り込む |
| ページ・位置・貼付履歴の一括移行 | 非対応。交換ファイルにはシール画像・作成者・作成日時のみを収録 |
| オフラインの独立アプリ | この構成は開発・動作確認用。初回読込や再接続には開発サーバーが必要 |

## 開発・検証

```sh
npm ci
npm run check:expo-go
npm run typecheck
npm test
npm run export:ios
npm start
```

`npm start` はExpo Go向けのLAN接続、`npm run start:phone` はトンネル接続です。
端末操作、2台間AirDrop、iPhoneのSafariからのCodespaces起動は実機確認が必要です。

- [構成・制約・検証手順](docs/expo-migration.md)
- [旧Swift版の説明](docs/native-ios.md)（`Stekki/` と `Stekki.xcodeproj` は参照用に保持し、Expoからは読み込みません）
