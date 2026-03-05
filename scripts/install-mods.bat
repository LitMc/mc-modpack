@echo off
chcp 65001 > nul

echo ========================================
echo   Minecraft MOD インストーラー (Windows)
echo ========================================
echo.

set "MC_DIR=%APPDATA%\.minecraft"

if not exist "%MC_DIR%" (
    echo [エラー] Minecraftフォルダが見つかりません: %MC_DIR%
    echo Minecraftを一度起動してから再実行してください。
    pause
    exit /b 1
)

echo [1/3] Fabric Loader を確認中...
set "FABRIC_FOUND=0"
for /d %%d in ("%MC_DIR%\versions\fabric-loader-*-1.21.1") do set "FABRIC_FOUND=1"

if "%FABRIC_FOUND%"=="0" (
    echo Fabric Loader が未導入です。インストールします...

    rem Minecraft同梱のJavaを検索
    set "JAVA="
    for /d %%d in ("%MC_DIR%\runtime\java-runtime-delta\*") do (
        if exist "%%d\bin\java.exe" set "JAVA=%%d\bin\java.exe"
    )

    if not defined JAVA (
        echo [エラー] Javaが見つかりません。
        echo Minecraftランチャーを一度起動してJavaランタイムをダウンロードしてください。
        pause
        exit /b 1
    )

    echo Fabric Installer をダウンロード中...
    curl.exe -L -o "%TEMP%\fabric-installer.jar" "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
    if errorlevel 1 (
        echo [エラー] Fabric Installer のダウンロードに失敗しました。
        echo インターネット接続を確認してください。
        pause
        exit /b 1
    )

    echo Fabric Loader をインストール中...
    "%JAVA%" -jar "%TEMP%\fabric-installer.jar" client -mcversion 1.21.1 -noprofile
    if errorlevel 1 (
        echo [エラー] Fabric Loader のインストールに失敗しました。
        pause
        exit /b 1
    )
    echo Fabric Loader インストール完了！
) else (
    echo Fabric Loader は導入済みです。
)

echo.
echo [2/3] MOD をダウンロード中...

if not exist "%MC_DIR%\mods" mkdir "%MC_DIR%\mods"

set "DL_ERROR=0"

echo   - Inventory Profiles Next ...
curl.exe -L -o "%MC_DIR%\mods\InventoryProfilesNext-fabric-1.21.1-2.2.3.jar" "https://cdn.modrinth.com/data/O7RBXm3n/versions/A2gB9UGG/InventoryProfilesNext-fabric-1.21.1-2.2.3.jar"
if errorlevel 1 set "DL_ERROR=1" & echo     [失敗] Inventory Profiles Next

echo   - Shoulder Surfing Reloaded ...
curl.exe -L -o "%MC_DIR%\mods\ShoulderSurfing-Fabric-1.21.1-4.22.0.jar" "https://cdn.modrinth.com/data/kepjj2sy/versions/XJw5tPaN/ShoulderSurfing-Fabric-1.21.1-4.22.0.jar"
if errorlevel 1 set "DL_ERROR=1" & echo     [失敗] Shoulder Surfing Reloaded

echo   - Fabric API ...
curl.exe -L -o "%MC_DIR%\mods\fabric-api-0.116.9+1.21.1.jar" "https://cdn.modrinth.com/data/P7dR8mSH/versions/yGAe1owa/fabric-api-0.116.9%%2B1.21.1.jar"
if errorlevel 1 set "DL_ERROR=1" & echo     [失敗] Fabric API

echo   - Fabric Language Kotlin ...
curl.exe -L -o "%MC_DIR%\mods\fabric-language-kotlin-1.13.9+kotlin.2.3.10.jar" "https://cdn.modrinth.com/data/Ha28R6CL/versions/ViT4gucI/fabric-language-kotlin-1.13.9%%2Bkotlin.2.3.10.jar"
if errorlevel 1 set "DL_ERROR=1" & echo     [失敗] Fabric Language Kotlin

echo   - libIPN ...
curl.exe -L -o "%MC_DIR%\mods\libIPN-fabric-1.21.1-6.6.2.jar" "https://cdn.modrinth.com/data/onSQdWhM/versions/3rPzmg5m/libIPN-fabric-1.21.1-6.6.2.jar"
if errorlevel 1 set "DL_ERROR=1" & echo     [失敗] libIPN

echo   - Cloth Config ...
curl.exe -L -o "%MC_DIR%\mods\cloth-config-15.0.140-fabric.jar" "https://cdn.modrinth.com/data/9s6osm5g/versions/HpMb5wGb/cloth-config-15.0.140-fabric.jar"
if errorlevel 1 set "DL_ERROR=1" & echo     [失敗] Cloth Config

echo.
if "%DL_ERROR%"=="1" (
    echo [警告] 一部のMODのダウンロードに失敗しました。
    echo 上記の [失敗] と表示されたMODを確認してください。
)

echo [3/3] 完了！
echo.
echo ========================================
echo   Minecraftランチャーを起動して
echo   「fabric-loader-1.21.1」を選択して
echo   プレイしてください！
echo ========================================
echo.
pause
