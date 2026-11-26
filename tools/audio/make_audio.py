"""Batch 13 audio: every sound effect and music loop of the game, built from CC0 packs
(PixelLab's sound tools need a higher subscription tier; the author chose CC0 packs).
One treatment for everything, so the packs sound like one game: retro and a little
muffled (low-pass), a short stone-room reflection, silence trimmed, a short fade at the
end, sound effects mono 44.1 kHz with the peak at -1 dBFS (footsteps -12 dBFS), music
stereo at -14 LUFS (ffmpeg loudnorm, true peak -1 dBFS), OGG Vorbis.

Sources (all CC0, see assets/audio/CREDITS.md), unpacked into one folder:
  k_rpg, k_impact, k_interface, k_ui, k_jingles, k_casino, k_digital, k_scifi:
      Kenney RPG Audio, Impact Sounds, Interface Sounds, UI Audio, Music Jingles,
      Casino Audio, Digital Audio, Sci-fi Sounds (kenney.nl/assets/<name>), their Audio/
  j512:  Juhani Junkala, "The Essential Retro Video Game Sound Effects Collection
         [512 sounds]" (opengameart.org/content/512-sound-effects-8-bit-style), flat
  jadv:  Juhani Junkala, "Chiptune Adventures" (opengameart.org/content/4-chiptunes-adventure)
  jret:  Juhani Junkala, "Retro Game Music Pack" (opengameart.org/content/5-chiptunes-action)
  synth: sounds synthesised in code, tools/audio/synth_sfx.py (bow_draw, crossbow_shot,
         crossbow_reload since batch 17: the packs only had creaking-door samples for them);
         building only these needs no sources folder (pass any folder, e.g. .)
Usage (from the project root, ffmpeg on PATH or FFMPEG=<path to ffmpeg.exe>):
    python tools/audio/make_audio.py <sources folder> [name ...]
Writes assets/audio/sfx/<name>.ogg and assets/audio/music/<name>.ogg and prints each
file's length (and loudness for music).
"""
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from scipy import signal
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(__file__))
from synth_sfx import SYNTH  # noqa: E402

SR = 44100
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
SFX_DIR, MUSIC_DIR = "assets/audio/sfx", "assets/audio/music"
ROOTS = {
    "k_rpg": "kenney_rpg-audio/Audio", "k_impact": "kenney_impact-sounds/Audio",
    "k_interface": "kenney_interface-sounds/Audio", "k_ui": "kenney_ui-audio/Audio",
    "k_jingles": "kenney_music-jingles/Audio", "k_casino": "kenney_casino-audio/Audio",
    "k_digital": "kenney_digital-audio/Audio", "k_scifi": "kenney_sci-fi-sounds/Audio",
    "j512": "j512", "jadv": "junkala_adventures", "jret": "junkala_action",
}
SRC = ""


# --- audio helpers ------------------------------------------------------------------

def load(ref, channels=1):
    root, name = ref.split(":", 1)
    if root == "synth":  # synthesised in code (tools/audio/synth_sfx.py), no pack needed
        return SYNTH[name]()
    path = os.path.join(SRC, ROOTS[root], name)
    raw = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-f", "f32le", "-ac", str(channels), "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    data = np.frombuffer(raw, dtype=np.float32).copy()
    return data.reshape(-1, channels) if channels > 1 else data


def speed(x, factor):
    """Plays faster (>1) or slower (<1): pitch and tempo together, like a tape."""
    if factor == 1:
        return x
    n = int(round(len(x) / factor))
    return signal.resample(x, n, axis=0).astype(np.float32)


def lowpass(x, hz, order=4):
    sos = signal.butter(order, hz, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0).astype(np.float32)


def highpass(x, hz, order=2):
    sos = signal.butter(order, hz, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0).astype(np.float32)


def echo(x, ms, decay, taps=1):
    """Short reflections: the stone room."""
    out = np.concatenate([x, np.zeros((int(SR * ms / 1000 * taps),) + x.shape[1:], np.float32)])
    for t in range(1, taps + 1):
        d = int(SR * ms / 1000 * t)
        out[d:d + len(x)] += x * (decay ** t)
    return out


def gain(x, db):
    return x * (10 ** (db / 20))


