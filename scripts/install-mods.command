#!/bin/bash
set -u

echo "========================================"
echo "  Minecraft MOD インストーラー (macOS)"
echo "========================================"
echo ""

MC_DIR="$HOME/Library/Application Support/minecraft"

if [ ! -d "$MC_DIR" ]; then
    echo "[エラー] Minecraftフォルダが見つかりません: $MC_DIR"
    echo "Minecraftを一度起動してから再実行してください。"
    exit 1
fi

echo "[1/3] Fabric Loader を確認中..."
FABRIC_FOUND=0
for d in "$MC_DIR/versions/fabric-loader-"*"-1.21.1"; do
    if [ -d "$d" ]; then
        FABRIC_FOUND=1
        break
    fi
done

if [ "$FABRIC_FOUND" -eq 0 ]; then
    echo "Fabric Loader が未導入です。インストールします..."

    # Minecraft同梱のJavaを検索
    JAVA=""
    for d in "$MC_DIR/runtime/java-runtime-delta/"*/bin/java; do
        if [ -x "$d" ]; then
            JAVA="$d"
            break
        fi
    done
    # macOS: javaHome内も検索
    if [ -z "$JAVA" ]; then
        for d in "$MC_DIR/runtime/java-runtime-delta/"*/"jre.bundle/Contents/Home/bin/java"; do
            if [ -x "$d" ]; then
                JAVA="$d"
                break
            fi
        done
    fi

    if [ -z "$JAVA" ]; then
        echo "[エラー] Javaが見つかりません。"
        echo "Minecraftランチャーを一度起動してJavaランタイムをダウンロードしてください。"
        exit 1
    fi

    echo "Fabric Installer をダウンロード中..."
    INSTALLER="/tmp/fabric-installer.jar"
    curl -L -o "$INSTALLER" "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"

    echo "Fabric Loader をインストール中..."
    "$JAVA" -jar "$INSTALLER" client -mcversion 1.21.1 -noprofile
    echo "Fabric Loader インストール完了！"
else
    echo "Fabric Loader は導入済みです。"
fi

echo ""
echo "[2/3] MOD をダウンロード中..."

mkdir -p "$MC_DIR/mods"

DL_ERROR=0

download_mod() {
    local name="$1"
    local filename="$2"
    local url="$3"
    echo "  - $name ..."
    if ! curl -L -o "$MC_DIR/mods/$filename" "$url"; then
        echo "    [失敗] $name"
        DL_ERROR=1
    fi
}

download_mod "Inventory Profiles Next" \
    "InventoryProfilesNext-fabric-1.21.1-2.2.3.jar" \
    "https://cdn.modrinth.com/data/O7RBXm3n/versions/A2gB9UGG/InventoryProfilesNext-fabric-1.21.1-2.2.3.jar"

download_mod "Shoulder Surfing Reloaded" \
    "ShoulderSurfing-Fabric-1.21.1-4.22.0.jar" \
    "https://cdn.modrinth.com/data/kepjj2sy/versions/XJw5tPaN/ShoulderSurfing-Fabric-1.21.1-4.22.0.jar"

download_mod "Fabric API" \
    "fabric-api-0.116.9+1.21.1.jar" \
    "https://cdn.modrinth.com/data/P7dR8mSH/versions/yGAe1owa/fabric-api-0.116.9%2B1.21.1.jar"

download_mod "Fabric Language Kotlin" \
    "fabric-language-kotlin-1.13.9+kotlin.2.3.10.jar" \
    "https://cdn.modrinth.com/data/Ha28R6CL/versions/ViT4gucI/fabric-language-kotlin-1.13.9%2Bkotlin.2.3.10.jar"

download_mod "libIPN" \
    "libIPN-fabric-1.21.1-6.6.2.jar" \
    "https://cdn.modrinth.com/data/onSQdWhM/versions/3rPzmg5m/libIPN-fabric-1.21.1-6.6.2.jar"

download_mod "Cloth Config" \
    "cloth-config-15.0.140-fabric.jar" \
    "https://cdn.modrinth.com/data/9s6osm5g/versions/HpMb5wGb/cloth-config-15.0.140-fabric.jar"

echo ""
if [ "$DL_ERROR" -eq 1 ]; then
    echo "[警告] 一部のMODのダウンロードに失敗しました。"
    echo "上記の [失敗] と表示されたMODを確認してください。"
fi

echo "[3/3] 完了！"
echo ""
echo "========================================"
echo "  Minecraftランチャーを起動して"
echo "  「fabric-loader-1.21.1」を選択して"
echo "  プレイしてください！"
echo "========================================"
