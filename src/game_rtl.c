/*
 * Hagane - The Final Conflict — per-game runtime glue.
 *
 * Implements beam-aligned execution with Scanout Latch for deterministic
 * frame timing, raster HDMA synchronization, and state management.
 */

#include "game_rtl.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common_cpu_infra.h"
#include "common_rtl.h"
#include "cpu_state.h"
#include "snes/cart.h"
#include "snes/cx4.h"
#include "snes/dma.h"
#include "snes/interp_bridge.h"
#include "snes/ppu.h"
#include "snes/sa1.h"
#include "snes/snes.h"
#include "snes/superfx.h"
#include "snes/saveload.h"

extern CpuState g_cpu;
extern Ppu *g_ppu;

#define BFD_MASTER_CYCLES_PER_FIELD 357368ull
#define BFD_MASTER_CYCLES_PER_LINE  1364u
#define BFD_VBLANK_LINE             225u
#define BFD_MAX_SLICES_PER_FIELD    1024

/* 0 until the first frame has booted from the reset vector. */
static uint32_t s_resume_pc;
static bool s_wai_halted;

/* Scanout Latch: OAM and CGRAM snapshot taken at line 0 / post-NMI */
static uint16_t s_scanout_oam[0x100];
static uint8_t  s_scanout_high_oam[0x20];
static uint16_t s_scanout_cgram[0x100];
static bool     s_scanout_valid;

static void capture_scanout(const Snes *snes, uint16_t line) {
  if (snes != g_snes || line != 0u)
    return;
  memcpy(s_scanout_oam, g_ppu->oam, sizeof(s_scanout_oam));
  memcpy(s_scanout_high_oam, g_ppu->highOam, sizeof(s_scanout_high_oam));
  memcpy(s_scanout_cgram, g_ppu->cgram, sizeof(s_scanout_cgram));
  s_scanout_valid = true;
}

static uint32_t read_vector(uint32_t addr) {
  uint32_t lo = snes_read(g_snes, addr);
  uint32_t hi = snes_read(g_snes, addr + 1u);
  return (hi << 8) | lo;
}

static uint32_t reset_vector(void) { return read_vector(0x00FFFCu); }
static uint32_t nmi_vector(void)   { return read_vector(0x00FFEAu); }
static uint32_t irq_vector(void)   { return read_vector(0x00FFEEu); }

static void update_resume_pc(void) {
  uint32_t resume = interp_bridge_lle_resume_pc();
  if (resume)
    s_resume_pc = resume;
}

static bool cart_irq_pending(void) {
  const Cart *cart = g_snes->cart;
  if (!cart)
    return false;
  if (cart->superfx && cart->superfx->irq_pending)
    return true;
  if (cart->cx4 && cx4_irq_pending(cart->cx4))
    return true;
  if (cart->sa1 && sa1_cpu_irq_pending(cart->sa1))
    return true;
  return false;
}

static bool irq_line_asserted(void) {
  return g_snes->inIrq || cart_irq_pending();
}

static bool irq_wanted(void) {
  return !g_cpu._flag_I && irq_line_asserted();
}

static uint64_t beam_debt(void) {
  return g_cpu.master_cycles > g_snes->beamMasterLast
             ? g_cpu.master_cycles - g_snes->beamMasterLast
             : 0;
}

static void advance_parked(uint64_t until) {
  g_cpu.master_cycles = until;
  snes_refresh_exempt();
  snes_sync_master_clock(g_snes, g_cpu.master_cycles);
  cart_sync_coprocessors(g_snes->cart, g_cpu.master_cycles);
}

static void run_interrupt(uint32_t vector, uint64_t deadline) {
  cpu_push_interrupt_frame_at(&g_cpu, s_resume_pc);
  g_cpu.P = (uint8_t)((g_cpu.P | 0x04u) & ~0x08u);
  cpu_p_to_mirrors(&g_cpu);
  interp_bridge_set_master_deadline(deadline);
  (void)interp_bridge_run_until_quiescent(&g_cpu, vector);
  interp_bridge_set_master_deadline(0);
  update_resume_pc();
  if (interp_bridge_lle_took_wai())
    s_wai_halted = true;
}

