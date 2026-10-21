param([string]$Rom = "")
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (!$Rom) { $Rom = (Get-Content -LiteralPath (Join-Path $projectRoot 'rom.cfg') -Raw).Trim() }
$Rom = (Resolve-Path -LiteralPath $Rom).Path
$tempRoot = Join-Path $projectRoot '.tmp'
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$env:TEMP = $tempRoot
$env:TMP = $tempRoot
$identity = @{}
Get-Content -LiteralPath (Join-Path $projectRoot 'rom_identity.txt') | ForEach-Object {
    if ($_ -match '^\s*([a-z0-9_]+)\s*=\s*(.*?)\s*$') { $identity[$Matches[1]] = $Matches[2] }
}
$cliPath = Join-Path $projectRoot 'modules/snesrecomp/snesrecomp_cli.py'
if (-not (Test-Path -LiteralPath $cliPath) -and (Test-Path -LiteralPath (Join-Path $projectRoot 'snesrecomp/snesrecomp_cli.py'))) {
    $cliPath = Join-Path $projectRoot 'snesrecomp/snesrecomp_cli.py'
}
$arguments = @($cliPath, 'generate',
    '--rom', $Rom, '--cfg-dir', (Join-Path $projectRoot 'recomp'),
    '--out-dir', (Join-Path $projectRoot 'src/gen'), '--funcs-h', (Join-Path $projectRoot 'recomp/funcs.h'),
    '--project-root', $projectRoot, '--cfg-roots', '--expected-crc32', $identity.expected_crc32,
    '--expected-sha256', $identity.expected_sha256)
& python @arguments
exit $LASTEXITCODE
