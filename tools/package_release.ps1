<#
.SYNOPSIS
    Packages Hagane: The Final Conflict SNES Recomp into a distributable ZIP for RecompLauncher (Zero-ROM).
#>
param(
    [string]$Config = "Release",
    [string]$OutDir = "dist"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $projectRoot)
$buildDir = Join-Path $projectRoot 'build'
$distDir = Join-Path $projectRoot $OutDir

$versionRaw = if (Test-Path (Join-Path $projectRoot 'VERSION')) {
    (Get-Content -Path (Join-Path $projectRoot 'VERSION') -Raw).Trim()
} else {
    "0.1.0"
}

$stageName = "Hagane-The-Final-Conflict-SNESRecomp-$versionRaw-Windows-x64"
$archiveName = "$stageName.zip"
$stageDir = Join-Path $distDir $stageName

Write-Host "==> Packaging Hagane: The Final Conflict Recomp v$versionRaw ($Config) for RecompLauncher..."

if (Test-Path $stageDir) {
    Remove-Item -Recurse -Force $stageDir
}

New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stageDir 'assets') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stageDir 'licenses') -Force | Out-Null
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

# 1. Executavel
$exeName = 'Hagane recomp.exe'
$exeCandidates = @(
    (Join-Path $buildDir $exeName),
    (Join-Path (Join-Path $buildDir $Config) $exeName)
)
$exeSource = $exeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exeSource) {
    throw "Executavel nao encontrado em build/ ou build/${Config}: $exeName"
}
Copy-Item $exeSource -Destination (Join-Path $stageDir $exeName) -Force

# 2. Metadados RecompLauncher e Recomp Project
$rlProfile = Join-Path $projectRoot 'recomplauncher.json'
if (Test-Path $rlProfile) {
    Copy-Item $rlProfile -Destination $stageDir -Force
} else {
    Write-Warning "recomplauncher.json nao encontrado na raiz do projeto!"
}

$recMeta = Join-Path $projectRoot '.recomp.json'
if (Test-Path $recMeta) {
    Copy-Item $recMeta -Destination $stageDir -Force
}

$readmeSource = Join-Path $projectRoot 'README.md'
if (Test-Path $readmeSource) {
    Copy-Item $readmeSource -Destination $stageDir -Force
}

# 3. Config.ini limpo padrao de fabrica
$cleanConfig = @"
[General]
Autosave = 0
DisableFrameDelay = 0
SkipLauncher = 0

[Graphics]
Fullscreen = 0
WindowSize = Auto
WindowScale = 3
NewRenderer = 1
IgnoreAspectRatio = 0
DisplayAspect = 4:3
VSync = 1
NoSpriteLimits = 1

[Sound]
EnableAudio = 1
Volume = 100
AudioFreq = 32040
AudioChannels = 2
AudioSamples = 512
"@
Set-Content -Path (Join-Path $stageDir 'config.ini') -Value $cleanConfig -Encoding UTF8

# 4. Assets (fonts e img)
$assetsCandidates = @(
    (Join-Path $buildDir 'assets'),
    (Join-Path (Join-Path $buildDir $Config) 'assets')
)
$assetsSource = $assetsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($assetsSource -and (Test-Path $assetsSource)) {
    Copy-Item -Recurse (Join-Path $assetsSource '*') -Destination (Join-Path $stageDir 'assets') -Force
}

# 5. Mods (estrutura preloaded)
$modsCandidates = @(
    (Join-Path $buildDir 'mods'),
    (Join-Path (Join-Path $buildDir $Config) 'mods')
)
$modsSource = $modsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($modsSource -and (Test-Path $modsSource)) {
    Copy-Item -Recurse $modsSource -Destination $stageDir -Force
}

# 6. Licencas
$licSdl = Join-Path $workspaceRoot 'dependences\SDL3\LICENSE.txt'
if (Test-Path $licSdl) {
    Copy-Item $licSdl -Destination (Join-Path $stageDir 'licenses\SDL3-LICENSE.txt') -Force
}

$licSnes = Join-Path $projectRoot 'snesrecomp\LICENSE'
if (-not (Test-Path $licSnes)) {
    $licSnes = Join-Path $projectRoot 'modules\snesrecomp\LICENSE'
}
if (Test-Path $licSnes) {
    Copy-Item $licSnes -Destination (Join-Path $stageDir 'licenses\snesrecomp-LICENSE.txt') -Force
}

$licUi = Join-Path $projectRoot 'recomp-ui\LICENSE'
if (-not (Test-Path $licUi)) {
    $licUi = Join-Path $projectRoot 'modules\recomp-ui\LICENSE'
}
if (Test-Path $licUi) {
    Copy-Item $licUi -Destination (Join-Path $stageDir 'licenses\recomp-ui-LICENSE.txt') -Force
}

$licJuice = Join-Path $workspaceRoot 'dependences\libjuice-1.7.2\LICENSE'
if (Test-Path $licJuice) {
    Copy-Item $licJuice -Destination (Join-Path $stageDir 'licenses\libjuice-LICENSE.txt') -Force
}

# 7. Instructions (README.txt para execucao direta fora do launcher)
$readmeContent = @"
Hagane: The Final Conflict SNES Recomp — Release v$versionRaw

HOW TO PLAY:
1. RecompLauncher: Select your legally dumped ROM file ("Hagane - The Final Conflict (USA).sfc" or compatible .smc/.bin).
2. Direct Execution: Run "Hagane recomp.exe". On first startup, select your ROM via the built-in Dear ImGui launcher, or place the ROM directly beside the executable.
3. Online / Netplay: Supported via the built-in lobby menu (Dear ImGui) when SkipLauncher is set to 0.
4. Saves: Game saves are stored durably in the "saves" folder.
"@
Set-Content -Path (Join-Path $stageDir 'README.txt') -Value $readmeContent -Encoding UTF8

# 8. Verificacao estrita de seguranca Zero-ROM
$forbidden = Get-ChildItem -Path $stageDir -Recurse -Include *.sfc, *.smc, *.bin, *.srm, *.log, *.tmp, rom.cfg, last_run_report.json | Where-Object {
    # Nao proibir fontes .ttf ou texturas dentro de assets/
    $_.Extension -match '^\.(sfc|smc|srm|log|tmp)$' -or $_.Name -eq 'rom.cfg' -or $_.Name -eq 'last_run_report.json'
}
if ($forbidden.Count -gt 0) {
    Remove-Item -Recurse -Force $stageDir
    throw "VIOLACAO DE SEGURANCA: Arquivo proibido encontrado no staging: $($forbidden.FullName -join ', ')"
}

# 9. Compactacao do pacote
$zipDest = Join-Path $distDir $archiveName
if (Test-Path $zipDest) {
    Remove-Item -Force $zipDest
}
Write-Host "==> Comprimindo pacote para $archiveName..."
Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $zipDest -CompressionLevel Optimal

# 10. Geracao de Checksum SHA-256
$hash = (Get-FileHash -Path $zipDest -Algorithm SHA256).Hash.ToLower()
$sha256File = "$zipDest.sha256"
"$hash *$archiveName" | Set-Content -Path $sha256File -Encoding UTF8

# 11. Limpeza do staging
Remove-Item -Recurse -Force $stageDir

Write-Host "==> Release gerada com sucesso:"
Write-Host "    ZIP:      $zipDest"
Write-Host "    SHA-256:  $hash"
Write-Host "    Checksum: $sha256File"
