$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $projectRoot)
$buildDir = Join-Path $projectRoot 'build'
$releaseDir = Join-Path $buildDir 'Release'
$distDir = Join-Path $projectRoot 'dist'

$versionRaw = (Get-Content -Path (Join-Path $projectRoot 'VERSION') -Raw).Trim()
$archiveName = "Hagane-The-Final-Conflict-SNESRecomp-v$versionRaw-win64.zip"

if (Test-Path $releaseDir) {
    Remove-Item -Recurse -Force $releaseDir
}

New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $releaseDir 'assets') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $releaseDir 'licenses') -Force | Out-Null
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

# 1. Executavel
$exeName = 'Hagane recomp.exe'
$exeSource = Join-Path $buildDir $exeName
if (-not (Test-Path $exeSource)) {
    throw "Executavel nao encontrado: $exeSource"
}
Copy-Item $exeSource -Destination (Join-Path $releaseDir $exeName) -Force

# 2. Assets (fonts e img)
$assetsSource = Join-Path $buildDir 'assets'
if (Test-Path $assetsSource) {
    Copy-Item -Recurse (Join-Path $assetsSource '*') -Destination (Join-Path $releaseDir 'assets') -Force
}

# 3. Mods (estrutura preloaded)
$modsSource = Join-Path $buildDir 'mods'
if (Test-Path $modsSource) {
    Copy-Item -Recurse $modsSource -Destination $releaseDir -Force
}

# 4. Licencas
$licSdl = Join-Path $workspaceRoot 'dependences\SDL3\LICENSE.txt'
if (Test-Path $licSdl) {
    Copy-Item $licSdl -Destination (Join-Path $releaseDir 'licenses\SDL3-LICENSE.txt') -Force
}

$licSnes = Join-Path $projectRoot 'snesrecomp\LICENSE'
if (-not (Test-Path $licSnes)) {
    $licSnes = Join-Path $projectRoot 'modules\snesrecomp\LICENSE'
}
if (Test-Path $licSnes) {
    Copy-Item $licSnes -Destination (Join-Path $releaseDir 'licenses\snesrecomp-LICENSE.txt') -Force
}

$licUi = Join-Path $projectRoot 'recomp-ui\LICENSE'
if (-not (Test-Path $licUi)) {
    $licUi = Join-Path $projectRoot 'modules\recomp-ui\LICENSE'
}
if (Test-Path $licUi) {
    Copy-Item $licUi -Destination (Join-Path $releaseDir 'licenses\recomp-ui-LICENSE.txt') -Force
}

$licJuice = Join-Path $workspaceRoot 'dependences\libjuice-1.7.2\LICENSE'
if (Test-Path $licJuice) {
    Copy-Item $licJuice -Destination (Join-Path $releaseDir 'licenses\libjuice-LICENSE.txt') -Force
}

# 5. Instrucoes de uso (LEIA-ME.txt)
$readmeContent = @"
Hagane: The Final Conflict SNES Recomp — Release v$versionRaw

COMO JOGAR:
1. Execute "Hagane recomp.exe".
2. A ROM oficial nao esta inclusa nesta distribuicao.
3. Na primeira execucao, selecione o arquivo da ROM "Hagane - The Final Conflict (USA).sfc" através da interface do launcher ou coloque a ROM diretamente na mesma pasta do executável.
4. As configuracoes de video, controles e salvamento serao criadas automaticamente.
"@
Set-Content -Path (Join-Path $releaseDir 'LEIA-ME.txt') -Value $readmeContent -Encoding utf8

# 6. Remocao estrita de arquivos nao permitidos
Get-ChildItem -Path $releaseDir -Recurse -Include *.sfc, *.smc, *.srm, *.log, *.tmp, rom.cfg, config.ini, last_run_report.json | Remove-Item -Force

# 7. Compactacao do pacote
$zipDest = Join-Path $distDir $archiveName
if (Test-Path $zipDest) {
    Remove-Item -Force $zipDest
}
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipDest -CompressionLevel Optimal

Write-Output "Release montada com sucesso em: $releaseDir"
Write-Output "Pacote compactado gerado em: $zipDest"