def trim_silence(x, db=-48):
    level = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    thresh = level.max() * 10 ** (db / 20)
    idx = np.where(level > thresh)[0]
    if not len(idx):
        return x
    return x[max(0, idx[0] - 32): idx[-1] + 1]


def fade_out(x, ms):
    n = min(len(x), int(SR * ms / 1000))
    ramp = np.linspace(1, 0, n, dtype=np.float32)
    x = x.copy()
    x[-n:] = x[-n:] * (ramp if x.ndim == 1 else ramp[:, None])
    return x


def fade_in(x, ms):
    n = min(len(x), int(SR * ms / 1000))
    ramp = np.linspace(0, 1, n, dtype=np.float32)
    x = x.copy()
    x[:n] = x[:n] * (ramp if x.ndim == 1 else ramp[:, None])
    return x


def peak_normalize(x, dbfs):
    p = np.abs(x).max()
    return x * (10 ** (dbfs / 20) / p) if p > 0 else x


def mix(parts):
    """parts: (signal, offset seconds)."""
    n = max(int(off * SR) + len(s) for s, off in parts)
    out = np.zeros(n, np.float32)
    for s, off in parts:
        o = int(off * SR)
        out[o:o + len(s)] += s
    return out


def seamless(x, seconds, cross=0.25):
    """A loop of `seconds`: the tail past the loop end is crossfaded into the start."""
    n, c = int(seconds * SR), int(cross * SR)
    x = x[:n + c].copy()
    ramp = np.linspace(0, 1, c, dtype=np.float32)
    head = x[:c] * ramp + x[n:n + c] * (1 - ramp)
    return np.concatenate([head, x[c:n]])


def write_ogg(x, path, channels=1, extra=None):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "a.wav")
        wavfile.write(wav, SR, np.clip(x, -1, 1).astype(np.float32))
        cmd = [FFMPEG, "-v", "error", "-y", "-i", wav]
        if extra:
            cmd += ["-af", extra]
        cmd += ["-ac", str(channels), "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5", path]
        subprocess.run(cmd, check=True)


# --- sound effects ------------------------------------------------------------------

# name: (layers, options). A layer: (source, gain dB, offset s, speed, start s, end s).
# Options: lp (Hz), hp (Hz), room (False to skip the stone reflection), max (s), min (s),
# loop (s, made seamless), peak (dBFS), fade (ms), rev (reverse the result).
def L(src, db=0.0, off=0.0, spd=1.0, start=0.0, end=None):
    return (src, db, off, spd, start, end)


