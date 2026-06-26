@echo off
setlocal enabledelayedexpansion

REM =====================================================================
REM kineld.bat - Build tool for Kinet OS (Windows Native Batch version)
REM Supports clean, build, -iso, -img formats, and --x86 / --x86_64 arches
REM Generates unified hybrid BIOS/UEFI boot images
REM =====================================================================

REM Auto-detect MSYS2 base path (subfolder path configuration is resolved dynamically after arg parsing)
if exist C:\msys64 (
    set "HAS_MSYS2=1"
) else (
    set "HAS_MSYS2=0"
)

REM Default settings
set ARCH=x86_64
set FORMAT=bin
set CLEAN=0
set BUILD=0
set VERSION=1.0.0

REM Check for sync tools command
if "%~1"=="sync" (
    if "%~2"=="tools" (
        echo === Syncing/Installing Build Tools via MSYS2 ===
        if "%HAS_MSYS2%"=="0" (
            echo MSYS2 not found. Installing MSYS2 installer via Winget...
            winget install -e --id MSYS2.MSYS2 --accept-source-agreements --accept-package-agreements
            if errorlevel 1 (
                echo Failed to install MSYS2 via Winget. Please install it manually from https://www.msys2.org/
                exit /b 1
            )
            echo.
            echo MSYS2 has been installed to C:\msys64.
            echo Please open a new command prompt/PowerShell terminal and run "kineld.bat sync tools" again to finish toolchain setup.
            exit /b 0
        )
        
        echo MSYS2 directory detected. Installing/updating compiler and packaging toolchains...
        REM Run pacman to update existing and install required packages
        C:\msys64\usr\bin\bash.exe -lc "pacman -Syu --noconfirm nasm mingw-w64-x86_64-gcc mingw-w64-i686-gcc mingw-w64-x86_64-mtools xorriso util-linux"
        if errorlevel 1 (
            echo Error: pacman failed to install/update required tools.
            exit /b 1
        )
        echo === Tools installation complete! ===
        exit /b 0
    )
)

REM Check for toolsync status command
if "%~1"=="toolsync" (
    if "%~2"=="status" (
        REM Prepend path dynamically to check status properly
        if "%HAS_MSYS2%"=="1" (
            set "PATH=C:\msys64\mingw64\bin;C:\msys64\mingw32\bin;C:\msys64\usr\bin;%PATH%"
        )
        
        echo === Toolchain Status ===
        call :check_tool nasm
        call :check_tool gcc
        call :check_tool g++
        call :check_tool ld
        call :check_tool mformat
        call :check_tool mcopy
        call :check_tool mmd
        call :check_tool sfdisk
        
        set "iso_found=0"
        where xorrisofs >nul 2>&1
        if !errorlevel! equ 0 (
            for /f "delims=" %%i in ('where xorrisofs 2^>nul') do (
                echo   [OK] xorrisofs ^(alternative to genisoimage^) : Installed ^(%%i^)
                set "iso_found=1"
            )
        )
        if "!iso_found!"=="0" (
            where genisoimage >nul 2>&1
            if !errorlevel! equ 0 (
                for /f "delims=" %%i in ('where genisoimage 2^>nul') do (
                    echo   [OK] genisoimage : Installed ^(%%i^)
                    set "iso_found=1"
                )
            )
        )
        if "!iso_found!"=="0" (
            where mkisofs >nul 2>&1
            if !errorlevel! equ 0 (
                for /f "delims=" %%i in ('where mkisofs 2^>nul') do (
                    echo   [OK] mkisofs ^(alternative to genisoimage^) : Installed ^(%%i^)
                    set "iso_found=1"
                )
            )
        )
        if "!iso_found!"=="0" (
            echo   [MISSING] genisoimage / mkisofs / xorrisofs
        )

        call :check_tool dd
        exit /b 0
    )
)

REM Parse arguments
:parse_args
if "%~1"=="" goto after_args
if "%~1"=="clean" (
    set CLEAN=1
) else if "%~1"=="build" (
    set BUILD=1
) else if "%~1"=="-iso" (
    set FORMAT=iso
) else if "%~1"=="-img" (
    set FORMAT=img
) else if "%~1"=="--x86" (
    set ARCH=x86
) else if "%~1"=="--x86_64" (
    set ARCH=x86_64
) else (
    echo Unknown argument: %~1
    echo Usage:
    echo   kineld.bat [clean] [build] [-iso ^| -img] [--x86 ^| --x86_64]
    echo   kineld.bat sync tools
    echo   kineld.bat toolsync status
    exit /b 1
)
shift
goto parse_args
:after_args

