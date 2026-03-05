@echo off
chcp 65001 > nul

echo ========================================
echo   MOD アンインストーラー (Windows)
echo ========================================
echo.

set "MODS_DIR=%APPDATA%\.minecraft\mods"

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