SFX = {
    # 1. player and weapons
    "sword_swing_1": ([L("j512:sfx_wpn_sword1.wav")], {}),
    "sword_swing_2": ([L("j512:sfx_wpn_sword2.wav")], {}),
    "sword_swing_3": ([L("j512:sfx_wpn_sword3.wav")], {}),
    "sword_hit_1": ([L("k_impact:impactPlate_light_000.ogg"), L("j512:sfx_damage_hit1.wav", -6)], {}),
    "sword_hit_2": ([L("k_impact:impactPlate_light_002.ogg"), L("j512:sfx_damage_hit3.wav", -6)], {}),
    "sword_hit_3": ([L("k_impact:impactPlate_light_004.ogg"), L("j512:sfx_damage_hit5.wav", -6)], {}),
    "heavy_slash": ([L("j512:sfx_wpn_sword2.wav", 0, 0, 0.8), L("k_impact:impactMetal_heavy_001.ogg", -4, 0.06)], {}),
    "bow_draw": ([L("synth:bow_draw")], {"max": 0.5}),
    "bow_release": ([L("k_rpg:drawKnife2.ogg", 0, 0, 1.3), L("j512:sfx_wpn_dagger.wav", -6)], {"max": 0.5}),
    "arrow_hit_flesh": ([L("k_impact:impactGeneric_light_001.ogg"), L("j512:sfx_damage_hit7.wav", -8)], {}),
    "arrow_hit_wall": ([L("k_impact:impactPlank_medium_002.ogg", 0, 0, 1.2), L("k_impact:impactMining_001.ogg", -6)], {}),
    "crossbow_shot": ([L("synth:crossbow_shot")], {"max": 0.5}),
    "crossbow_reload": ([L("synth:crossbow_reload")], {"max": 0.8}),
    "spear_thrust_1": ([L("k_rpg:knifeSlice.ogg", 0, 0, 0.85)], {}),
    "spear_thrust_2": ([L("k_rpg:knifeSlice2.ogg", 0, 0, 0.85)], {}),
    "dagger_stab_1": ([L("k_rpg:knifeSlice.ogg", 0, 0, 1.25)], {"max": 0.4}),
    "dagger_stab_2": ([L("k_rpg:knifeSlice2.ogg", 0, 0, 1.3)], {"max": 0.4}),
    "dagger_stab_3": ([L("k_rpg:drawKnife3.ogg", 0, 0, 1.4)], {"max": 0.4}),
    "crit_hit": ([L("j512:sfx_damage_hit9.wav"), L("k_impact:impactBell_heavy_002.ogg", -4, 0.02, 1.25)], {"max": 1.0, "lp": 9000}),
    "player_hurt_1": ([L("j512:sfx_sounds_damage2.wav")], {}),
    "player_hurt_2": ([L("j512:sfx_sounds_damage1.wav")], {"min": 0.1}),
    "player_hurt_3": ([L("j512:sfx_damage_hit6.wav")], {}),
    "player_death": ([L("j512:sfx_sounds_negative1.wav"), L("j512:sfx_sounds_falling3.wav", -4, 0.25)], {"max": 1.2}),
    "footstep_stone_1": ([L("k_impact:footstep_concrete_000.ogg")], {"peak": -12, "lp": 4000}),
    "footstep_stone_2": ([L("k_impact:footstep_concrete_001.ogg")], {"peak": -12, "lp": 4000}),
    "footstep_stone_3": ([L("k_impact:footstep_concrete_002.ogg")], {"peak": -12, "lp": 4000}),
    "footstep_stone_4": ([L("k_impact:footstep_concrete_003.ogg")], {"peak": -12, "lp": 4000}),
    "dash": ([L("j512:sfx_movement_jump8.wav", 0, 0, 0.8), L("k_rpg:cloth2.ogg", -6)], {"max": 0.5}),
    "shield_block": ([L("k_impact:impactPlank_medium_000.ogg"), L("k_impact:impactMetal_light_001.ogg", -5)], {}),
    "parry": ([L("k_impact:impactMetal_heavy_003.ogg"), L("k_impact:impactBell_heavy_000.ogg", -3, 0.01, 1.3)], {"max": 1.1, "lp": 9000}),
    "teleport_out": ([L("j512:sfx_movement_portal2.wav")], {"max": 0.9}),
    "teleport_in": ([L("j512:sfx_movement_portal2.wav")], {"max": 0.9, "rev": True}),
    "weapon_level_up": ([L("j512:sfx_sounds_powerup4.wav"), L("k_impact:impactBell_heavy_004.ogg", -8, 0.12, 1.5)], {"max": 1.2}),
    # 2. enemies
    "skeleton_swing": ([L("j512:sfx_wpn_sword3.wav", 0, 0, 0.85)], {}),
    "bones_hit_1": ([L("k_casino:chips-collide-1.ogg", 0, 0, 0.8), L("j512:sfx_damage_hit8.wav", -8)], {"max": 0.5}),
    "bones_hit_2": ([L("k_casino:chips-collide-2.ogg", 0, 0, 0.8), L("j512:sfx_damage_hit10.wav", -8)], {"max": 0.5}),
    "bones_hit_3": ([L("k_casino:chips-collide-3.ogg", 0, 0, 0.8), L("j512:sfx_damage_hit8.wav", -8)], {"max": 0.5}),
    "skeleton_death": ([L("k_casino:chips-stack-3.ogg", 0, 0, 0.7), L("k_casino:dice-throw-2.ogg", -3, 0.15, 0.75)], {"max": 1.2}),
    "archer_release": ([L("k_rpg:drawKnife1.ogg", 0, 0, 1.2), L("j512:sfx_wpn_dagger.wav", -6, 0, 0.9)], {"max": 0.5}),
    "beetle_bite": ([L("k_casino:card-place-2.ogg", 0, 0, 1.4), L("k_casino:chip-lay-1.ogg", -4, 0.04, 1.3)], {"max": 0.4}),
    "beetle_swarm_loop": ([L("k_casino:card-shuffle.ogg", 0, 0, 1.15)], {"loop": 2.0, "hp": 600}),
    "golem_windup": ([L("k_scifi:spaceEngineLow_001.ogg", 0, 0, 0.55), L("k_impact:impactMining_003.ogg", -4, 0.3, 0.6)], {"max": 1.2, "lp": 3500}),
    "golem_slam": ([L("k_impact:impactMining_004.ogg", 0, 0, 0.6), L("k_scifi:lowFrequency_explosion_000.ogg", -3)], {"max": 1.2}),
    "ghost_wail": ([L("k_scifi:forceField_002.ogg", 0, 0, 0.55)], {"max": 1.2, "lp": 3000}),
    "ghost_fade": ([L("k_digital:phaserDown2.ogg", 0, 0, 0.7)], {"max": 0.8, "lp": 3500}),
    "drowned_grab": ([L("k_scifi:slime_000.ogg", 0, 0, 0.8), L("k_rpg:cloth3.ogg", -4)], {"max": 0.7}),
    "crab_snap": ([L("k_casino:chip-lay-3.ogg", 0, 0, 1.2), L("k_casino:card-place-4.ogg", -3, 0.03, 1.5)], {"max": 0.35}),
    "imp_cast": ([L("k_scifi:thrusterFire_001.ogg", 0, 0, 1.1)], {"max": 0.7}),
    "magma_hiss": ([L("j512:sfx_sound_depressurizing.wav", 0, 0, 0.8)], {"max": 1.0, "lp": 4500}),
    "enemy_spawn": ([L("j512:sfx_movement_portal5.wav", 0, 0, 0.8)], {"max": 1.0}),
    "warden_roar": ([L("k_scifi:spaceEngineLarge_002.ogg", 0, 0, 0.45), L("k_scifi:lowFrequency_explosion_001.ogg", -4, 0.2, 0.7)], {"max": 2.6, "lp": 2500, "fade": 500}),
    "warden_slam": ([L("k_scifi:explosionCrunch_002.ogg", 0, 0, 0.7), L("k_impact:impactMining_002.ogg", -2, 0, 0.5)], {"max": 1.2}),
    "warden_throw": ([L("j512:sfx_wpn_sword1.wav", 0, 0, 0.55), L("k_impact:impactMining_000.ogg", -8, 0, 0.6)], {"max": 0.8}),
    "boulder_hit": ([L("k_scifi:explosionCrunch_000.ogg", 0, 0, 0.85), L("k_impact:impactMining_001.ogg", -2, 0, 0.7)], {"max": 0.9}),
    "warden_summon": ([L("k_scifi:forceField_000.ogg", 0, 0, 0.6), L("j512:sfx_sounds_powerup9.wav", -6, 0.1, 0.6)], {"max": 1.2, "lp": 4000, "fade": 200}),
    "warden_death": ([L("j512:sfx_exp_long2.wav", 0, 0, 0.7), L("k_impact:impactMining_004.ogg", -2, 0.4, 0.5),
                      L("k_impact:impactMining_002.ogg", -4, 0.9, 0.55)], {"max": 3.0, "lp": 3500, "fade": 600}),
    # 3. spells
    "fireball_cast": ([L("k_scifi:thrusterFire_000.ogg", 0, 0, 0.9)], {"max": 0.7}),
    "fireball_explode": ([L("j512:sfx_exp_short_soft3.wav"), L("k_scifi:thrusterFire_003.ogg", -6, 0, 0.8)], {"max": 1.0}),
    "water_wave": ([L("k_scifi:slime_001.ogg", 0, 0, 0.6), L("k_scifi:thrusterFire_002.ogg", -8, 0, 0.5)], {"max": 1.2, "lp": 3500}),
    "ice_freeze": ([L("k_impact:impactGlass_light_002.ogg"), L("k_interface:glass_003.ogg", -4, 0.05)], {"max": 0.9}),
    "whirlwind_loop": ([L("k_scifi:spaceEngineSmall_001.ogg", 0, 0, 0.7)], {"loop": 2.0, "lp": 2500, "hp": 200}),
    "stone_spikes": ([L("k_impact:impactMining_000.ogg", 0, 0, 0.8), L("k_impact:impactMining_003.ogg", -4, 0.08, 0.9)], {"max": 0.8}),
    "steam_burst": ([L("j512:sfx_sound_vaporizing.wav")], {"max": 1.0, "hp": 300}),
    "plasma_shot": ([L("k_scifi:laserRetro_002.ogg", 0, 0, 0.8)], {"max": 0.6}),
    "lava_bubble_loop": ([L("k_scifi:slime_000.ogg", 0, 0, 0.6), L("k_scifi:slime_001.ogg", -2, 0.6, 0.55)], {"loop": 1.6, "lp": 2500}),
    "lightning_strike_1": ([L("k_digital:zap1.ogg", 0, 0, 0.8), L("j512:sfx_exp_shortest_hard2.wav", -2, 0.03)], {"max": 0.9, "lp": 9000}),
    "lightning_strike_2": ([L("k_digital:zap2.ogg", 0, 0, 0.8), L("j512:sfx_exp_shortest_hard5.wav", -2, 0.03)], {"max": 0.9, "lp": 9000}),
    "vines_grow": ([L("k_rpg:creak3.ogg", 0, 0, 0.8), L("k_rpg:cloth4.ogg", -4, 0.1)], {"max": 1.1}),
    "sandstorm_loop": ([L("k_scifi:spaceEngine_001.ogg", 0, 0, 0.8)], {"loop": 2.5, "lp": 3000, "hp": 400}),
    "thunder_rumble": ([L("k_scifi:lowFrequency_explosion_000.ogg", 0, 0, 0.6), L("j512:sfx_exp_long4.wav", -4, 0.1, 0.6)], {"max": 2.8, "lp": 2500, "fade": 600}),
    "meteor_fall": ([L("j512:sfx_wpn_grenadewhistle1.wav", 0, 0, 0.8)], {"max": 1.2}),
    "meteor_impact": ([L("j512:sfx_exp_medium4.wav"), L("k_scifi:lowFrequency_explosion_001.ogg", -2)], {"max": 1.2}),
    "spell_fusion": ([L("k_impact:impactBell_heavy_001.ogg", 0, 0, 1.4), L("j512:sfx_sounds_powerup12.wav", -5, 0.05)], {"max": 1.2, "lp": 9000}),
    # 4. world and UI
    "coin_pickup_1": ([L("j512:sfx_coin_single1.wav")], {"room": False}),
    "coin_pickup_2": ([L("j512:sfx_coin_single3.wav")], {"room": False}),
    "shard_pickup": ([L("k_interface:glass_001.ogg", 0, 0, 1.2), L("j512:sfx_coin_single5.wav", -6, 0.02, 1.4)], {"max": 0.7, "lp": 9000}),
    "health_pickup": ([L("j512:sfx_sounds_powerup2.wav")], {"max": 0.9}),
    "chest_open": ([L("k_rpg:doorOpen_1.ogg"), L("k_rpg:metalLatch.ogg", -4)], {"max": 1.0}),
    "chest_locked": ([L("k_rpg:metalLatch.ogg"), L("k_rpg:metalClick.ogg", -2, 0.12)], {"max": 0.6}),
    "gate_open": ([L("k_rpg:doorOpen_2.ogg", 0, 0, 0.6), L("k_impact:impactMining_002.ogg", -6, 0.5, 0.6)], {"max": 1.2, "lp": 4000, "fade": 200}),
    "portal_enter": ([L("j512:sfx_movement_portal6.wav")], {"max": 1.2}),
    "secret_wall_break": ([L("k_scifi:explosionCrunch_004.ogg", 0, 0, 0.8), L("k_impact:impactMining_004.ogg", -3, 0.05, 0.8)], {"max": 1.2}),
    "spikes_out": ([L("k_rpg:drawKnife1.ogg", 0, 0, 0.9), L("k_rpg:metalClick.ogg", -4)], {"max": 0.5}),
    "pit_fall": ([L("j512:sfx_sounds_falling1.wav")], {"max": 1.2}),
    "shop_buy": ([L("k_rpg:handleCoins.ogg"), L("j512:sfx_coin_double2.wav", -6, 0.05)], {"max": 0.9}),
    "shop_denied": ([L("k_interface:error_004.ogg")], {"room": False}),
    "ui_click": ([L("k_interface:switch_002.ogg")], {"room": False}),
    "ui_open": ([L("k_interface:open_002.ogg")], {"room": False}),
    "ui_close": ([L("k_interface:close_002.ogg")], {"room": False}),
    "banner": ([L("k_jingles:8-Bit jingles/jingles_NES13.ogg", 0, 0, 0.85)], {"max": 1.4, "lp": 6000}),
    "death_sting": ([L("k_jingles:8-Bit jingles/jingles_NES00.ogg", 0, 0, 0.75)], {"max": 2.5, "lp": 5000, "fade": 300}),
    # 5. batch 15: fungal and sand styles, elemental Wardens, boss chest
    "spore_burst": ([L("k_scifi:slime_001.ogg", 0, 0, 1.3), L("j512:sfx_sound_vaporizing.wav", -4, 0, 1.4)], {"max": 0.7, "hp": 200}),
    "vine_lash": ([L("j512:sfx_wpn_sword1.wav", 0, 0, 1.25), L("k_rpg:creak3.ogg", -6, 0, 1.6)], {"max": 0.5}),
    "bat_screech": ([L("j512:sfx_deathscream_alien3.wav", 0, 0, 1.6)], {"max": 0.5, "lp": 8000}),
    "mushroom_squish": ([L("k_scifi:slime_000.ogg", 0, 0, 1.4), L("k_impact:impactSoft_medium_001.ogg", -3)], {"max": 0.5}),
    "root_burst": ([L("k_impact:impactWood_heavy_002.ogg", 0, 0, 0.8), L("k_impact:impactMining_001.ogg", -4, 0.03, 0.8),
                    L("k_rpg:creak2.ogg", -6, 0, 0.7)], {"max": 0.9}),
    "mother_roar": ([L("k_scifi:spaceEngineLarge_001.ogg", 0, 0, 0.5), L("j512:sfx_deathscream_alien5.wav", -6, 0.1, 0.5)],
                    {"max": 2.6, "lp": 2500, "fade": 500}),
    "quicksand_loop": ([L("j512:sfx_sound_noise.wav", 0, 0, 0.6)], {"loop": 2.0, "lp": 1800, "hp": 150}),
    "mummy_groan": ([L("j512:sfx_deathscream_human4.wav", 0, 0, 0.6)], {"max": 1.0, "lp": 2500}),
    "scarab_burrow": ([L("k_rpg:cloth4.ogg", 0, 0, 0.8), L("j512:sfx_sound_noise.wav", -8, 0, 1.2)], {"max": 0.6, "lp": 3500}),
    "serpent_emerge": ([L("k_scifi:thrusterFire_004.ogg", 0, 0, 0.7), L("j512:sfx_sound_depressurizing.wav", -4, 0.05, 1.3)], {"max": 0.9}),
    "sun_beam_loop": ([L("k_scifi:forceField_001.ogg", 0, 0, 0.9)], {"loop": 2.0, "lp": 6000}),
    "pharaoh_roar": ([L("k_scifi:spaceEngineLarge_003.ogg", 0, 0, 0.5), L("j512:sfx_deathscream_human9.wav", -6, 0.1, 0.5)],
                     {"max": 2.6, "lp": 2500, "fade": 500}),
    "geyser": ([L("k_scifi:thrusterFire_002.ogg", 0, 0, 0.6), L("k_scifi:slime_001.ogg", -3, 0, 0.7)], {"max": 1.2, "lp": 3500}),
    "lava_crack": ([L("k_impact:impactMining_002.ogg", 0, 0, 0.7), L("k_scifi:thrusterFire_000.ogg", -4, 0.05, 0.6)], {"max": 1.0, "lp": 4000}),
    "boss_chest_open": ([L("k_rpg:doorOpen_1.ogg", 0, 0, 0.8), L("k_impact:impactBell_heavy_002.ogg", -4, 0.15, 1.2),
                         L("j512:sfx_sounds_fanfare1.wav", -6, 0.25)], {"max": 1.6, "lp": 8000}),
}