REM Configure compiler PATH priority depending on selected architecture
if "%HAS_MSYS2%"=="1" (
    if "%ARCH%"=="x86_64" (
        set "PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%"
    ) else (
        set "PATH=C:\msys64\mingw32\bin;C:\msys64\usr\bin;%PATH%"
    )
)

if "%CLEAN%"=="1" (
    echo === Cleaning Build Directory ===
    if exist build (
        rmdir /s /q build
    )
    mkdir build
)

if "%BUILD%"=="0" (
    echo No build action specified. Exiting.
    exit /b 0
)

REM Check if compiler tools are available in PATH
where nasm >nul 2>&1
if errorlevel 1 (
    echo Error: 'nasm' not found in PATH. Please run "kineld.bat sync tools" first.
    exit /b 1
)
where gcc >nul 2>&1
if errorlevel 1 (
    echo Error: 'gcc' not found in PATH. Please run "kineld.bat sync tools" first.
    exit /b 1
)

echo === Building Kinet OS ===
echo Target Architecture: %ARCH%
echo Target Format      : %FORMAT%

REM Create build directory if it doesn't exist
if not exist build mkdir build
if not exist build\binary mkdir build\binary

set BIOS_BIN=build\binary\kinet-%VERSION%-%ARCH%-bios.bin
set UEFI_EFI=build\binary\kinet-%VERSION%-%ARCH%-uefi.efi
set BIOS_IMG=build\binary\kinet-%VERSION%-%ARCH%-bios.img
set UEFI_IMG=build\binary\kinet-%VERSION%-%ARCH%-uefi.img
set ISO_OUT=build\binary\kinet-%VERSION%-%ARCH%.iso

