@echo off
chcp 65001 > nul

echo ========================================
echo   Minecraft MOD インストーラー (Windows)
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
    echo プロファイルフォルダのフルパスを入力するか、
    echo 標準のMinecraftフォルダのパスを入力してください。
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
    echo 対処: Minecraftを一度起動してフォルダが作成されてから再実行してください。
    goto :eof
)
set /p MC_DIR="Minecraftフォルダのパスを入力してください: "
if exist "%MC_DIR%" goto :mc_found
echo [エラー] 指定されたパスが存在しません: %MC_DIR%
set /a MC_RETRY+=1
goto :mc_ask_loop

:mc_found
echo.
echo --- Step 1/3: Fabric Loader を確認中 ---
set "FABRIC_FOUND=0"
for /d %%d in ("%MC_DIR%\versions\fabric-loader-*") do set "FABRIC_FOUND=1"

if "%FABRIC_FOUND%"=="1" goto :fabric_already_installed
call :install_fabric
if errorlevel 1 goto :eof
goto :fabric_done

:fabric_already_installed
echo Fabric Loader は導入済みです。

:fabric_done
echo.
echo --- Step 2/3: MOD をダウンロード中 ---

if not exist "%MC_DIR%\mods" mkdir "%MC_DIR%\mods"

set "DL_IPN=OK"
set "DL_SSR=OK"
set "DL_FAPI=OK"
set "DL_FLK=OK"
set "DL_LIPN=OK"
set "DL_CLOTH=OK"

echo   - Inventory Profiles Next ...
curl.exe -L --silent --show-error -o "%MC_DIR%\mods\InventoryProfilesNext-fabric-1.21.11-2.2.3.jar" "https://cdn.modrinth.com/data/O7RBXm3n/versions/hUyBZiaa/InventoryProfilesNext-fabric-1.21.11-2.2.3.jar"
if errorlevel 1 set "DL_IPN=FAIL"

echo   - Shoulder Surfing Reloaded ...
curl.exe -L --silent --show-error -o "%MC_DIR%\mods\ShoulderSurfing-Fabric-1.21.11-4.22.0.jar" "https://cdn.modrinth.com/data/kepjj2sy/versions/VIt9lLsi/ShoulderSurfing-Fabric-1.21.11-4.22.0.jar"
if errorlevel 1 set "DL_SSR=FAIL"

echo   - Fabric API ...
curl.exe -L --silent --show-error -o "%MC_DIR%\mods\fabric-api-0.141.3+1.21.11.jar" "https://cdn.modrinth.com/data/P7dR8mSH/versions/i5tSkVBH/fabric-api-0.141.3%%2B1.21.11.jar"
if errorlevel 1 set "DL_FAPI=FAIL"

echo   - Fabric Language Kotlin ...
curl.exe -L --silent --show-error -o "%MC_DIR%\mods\fabric-language-kotlin-1.13.9+kotlin.2.3.10.jar" "https://cdn.modrinth.com/data/Ha28R6CL/versions/ViT4gucI/fabric-language-kotlin-1.13.9%%2Bkotlin.2.3.10.jar"
if errorlevel 1 set "DL_FLK=FAIL"

echo   - libIPN ...
curl.exe -L --silent --show-error -o "%MC_DIR%\mods\libIPN-fabric-1.21.11-6.6.2.jar" "https://cdn.modrinth.com/data/onSQdWhM/versions/NfmfXRhx/libIPN-fabric-1.21.11-6.6.2.jar"
if errorlevel 1 set "DL_LIPN=FAIL"

echo   - Cloth Config ...
curl.exe -L --silent --show-error -o "%MC_DIR%\mods\cloth-config-21.11.153-fabric.jar" "https://cdn.modrinth.com/data/9s6osm5g/versions/xuX40TN5/cloth-config-21.11.153-fabric.jar"
if errorlevel 1 set "DL_CLOTH=FAIL"