def build_sfx(name, layers, opt):
    parts = []
    for src, db, off, spd, start, end in layers:
        x = load(src)
        x = x[int(start * SR): int(end * SR) if end else None]
        parts.append((gain(speed(trim_silence(x), spd), db), off))
    x = mix(parts)
    if opt.get("rev"):
        x = x[::-1].copy()
    if opt.get("hp"):
        x = highpass(x, opt["hp"])
    x = lowpass(x, opt.get("lp", 7000))
    if opt.get("room", True):
        x = echo(x, 23, 0.22, 2)
    full = x
    x = trim_silence(full)
    if opt.get("min") and len(x) < opt["min"] * SR:
        # a very short sound: keep more of its quiet tail (trim deeper, then only the start)
        x = trim_silence(full, -70)
        if len(x) < opt["min"] * SR:
            start = len(full) - len(trim_silence(full[::-1].copy(), -48)[::-1])
            x = full[max(0, start - 32):]
    if opt.get("loop"):
        x = np.tile(x, int(np.ceil((opt["loop"] + 0.5) * SR / len(x))) + 1) if len(x) < (opt["loop"] + 0.3) * SR else x
        x = seamless(x, opt["loop"])
    else:
        if opt.get("max"):
            x = x[:int(opt["max"] * SR)]
        x = fade_out(x, opt.get("fade", 25))
    x = fade_in(x, 2)
    x = peak_normalize(x, opt.get("peak", -1.0))
    path = os.path.join(SFX_DIR, f"{name}.ogg")
    target = opt.get("peak", -1.0)
    for _ in range(4):
        # Vorbis overshoots peaks by up to ~1 dB: encode, measure, correct the gain
        write_ogg(x, path)
        over = file_peak_db(path) - target
        if over <= 0.05:
            break
        x = gain(x, -over - 0.05)
    return len(x) / SR


