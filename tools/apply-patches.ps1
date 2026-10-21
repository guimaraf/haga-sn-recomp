param()
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot

function Apply-GitPatch {
    param(
        [string]$Repository,
        [string]$PatchFile
    )

    if (-not (Test-Path -LiteralPath $Repository)) {
        Write-Error "Diretório do repositório não encontrado: $Repository"
        return
    }

    if (-not (Test-Path -LiteralPath $PatchFile)) {
        return
    }

    $patchName = Split-Path -Leaf $PatchFile
    $repoName = Split-Path -Leaf $Repository

    & git -C $Repository apply --ignore-space-change --check $PatchFile 2>$null
    if ($LASTEXITCODE -eq 0) {
        & git -C $Repository apply --ignore-space-change $PatchFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Patch aplicado com sucesso: $patchName -> $repoName"
        } else {
            Write-Error "Falha ao aplicar patch: $PatchFile"
        }
        return
    }

    & git -C $Repository apply --ignore-space-change --reverse --check $PatchFile 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Patch já estava aplicado: $patchName"
        return
    }

    Write-Error "Não foi possível aplicar o patch: $PatchFile"
}

$recompUiDir = Join-Path $projectRoot 'modules/recomp-ui'
if (-not (Test-Path -LiteralPath $recompUiDir) -and (Test-Path -LiteralPath (Join-Path $projectRoot 'recomp-ui'))) {
    $recompUiDir = Join-Path $projectRoot 'recomp-ui'
}

$snesrecompDir = Join-Path $projectRoot 'modules/snesrecomp'
if (-not (Test-Path -LiteralPath $snesrecompDir) -and (Test-Path -LiteralPath (Join-Path $projectRoot 'snesrecomp'))) {
    $snesrecompDir = Join-Path $projectRoot 'snesrecomp'
}

$recompUiPatch = Join-Path $projectRoot 'patches/recomp-ui.patch'
if (Test-Path -LiteralPath $recompUiPatch) {
    Apply-GitPatch -Repository $recompUiDir -PatchFile $recompUiPatch
}

$snesrecompPatch = Join-Path $projectRoot 'patches/snesrecomp.patch'
if (Test-Path -LiteralPath $snesrecompPatch) {
    Apply-GitPatch -Repository $snesrecompDir -PatchFile $snesrecompPatch
}
