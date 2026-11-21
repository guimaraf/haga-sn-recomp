# Hagane: The Final Conflict — SNESRecomp Native Port

Native static recompilation port of **Hagane: The Final Conflict** (USA) powered by the **SNESRecomp** framework.

## Features
- Native x86_64 execution via SNESRecomp.
- Integrated graphical launcher based on Dear ImGui (`recomp-ui`) with support for gamepad remapping, video/audio configuration, and system hotkeys.
- Online Netplay support via ICE/libjuice with built-in lobby browser.
- Run-ahead explicitly disabled (`SNESRECOMP_DISABLE_RUNAHEAD=1`) for timing accuracy and netplay stability.
- Scanline beam hook (`snes_set_beam_line_hook`) integrated into the game loop for authentic visual rendering.
- RecompLauncher & Easy Setup compatibility (Zero-ROM distribution, persistent SRAM, launcher settings).

## ROM Requirements
- **Title**: Hagane - The Final Conflict (USA)
- **File Size**: 2,097,152 bytes (2048 KB)
- **CRC32**: `8e0a7034`
- **SHA-1**: `380046437930d0e39cebd662ad1657e20ac4c9c8`
- **SHA-256**: `5a6deb5617e86a9f4b981031e939510e30c5c8ad047f5f012e40442113fd28c2`
- **Mapping**: HiROM
- **Accepted Formats**: `.sfc`, `.smc` (512-byte copier header auto-stripped), `.bin`

Place your legally dumped ROM named `Hagane - The Final Conflict (USA).sfc` in the project root, or select it via RecompLauncher / the built-in file picker.

## How to Play

### Via RecompLauncher
1. Install and launch the game through **RecompLauncher**.
2. Select your legally obtained ROM when prompted by Easy Setup.
3. Configure video, VSync, and launcher preferences directly within the launcher interface.

### Standalone / Direct Execution
1. Run `Hagane recomp.exe`.
2. On first run, select your ROM file via the built-in Dear ImGui launcher, or place the ROM next to the executable.
3. Save data is stored automatically in the `saves/` folder.

## Cloning and Submodules

This project uses git submodules for the SNESRecomp framework and the recomp-ui launcher.

```bash
git clone --recurse-submodules https://github.com/guimaraf/haga-sn-recomp.git
```

If cloned without `--recurse-submodules`:
```bash
git submodule update --init --recursive
```

### Applying Framework Patches

After cloning or updating submodules, apply project-specific patches:

**On Windows (PowerShell):**
```powershell
.\tools\apply-patches.ps1
```

**On Linux / macOS / MSYS2 (Bash):**
```bash
bash scripts/apply-framework-patches.sh
```

## Building from Source

### Prerequisites
- CMake 3.20+
- C/C++ Compiler (MSVC 2022 / Clang / GCC) with C11 support
- Ninja
- Python 3.10+
- Shared dependencies (SDL3, Lua 5.4.9, libjuice 1.7.2) located in the workspace `dependences/` folder.

### Build Steps

1. **Generate C code from the ROM:**
   ```powershell
   .\tools\regen.ps1 -Rom "path\to\Hagane - The Final Conflict (USA).sfc"
   ```

2. **Compile the release binary:**
   ```powershell
   .\tools\build.ps1
   ```

3. **Package for distribution:**
   ```powershell
   .\tools\package_release.ps1
   ```