def file_peak_db(path):
    raw = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return float(20 * np.log10(np.abs(np.frombuffer(raw, np.float32)).max()))


# --- music ------------------------------------------------------------------------------

# name: (source, speed, low-pass Hz, echo (ms, decay) or None, loop length target s,
#        repeats of the source loop). The sources loop on their own; the loop is the
# whole track (cut at the loop point found below), repeated to reach 60-120 s.
MUSIC = {
    "menu_camp": ("jadv:Juhani Junkala [Chiptune Adventures] 4. Stage Select.ogg", 0.85, 3200, (180, 0.3)),
    "ruins_explore": ("jadv:Juhani Junkala [Chiptune Adventures] 1. Stage 1.ogg", 0.8, 2800, (220, 0.3)),
    "flooded_explore": ("jadv:Juhani Junkala [Chiptune Adventures] 2. Stage 2.ogg", 0.85, 2600, (260, 0.45)),
    "fire_explore": ("jret:Juhani Junkala [Retro Game Music Pack] Level 2.wav", 0.88, 3500, (150, 0.25)),
    "combat": ("jret:Juhani Junkala [Retro Game Music Pack] Level 3.wav", 1.0, 6000, (120, 0.2)),
    "boss_warden": ("jadv:Juhani Junkala [Chiptune Adventures] 3. Boss Fight.ogg", 0.92, 4500, (160, 0.25)),
    "glade_merchant": ("jret:Juhani Junkala [Retro Game Music Pack] Level 1.wav", 1.0, 5000, (120, 0.2)),
    # batch 15: the packs have only nine tracks, so the new pieces are slower / faster,
    # darker or brighter versions of them (fungal and sand use the two tracks not used yet)
    "fungal_explore": ("jret:Juhani Junkala [Retro Game Music Pack] Title Screen.wav", 0.75, 2400, (320, 0.45)),
    "sand_explore": ("jret:Juhani Junkala [Retro Game Music Pack] Ending.wav", 0.8, 3000, (200, 0.3)),
    "boss_elemental": ("jadv:Juhani Junkala [Chiptune Adventures] 3. Boss Fight.ogg", 1.06, 5500, (110, 0.2)),
    "boss_mother": ("jadv:Juhani Junkala [Chiptune Adventures] 3. Boss Fight.ogg", 0.78, 2600, (300, 0.4)),
    "boss_pharaoh": ("jret:Juhani Junkala [Retro Game Music Pack] Level 3.wav", 0.86, 3800, (180, 0.3)),
}