if "%ARCH%"=="x86_64" (
    REM =================================================================
    REM x86_64 Target Build
    REM =================================================================
    
    REM 1. BIOS Build
    echo --- Assembling x86_64 BIOS Bootloader ---
    if not exist build\bios\arch\boot\x86_64 mkdir build\bios\arch\boot\x86_64
    nasm -f bin -d BIOS arch/boot/x86_64\boot.asm -o build/bios/arch/boot/x86_64\boot.bin

    echo --- Compiling x86_64 BIOS Kernel, Drivers ^& Userland ---
    if not exist build\bios\kernel mkdir build\bios\kernel
    if not exist build\bios\driver mkdir build\bios\driver
    if not exist build\bios\userland mkdir build\bios\userland
    
    gcc -c -ffreestanding -fno-pic -fno-pie -nostdlib -I driver/include kernel/kernel.c -o build/bios/kernel/kernel.o
    gcc -c -ffreestanding -fno-pic -fno-pie -nostdlib -I driver/include driver/console.c -o build/bios/driver/console.o
    g++ -c -ffreestanding -fno-pic -fno-pie -fno-rtti -fno-exceptions -nostdlib -I driver/include userland/shell.cpp -o build/bios/userland/shell.o

    REM Remove exception unwinding sections to avoid relocation truncation issues under MinGW PE targets
    objcopy --remove-section=.pdata --remove-section=.xdata build/bios/kernel/kernel.o >nul 2>&1
    objcopy --remove-section=.pdata --remove-section=.xdata build/bios/driver/console.o >nul 2>&1
    objcopy --remove-section=.pdata --remove-section=.xdata build/bios/userland/shell.o >nul 2>&1

    echo --- Linking x86_64 BIOS Kernel ---
    REM Link kernel.o first to ensure it occupies the entry address (0x9000). Set image-base to 0 to avoid relocation truncation.
    ld -m i386pep --image-base 0x0 --file-alignment 16 --section-alignment 16 -Ttext 0x9000 -e kernel_main build/bios/kernel/kernel.o build/bios/driver/console.o build/bios/userland/shell.o -o build/bios/kernel.elf
    objcopy -O binary build/bios/kernel.elf build/bios/kernel.bin
    del /f /q build\bios\kernel.elf

    echo --- Creating x86_64 Raw BIOS OS Image ---
    copy /b build\bios\arch\boot\x86_64\boot.bin+build\bios\kernel.bin "%BIOS_BIN%" >nul

    REM 2. UEFI Build
    echo --- Assembling x86_64 UEFI Bootloader ---
    if not exist build\uefi\arch\boot\x86_64 mkdir build\uefi\arch\boot\x86_64
    nasm -f win64 -d UEFI arch/boot/x86_64\boot.asm -o build/uefi/arch/boot/x86_64\boot.o

    echo --- Compiling x86_64 UEFI Kernel, Drivers ^& Userland ---
    if not exist build\uefi\kernel mkdir build\uefi\kernel
    if not exist build\uefi\driver mkdir build\uefi\driver
    if not exist build\uefi\userland mkdir build\uefi\userland
    
    set UEFI_CFLAGS=-ffreestanding -fshort-wchar -mno-red-zone -DUEFI_MODE -fpic -fpie -mabi=ms -fno-asynchronous-unwind-tables -fno-ident -fcf-protection=none
    gcc -c !UEFI_CFLAGS! -I driver/include kernel/kernel.c -o build/uefi/kernel/kernel.o
    gcc -c !UEFI_CFLAGS! -I driver/include driver/console.c -o build/uefi/driver/console.o
    g++ -c !UEFI_CFLAGS! -fno-rtti -fno-exceptions -I driver/include userland/shell.cpp -o build/uefi/userland/shell.o

    echo --- Linking x86_64 UEFI Application ---
    ld -m i386pep --subsystem 10 -e efi_main --build-id=none -S build/uefi/arch/boot/x86_64\boot.o build/uefi/kernel/kernel.o build/uefi/driver/console.o build/uefi/userland/shell.o -o "%UEFI_EFI%"

) else if "%ARCH%"=="x86" (
    REM =================================================================
    REM x86 (32-bit) Target Build
    REM =================================================================
    
    REM 1. BIOS Build
    echo --- Assembling x86 BIOS Bootloader ---
    if not exist build\bios\arch\boot\x86 mkdir build\bios\arch\boot\x86
    nasm -f bin -d BIOS arch/boot/x86\boot.asm -o build\bios\arch\boot\x86\boot.bin

    echo --- Compiling x86 BIOS Kernel, Drivers ^& Userland ---
    if not exist build\bios\kernel mkdir build\bios\kernel
    if not exist build\bios\driver mkdir build\bios\driver
    if not exist build\bios\userland mkdir build\bios\userland
    
    gcc -c -ffreestanding -fno-pic -fno-pie -nostdlib -I driver/include kernel/kernel.c -o build/bios/kernel/kernel.o
    gcc -c -ffreestanding -fno-pic -fno-pie -nostdlib -I driver/include driver/console.c -o build/bios/driver/console.o
    g++ -c -ffreestanding -fno-pic -fno-pie -fno-rtti -fno-exceptions -nostdlib -I driver/include userland/shell.cpp -o build/bios/userland/shell.o

    REM Remove exception unwinding sections to avoid relocation truncation issues under MinGW PE targets
    objcopy --remove-section=.pdata --remove-section=.xdata build/bios/kernel/kernel.o >nul 2>&1
    objcopy --remove-section=.pdata --remove-section=.xdata build/bios/driver/console.o >nul 2>&1
    objcopy --remove-section=.pdata --remove-section=.xdata build/bios/userland/shell.o >nul 2>&1

    echo --- Linking x86 BIOS Kernel ---
    REM Link kernel.o first to ensure it occupies the entry address (0x9000). Set image-base to 0 to avoid relocation truncation.
    ld -m i386pe --image-base 0x0 --file-alignment 16 --section-alignment 16 -Ttext 0x9000 -e kernel_main build/bios/kernel/kernel.o build/bios/driver/console.o build/bios/userland/shell.o -o build/bios/kernel.elf
    objcopy -O binary build/bios/kernel.elf build/bios/kernel.bin
    del /f /q build\bios\kernel.elf

    echo --- Creating x86 Raw BIOS OS Image ---
    copy /b build\bios\arch\boot\x86\boot.bin+build\bios\kernel.bin "%BIOS_BIN%" >nul

    REM 2. UEFI Build
    echo --- Assembling x86 UEFI Bootloader ---
    if not exist build\uefi\arch\boot\x86 mkdir build\uefi\arch\boot\x86
    nasm -f win32 -d UEFI arch/boot/x86\boot.asm -o build\uefi/arch/boot/x86\boot.o

    echo --- Compiling x86 UEFI Kernel, Drivers ^& Userland ---
    if not exist build\uefi\kernel mkdir build\uefi\kernel
    if not exist build\uefi\driver mkdir build\uefi\driver
    if not exist build\uefi\userland mkdir build\uefi\userland
    
    set UEFI_CFLAGS=-ffreestanding -fshort-wchar -DUEFI_MODE -fno-pic -fno-pie -fno-asynchronous-unwind-tables -fno-ident -fcf-protection=none
    gcc -c !UEFI_CFLAGS! -I driver/include kernel/kernel.c -o build/uefi/kernel/kernel.o
    gcc -c !UEFI_CFLAGS! -I driver/include driver/console.c -o build/uefi/driver/console.o
    g++ -c !UEFI_CFLAGS! -fno-rtti -fno-exceptions -I driver/include userland/shell.cpp -o build/uefi/userland/shell.o

    echo --- Linking x86 UEFI Application ---
    ld -m i386pe --subsystem 10 -e efi_main --build-id=none -S build/uefi/arch/boot/x86\boot.o build/uefi/kernel/kernel.o build/uefi/driver/console.o build/uefi/userland/shell.o -o "%UEFI_EFI%"
)

