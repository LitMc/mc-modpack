#!/bin/bash

echo "========================================"
echo "  MOD アンインストーラー (macOS/Linux)"
echo "========================================"
echo ""

# === Minecraftフォルダの多段探索 ===
MC_DIR=""

# 候補1: 標準 macOS
if [ -d "$HOME/Library/Application Support/minecraft" ]; then
    MC_DIR="$HOME/Library/Application Support/minecraft"
    echo "[検出] Minecraftフォルダ: $MC_DIR"
# 候補2: Linux標準
elif [ -d "$HOME/.minecraft" ]; then
    MC_DIR="$HOME/.minecraft"
    echo "[検出] Minecraftフォルダ: $MC_DIR"
# 候補3: Linux XDG環境
elif [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/minecraft" ]; then
    MC_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/minecraft"
    echo "[検出] Minecraftフォルダ: $MC_DIR"
fi

# 候補4: Modrinth App (MC_DIRが未検出の場合のみ)
if [ -z "$MC_DIR" ]; then
    MODRINTH_MAC="$HOME/Library/Application Support/com.modrinth.theseus/profiles"
    MODRINTH_LINUX="${XDG_DATA_HOME:-$HOME/.local/share}/com.modrinth.theseus/profiles"
    MODRINTH_DIR=""
    if [ -d "$MODRINTH_MAC" ]; then
        MODRINTH_DIR="$MODRINTH_MAC"
    elif [ -d "$MODRINTH_LINUX" ]; then
        MODRINTH_DIR="$MODRINTH_LINUX"
    fi

    if [ -n "$MODRINTH_DIR" ]; then
        echo "[検出] Modrinth App プロファイルが見つかりました:"
        echo ""
        for p in "$MODRINTH_DIR"/*/; do
            [ -d "$p" ] && echo "  - $(basename "$p")"
        done
        echo ""
        echo "プロファイルフォルダのフルパスを次の入力欄に入力してください。"
        echo ""
    fi
fi

# 全候補が見つからない場合: ユーザー入力
if [ -z "$MC_DIR" ]; then
    echo "[情報] Minecraftフォルダが自動検出できませんでした。"
    echo ""
    for i in 1 2 3; do
        read -r -p "Minecraftフォルダのパスを入力してください: " MC_DIR
        if [ -d "$MC_DIR" ]; then
            echo "[検出] 入力されたパス: $MC_DIR"
            break
        fi
        echo "[エラー] 指定されたパスが存在しません: $MC_DIR"
        MC_DIR=""
        if [ "$i" -eq 3 ]; then
            echo ""
            echo "[エラー] 3回入力しましたが有効なパスが見つかりませんでした。"
            echo "原因: Minecraftがインストールされていないか、フォルダパスが正しくありません。"
            echo "対処: Minecraftのインストール先を確認してから再実行してください。"
            exit 1
        fi
    done
fi

MODS_DIR="$MC_DIR/mods"

if [ ! -d "$MODS_DIR" ]; then
    echo "[情報] modsフォルダが見つかりません。MODは導入されていないようです。"
    exit 0
fi

echo "推奨MODを削除中..."

rm -f "$MODS_DIR"/InventoryProfilesNext-*.jar
rm -f "$MODS_DIR"/ShoulderSurfing-*.jar
rm -f "$MODS_DIR"/fabric-api-*.jar
rm -f "$MODS_DIR"/fabric-language-kotlin-*.jar
rm -f "$MODS_DIR"/libIPN-*.jar
rm -f "$MODS_DIR"/cloth-config-*-fabric.jar

echo ""
echo "========================================"
echo "  推奨MODを削除しました。"
echo "  通常のMinecraftで起動すると"
echo "  バニラでプレイできます。"
echo "========================================"
echo ""
echo "※ 自分で追加したMODはそのまま残っています。"