void GameRunOneFrame(void) {
  const bool booting = s_resume_pc == 0;
  int slices = 0;
  uint64_t frame_end;

  snes_set_beam_line_hook(capture_scanout);
  s_scanout_valid = false;

  {
    uint32_t to_vblank = snes_master_clocks_until_line(g_snes, BFD_VBLANK_LINE);
    frame_end = g_snes->beamMasterLast +
                (to_vblank ? to_vblank : BFD_MASTER_CYCLES_PER_FIELD);
  }

  if (booting) {
    s_resume_pc = reset_vector();
  } else {
    ppu_checkOverscan(g_ppu);
    ppu_handleVblank(g_ppu);
  }

  snes_set_hdma_beam_enabled(g_snes, false);
  snes_set_raster_irq_beam_enabled(true);
  ppu_rasterBegin(g_ppu);

  if (!booting && g_snes->nmiEnabled) {
    g_snes->inNmi = true;
    s_wai_halted = false;
    run_interrupt(nmi_vector(), frame_end);
    g_snes->inNmi = false;
  }

  while (g_cpu.master_cycles < frame_end && slices++ < BFD_MAX_SLICES_PER_FIELD) {
    uint64_t next;
    uint32_t to_irq;

    if (s_wai_halted && irq_line_asserted())
      s_wai_halted = false;

    if (!s_wai_halted && !irq_wanted()) {
      interp_bridge_set_master_deadline(frame_end);
      (void)interp_bridge_run_until_quiescent(&g_cpu, s_resume_pc);
      interp_bridge_set_master_deadline(0);
      update_resume_pc();
      if (interp_bridge_lle_took_wai())
        s_wai_halted = true;
    }

    if (g_cpu.master_cycles >= frame_end)
      break;

    if (irq_wanted()) {
      s_wai_halted = false;
      run_interrupt(irq_vector(), frame_end);
      continue;
    }

    if (beam_debt()) {
      snes_sync_master_clock(g_snes, g_cpu.master_cycles);
      cart_sync_coprocessors(g_snes->cart, g_cpu.master_cycles);
      continue;
    }

    to_irq = snes_master_clocks_until_irq(g_snes);
    if (to_irq)
      to_irq += 1;
    if (to_irq == 0 || to_irq > BFD_MASTER_CYCLES_PER_LINE)
      to_irq = BFD_MASTER_CYCLES_PER_LINE;
    next = g_cpu.master_cycles + to_irq;
    if (next > frame_end)
      next = frame_end;
    advance_parked(next);
  }

  {
    int walk = 0;
    if (g_cpu.master_cycles < frame_end)
      advance_parked(frame_end);
    while (g_snes->beamMasterLast < frame_end && walk++ < 1200) {
      uint64_t before = g_snes->beamMasterLast;
      uint64_t want = frame_end - before;
      snes_advance_master_cycles(g_snes, want > UINT32_MAX ? UINT32_MAX : (uint32_t)want);
      if (g_snes->beamMasterLast == before)
        break;
    }
    cart_sync_coprocessors(g_snes->cart, g_cpu.master_cycles);
  }
}

void GameDrawPpuFrame(void) {
  int line;
  uint16_t live_oam[0x100];
  uint8_t  live_high_oam[0x20];
  uint16_t live_cgram[0x100];
  const bool latched = s_scanout_valid && !g_ppu_scanout_latch_bypass;

  if (latched) {
    memcpy(live_oam, g_ppu->oam, sizeof(live_oam));
    memcpy(live_high_oam, g_ppu->highOam, sizeof(live_high_oam));
    memcpy(live_cgram, g_ppu->cgram, sizeof(live_cgram));
    memcpy(g_ppu->oam, s_scanout_oam, sizeof(s_scanout_oam));
    memcpy(g_ppu->highOam, s_scanout_high_oam, sizeof(s_scanout_high_oam));
    memcpy(g_ppu->cgram, s_scanout_cgram, sizeof(s_scanout_cgram));
  }

  snes_set_hdma_beam_enabled(g_snes, false);
  ppu_rasterRenderBegin(g_ppu);
  ppu_rasterApplyLine(g_ppu, 0);
  {
    uint8_t hdmaen;
    if (ppu_rasterTakeHdmaen(&hdmaen))
      dma_startDma(g_snes->dma, hdmaen, true);
  }
  dma_initHdma(g_snes->dma);
  dma_doHdma(g_snes->dma);

  for (line = 1; line <= 224; line++) {
    uint8_t hdmaen;
    if (line > 1)
      ppu_rasterApplyLine(g_ppu, line - 1);
    if (ppu_rasterTakeHdmaen(&hdmaen))
      dma_startDma(g_snes->dma, hdmaen, true);
    ppu_runLine(g_ppu, line);
    dma_doHdma(g_snes->dma);
  }
  ppu_rasterRenderEnd(g_ppu);

  if (latched) {
    memcpy(g_ppu->oam, live_oam, sizeof(live_oam));
    memcpy(g_ppu->highOam, live_high_oam, sizeof(live_high_oam));
    memcpy(g_ppu->cgram, live_cgram, sizeof(live_cgram));
  }
}

void GameSessionReset(void) {
  s_resume_pc = 0;
  s_wai_halted = false;
  s_scanout_valid = false;
  memset(s_scanout_oam, 0, sizeof(s_scanout_oam));
  memset(s_scanout_high_oam, 0, sizeof(s_scanout_high_oam));
  memset(s_scanout_cgram, 0, sizeof(s_scanout_cgram));
}

