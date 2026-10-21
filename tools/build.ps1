param([int]$Jobs = 8)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& cmake -S $projectRoot -B (Join-Path $projectRoot 'build') -G Ninja -DCMAKE_BUILD_TYPE=Release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& cmake --build (Join-Path $projectRoot 'build') --parallel $Jobs
exit $LASTEXITCODE
