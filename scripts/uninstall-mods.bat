@echo off
chcp 65001 > nul

echo ========================================
echo   MOD アンインストーラー (Windows)
echo ========================================
echo.

rem === Minecraftフォルダの多段探索 ===
set "MC_DIR="

rem 候補1: 標準Minecraftランチャー
if exist "%APPDATA%\.minecraft" (
    set "MC_DIR=%APPDATA%\.minecraft"
    echo [検出] Minecraftフォルダ: %APPDATA%\.minecraft
    goto :mc_found
)

rem 候補2: Microsoft Store版
set "MS_STORE=%LOCALAPPDATA%\Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe\LocalCache\Local\.minecraft"
if exist "%MS_STORE%" (
    set "MC_DIR=%MS_STORE%"
    echo [検出] Minecraftフォルダ (Microsoft Store): %MS_STORE%
    goto :mc_found
)

rem 候補3: 各ドライブの標準パス
for %%D in (C D E F) do (
    if exist "%%D:\Users\%USERNAME%\AppData\Roaming\.minecraft" (
        set "MC_DIR=%%D:\Users\%USERNAME%\AppData\Roaming\.minecraft"
        echo [検出] Minecraftフォルダ: %%D:\Users\%USERNAME%\AppData\Roaming\.minecraft
        goto :mc_found
    )
)

rem 候補4: Modrinth Appインスタンス
set "MODRINTH_DIR=%APPDATA%\com.modrinth.theseus\profiles"
if exist "%MODRINTH_DIR%" (
    echo [検出] Modrinth App プロファイルが見つかりました:
    echo.
    for /d %%P in ("%MODRINTH_DIR%\*") do (
        echo   - %%~nxP
    )
    echo.
    echo プロファイルフォルダのフルパスを次の入力欄に入力してください。
    echo.
    goto :mc_ask_user
)

:mc_ask_user
echo [情報] Minecraftフォルダが自動検出できませんでした。
echo.
set "MC_RETRY=0"
:mc_ask_loop
if %MC_RETRY% GEQ 3 (
    echo [エラー] 3回入力しましたが有効なパスが見つかりませんでした。
    echo 原因: Minecraftがインストールされていないか、フォルダパスが正しくありません。
    echo 対処: Minecraftのインストール先を確認してから再実行してください。
    echo.
    echo Enterキーで終了します。
    pause > nul
    exit /b 1
)
set /p MC_DIR="Minecraftフォルダのパスを入力してください (例: C:\Users\<名前>\AppData\Roaming\.minecraft): "
if exist "%MC_DIR%" (
    echo [検出] 入力されたパス: %MC_DIR%
    goto :mc_found
)
echo [エラー] 指定されたパスが存在しません: %MC_DIR%
set /a MC_RETRY+=1
goto :mc_ask_loop

:mc_found

set "MODS_DIR=%MC_DIR%\mods"

if not exist "%MODS_DIR%" (
    echo [情報] modsフォルダが見つかりません。MODは導入されていないようです。
    pause
    exit /b 0
)

echo 推奨MODを削除中...

del /q "%MODS_DIR%\InventoryProfilesNext-*.jar" 2>nul
del /q "%MODS_DIR%\ShoulderSurfing-*.jar" 2>nul
del /q "%MODS_DIR%\fabric-api-*.jar" 2>nul
del /q "%MODS_DIR%\fabric-language-kotlin-*.jar" 2>nul
del /q "%MODS_DIR%\libIPN-*.jar" 2>nul
del /q "%MODS_DIR%\cloth-config-*-fabric.jar" 2>nul

echo.
echo ========================================
echo   推奨MODを削除しました。
echo   通常のMinecraftで起動すると
echo   バニラでプレイできます。
echo ========================================
echo.
echo ※ 自分で追加したMODはそのまま残っています。
echo.
pause
