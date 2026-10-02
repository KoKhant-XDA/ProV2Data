@echo off
setlocal enabledelayedexpansion
title GhostLock 1-Click Temp Root
color 0A

:: ── Local paths ──
set "BASE=%~dp0"
set "BIN=%BASE%bin"
set "PROFILES=%BASE%profiles"
set "ADB="
if exist "%BASE%adbfastboot\adb.exe" set "ADB=%BASE%adbfastboot\adb.exe"
if not defined ADB if exist "C:\adb\adb.exe" set "ADB=C:\adb\adb.exe"
if not defined ADB where adb >nul 2>&1 && set "ADB=adb"
if not defined ADB (
    echo [ERROR] adb.exe not found. Place it in adbfastboot\ or C:\adb\
    pause
    exit /b 1
)

echo ============================================
echo   GhostLock 1-Click Temporary Root
echo   CVE-2026-43499 futex PI UAF exploit
echo   v1.2 Universal Binary + Kernel Profiles
echo ============================================
echo.
echo   Supported devices:
echo     Xiaomi 14                 (houji / SM8650)
echo     Mi 14 Pro / Civi 4 Pro    (shennong/chenfeng)
echo     Mi 14 Ultra / K80         (aurora/zorn)
echo     K80 Pro / K80 Ultra        (socrates)
echo     Mi 15 Pro (6.6)            (dada)
echo     Xiaomi Pad 7 Pro           (muyu)
echo     Xiaomi 14R                 (skywalker/quark)
echo     Redmi 15R Spring           (spring/SM6375)
echo     Redmi Note 12R             (sky-river)
echo     8G2 devices                (SM8550)
echo     5.15 kernel devices        (android13)
echo     6.12 kernel devices        (android16)
echo ============================================
echo.

:: ── Step 1: Check ADB ──
echo [1/7] Checking ADB...
"%ADB%" version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ADB not working.
    pause
    exit /b 1
)
echo       ADB OK
echo.

:: ── Step 2: Check device connection ──
echo [2/7] Checking device connection...
"%ADB%" devices | findstr /r "device$" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] No device found. Connect via USB and enable USB debugging.
    pause
    exit /b 1
)
echo       Device connected
echo.

:: ── Step 3: Device info + kernel detection ──
echo [3/7] Device info:
for /f "tokens=*" %%i in ('"%ADB%" shell getprop ro.product.model') do set "MODEL=%%i"
for /f "tokens=*" %%i in ('"%ADB%" shell getprop ro.build.version.release') do set "ANDROID_VER=%%i"
for /f "tokens=*" %%i in ('"%ADB%" shell uname -r') do set "KERN=%%i"
for /f "tokens=*" %%i in ('"%ADB%" shell getprop ro.product.device') do set "DEVICE=%%i"
for /f "tokens=*" %%i in ('"%ADB%" shell getprop ro.soc.model 2^>nul') do set "SOC=%%i"
echo       Model: %MODEL%
echo       Codename: %DEVICE%
echo       Android: %ANDROID_VER%
echo       Kernel: %KERN%
echo       SoC: %SOC%
echo.

:: ── Step 4: Select binary and profile ──
echo [4/7] Selecting exploit for kernel...
set "EXPLOIT_BIN="
set "PROFILE_BIN="
set "KSUD_SRC="
set "IS_SKY=0"
set "USE_FALLBACK=0"
set "FALLBACK_NAME="

:: ─── Sky (Redmi Note 12R) uses a completely different exploit binary ───
echo "%DEVICE%" | findstr /i /c:"sky" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%BIN%\gl_sky_exploit" (
        set "IS_SKY=1"
        echo       Matched: Redmi Note 12R (sky-river) - special exploit
        goto :sky_flow
    )
)

:: ─── All other devices: universal ghostlock + profile ───
set "EXPLOIT_BIN=%BIN%\ghostlock"

