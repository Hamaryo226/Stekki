# Expo Go移行とiPhoneでの起動

## 構成

画面・シール編集・データ操作をTypeScriptに移植し、ローカルSwiftモジュール、Swiftソース同期処理、expo-dev-client、CocoaPodsビルドをExpoの起動経路から取り除きました。

- `App.tsx`：画面遷移・起動時のストア読込
- `src/screens/`：一覧、編集、作成、詳細、受信
- `src/model.ts`：シール帳・ページ・シール・配置・履歴の状態遷移
- `src/serial-store.ts`：保存の直列化。SQLiteへの書込に成功してから画面へ反映
- `src/storage.ts`：SQLite、PNGファイル、写真処理、ファイル選択と共有
- `src/gesture.ts`：指の中心を支点にした拡縮・回転計算
- `src/trade-format.ts`：旧Swift版と同じv1形式のZIP・CRC32・SHA-256・PNGヘッダー検証

Expo Goに含まれるモジュールとJavaScriptライブラリのみを実行時に使用します。SDKは57、対応するExpo Goが必要です。独自ネイティブコードのビルドはありません。

## iPhoneだけで動作確認する

iPhoneのSafariでGitHub Codespacesを操作し、クラウド上のMetroへExpo Goから接続します。**Macは不要ですが、開発サーバーとネットワーク接続は必要です。** Codespacesのアカウント・利用枠はユーザー側で用意してください。

1. [Expo Go](https://expo.dev/go)をインストール。
2. Safariで [ブランチ指定のCodespaces作成ページ](https://codespaces.new/Hamaryo226/Stekki/tree/codex/migrate-to-expo) を開く。
3. ブランチが `codex/migrate-to-expo` であることを確認してCodespaceを作成。
4. `.devcontainer/devcontainer.json` によりNode.js 22環境を準備し、`npm ci` を実行。セットアップ完了を待つ。
5. VS Code Webのメニューから「Terminal」→「New Terminal」を開き、`npm run start:phone` を実行。
6. `Metro waiting on exp://…` が表示されたら、そのURLを開いてExpo Goへ移動。ブラウザー上でターミナルのリンクを長押ししてコピーする操作も利用できます。
7. Safariで直接カスタムURLを開けない場合は、iPhoneの「ショートカット」で「URL」にその `exp://…` を指定し、「URLを開く」を続けて実行する方法があります。URLは起動のたびに変わり得ます。
8. 同じiPhone内でアプリを切り替えるため、QRコードを別の端末で読み取る必要はありません。

Safariの画面が狭い場合は横向きやデスクトップ用Webサイト表示を試してください。iPhone Safariでの操作とカスタムURL起動はこの開発環境では未検証です。

トンネル開始に失敗した場合はターミナルのエラーを確認してください。`--tunnel` は外部のトンネルサービスを利用します。Codespacesの8081番ポートを単に転送する操作とは異なります。この作業環境からの公開トンネル起動はネットワーク制約により確認できていません。

## 保存・互換性

Expo Go内の `stekki-expo-go.db` と `stekki-images/` に保存します。DBが読めない場合に空データで上書きする処理はありません。画像コピーに失敗したりDBへ保存できなかった場合、シールの追加は確定しません。

旧SwiftアプリとExpo Goは別のアプリ領域です。SwiftDataファイルの直接読み込みや自動移行はできません。旧版の「このシールを送る」で `.stickertrade` を保存し、Expo Go版の「ファイルから受け取る」で取り込みます。ページ配置と貼付履歴は交換形式に含まれないため移行できません。

受信は内容を検証し、プレビュー後に「トレイに追加」を押した時だけ保存します。受信画像・サムネイルはバイト列を維持し、受信側のIDは必ず新しく生成します。送信しても手元のシールは消えません。

Expo Goの削除やアプリデータ消去でローカルデータが失われるため、残したいシールは交換ファイルとして書き出してください。Expo Goは独立配布アプリの代わりではありません。

## 機能の調整

- Vision背景除去はExpo Goで利用できないため削除。透明PNGをあらかじめ用意して取り込めます。
- 独自拡張子の受信先としてExpo Goを登録できないため、AirDrop受信後はFiles経由で読み込みます。
- 貼付はトレイのタップ。貼付後の移動・拡縮・回転はジェスチャと補助ボタンを用意。
- 文字の描画はSVGとPNGキャプチャ。旧UIKit描画との字形・字間の完全一致は保証しません。長文は60文字・4行以内。
- 今回はiOSが対象。AndroidとWebの動作保証・専用調整は行っていません。

## 検証

```sh
npm run check:expo-go
npm run typecheck
npm test
npm run export:ios
```

自動テストは、ページとシールの関係、削除時のトレイ返却、保存失敗と並行保存、ジェスチャ計算、交換ZIP互換形式、改ざん・異常サイズ・不正エントリ・過剰展開の拒否を検証します。ネイティブUIを操作するテストではありません。

実機での確認事項：

1. Expo Goのコールド起動、保存後の再読込・再接続でシール帳とPNGが残ること。
2. 写真選択、透明PNG、角丸、文字の各スタイルで保存した画像がプレビューと一致すること。
3. 編集モードで貼付・移動・2本指拡縮／回転・トレイへの返却、ページ削除と履歴を確認。
4. ファイルから受信してキャンセルしたときにトレイが増えず、追加を選んだ場合だけ増えること。
5. 旧Swift版との双方の送受信、破損ファイル拒否後の正常ファイル受信を確認。
6. Codespacesの作成からExpo Goの起動までをiPhoneのSafariだけで行えること。

参考：[Expo Go](https://expo.dev/go)、[Expo CLIのトンネル](https://docs.expo.dev/more/expo-cli/#tunneling)、[GitHub Codespacesのブランチ指定リンク](https://docs.github.com/en/codespaces/setting-up-your-project-for-codespaces/setting-up-your-repository/facilitating-quick-creation-and-resumption-of-codespaces)。