static size_t GameExecStateBound(void) {
  return sizeof(uint32_t) + sizeof(uint8_t) + sizeof(uint8_t) +
         sizeof(s_scanout_oam) + sizeof(s_scanout_high_oam) + sizeof(s_scanout_cgram);
}

static size_t GameExecStateSave(void *out, size_t capacity) {
  if (capacity < GameExecStateBound())
    return 0;
  uint8_t *p = (uint8_t *)out;
  memcpy(p, &s_resume_pc, sizeof(uint32_t));
  p += sizeof(uint32_t);
  uint8_t wai = s_wai_halted ? 1 : 0;
  memcpy(p, &wai, sizeof(uint8_t));
  p += sizeof(uint8_t);
  uint8_t valid = s_scanout_valid ? 1 : 0;
  memcpy(p, &valid, sizeof(uint8_t));
  p += sizeof(uint8_t);
  memcpy(p, s_scanout_oam, sizeof(s_scanout_oam));
  p += sizeof(s_scanout_oam);
  memcpy(p, s_scanout_high_oam, sizeof(s_scanout_high_oam));
  p += sizeof(s_scanout_high_oam);
  memcpy(p, s_scanout_cgram, sizeof(s_scanout_cgram));
  p += sizeof(s_scanout_cgram);
  return (size_t)(p - (uint8_t *)out);
}

static int GameExecStateLoad(const void *in, size_t size) {
  if (size < GameExecStateBound())
    return 0;
  const uint8_t *p = (const uint8_t *)in;
  memcpy(&s_resume_pc, p, sizeof(uint32_t));
  p += sizeof(uint32_t);
  uint8_t wai = 0;
  memcpy(&wai, p, sizeof(uint8_t));
  s_wai_halted = (wai != 0);
  p += sizeof(uint8_t);
  uint8_t valid = 0;
  memcpy(&valid, p, sizeof(uint8_t));
  s_scanout_valid = (valid != 0);
  p += sizeof(uint8_t);
  memcpy(s_scanout_oam, p, sizeof(s_scanout_oam));
  p += sizeof(s_scanout_oam);
  memcpy(s_scanout_high_oam, p, sizeof(s_scanout_high_oam));
  p += sizeof(s_scanout_high_oam);
  memcpy(s_scanout_cgram, p, sizeof(s_scanout_cgram));
  return 1;
}

static void GameStateSave(SaveLoadInfo *sli) {
  uint32_t state[4] = {0x48414741u, 2u, s_resume_pc, s_wai_halted ? 1u : 0u};
  uint32_t valid = s_scanout_valid ? 1u : 0u;
  sli->func(sli, state, sizeof(state));
  sli->func(sli, &valid, sizeof(valid));
  sli->func(sli, s_scanout_oam, sizeof(s_scanout_oam));
  sli->func(sli, s_scanout_high_oam, sizeof(s_scanout_high_oam));
  sli->func(sli, s_scanout_cgram, sizeof(s_scanout_cgram));
}

static void GameStateLoad(SaveLoadInfo *sli, uint32_t version) {
  uint32_t state[4] = {0};
  (void)version;
  sli->func(sli, state, sizeof(state));
  if (state[0] != 0x48414741u || (state[1] != 1u && state[1] != 2u) ||
      state[2] > 0xffffffu || state[3] > 1u) {
    RtlStateStreamFail(sli);
    return;
  }
  s_resume_pc = state[2];
  s_wai_halted = (state[3] != 0);
  s_scanout_valid = false;
  if (state[1] == 2u) {
    uint32_t valid = 0;
    sli->func(sli, &valid, sizeof(valid));
    sli->func(sli, s_scanout_oam, sizeof(s_scanout_oam));
    sli->func(sli, s_scanout_high_oam, sizeof(s_scanout_high_oam));
    sli->func(sli, s_scanout_cgram, sizeof(s_scanout_cgram));
    if (valid > 1u) {
      RtlStateStreamFail(sli);
      return;
    }
    s_scanout_valid = (valid != 0);
  } else {
    memset(s_scanout_oam, 0, sizeof(s_scanout_oam));
    memset(s_scanout_high_oam, 0, sizeof(s_scanout_high_oam));
    memset(s_scanout_cgram, 0, sizeof(s_scanout_cgram));
  }
}

const RtlGameInfo kGameInfo = {
    .title = "hagane-the-final-conflict-usa",
    .run_frame = &GameRunOneFrame,
    .draw_ppu_frame = &GameDrawPpuFrame,
    .save_name_prefix = "save",
    .session_reset = &GameSessionReset,
    .hardware_reset = &GameSessionReset,
    .state_save_extra = &GameStateSave,
    .state_load_extra = &GameStateLoad,
    .minimum_state_version = 5,
    .exec_state_bound = &GameExecStateBound,
    .exec_state_save  = &GameExecStateSave,
    .exec_state_load  = &GameExecStateLoad,
};
