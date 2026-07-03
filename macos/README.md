# CLCL for Mac

オリジナルの [CLCL](https://www.nakka.com/soft/clcl/)(Windows 用クリップボード履歴ユーティリティ、Ohno Tomoaki 作)を macOS 向けに再実装したものです。Win32 API ベースのオリジナルとはコードを共有せず、Swift / AppKit でネイティブに書き直しています。

A native macOS re-implementation of [CLCL](https://www.nakka.com/soft/clcl/), the Windows clipboard caching utility. Written from scratch in Swift / AppKit.

## 機能 / Features

- クリップボード履歴(テキスト・画像・ファイル)をメニューバーから参照
- **⌥C**(Option+C)でカーソル位置にポップアップメニューを表示(オリジナルの Alt+C に対応)
- 項目を選ぶと自動貼り付け(アクセシビリティ許可が必要。未許可時はクリップボードへのコピーのみ)
- 履歴の項目 1〜9 は数字キーで選択可能
- 画像はメニュー内にサムネイル表示
- 定型文(テンプレート)の登録・削除
- 履歴・定型文は `~/Library/Application Support/CLCL/` に JSON で永続化

## ビルド / Build

macOS 13+ / Xcode Command Line Tools (Swift 5.9+) が必要です。

```sh
cd macos
./make_app.sh        # CLCL.app を生成
open CLCL.app
```

開発中は `swift run` でも起動できます。

## 設定 / Settings

### Windows 版 CLCL.ini の読み込み

Windows で使っている **CLCL.ini をそのまま読み込めます**。以下に置いて再起動してください(メニューの「CLCL.ini 未検出…」をクリックするとフォルダが開きます):

```
~/Library/Application Support/CLCL/CLCL.ini
```

UTF-16LE(Windows 版が書き出す形式)・UTF-8・Shift_JIS に対応。取り込まれるのは次のキーです:

| ini | 効果 |
|---|---|
| `[history] max` | 履歴の最大件数 |
| `[history] save` | 履歴をファイルに保存するか |
| `[history] overlap_check` | 重複時に既存項目を先頭へ移動 |
| `[main] clipboard_watch` | クリップボード監視の ON/OFF |
| `[menu] bitmap_width` / `bitmap_height` | メニュー内サムネイルのサイズ |
| `[menu] show_tooltip` | ツールチップ表示 |
| `[action]` のホットキー定義 | ポップアップのホットキー(Alt→⌥、Ctrl→⌃、Shift→⇧、Win→⌘ に変換) |

それ以外(フォント・色・ウィンドウフィルタ・sendkey・ツール等)は Windows 固有のため無視されます。履歴データ本体(history.dat / regist.dat)は独自バイナリのため読み込み対象外です。

### ini がない場合

デフォルト(履歴 30 件・⌥C)。履歴件数だけなら `defaults` でも変更できます:

```sh
defaults write com.nakka.clcl.mac maxHistory 50
```

## 自動貼り付けについて / Auto-paste

自動貼り付けは Cmd+V のキーイベント送出で実現しているため、**システム設定 → プライバシーとセキュリティ → アクセシビリティ** で CLCL を許可してください。メニューの「自動貼り付けを有効化…」からも許可ダイアログを表示できます。許可しない場合でも、選択した項目はクリップボードにセットされるので手動で ⌘V できます。

## オリジナルとの対応 / Mapping to the original

| オリジナル (Windows) | Mac 版 |
|---|---|
| Alt+C ポップアップ | ⌥C ポップアップ |
| タスクトレイ常駐 | メニューバー常駐 |
| 履歴 (`history.dat`) | `history.json` |
| 登録アイテム(定型文) | 定型文メニュー |
| 自動貼り付け (SendKey) | CGEvent による ⌘V 送出 |
| ビューア / プラグイン / ウィンドウ別ペーストキー | 未実装 |

## License

MIT (オリジナルと同じ / same as the original)
