# Third-person action and difficulty overhaul — 2026-10-18

## Controls
Camera-relative WASD, independent mouse orbit, body turns toward movement, right-button precise facing. Acceleration 38 m/s², braking 48 m/s², bounded 14 rad/s body turn (no large-delta lerp overshoot). Club/net immediately zero horizontal velocity and lock locomotion/jump during the complete 0.5-second strike; gravity and incoming knockback remain physical. Ground landing ring and persistent landing captions removed; short hit/miss feedback retained.

Web defaults to pointer lock/free camera. First gameplay click requests lock and is consumed (no accidental swing); no entry confirmation window. Browser security still requires this gesture. If the lock request is refused for 0.35 seconds, right-drag fallback enables automatically; it is also available in Esc settings. Q menu clears lock history/input and reacquires on a closing user gesture.

Reference: Capcom official keyboard/camera control separation, https://game.capcom.com/manual/Multi-Platform/en/windows/page/3/2 and camera options https://game.capcom.com/manual/Multi-Platform/en/windows/page/4/4 . Numerical tuning and mixed third-person behavior are this project's design, not a claim to reproduce any commercial game's controller exactly.

## Curve
Normal: 5 / Lv1 / 180 seconds; Hard: 10 / Lv15 / 120 seconds; Mania: 15 / Lv35 / 90 seconds; Despair: 20 / Lv60 / 75 seconds.
- Sight 10/15/19/24 m, cone 110/140/175/220 degrees, confirmation .60/.32/.18/.08 s.
- Dodge .40/.65/.85/.98 probability, delayed response .18/.12/.075/.04 s with seeded variation; cooldown 1.5/1/.65/.35 s.
- Escape multiplier 1.2/1.55/1.9/2.25, seeded personality .92–1.12, route score randomness, stronger final-survivor pressure (up to +25%).
- Hard+: line-of-sight team alarm sharing last observed position as suspicion, feint pause then real sidestep, shorter pounce windup and recovery, anti-chain-stun resistance (minimum .35-second opening), obstacle escape hops.
- Mania+: ordinary monkeys may counterattack; staggered 1.4–2.4-second frenzy surges, visible red rank text and body agitation. Despair compresses recovery and detection further.
- No through-wall player tracking. Alarm recipients get suspicion, not instant exact ongoing tracking. Pounces retain committed telegraphed direction. High jumps validate every arc segment.

## Persistence / counts
Four native river regions; original three stable habitat and template IDs retained. New independent despair arena/habitat/wrapper. Native member rules own actual count and level. Additive roster_refresh skips reserved encounters and paused contexts, preserves existing unit IDs, adds missing type members, refreshes level preserving HP ratio, updates title/power and is idempotent. Snapshot enemies remain authoritative; controller uses snapshot count/type/IDs, HUD and victory use target_count. Demo-only counts come from MonkeyProfile. Added spawn copies spread onto connected safe navigation, high copies use authored jump markers. Environment art unchanged.

## Verification so far
- Monkey core: 18 passed.
- AI regression: 17 passed.
- Action suite: 28 passed (four actual world counts/levels, unique snapshot IDs, rotated-camera W motion, net/club rooted movement, no ground marker, alarm suspicion, repeated-stun openings, 20 real net sweeps, no five-capture early victory, deferred/idempotent additive migration, refused-pointer-lock fallback).
- Four-zone native village regression: passed, including capsule overlap and connected spawn checks.
- Final Web release c8bc08aeeeee33201bbc4e35: all 17 export gates passed. Object audit: no corrupt chunks, retained releases valid. First transfer 311,348,498 bytes: existing first-download budget warning remains.


## Actual Web evidence
Final release was loaded at http://127.0.0.1:18865/. Normal encounter entered with automatic 3-2-1 and five targets. The embedded browser rejected pointer lock (WrongDocumentError); the new automatic fallback enabled, HUD changed to right-drag camera, and W movement followed by a normal net click captured one monkey (5 -> 4). Q opened/closed the tool wheel and paused the timer. Screenshot: action-web-capture.png. Viewport override reset; game left paused.

The preceding release 3626c5b0b3b8f3be765f2f0d (same gameplay, before automatic pointer fallback) was also manually exercised: normal retreat, Despair entry at Lv60 / 20 / 01:15, camera rotation, movement, hoop sprint, and timeout return to river. No manual full clear is claimed for any new difficulty. The 20-capture automated test validates settlement/count correctness, not human balance.

Embedded browser free-mouse pointer lock remains unverified because the host refuses it. Native camera-relative controls pass; external Chrome/Edge pointer-lock acceptance still needs testing. Fallback is verified in this browser, not presented as equivalent free-mouse acceptance.

Performance: Windows / NVIDIA RTX PRO 6000 Blackwell, Compatibility renderer; 1280x720 browser override during earlier runs. Normal sampled about 51-53 FPS; Despair 10-second windows ranged 32-60 FPS. Godot export was running during some samples. These are short non-isolated gameplay observations, not a sustained 60 FPS benchmark. Logs: action-perf-web.json. The authored environment was not changed.