def loop_point(x):
    """Where the track starts over: the sample near the end whose next 1.5 s best
    match the first 1.5 s (the packs' tracks are written to loop, often with a tail)."""
    mono = x.mean(axis=1)
    w = int(1.5 * SR)
    head = mono[:w]
    lo = int(len(mono) * 0.6)
    best, best_i = -1.0, len(mono)
    step = 64
    env = mono[lo:len(mono) - w]
    for i in range(0, len(env), step):
        seg = mono[lo + i: lo + i + w]
        c = float(np.dot(seg, head) / (np.linalg.norm(seg) * np.linalg.norm(head) + 1e-9))
        if c > best:
            best, best_i = c, lo + i
    # refine to the sample
    for i in range(best_i - step, best_i + step):
        seg = mono[i:i + w]
        if len(seg) < w:
            break
        c = float(np.dot(seg, head) / (np.linalg.norm(seg) * np.linalg.norm(head) + 1e-9))
        if c > best:
            best, best_i = c, i
    return best_i, best


def build_music(name, src, spd, lp, room):
    x = load(src, channels=2)
    x = trim_silence(x, -60)
    n, corr = loop_point(x)
    if corr < 0.9:
        n = len(x)               # no repeat found inside: the file itself is the loop
    x = x[:n]
    x = speed(x, spd)
    reps = max(1, int(np.ceil(60.0 / (len(x) / SR))))
    while (len(x) * reps) / SR > 120 and reps > 1:
        reps -= 1
    loop = np.tile(x, (reps, 1))
    # filter and echo on three copies, keep the middle one: the loop's start gets the
    # end's filter state and echo tail, so it joins without a seam
    three = np.tile(loop, (3, 1))
    three = lowpass(three, lp)
    if room:
        ms, dec = room
        d = int(SR * ms / 1000)
        wet = np.zeros_like(three)
        wet[d:] = three[:-d] * dec
        wet[2 * d:] += three[:-2 * d] * dec * dec
        three = three + wet
    loop = three[len(loop):2 * len(loop)]
    path = os.path.join(MUSIC_DIR, f"{name}.ogg")
    # loudness: measure, then a single gain so the whole loop sits at -14 LUFS
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "m.wav")
        wavfile.write(wav, SR, np.clip(loop / max(1.0, np.abs(loop).max()), -1, 1).astype(np.float32))
        lufs = measure_lufs(wav)
    loop = loop / max(1.0, np.abs(loop).max()) * 10 ** ((-14.0 - lufs) / 20)
    peak = np.abs(loop).max()
    limit = 10 ** (-2.0 / 20)            # Vorbis adds up to ~1 dB on peaks: -2 here, <= -1 in the file
    if peak > limit:
        # soft limiting only where it peaks: a tanh knee above -3 dBFS
        knee = 10 ** (-4.0 / 20)
        over = np.abs(loop) > knee
        loop[over] = np.sign(loop[over]) * (knee + (limit - knee) * np.tanh((np.abs(loop[over]) - knee) / (limit - knee)))
    write_ogg(loop, path, channels=2)
    return len(loop) / SR, measure_lufs(path), corr