:: Search for matching kernel profile (.bin) in profiles\ directory
if exist "%PROFILES%\%KERN%.bin" (
    set "PROFILE_BIN=%PROFILES%\%KERN%.bin"
    echo       Profile: %KERN%.bin
    goto :binary_selected
)

:: ─── No profile found — try device-specific fallback binaries ───
echo       [!] No profile for kernel: %KERN%

:: Pad 7 Pro (g7b9e94e37cfa variant)
echo "%KERN%" | findstr /c:"g7b9e94e37cfa" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%BIN%\ghostlock_pad7pro_g7b9e94e37cfa" (
        set "EXPLOIT_BIN=%BIN%\ghostlock_pad7pro_g7b9e94e37cfa"
        set "USE_FALLBACK=1"
        set "FALLBACK_NAME=Pad 7 Pro (g7b9e94e37cfa)"
        goto :binary_selected
    )
)

:: Pad 7 Pro (g614238d0d630 variant)
echo "%KERN%" | findstr /c:"g614238d0d630" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%BIN%\ghostlock_pad7pro" (
        set "EXPLOIT_BIN=%BIN%\ghostlock_pad7pro"
        set "USE_FALLBACK=1"
        set "FALLBACK_NAME=Pad 7 Pro (g614238d0d630)"
        goto :binary_selected
    )
)

:: 14R (quark) - 6.6.82-android15
echo "%KERN%" | findstr /c:"6.6.82-android15" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%BIN%\ghostlock_14r" (
        set "EXPLOIT_BIN=%BIN%\ghostlock_14r"
        if exist "%BASE%legacy\devices\14r\ksud" set "KSUD_SRC=%BASE%legacy\devices\14r\ksud"
        set "USE_FALLBACK=1"
        set "FALLBACK_NAME=Xiaomi 14R (quark)"
        goto :binary_selected
    )
)

:: ─── Exact known legacy fallbacks retained from the previous release ───
echo "%KERN%" | findstr /c:"6.1.138-android14-11-g0c3d559bcd85-ab14529422" >nul 2>&1
if %errorlevel% equ 0 (
    echo "%SOC% %DEVICE%" | findstr /i /c:"SM8650" /c:"shennong" /c:"chenfeng" >nul 2>&1
    if !errorlevel! equ 0 (
        if exist "%BASE%legacy\devices\k80_pro_ultra\ghostlock" (
            set "EXPLOIT_BIN=%BASE%legacy\devices\k80_pro_ultra\ghostlock"
            set "KSUD_SRC=%BASE%legacy\bin\ksud"
            set "USE_FALLBACK=1"
            set "FALLBACK_NAME=Mi 14 Pro / Civi 4 Pro legacy"
            goto :binary_selected
        )
    )
    echo "%SOC% %DEVICE%" | findstr /i /c:"SM6375" /c:"blair" /c:"spring" >nul 2>&1
    if !errorlevel! equ 0 (
        if exist "%BASE%legacy\devices\spring\ghostlock" (
            set "EXPLOIT_BIN=%BASE%legacy\devices\spring\ghostlock"
            set "KSUD_SRC=%BASE%legacy\bin\ksud"
            set "USE_FALLBACK=1"
            set "FALLBACK_NAME=Redmi 15R Spring legacy"
            goto :binary_selected
        )
    )
)

echo "%KERN%" | findstr /c:"6.6.77-android15-8-gca30f3b4bef6" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%BASE%legacy\devices\k80_pro_ultra\ghostlock" (
        set "EXPLOIT_BIN=%BASE%legacy\devices\k80_pro_ultra\ghostlock"
        set "KSUD_SRC=%BASE%legacy\bin\ksud"
        set "USE_FALLBACK=1"
        set "FALLBACK_NAME=K80 Pro / K80 Ultra legacy"
        goto :binary_selected
    )
)