REM =====================================================================
REM Packaging according to requested format
REM =====================================================================
if "%FORMAT%"=="bin" (
    set "OUTPUT_BIN=build\binary\kinet-%VERSION%-%ARCH%.bin"
    call :create_hybrid_img "!OUTPUT_BIN!"
    echo SUCCESS: Hybrid BIOS/UEFI binary !OUTPUT_BIN! created!

) else if "%FORMAT%"=="img" (
    set "OUTPUT_IMG=build\binary\kinet-%VERSION%-%ARCH%.img"
    call :create_disk_img "!OUTPUT_IMG!"
    echo SUCCESS: Hybrid BIOS/UEFI disk image !OUTPUT_IMG! created!

) else if "%FORMAT%"=="iso" (
    set "OUTPUT_ISO=build\binary\kinet-%VERSION%-%ARCH%.iso"

    if "%ARCH%"=="x86_64" (
        set "ISO_BOOT_SRC=arch\boot\x86_64\boot.asm"
    ) else (
        set "ISO_BOOT_SRC=arch\boot\x86\boot.asm"
    )
    set "ISO_BOOT_BIN=build\iso_bios_boot.bin"
    set "ISO_BIOS_IMG=build\iso_bios.bin"
    
    echo --- Assembling No-Emulation BIOS Bootloader for ISO ---
    nasm -f bin -d BIOS -d ISO "!ISO_BOOT_SRC!" -o "!ISO_BOOT_BIN!"
    copy /b "!ISO_BOOT_BIN!"+build\bios\kernel.bin "!ISO_BIOS_IMG!" >nul
    
    REM Pad to 16 sectors (8KB) using PowerShell to truncate/pad.
    powershell -Command "$f = [System.IO.File]::OpenWrite('!ISO_BIOS_IMG!'); $f.SetLength(8192); $f.Close()"

    set "UEFI_IMG_FILE=build\iso_efi.img"
    call :create_hybrid_img "!UEFI_IMG_FILE!"

    echo === Packaging Bootable Hybrid ISO ===
    if not exist build\iso_root mkdir build\iso_root
    copy /y "!ISO_BIOS_IMG!" build\iso_root\bios.bin >nul
    copy /y "!UEFI_IMG_FILE!" build\iso_root\efi.img >nul

    REM Call xorrisofs (MSYS2 standard), otherwise fall back to mkisofs or genisoimage
    where xorrisofs >nul 2>&1
    if !errorlevel! equ 0 (
        xorrisofs -quiet -V "KINET_OS" -b bios.bin -no-emul-boot -boot-load-size 16 -eltorito-alt-boot -e efi.img -no-emul-boot -o "!OUTPUT_ISO!" build\iso_root >nul 2>&1
    ) else (
        where mkisofs >nul 2>&1
        if !errorlevel! equ 0 (
            mkisofs -quiet -V "KINET_OS" -b bios.bin -no-emul-boot -boot-load-size 16 -eltorito-alt-boot -e efi.img -no-emul-boot -o "!OUTPUT_ISO!" build\iso_root >nul 2>&1
        ) else (
            genisoimage -quiet -V "KINET_OS" -b bios.bin -no-emul-boot -boot-load-size 16 -eltorito-alt-boot -e efi.img -no-emul-boot -o "!OUTPUT_ISO!" build\iso_root >nul 2>&1
        )
    )

    rmdir /s /q build\iso_root
    del /f /q "!ISO_BOOT_BIN!" "!ISO_BIOS_IMG!" "!UEFI_IMG_FILE!"
    echo SUCCESS: Hybrid BIOS/UEFI ISO !OUTPUT_ISO! created!
)

