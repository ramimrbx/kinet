# Kinet OS

Kinet OS is a hybrid operating system supporting both legacy BIOS and modern UEFI boot systems. The project provides unified compilation and packaging pipelines for both **Linux** and **Windows** hosts.

---

## Build System (`kineld` / `kineld.bat`)

The project uses a unified build script:
- **Linux/WSL**: [kineld](file:///C:/Users/ramim/Projects/Software/kinet/kineld) (Bash script)
- **Windows Native**: [kineld.bat](file:///C:/Users/ramim/Projects/Software/kinet/kineld.bat) (Batch script)

Both build tools support automatic dependency syncing, tool verification, compilation of C/C++ components, and packaging boot images in floppy (`.bin`), partitioned disk (`.img`), or optical disc (`.iso`) formats.

---

## Step 1: Install Build Tools (`sync tools`)

Before compiling, you must install the required toolchains (compilers, assemblers, and FAT formatting utility suites).

### On Linux (Debian, Ubuntu, Fedora, Arch) or WSL:
Run the sync command to automatically detect your package manager and install/update all dependencies:
```bash
./kineld sync tools
```
*Required tools include: `nasm`, `gcc`, `g++`, `binutils` (ld), `xorriso` / `genisoimage`, and `mtools`.*

### On Windows Native:
Make sure you have Windows Package Manager (`winget`) available, then run:
```powershell
.\kineld.bat sync tools
```
1. If MSYS2 is not installed, the script will use `winget` to install it to `C:\msys64`.
2. Once installed, **open a new terminal** and run `.\kineld.bat sync tools` again. The script will automatically trigger MSYS2's `pacman` database update and download the required toolchains:
   - Compilers: `mingw-w64-x86_64-gcc`, `mingw-w64-i686-gcc`
   - Assembler: `nasm`
   - FAT Formatting: `mingw-w64-x86_64-mtools`
   - ISO Packaging: `xorriso` (provides `xorrisofs`)
   - Utilities: `util-linux` (provides `sfdisk`), `dd`

---

## Step 2: Verify Toolchain Status (`toolsync status`)

You can inspect whether the dependencies are installed and mapped correctly in your environment path by running:

### On Linux or WSL:
```bash
./kineld toolsync status
```

### On Windows Native:
```powershell
.\kineld.bat toolsync status
```

#### Example Output:
```text
=== Toolchain Status ===
  [OK] nasm : Installed (C:\msys64\usr\bin\nasm.exe)
  [OK] gcc : Installed (C:\msys64\mingw64\bin\gcc.exe)
  [OK] g++ : Installed (C:\msys64\mingw64\bin\g++.exe)
  [OK] ld : Installed (C:\msys64\mingw64\bin\ld.exe)
  [OK] mformat : Installed (C:\msys64\mingw64\bin\mformat.exe)
  [OK] mcopy : Installed (C:\msys64\mingw64\bin\mcopy.exe)
  [OK] mmd : Installed (C:\msys64\mingw64\bin\mmd.exe)
  [OK] sfdisk : Installed (C:\msys64\usr\bin\sfdisk.exe)
  [OK] xorrisofs (alternative to genisoimage) : Installed (C:\msys64\usr\bin\xorrisofs.exe)
  [OK] dd : Installed (C:\msys64\usr\bin\dd.exe)
```

---

## Step 3: Compiling and Packaging Kinet OS

Once the status command reports all tools as `[OK]`, you can build Kinet OS.

### Command Usage:
```text
# Linux
./kineld [clean] [build] [-iso | -img] [--x86 | --x86_64]

# Windows
.\kineld.bat [clean] [build] [-iso | -img] [--x86 | --x86_64]
```

### Common Build Commands:

#### 1. Compile 64-bit Hybrid Floppy Binary (Default)
Builds the BIOS boot sector loader, compiled kernel, and UEFI bootloader, packaging them into a 1.44MB hybrid FAT12 floppy image (`.bin`).
```bash
# Linux / WSL
./kineld clean build

# Windows Native
.\kineld.bat clean build
```
- **Output path**: `build/binary/kinet-1.0.0-x86_64.bin`
- *Features*: Bootable directly in VM floppy drives (QEMU/VMware) for legacy BIOS or loaded under UEFI platforms using `/efi/boot/bootx64.efi`.

#### 2. Compile 64-bit Partitioned Disk Image (`.img`)
Creates a partitioned disk image with an MBR partition layout.
```bash
# Linux / WSL
./kineld clean build -img

# Windows Native
.\kineld.bat clean build -img
```
- **Output path**: `build/binary/kinet-1.0.0-x86_64.img`
- *Features*: Suitable for flashing to raw USB thumb drives or hard disk drives. Sector 0 contains the MBR bootstrap, Sector 1 onwards stores the raw BIOS kernel, and the FAT EFI System Partition (ESP) starts at 1 MiB alignment (Sector 2048) containing the UEFI binaries.

#### 3. Compile 64-bit Bootable CD-ROM ISO (`.iso`)
Assembles a hybrid ISO-9660 image supporting both legacy BIOS El Torito No-Emulation boot and UEFI alt-boot records.
```bash
# Linux / WSL
./kineld clean build -iso

# Windows Native
.\kineld.bat clean build -iso
```
- **Output path**: `build/binary/kinet-1.0.0-x86_64.iso`
- *Features*: Standard hybrid optical disk format bootable under modern hypervisors and legacy optical drives.

#### 4. Compile 32-bit (x86) Targets
To compile any of the above formats for a 32-bit (x86) target, append the `--x86` flag:
```bash
# Linux / WSL
./kineld clean build -iso --x86

# Windows Native
.\kineld.bat clean build -iso --x86
```
- **Output path**: `build/binary/kinet-1.0.0-x86.iso`
- *Features*: Packages 32-bit BIOS kernel binaries and 32-bit UEFI application packages (`bootia32.efi`).
