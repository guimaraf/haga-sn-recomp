# Hagane: The Final Conflict — SNESRecomp Native Port

Port nativo por recompilação estática de **Hagane - The Final Conflict** (USA) utilizando o framework **SNESRecomp**.

## Características
- Execução nativa x86_64 via SNESRecomp.
- Launcher gráfico integrado baseado em Dear ImGui (`recomp-ui`) com suporte a remapeamento de controles, opções de vídeo, áudio e hotkeys.
- Desativação de run-ahead (`SNESRECOMP_DISABLE_RUNAHEAD=1`) para precisão e estabilidade de sincronismo.
- Gancho de scanline (`snes_set_beam_line_hook`) integrado ao loop do jogo para captura e renderização fiel.

## Requisitos da ROM
- **Título**: Hagane - The Final Conflict (USA)
- **Tamanho**: 2.097.152 bytes (2048 KB)
- **CRC32**: `8e0a7034`
- **SHA256**: `5a6deb5617e86a9f4b981031e939510e30c5c8ad047f5f012e40442113fd28c2`
- **Mapeamento**: HiROM

Coloque a ROM com o nome `Hagane - The Final Conflict (USA).sfc` na raiz do projeto (ou configure via `rom.cfg` / launcher).

## Clonagem e Submódulos

Este projeto utiliza submódulos oficiais para o framework SNESRecomp e para o lançador recomp-ui.

```bash
git clone --recurse-submodules https://github.com/guimaraf/haga-sn-recomp.git
```

Se clonado sem `--recurse-submodules`:
```bash
git submodule update --init --recursive
```

### Aplicação dos Patches do Framework

Após clonar ou atualizar os submódulos, aplique os patches específicos do projeto:

**No Windows (PowerShell):**
```powershell
.\tools\apply-patches.ps1
```

**No Linux / macOS / MSYS2 (Bash):**
```bash
bash scripts/apply-framework-patches.sh
```

## Geração do Código C e Compilação

### Dependências Requisitadas
- CMake 3.20+
- Compilador C/C++ (MSVC 2022 / Clang / GCC)
- Ninja
- Python 3.10+
- Dependências compartilhadas (SDL3, Lua 5.4.9, libjuice 1.7.2) na pasta `dependences/` ou fornecidas pelo workspace pai.

### Passos de Build

1. **Gerar o código C a partir da ROM:**
   ```powershell
   .\tools\regen.ps1 -Rom "caminho\para\Hagane - The Final Conflict (USA).sfc"
   ```

2. **Compilar:**
   ```powershell
   .\tools\build.ps1
   ```
