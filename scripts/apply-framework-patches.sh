#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

apply_patch() {
    local repository="$1"
    local patch_file="$2"

    if [ ! -f "$patch_file" ]; then
        return 0
    fi

    if [ ! -d "$repository" ]; then
        printf 'Diretório não encontrado: %s\n' "$repository" >&2
        return 1
    fi

    if git -C "$repository" apply --ignore-space-change --check "$patch_file" 2>/dev/null; then
        git -C "$repository" apply --ignore-space-change "$patch_file"
        printf 'Patch aplicado com sucesso: %s\n' "$patch_file"
    elif git -C "$repository" apply --ignore-space-change --reverse --check "$patch_file" 2>/dev/null; then
        printf 'Patch já estava aplicado: %s\n' "$patch_file"
    else
        printf 'Não foi possível aplicar o patch: %s\n' "$patch_file" >&2
        return 1
    fi
}

snesrecomp_dir="$root/modules/snesrecomp"
if [ ! -d "$snesrecomp_dir" ] && [ -d "$root/snesrecomp" ]; then
    snesrecomp_dir="$root/snesrecomp"
fi

recomp_ui_dir="$root/modules/recomp-ui"
if [ ! -d "$recomp_ui_dir" ] && [ -d "$root/recomp-ui" ]; then
    recomp_ui_dir="$root/recomp-ui"
fi

apply_patch "$recomp_ui_dir" "$root/patches/recomp-ui.patch"
apply_patch "$snesrecomp_dir" "$root/patches/snesrecomp.patch"
