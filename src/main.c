/*
 * Hagane - The Final Conflict — desktop host shim.
 *
 * Identity and hooks, nothing else. The host itself is the framework's
 * (snesrecomp/runner/src/desktop/host_main.h): the pre-boot launcher, ROM
 * resolution and digest checks, config.ini and keybinds.ini, the window and
 * the SDL / OpenGL presenters, audio, gamepads, the in-game save-state
 * browser and rewind filmstrip, the OSD, the pacing clock, crash handlers and
 * the post-mortem report, mod packages, and Generate & rebuild.
 */

#include "host_main.h"
#include "game_rtl.h"
#include "snesrecomp_rom_identity.h"  /* generated from rom_identity.txt */
#include "recomp_launcher.h"

#ifndef __ANDROID__
#define SDL_MAIN_HANDLED 1
#endif
#include "desktop/sdl_compat.h"
#ifdef __ANDROID__
#define main SDL_main
#endif

#ifndef SNES_GAME_VERSION
#define SNES_GAME_VERSION "dev"
#endif

static void configure_launcher(struct RecompLauncherCGameInfo *gi) {
    /* Explicitly ensure run-ahead is disabled and removed from the launcher UI */
    gi->has_run_ahead = 0;
}

static const SnesDesktopHostGame kGameHost = {
    .display_name        = "Hagane recomp",
    .window_title        = "Hagane recomp",
    .launcher_title      = "Hagane recomp",
    .region              = SNESRECOMP_ROM_REGION,
    .rom_file            = SNESRECOMP_ROM_FILE,
    .expected_sha256_hex = SNESRECOMP_ROM_EXPECTED_SHA256,
    .expected_crc32_hex  = SNESRECOMP_ROM_EXPECTED_CRC32,
    .game_id             = SNESRECOMP_ROM_GAME_ID,
    .build_version       = SNES_GAME_VERSION,
    .game_info           = &kGameInfo,
    .num_players         = 1,
    .sram_path           = NULL,
    .configure_launcher  = &configure_launcher,
};

#ifndef __ANDROID__
#undef main   /* desktop: keep plain main() even if SDL_main.h remapped it */
#endif
int main(int argc, char **argv)
{
    return snesrecomp_desktop_main(&kGameHost, argc, argv);
}
