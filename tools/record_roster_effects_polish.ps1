$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$out=Join-Path $taskRoot 'artifacts/roster-effects-polish-2026-10-11'
$headless=Get-Content (Join-Path $out 'headless.json') -Raw | ConvertFrom-Json
$render=Get-Content (Join-Path $out 'render.json') -Raw | ConvertFrom-Json
$full=Get-Content (Join-Path $taskRoot 'artifacts/world/results.json') -Raw | ConvertFrom-Json
if($headless.passed -lt 45 -or $headless.failed -ne 0 -or $render.passed -lt 45 -or $render.failed -ne 0){throw 'D32 evidence incomplete'}
$movement=Get-Content (Join-Path $out 'movement.log') -Raw
if($movement -notmatch 'WORLD_MOVEMENT_RESULT passed=40 failed=0'){throw 'Actual movement render evidence missing'}
$prior=Get-Content (Join-Path $taskRoot 'artifacts/mercenary-storage-2026-10-11/results.json') -Raw | ConvertFrom-Json
$newFailures=@(Compare-Object @($prior.full_failures) @($full.failures) | Where-Object SideIndicator -eq '=>' | ForEach-Object InputObject)
$files=@('AGENTS.md','specs/roster_effects_polish.md','specs/mercenary_storage.md','docs/new_units_guide.md','common/data/unit_definition.gd','common/data/skill_definition.gd','common/data/skill_effect_definition.gd','common/data/sprite_sheet_layout.gd','features/progression/mercenary_roster.gd','features/world/runtime/world_session.gd','features/battle/game_director.gd','features/battle/selection_controller.gd','features/ui/world_hud.gd','features/ui/game_hud.gd','features/ui/progression_panels.gd','features/ui/mercenary_storage_panel.gd','features/ui/skill_description.gd','features/skills/advanced_skill_visual.gd','features/skills/advanced_skill_runtime.gd','features/skills/skill_vfx.gd','features/skills/battle_skill_effect.gd','features/presentation/unit_view.gd','features/presentation/sprite_atlas.gd','features/skills/data/dragon.tres','features/skills/data/lightning.tres','features/skills/data/ninja_fire_trail.tres','features/skills/data/claw_strike.tres','features/skills/art/fire-trail-v2.png','features/skills/art/lightning-v2.png','features/units/art/earth-claw-v2.png','features/units/data/summons/earth_claw.tres','features/units/data/monsters/earth_claw_enemy.tres','features/units/data/layouts/earth_claw_v2_layout.tres','tests/roster_effects_polish_suite.gd','tests/run_all.gd')
$files+=@('tests/v2_suite.gd')
$status="headless$($headless.passed)_render$($render.passed)_MOVE40_full$($full.passed)_$($full.failed)_manual_mouse_pending"
$manifestPath=Join-Path $taskRoot 'specs/manifest.json'
$manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
$manifest.features | Add-Member NoteProperty roster_effects_polish ([ordered]@{status=$status;requirements=@('D32 independent warehouse deposit withdraw','D32 actual active count saves and battle','D32 original animated fire lightning','D32 scene full-range dragon','D32 giant claw spike strike');dependencies=@('mercenary_storage','new_units','battle','controls');tests=@('roster_effects_polish_suite','mercenary_storage_suite','new_units_suite','all','world_movement');files=$files;evidence=@('artifacts/roster-effects-polish-2026-10-11/headless.json','artifacts/roster-effects-polish-2026-10-11/render.json','artifacts/roster-effects-polish-2026-10-11/results.json')}) -Force
$manifest.features.mercenary_storage.status=$status
$manifest.features.new_units.status=$status
foreach($file in $files){$manifest.validated_hashes | Add-Member NoteProperty $file (Get-FileHash -LiteralPath (Join-Path $taskRoot $file) -Algorithm SHA256).Hash -Force}
$manifest | ConvertTo-Json -Depth 100 | Set-Content $manifestPath -Encoding utf8
$contextPath=Join-Path $taskRoot 'specs/context_map.json'
$context=Get-Content $contextPath -Raw | ConvertFrom-Json
$context.topics | Add-Member NoteProperty roster_effects ([ordered]@{label='倉庫存取／火徑／落雷／全場火龍／大型魔爪';aliases=@('roster_effects','存入','取出','熾火徑','熾烈之徑','雷擊術','火龍破','火龍波','魔爪','D32');read_first=@('docs/new_units_guide.md','specs/roster_effects_polish.md');authority=@('features/skills/data/dragon.tres','features/skills/data/lightning.tres','features/skills/data/ninja_fire_trail.tres','features/skills/data/claw_strike.tres','features/units/data/summons/earth_claw.tres','features/units/data/layouts/earth_claw_v2_layout.tres');code=@(@{path='features/progression/mercenary_roster.gd';symbols='decode, deposit, withdraw, exchange'},@{path='features/ui/mercenary_storage_panel.gd';symbols='deposit_selected, withdraw_selected'},@{path='features/skills/battle_skill_effect.gd';symbols='initialize'},@{path='features/skills/advanced_skill_visual.gd';symbols='update_fire, create_stakes'},@{path='features/battle/game_director.gd';symbols='spawn_spike_burst, resolve_skill, start_battle'});related=@('mercenary_storage','new_units','controls','sorting');feature='roster_effects_polish';warnings=@('Active1–7，主角固定，完整紀錄先保存再發布。外觀不改導航，尖刺視覺不可造成第二次傷害。');evidence=@('artifacts/roster-effects-polish-2026-10-11/headless.json','artifacts/roster-effects-polish-2026-10-11/render.json')}) -Force
$context.documents | Add-Member NoteProperty 'specs/roster_effects_polish.md' @{category='current_contract';title='D32倉庫獨立存取與戰鬥特效'} -Force
$context.topics.mercenary_storage.read_first=@('docs/new_units_guide.md','specs/roster_effects_polish.md','specs/mercenary_storage.md')
$context.topics.mercenary_storage.warnings=@('D32 Active1–7，F2單獨存取或交換；主角固定，保存完整紀錄。')
$context.topics.mercenary_storage.related+=@('roster_effects')
$context.topics.mercenary_storage.related=@($context.topics.mercenary_storage.related | Select-Object -Unique)
$context | ConvertTo-Json -Depth 100 | Set-Content $contextPath -Encoding utf8
[ordered]@{status=$status;passed=$headless.passed;failed=$headless.failed;render_passed=$render.passed;render_failed=$render.failed;movement='actual render40/0 30 and120FPS';full_passed=$full.passed;full_failed=$full.failed;full_failures=$full.failures;new_full_failures=$newFailures;manual_mouse='not performed';assets=@('features/skills/art/fire-trail-v2.png','features/skills/art/lightning-v2.png','features/units/art/earth-claw-v2.png')} | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $out 'results.json') -Encoding utf8
Write-Output $status
