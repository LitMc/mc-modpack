@echo off
chcp 65001 > nul

echo ========================================
echo   MOD アンインストーラー (Windows)
echo ========================================
echo.

call :main
pause
exit /b 0

rem ============================================================
:main
rem ============================================================

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
    for /d %%P in ("%MODRINTH_DIR%\*") do echo   - %%~nxP
    echo.
    echo プロファイルフォルダのフルパスを入力してください。
    echo.
    goto :mc_ask_user
)

:mc_ask_user
echo [情報] Minecraftフォルダが自動検出できませんでした。
echo.
set "MC_RETRY=0"

:mc_ask_loop
if %MC_RETRY% GEQ 3 (
    echo.
    echo [エラー] 3回入力しましたが有効なパスが見つかりませんでした。
    goto :eof
)
set /p MC_DIR="Minecraftフォルダのパスを入力してください: "
if exist "%MC_DIR%" goto :mc_found
echo [エラー] 指定されたパスが存在しません: %MC_DIR%
set /a MC_RETRY+=1
goto :mc_ask_loop

:mc_found
set "MODS_DIR=%MC_DIR%\mods"

if not exist "%MODS_DIR%" (
    echo.
    echo [情報] modsフォルダが見つかりません。MODは導入されていないようです。
    goto :eof
)

echo.
echo --- 推奨MODを削除中 ---
echo.

set "DEL_IPN=NONE"
set "DEL_SSR=NONE"
set "DEL_FAPI=NONE"
set "DEL_FLK=NONE"
set "DEL_LIPN=NONE"
set "DEL_CLOTH=NONE"

rem IPN (複数バージョン対応)
for %%f in ("%MODS_DIR%\InventoryProfilesNext-*.jar") do (
    del /q "%%f" 2>nul
    set "DEL_IPN=DELETED"
)

rem Shoulder Surfing Reloaded
for %%f in ("%MODS_DIR%\ShoulderSurfing-*.jar") do (
    del /q "%%f" 2>nul
    set "DEL_SSR=DELETED"
)

rem Fabric API
for %%f in ("%MODS_DIR%\fabric-api-*.jar") do (
    del /q "%%f" 2>nul
    set "DEL_FAPI=DELETED"
)

rem Fabric Language Kotlin
for %%f in ("%MODS_DIR%\fabric-language-kotlin-*.jar") do (
    del /q "%%f" 2>nul
    set "DEL_FLK=DELETED"
)

rem libIPN
for %%f in ("%MODS_DIR%\libIPN-*.jar") do (
    del /q "%%f" 2>nul
    set "DEL_LIPN=DELETED"
)

rem Cloth Config
for %%f in ("%MODS_DIR%\cloth-config-*-fabric.jar") do (
    del /q "%%f" 2>nul
    set "DEL_CLOTH=DELETED"
)

echo --- アンインストール結果 ---
echo.
if "%DEL_IPN%"=="DELETED"    (echo [削除] Inventory Profiles Next)   else (echo [なし] Inventory Profiles Next)
if "%DEL_SSR%"=="DELETED"    (echo [削除] Shoulder Surfing Reloaded) else (echo [なし] Shoulder Surfing Reloaded)
if "%DEL_FAPI%"=="DELETED"   (echo [削除] Fabric API)                else (echo [なし] Fabric API)
if "%DEL_FLK%"=="DELETED"    (echo [削除] Fabric Language Kotlin)    else (echo [なし] Fabric Language Kotlin)
if "%DEL_LIPN%"=="DELETED"   (echo [削除] libIPN)                    else (echo [なし] libIPN)
if "%DEL_CLOTH%"=="DELETED"  (echo [削除] Cloth Config)              else (echo [なし] Cloth Config)

echo.
echo ========================================
echo   推奨MODを削除しました。
echo   通常のMinecraftで起動すると
echo   バニラでプレイできます。
echo ========================================
echo.
echo ※ 自分で追加したMODはそのまま残っています。
goto :eof