echo =========================================
echo  BUILD SUCCESSFUL (Format: %FORMAT%, Arch: %ARCH%)
echo =========================================
exit /b 0

REM =====================================================================
REM Helper function to create the hybrid BIOS/UEFI floppy disk image
REM =====================================================================
:create_hybrid_img
set "target_file=%~1"
echo Creating hybrid BIOS/UEFI image: %target_file%

REM Create a zeroed 1.44MB floppy image file using fsutil or dd
fsutil file createnew "%target_file%" 1474560 >nul 2>&1
if errorlevel 1 (
    dd if=/dev/zero of="%target_file%" bs=1024 count=1440 >nul 2>&1
)

REM Format as FAT12
mformat -i "%target_file%" -f 1440 ::

REM Write BIOS boot sector into sector 0
if "%ARCH%"=="x86_64" (
    dd if=build\bios\arch\boot\x86_64\boot.bin of="%target_file%" conv=notrunc >nul 2>&1
) else (
    dd if=build\bios\arch\boot\x86\boot.bin of="%target_file%" conv=notrunc >nul 2>&1
)

REM Copy files into FAT filesystem
mcopy -i "%target_file%" build\bios\kernel.bin ::/kernel.bin
mmd -i "%target_file%" ::/efi
mmd -i "%target_file%" ::/efi/boot

if "%ARCH%"=="x86_64" (
    mcopy -i "%target_file%" "%UEFI_EFI%" ::/efi/boot/bootx64.efi
) else (
    mcopy -i "%target_file%" "%UEFI_EFI%" ::/efi/boot/bootia32.efi
)
exit /b 0

REM =====================================================================
REM Helper function to create a PARTITIONED hybrid BIOS/UEFI disk image.
REM =====================================================================
:create_disk_img
set "target_file=%~1"
echo Creating partitioned BIOS/UEFI disk image: %target_file%

set /a part_start=2048
set /a part_sectors=2880
set /a total_sectors=part_start + part_sectors
set /a total_bytes=total_sectors * 512

REM Create zeroed disk
fsutil file createnew "%target_file%" %total_bytes% >nul 2>&1
if errorlevel 1 (
    dd if=/dev/zero of="%target_file%" bs=512 count=%total_sectors% >nul 2>&1
)

REM Partition table layout via sfdisk
echo label: dos > build\sfdisk.txt
echo start=%part_start%, size=%part_sectors%, type=ef, bootable >> build\sfdisk.txt
sfdisk --quiet "%target_file%" < build\sfdisk.txt >nul 2>&1
del /f /q build\sfdisk.txt

REM Build the FAT ESP and write it to partition offset
set "tmp_esp=build\disk_esp.img"
call :create_hybrid_img "!tmp_esp!"
dd if="!tmp_esp!" of="%target_file%" bs=512 seek=%part_start% conv=notrunc >nul 2>&1
del /f /q "!tmp_esp!"

REM Store raw BIOS kernel right after MBR (LBA 1)
dd if=build\bios\kernel.bin of="%target_file%" bs=512 seek=1 conv=notrunc >nul 2>&1

REM Assemble and write MBR bootstrap area (first 446 bytes)
if "%ARCH%"=="x86_64" (
    nasm -f bin -d BIOS -d DISK arch\boot\x86_64\boot.asm -o build\mbr.bin
) else (
    nasm -f bin -d BIOS -d DISK arch\boot\x86\boot.asm -o build\mbr.bin
)
dd if=build\mbr.bin of="%target_file%" bs=1 count=446 conv=notrunc >nul 2>&1
del /f /q build\mbr.bin

exit /b 0

REM =====================================================================
REM Helper subroutine to check and print tool status
REM =====================================================================
:check_tool
set "tname=%~1"
where %tname% >nul 2>&1
if !errorlevel! equ 0 (
    for /f "delims=" %%i in ('where %tname% 2^>nul') do (
        echo   [OK] !tname! : Installed ^(%%i^)
        exit /b 0
    )
) else (
    echo   [MISSING] !tname!
)
exit /b 0