echo "%KERN%" | findstr /c:"6.1.138-android14-11-g965475777129-mi" >nul 2>&1
if %errorlevel% equ 0 (
    echo "%DEVICE%" | findstr /i /c:"aurora" /c:"zorn" /c:"muyu" >nul 2>&1
    if !errorlevel! equ 0 (
        if exist "%BASE%legacy\devices\k80_pro_ultra\ghostlock" (
            set "EXPLOIT_BIN=%BASE%legacy\devices\k80_pro_ultra\ghostlock"
            set "KSUD_SRC=%BASE%legacy\bin\ksud"
            set "USE_FALLBACK=1"
            set "FALLBACK_NAME=Mi 14 Ultra / K80 / Pad 7 Pro legacy"
            goto :binary_selected
        )
    )
)

:: ─── Nothing matched ───
echo.
echo [ERROR] No profile or fallback binary for this device.
echo         Kernel: %KERN%
echo         Device: %DEVICE% / SoC: %SOC%
echo.
echo         To add support:
echo           1. Get boot.img for this firmware
echo           2. Run: ghostlock-extract.exe boot.img --format conf --out profile.conf
echo           3. Place the .bin profile in profiles\ named as the kernel string
pause
exit /b 1

:binary_selected
if not exist "%EXPLOIT_BIN%" (
    echo [ERROR] Binary not found: %EXPLOIT_BIN%
    pause
    exit /b 1
)
echo       Binary: %EXPLOIT_BIN%
if defined PROFILE_BIN echo       Profile: %PROFILE_BIN%
if %USE_FALLBACK% equ 1 (
    echo       Mode: FALLBACK (device-specific binary for %FALLBACK_NAME%)
    echo       Note: This device has no profile. Using baked-in offsets from old binary.
)
echo.

:: ── Step 5: Install KernelSU Manager APK ──
echo [5/7] Installing KernelSU Manager...
if exist "%BIN%\ksu-manager.apk" (
    "%ADB%" install -r "%BIN%\ksu-manager.apk" >nul 2>&1
    if !errorlevel! equ 0 (
        echo       KernelSU Manager installed
    ) else (
        echo       APK install skipped (may already be installed)
    )
) else (
    echo       KSU APK not found in bin\ - skipping
)
echo.

:: ── Step 6: Push binary + profile to device ──
echo [6/7] Pushing files to device...
"%ADB%" push "%EXPLOIT_BIN%" /data/local/tmp/ghostlock >nul 2>&1
"%ADB%" shell chmod 755 /data/local/tmp/ghostlock >nul 2>&1
echo       ghostlock pushed

if defined PROFILE_BIN (
    "%ADB%" push "%PROFILE_BIN%" /data/local/tmp/profile.bin >nul 2>&1
    echo       profile pushed
)

:: Push ksud if available
if exist "%BIN%\ksud" set "KSUD_SRC=%BIN%\ksud"
if defined KSUD_SRC (
    "%ADB%" push "%KSUD_SRC%" /data/local/tmp/ksud >nul 2>&1
    "%ADB%" shell chmod 755 /data/local/tmp/ksud >nul 2>&1
    echo       ksud pushed
)
echo.

:: ── Step 7: Run exploit ──
echo [7/7] Running GhostLock exploit...
echo       (Root is temporary - lost on reboot)
echo.
echo ============================================
if defined PROFILE_BIN (
    "%ADB%" shell /data/local/tmp/ghostlock --load-prebuilt-profile /data/local/tmp/profile.bin
) else (
    "%ADB%" shell /data/local/tmp/ghostlock
)
set "EXPLOIT_RC=%errorlevel%"
echo ============================================
echo.

:: ── Verify ──
if %EXPLOIT_RC% equ 0 (
    echo [OK] Exploit completed successfully.
    echo.
    echo Checking root status...
    "%ADB%" shell "su -c 'id'" 2>nul
    echo.
    echo Checking SELinux...
    "%ADB%" shell getenforce 2>nul
    echo.
    echo Checking KernelSU module...
    "%ADB%" shell "grep kernelsu /proc/modules" 2>nul
) else (
    echo [!] Exploit exited with code %EXPLOIT_RC%.
    echo     Check output above for details.
)

