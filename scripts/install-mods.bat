@echo off
chcp 65001 > nul

echo ========================================
echo   Minecraft MOD インストーラー (Windows)
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
    set "PROF_NUM=0"
    for /d %%P in ("%MODRINTH_DIR%\*") do (
        set /a PROF_NUM+=1
        echo   - %%~nxP
    )
    echo.
    echo Modrinth Appのプロファイルを使用する場合は、
    echo プロファイルフォルダのフルパスを次の入力欄に入力してください。
    echo 標準のMinecraftを使う場合は、そのフォルダパスを入力してください。
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
    echo 対処: Minecraftを一度起動してフォルダが作成されてから再実行してください。
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

echo.
echo [1/3] Fabric Loader を確認中...
set "FABRIC_FOUND=0"
for /d %%d in ("%MC_DIR%\versions\fabric-loader-*-1.21.1") do set "FABRIC_FOUND=1"

if "%FABRIC_FOUND%"=="0" (
    echo Fabric Loader が未導入です。インストールします...

    rem === Javaパスの多段探索 ===
    set "JAVA="

    rem 候補1: java-runtime-delta
    for /d %%d in ("%MC_DIR%\runtime\java-runtime-delta\*") do (
        if exist "%%d\bin\java.exe" set "JAVA=%%d\bin\java.exe"
    )
    if defined JAVA goto :java_found

    rem 候補2: java-runtime-gamma
    for /d %%d in ("%MC_DIR%\runtime\java-runtime-gamma\*") do (
        if exist "%%d\bin\java.exe" set "JAVA=%%d\bin\java.exe"
    )
    if defined JAVA goto :java_found

    rem 候補3: システムPATH上のjava
    where java >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%j in ('where java') do (
            set "JAVA=%%j"
            goto :java_found
        )
    )

    rem Javaが見つからない場合: ユーザー入力
    echo [情報] Javaが自動検出できませんでした。
    echo.
    set "JAVA_RETRY=0"
    :java_ask_loop
    if %JAVA_RETRY% GEQ 3 (
        echo [エラー] 3回入力しましたが有効なJavaパスが見つかりませんでした。
        echo 原因: Javaがインストールされていないか、パスが正しくありません。
        echo 対処: Minecraftランチャーを一度起動してJavaランタイムをダウンロードするか、
        echo       https://adoptium.net/ からJavaをインストールしてください。
        echo.
        echo Enterキーで終了します。
        pause > nul
        exit /b 1
    )
    set /p JAVA="java.exeのパスを入力してください (例: C:\Program Files\Java\jdk-21\bin\java.exe): "
    if exist "%JAVA%" goto :java_found
    echo [エラー] 指定されたパスが存在しません: %JAVA%
    set "JAVA="
    set /a JAVA_RETRY+=1
    goto :java_ask_loop

    :java_found
    echo [検出] Java: %JAVA%

    echo Fabric Installer をダウンロード中...
    curl.exe -L -o "%TEMP%\fabric-installer.jar" "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
    if errorlevel 1 (
        echo [エラー] Fabric Installer のダウンロードに失敗しました。
        echo 原因: インターネット接続に問題があるか、サーバーがダウンしている可能性があります。
        echo 対処: インターネット接続を確認して再実行してください。
        echo.
        echo Enterキーで終了します。
        pause > nul
        exit /b 1
    )

    echo Fabric Loader をインストール中...
    "%JAVA%" -jar "%TEMP%\fabric-installer.jar" client -mcversion 1.21.1 -noprofile
    if errorlevel 1 (
        echo [エラー] Fabric Loader のインストールに失敗しました。
        echo 原因: Javaの実行に問題があるか、Fabric Installerが破損している可能性があります。
        echo 対処: Minecraftランチャーを閉じてから再実行してください。
        echo.
        echo Enterキーで終了します。
        pause > nul
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
echo === インストール結果 ===
if not "%DL_ERROR%"=="1" (
    echo [完了] Inventory Profiles Next
    echo [完了] Shoulder Surfing Reloaded
    echo [完了] Fabric API
    echo [完了] Fabric Language Kotlin
    echo [完了] libIPN
    echo [完了] Cloth Config
) else (
    echo 上記の [失敗] と表示されたMOD以外はインストール済みです。
    echo.
    echo [注意] 一部のMODのダウンロードに失敗しました。
    echo 再度実行するか、手動でダウンロードしてください。
)
echo.
echo ========================================
echo   Minecraftランチャーを起動して
echo   「fabric-loader-1.21.1」を選択して
echo   プレイしてください！
echo ========================================
echo.
pause
