# Background music contract

User decision 2026-10-10: use the six supplied local MP3s; smooth transitions.

- Authority: `features/audio/background_music.gd` TRACKS and track_for.
- river_bay/default world → ChinaField; qingling_town → ChinaVillage;
  shaolin_temple → shaolin temple; millennium_lake → Ghost lake;
  well_1/well_2 → weapon grave; battle/results → Battle music.
- Countdown keeps regional music. Loading keeps the previous music until arrival.
- Same track requests never restart playback (including between well floors).
- 1.2-second linear-gain crossfade, -12 dB default level, dedicated Music bus.
  Exports can be adjusted on the BackgroundMusic node; there is no new volume menu.
- Interrupted fades begin from current gains. No stale callback stops the new target.
- Local duplicated MP3 streams loop; original media/import settings stay unchanged.
- GameDirector owns the persistent music child outside level roots. Audio does not
  write saves, alter world clocks/movement, or replace existing GameAudio effects.
- Test: `tests/background_music_suite.tscn`, included in run_all --all.
  Headless checks validate routes, looping, gain overlap, interruption, cleanup and
  real director world→battle→result→world integration, not human listening approval.

Public repository decision 2026-10-18: `art/music/` and its import sidecars are
Git-ignored. Tracks are optional runtime resources. A checkout without them
plays silently while effects, unit voices, combat, and saves remain available.
Missing tracks allocate no AudioStreamPlayer nodes. The BGM suite verifies
silent routing and real world/battle/results/return flow when no tracks exist;
with the six local MP3s present it also checks playback and crossfades.