echo.
echo --- Step 3/3: インストール結果 ---
echo.
if "%DL_IPN%"=="OK"    (echo [完了] Inventory Profiles Next)   else (echo [失敗] Inventory Profiles Next)
if "%DL_SSR%"=="OK"    (echo [完了] Shoulder Surfing Reloaded) else (echo [失敗] Shoulder Surfing Reloaded)
if "%DL_FAPI%"=="OK"   (echo [完了] Fabric API)                else (echo [失敗] Fabric API)
if "%DL_FLK%"=="OK"    (echo [完了] Fabric Language Kotlin)    else (echo [失敗] Fabric Language Kotlin)
if "%DL_LIPN%"=="OK"   (echo [完了] libIPN)                    else (echo [失敗] libIPN)
if "%DL_CLOTH%"=="OK"  (echo [完了] Cloth Config)              else (echo [失敗] Cloth Config)

echo.
set "ANY_FAIL=0"
if "%DL_IPN%"=="FAIL"   set "ANY_FAIL=1"
if "%DL_SSR%"=="FAIL"   set "ANY_FAIL=1"
if "%DL_FAPI%"=="FAIL"  set "ANY_FAIL=1"
if "%DL_FLK%"=="FAIL"   set "ANY_FAIL=1"
if "%DL_LIPN%"=="FAIL"  set "ANY_FAIL=1"
if "%DL_CLOTH%"=="FAIL" set "ANY_FAIL=1"

if "%ANY_FAIL%"=="1" (
    echo [注意] 一部のMODのダウンロードに失敗しました。
    echo インターネット接続を確認して再実行してください。
) else (
    echo ========================================
    echo   インストール完了！
    echo   Minecraftランチャーを起動して
    echo   fabric-loader-1.21.11 を選択して
    echo   プレイしてください！
    echo ========================================
)
goto :eof

rem ============================================================
:install_fabric
rem ============================================================
echo Fabric Loader が未導入です。インストールします...
echo.

rem === Javaパスの多段探索 ===
set "JAVA="

for /d %%d in ("%MC_DIR%\runtime\java-runtime-delta\*") do (
    if exist "%%d\bin\java.exe" set "JAVA=%%d\bin\java.exe"
)
if defined JAVA goto :java_found

for /d %%d in ("%MC_DIR%\runtime\java-runtime-gamma\*") do (
    if exist "%%d\bin\java.exe" set "JAVA=%%d\bin\java.exe"
)
if defined JAVA goto :java_found

for /d %%d in ("%MC_DIR%\runtime\java-runtime-alpha\*") do (
    if exist "%%d\bin\java.exe" set "JAVA=%%d\bin\java.exe"
)
if defined JAVA goto :java_found

where java >nul 2>nul
if not errorlevel 1 (
    for /f "delims=" %%j in ('where java') do (
        if not defined JAVA set "JAVA=%%j"
    )
)
if defined JAVA goto :java_found

rem Javaが見つからない場合: ユーザー入力
echo [情報] Javaが自動検出できませんでした。
echo.
set "JAVA_RETRY=0"

:java_ask_loop
if %JAVA_RETRY% GEQ 3 (
    echo.
    echo [エラー] Javaが見つかりませんでした。
    echo 対処: Minecraftランチャーを一度起動してJavaランタイムをダウンロードしてください。
    exit /b 1
)
set /p JAVA="java.exeのパスを入力してください: "
if exist "%JAVA%" goto :java_found
echo [エラー] 指定されたパスが存在しません: %JAVA%
set "JAVA="
set /a JAVA_RETRY+=1
goto :java_ask_loop

:java_found
echo [検出] Java: %JAVA%

echo Fabric Installer をダウンロード中...
curl.exe -L --silent --show-error -o "%TEMP%\fabric-installer.jar" "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
if errorlevel 1 (
    echo.
    echo [エラー] Fabric Installer のダウンロードに失敗しました。
    echo インターネット接続を確認して再実行してください。
    exit /b 1
)

echo Fabric Loader をインストール中...
"%JAVA%" -jar "%TEMP%\fabric-installer.jar" client -mcversion 1.21.11 -noprofile
if errorlevel 1 (
    echo.
    echo [エラー] Fabric Loader のインストールに失敗しました。
    echo Minecraftランチャーを閉じてから再実行してください。
    exit /b 1
)
echo Fabric Loader インストール完了！
exit /b 0
