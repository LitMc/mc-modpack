#!/bin/bash

echo "========================================"
echo "  MOD アンインストーラー (macOS)"
echo "========================================"
echo ""

MODS_DIR="$HOME/Library/Application Support/minecraft/mods"

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
