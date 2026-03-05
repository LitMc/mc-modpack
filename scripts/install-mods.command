#!/bin/bash
set -u

echo "========================================"
echo "  Minecraft MOD インストーラー (macOS/Linux)"
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
        echo "Modrinth Appのプロファイルを使用する場合は、"
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
            echo "対処: Minecraftを一度起動してフォルダが作成されてから再実行してください。"
            exit 1
        fi
    done
fi

echo ""
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

    # === Javaパスの多段探索 ===
    JAVA=""

    # 候補1: java-runtime-delta
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

    # 候補2: java-runtime-gamma
    if [ -z "$JAVA" ]; then
        for d in "$MC_DIR/runtime/java-runtime-gamma/"*/bin/java; do
            if [ -x "$d" ]; then
                JAVA="$d"
                break
            fi
        done
    fi
    if [ -z "$JAVA" ]; then
        for d in "$MC_DIR/runtime/java-runtime-gamma/"*/"jre.bundle/Contents/Home/bin/java"; do
            if [ -x "$d" ]; then
                JAVA="$d"
                break
            fi
        done
    fi

    # 候補3: JAVA_HOME環境変数
    if [ -z "$JAVA" ] && [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
        JAVA="$JAVA_HOME/bin/java"
    fi

    # 候補4: システムPATH上のjava
    if [ -z "$JAVA" ] && command -v java >/dev/null 2>&1; then
        JAVA="$(command -v java)"
    fi

    # Javaが見つからない場合: ユーザー入力
    if [ -z "$JAVA" ]; then
        echo "[情報] Javaが自動検出できませんでした。"
        echo ""
        for i in 1 2 3; do
            read -r -p "javaコマンドのパスを入力してください (例: /usr/bin/java): " JAVA
            if [ -x "$JAVA" ]; then
                break
            fi
            echo "[エラー] 指定されたパスが存在しないか実行できません: $JAVA"
            JAVA=""
            if [ "$i" -eq 3 ]; then
                echo ""
                echo "[エラー] 3回入力しましたが有効なJavaパスが見つかりませんでした。"
                echo "原因: Javaがインストールされていないか、パスが正しくありません。"
                echo "対処: Minecraftランチャーを一度起動してJavaランタイムをダウンロードするか、"
                echo "      https://adoptium.net/ からJavaをインストールしてください。"
                exit 1
            fi
        done
    fi

    echo "[検出] Java: $JAVA"

    echo "Fabric Installer をダウンロード中..."
    INSTALLER="/tmp/fabric-installer.jar"
    if ! curl -L -o "$INSTALLER" "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"; then
        echo "[エラー] Fabric Installer のダウンロードに失敗しました。"
        echo "原因: インターネット接続に問題があるか、サーバーがダウンしている可能性があります。"
        echo "対処: インターネット接続を確認して再実行してください。"
        exit 1
    fi

    echo "Fabric Loader をインストール中..."
    if ! "$JAVA" -jar "$INSTALLER" client -mcversion 1.21.1 -noprofile; then
        echo "[エラー] Fabric Loader のインストールに失敗しました。"
        echo "原因: Javaの実行に問題があるか、Fabric Installerが破損している可能性があります。"
        echo "対処: Minecraftランチャーを閉じてから再実行してください。"
        exit 1
    fi
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