def measure_lufs(path):
    out = subprocess.run([FFMPEG, "-hide_banner", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", out)
    return float(m[-1])


def build_death_jingle():
    """4-6 s, not a loop: the opening of the Retro Game Music Pack's ending, slowed."""
    x = load("jret:Juhani Junkala [Retro Game Music Pack] Ending.wav", channels=2)
    x = trim_silence(x, -60)
    x = speed(x[:int(4.4 * SR)], 0.85)
    x = lowpass(x, 3500)
    x = fade_out(x, 1200)
    x = x / np.abs(x).max() * 10 ** (-1 / 20)
    path = os.path.join(MUSIC_DIR, "death_jingle.ogg")
    write_ogg(x, path, channels=2)
    return len(x) / SR, measure_lufs(path)


def main():
    global SRC
    SRC = sys.argv[1]
    only = set(sys.argv[2:])
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    report = {}
    for name, (layers, opt) in SFX.items():
        if only and name not in only:
            continue
        report[name] = round(build_sfx(name, layers, opt), 2)
        print(f"sfx   {name:22s} {report[name]:.2f} s")
    for name, (src, spd, lp, room) in MUSIC.items():
        if only and name not in only:
            continue
        length, lufs, corr = build_music(name, src, spd, lp, room)
        report[name] = round(length, 1)
        print(f"music {name:22s} {length:.1f} s  {lufs:.1f} LUFS  loop match {corr:.2f}")
    if not only or "death_jingle" in only:
        length, lufs = build_death_jingle()
        report["death_jingle"] = round(length, 1)
        print(f"music death_jingle           {length:.1f} s  {lufs:.1f} LUFS")


if __name__ == "__main__":
    main()
