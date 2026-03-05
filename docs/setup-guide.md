# MODパック 導入ガイド

jln-hut.page Minecraft サーバー向け推奨MODパックの導入・管理手順。

---

## 1. 必要なもの

- Minecraft Java Edition（購入済み）
- [Modrinth App](https://modrinth.com/app)（無料）

---

## 2. Modrinth App のインストール

1. [https://modrinth.com/app](https://modrinth.com/app) を開く
2. ご利用のOS（Windows / macOS）向けインストーラーをダウンロード
3. インストーラーを実行してインストール完了

---

## 3. MODパックのインポートと起動

### 方法1: ダブルクリック（簡単）

1. 最新の [jln-hut-modpack.mrpack をダウンロード](https://github.com/LitMc/mc-modpack/releases/latest/download/jln-hut-modpack.mrpack)
2. ダウンロードした `.mrpack` ファイルをダブルクリック
3. Modrinth App が自動で開き、インポート確認が表示される
4. 確認してインポート完了 → 「Play」ボタンで起動

### 方法2: アプリから手動インポート

1. Modrinth App を起動
2. 左上の「**+**」ボタン → 「**From file**」を選択
3. ダウンロードした `.mrpack` ファイルを選択
4. インポート完了 → 「Play」ボタンで起動

---

## 4. バニラからの引き継ぎ（オプション）

すでにバニラ（MODなし）Minecraft でプレイしていた場合、設定・サーバリスト・リソースパックを引き継げます。

### Modrinth インスタンスフォルダの開き方

1. Modrinth App でインスタンスを右クリック（または「⋮」メニュー）
2. 「**Open Folder**」または「**フォルダを開く**」を選択
3. インスタンスの `.minecraft` フォルダが開く

### 引き継ぎたいファイル

バニラの `.minecraft` フォルダから、Modrinth インスタンスの `.minecraft` フォルダへコピーします。

| ファイル / フォルダ | 内容 |
|---------------------|------|
| `options.txt` | 操作設定・グラフィック設定・音量設定など |
| `servers.dat` | マルチプレイのサーバリスト |
| `resourcepacks/` | 導入済みリソースパック |
| `screenshots/` | スクリーンショット（任意） |

#### バニラの `.minecraft` フォルダの場所

| OS | パス |
|----|------|
| Windows | `%AppData%\.minecraft` （エクスプローラーのアドレスバーに入力） |
| macOS | `~/Library/Application Support/minecraft` |

---

## 5. アンインストール / バニラへの戻し方

MODパックを削除してもバニラの Minecraft には一切影響ありません。

1. Modrinth App を起動
2. MODパックのインスタンスを右クリック（または「⋮」メニュー）
3. 「**Delete**」または「**削除**」を選択
4. 確認してインスタンス削除完了

バニラで遊ぶ場合はそのまま通常の Minecraft Launcher から起動してください。

---

## 6. 含まれるMOD

| MOD | 用途 |
|-----|------|
| Inventory Profiles Next (IPN) | インベントリソート（中ボタン）、スロットロック（Alt+クリック） |
| Shoulder Surfing Reloaded | 三人称肩越し視点（F5→三人称、Oキー→肩の左右切替） |
| Fabric API | MOD共通基盤 |
| Fabric Language Kotlin | Kotlin言語サポート |
| libIPN | IPN依存ライブラリ |
| Cloth Config | 設定画面ライブラリ |
| Forge Config API Port | Shoulder Surfing Reloaded依存ライブラリ |

---

## 7. トラブルシューティング

| 症状 | 対処 |
|------|------|
| .mrpack をダブルクリックしても何も起きない | Modrinth App がインストールされているか確認。されていれば App を先に起動してから再度ダブルクリック |
| 「このゲームバージョンはサポートされていません」 | Modrinth App を最新版にアップデート |
| サーバに接続できない | `/status` コマンドでサーバ稼働確認。バージョンがサーバ側（1.21.11）と一致しているか確認 |
| MODを入れたくない | 不要。MODなしでも通常通りサーバに接続可能 |
