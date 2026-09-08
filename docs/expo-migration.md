# Expo移行

このブランチは **iOS向けExpoアプリ＋ローカルSwiftモジュール** です。全画面をTypeScriptへ書き直したものではありません。

## 構成と対応範囲

| 項目 | Expo版の実装 |
|---|---|
| 起動・開発サーバー・JSバンドル | Expo SDK 57 / React Native / TypeScript |
| シール帳一覧・作成・名前変更・削除 | React Nativeの画面から型付きネイティブAPIを呼び出す |
| ページ編集・トレイ・ドラッグ・ピンチ・回転・反転・影 | 既存SwiftUIエディタを全画面で表示 |
| 写真・背景除去・角丸・文字シール | 既存SwiftUI / Vision / UIKitの処理を再利用 |
| シール詳細・履歴・送信・受信プレビュー | 既存SwiftUIの画面を再利用 |
| 保存 | 同じSwiftDataモデルとApplication Support/Stickers |
| `.stickertrade` | 同じZIP・SHA-256検証。JSの受信キューで画面の重複表示を防止 |
| Android / Web / Expo Go | 非対応。iOS Development Buildが必要 |

`App.tsx` がExpo側のホーム画面、`modules/stekki-native/index.ts` が境界の型定義です。
Swiftソースの正本は `Stekki/` にあります。`npm ci` のprepareとprebuildスクリプトが `modules/stekki-native/ios/Core/` にコピーします。生成先を直接編集しないでください。元のXcodeプロジェクトも引き続き利用できます。

## 起動

Node.js 22.13以降、macOS、利用するExpo SDKに対応したXcodeとCocoaPodsを用意してください。

```sh
npm ci
npm run ios
```

実機を選択する場合は `npm run ios -- --device`。初回は署名用のApple開発チームの設定が必要です。
作成済みのDevelopment Buildを使う場合は `npm start` でMetroを起動します。
Swiftを変更した場合は `npm run ios` で再ビルドしてください。Fast Refreshの対象はTypeScript側です。

EASを使う場合（初回にExpoアカウント・プロジェクト連携・署名設定が必要）：

```sh
npx eas-cli build --platform ios --profile development
```

シミュレータ用は `--profile simulator`、Metro不要の配布確認用は `--profile preview` を使います。
このPRではEASへの送信・TestFlight配布・ストア公開は実行していません。

## 既存データ

バンドルID `hamaryo.Stekki`、Swiftモジュール名 `Stekki`、SwiftDataスキーマと保存先を維持する設計です。
Expoが生成するアプリターゲット名は `StekkiExpo` で、モデルを含むPodのモジュール名 `Stekki` とは分離しています。

**既存アプリへの上書きインストールによるデータ引き継ぎは実機で未確認です。** 本番データで移行する前に、テスト用端末で旧版からの更新を検証してください。アンインストールするとアプリのローカルデータも削除されます。ストアの読み込みに失敗した場合、新規DBへのフォールバックや既存DBの削除は行いません。

## 検証

```sh
npm run typecheck
npm test
node scripts/verify-native.cjs
npm run export:ios
npm run prebuild -- --no-install
```

GitHub ActionsはJS検証と、macOS上での署名なしiOSシミュレータ向けビルドを行います。ローカルのLinux環境ではSwiftのコンパイルやiOS UI操作は検証できません。

マージ前の実機確認項目：

1. 旧版でシール帳・画像・文字シール・配置履歴を作成し、Expo版を同じバンドルID・署名で上書きして全データを確認。
2. 一覧の作成・名前変更・削除、最後の一冊を削除後に新規作成し、既存シールがトレイに残ることを確認。
3. 編集モード、ドラッグ貼付、トレイへの取り出し、ピンチ／回転、ページ追加／削除、反転／影、履歴を確認。
4. 写真加工（実機の背景除去、シミュレータでは背景除去OFF）と全テキストスタイルを確認。
5. シール詳細のフルスクリーンプレビューを開閉してもエディタが閉じず、一覧へ戻ると枚数が更新されることを確認。
6. 2台で旧版↔Expo版のAirDrop送受信。起動済み・終了状態・編集画面表示中それぞれで受信し、確認前には保存されないことを確認。
7. 破損・容量超過ファイルの拒否、その後の正常ファイルの受信を確認。
8. Development Buildに加え、previewビルドでもコールドスタート・ファイル受信を確認。

全画面のReact Native化やAndroid対応には、編集ジェスチャとネイティブ機能の別途移植が必要です。

参考：[Expoのローカルモジュール](https://docs.expo.dev/modules/get-started/)、[Expo Modules API](https://docs.expo.dev/modules/module-api/)。