echo.
echo ============================================
echo   Root is TEMPORARY - lost on reboot.
echo   Re-run this script after each reboot.
echo ============================================
echo.

:: ── Cleanup ──
echo Cleaning up /data/local/tmp/...
"%ADB%" shell "rm -f /data/local/tmp/ghostlock /data/local/tmp/profile.bin /data/local/tmp/ksud /data/local/tmp/.ghostlock_root.sh /data/local/tmp/.ghostlock_ksu.log" >nul 2>&1
echo       Done
echo.
pause
exit /b 0

:: ══════════════════════════════════════════════
:: ══ Redmi Note 12R (Sky) - Full KSU Root Flow ══
:: ══════════════════════════════════════════════
:sky_flow
echo.
echo ============================================
echo   Redmi Note 12R (Sky-River) - KSU Root
echo   GhostLock exploit + KernelSU late-load
echo ============================================
echo.

echo [Sky 1/5] Copying KernelSU Manager to internal storage...
"%ADB%" push "%BIN%\ksu-manager.apk" /sdcard/KernelSU_manager.apk >nul 2>&1
if %errorlevel% equ 0 (
    echo       KernelSU_manager.apk copied to /sdcard/
) else (
    echo [ERROR] Failed to copy KernelSU Manager APK to internal storage.
    pause
    exit /b 1
)
echo.

echo [Sky 2/5] Pushing exploit files to /data/local/tmp/...
"%ADB%" push "%BIN%\gl_sky_exploit" /data/local/tmp/gl_sky_exploit >nul 2>&1
"%ADB%" shell chmod 755 /data/local/tmp/gl_sky_exploit >nul 2>&1
echo       gl_sky_exploit pushed

"%ADB%" push "%BIN%\libksud.so" /data/local/tmp/libksud.so >nul 2>&1
"%ADB%" shell chmod 755 /data/local/tmp/libksud.so >nul 2>&1
echo       libksud.so pushed

"%ADB%" push "%BIN%\ksu_loader.sh" /data/local/tmp/ksu_loader.sh >nul 2>&1
"%ADB%" shell chmod 755 /data/local/tmp/ksu_loader.sh >nul 2>&1
echo       ksu_loader.sh pushed

"%ADB%" push "%BIN%\run_ksu_full.sh" /data/local/tmp/run_ksu_full.sh >nul 2>&1
"%ADB%" shell chmod 755 /data/local/tmp/run_ksu_full.sh >nul 2>&1
echo       run_ksu_full.sh pushed
echo.

echo [Sky 3/5] Install KernelSU Manager APK
echo ============================================
echo   IMPORTANT: Install KernelSU Manager NOW
echo ============================================
echo.
echo   1. Open your phone's File Manager
echo   2. Navigate to Internal Storage
echo   3. Find "KernelSU_manager.apk" and install it
echo   4. If blocked, allow "Install from unknown sources"
echo.
echo   Press ENTER here after installing the APK...
echo ============================================
pause >nul

echo.
echo [Sky 4/5] Running exploit (this may take 30-160 seconds)...
echo.
"%ADB%" shell sh /data/local/tmp/run_ksu_full.sh
set "SKY_RC=%errorlevel%"

echo.
echo ============================================
if %SKY_RC% equ 0 (
    echo   Exploit completed.
    echo   Checking root status...
    "%ADB%" shell "su -c 'id'" 2>nul
) else (
    echo   Exploit exited with code %SKY_RC%.
    echo   Check output above for details.
)
echo   Root is temporary - lost on reboot.
echo ============================================
echo.

echo [Sky 5/5] Cleanup
echo Cleaning up /data/local/tmp/...
"%ADB%" shell "rm -f /data/local/tmp/gl_sky_exploit /data/local/tmp/libksud.so /data/local/tmp/ksu_loader.sh /data/local/tmp/run_ksu_full.sh" >nul 2>&1
echo       Done
echo.
pause
exit /b 0
