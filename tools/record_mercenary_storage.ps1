$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$out=Join-Path $projectRoot 'artifacts/mercenary-storage-2026-10-11'
$headless=Get-Content (Join-Path $out 'headless-results.json') -Raw | ConvertFrom-Json
$render=Get-Content (Join-Path $out 'render-results.json') -Raw | ConvertFrom-Json
$full=Get-Content (Join-Path $projectRoot 'artifacts/world/results.json') -Raw | ConvertFrom-Json
$move=Get-Content (Join-Path $out 'movement-render.log') -Raw
if ($headless.failed -ne 0 -or $render.failed -ne 0 -or $headless.passed -lt 49 -or $render.passed -lt 49 -or $move -notmatch 'WORLD_MOVEMENT_RESULT passed=40 failed=0') {throw 'Targeted evidence incomplete'}
$files=@('AGENTS.md','specs/mercenary_storage.md','specs/new_units.md','docs/new_units_guide.md','features/progression/mercenary_roster.gd','features/progression/party_progress.gd','features/progression/character_record.gd','features/world/runtime/world_context.gd','features/world/runtime/world_session.gd','features/battle/game_director.gd','features/ui/item_debug_panel.gd','features/ui/mercenary_storage_panel.gd','features/ui/world_hud.gd','features/ui/progression_panels.gd','features/ui/game_hud.gd','tests/mercenary_storage_suite.gd')
foreach ($id in @('kohime','ninja','teppo')) {$files+="features/units/art/$id-standee-v1.png"; $files+="features/units/data/mercenaries/$id.tres"}
foreach ($id in @('ninja_stealth','ninja_fire_trail','ninja_chain')) {$files+="features/skills/data/$id.tres"}
$status="headless$($headless.passed)_render$($render.passed)_MOVE40_full$($full.passed)_$($full.failed)_manual_mouse_pending"
$manifestPath=Join-Path $projectRoot 'specs/manifest.json'
$manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
$feature=[ordered]@{status=$status;requirements=@('D31 persistent Lv1 recruitment','D31 non-destructive reserve swap','D31 v1-v2 restore','D31 immediate J K and C target','D31 original standees');dependencies=@('new_units','save','battle','controls');tests=@('mercenary_storage_suite','new_units_suite','all','world_movement');files=$files;evidence=@('artifacts/mercenary-storage-2026-10-11/headless-results.json','artifacts/mercenary-storage-2026-10-11/render-results.json','artifacts/mercenary-storage-2026-10-11/results.json')}
$manifest.features | Add-Member NoteProperty mercenary_storage $feature -Force
$manifest.features.new_units.status=$status
foreach ($file in $files) {$manifest.validated_hashes | Add-Member NoteProperty $file (Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash -Force}
$manifest | ConvertTo-Json -Depth 100 | Set-Content $manifestPath -Encoding utf8
$contextPath=Join-Path $projectRoot 'specs/context_map.json'
$context=Get-Content $contextPath -Raw | ConvertFrom-Json
$context.topics.new_units.warnings=@('D31：F2 傭兵倉庫可招募 Lv1 正式兵及交換候補；戰鬥試兵仍為臨時。J/K立即、C導雷。保留原兵進度，禁止重跑 one-shot builders。')
$context.topics.new_units.related+=@('mercenary_storage')
$context.topics.new_units.related=@($context.topics.new_units.related | Select-Object -Unique)
$context.topics | Add-Member NoteProperty mercenary_storage ([ordered]@{label='傭兵倉庫／正式招募／替換兵種';aliases=@('倉庫','仓库','招募','換兵','替換','reserve','recruit','storage','mercenary_storage');read_first=@('docs/new_units_guide.md','specs/mercenary_storage.md');authority=@('features/units/data/mercenaries/*.tres','features/skills/data/ninja_*.tres');code=@(@{path='features/progression/mercenary_roster.gd';symbols='decode, recruit, exchange'},@{path='features/progression/party_progress.gd';symbols='serialize, restore'},@{path='features/world/runtime/world_session.gd';symbols='change_mercenary_roster'},@{path='features/ui/mercenary_storage_panel.gd';symbols='recruit_selected, exchange_selected'});related=@('new_units','units','controls');feature='mercenary_storage';warnings=@('候補保留完整角色。完整世界先保存成功才發布；不得按位置還原舊固定兵種。');evidence=@('artifacts/mercenary-storage-2026-10-11/headless-results.json','artifacts/mercenary-storage-2026-10-11/render-results.json')}) -Force
$context.documents | Add-Member NoteProperty 'specs/mercenary_storage.md' @{category='current_contract';title='正式傭兵倉庫與立即忍法'} -Force
$context.documents.'docs/new_units_guide.md'.title='F2正式招募與倉庫交換、試兵與技能配置'
$context | ConvertTo-Json -Depth 100 | Set-Content $contextPath -Encoding utf8
[ordered]@{status=$status;passed=$headless.passed;failed=$headless.failed;render_passed=$render.passed;render_failed=$render.failed;movement='40/0 actual render';full_passed=$full.passed;full_failed=$full.failed;full_failures=$full.failures;manual_mouse='not performed';assets=@('features/units/art/kohime-standee-v1.png','features/units/art/ninja-standee-v1.png','features/units/art/teppo-standee-v1.png')} | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $out 'results.json') -Encoding utf8
Write-Output $status
