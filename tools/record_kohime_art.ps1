$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$out=Join-Path $taskRoot 'artifacts/kohime-art-2026-10-11'
$full=Get-Content (Join-Path $taskRoot 'artifacts/world/results.json') -Raw | ConvertFrom-Json
$render=Get-Content (Join-Path $out 'render.json') -Raw | ConvertFrom-Json
$movement=Get-Content 'C:\Users\Furion Mashiou\AppData\Local\Temp\gersang-kohime-movement.log' -Raw
$review=Get-Content 'C:\Users\Furion Mashiou\AppData\Local\Temp\gersang-kohime-review-final.log' -Raw
if($render.passed -lt 45 -or $render.failed -ne 0 -or $movement -notmatch 'WORLD_MOVEMENT_RESULT passed=40 failed=0' -or $review -notmatch 'KOHIME_NATIVE_REVIEW 48 frames saved=0'){throw 'Kohime visual evidence incomplete'}
$prior=Get-Content (Join-Path $taskRoot 'artifacts/roster-effects-polish-2026-10-11/results.json') -Raw | ConvertFrom-Json
$newFailures=@(Compare-Object @($prior.full_failures) @($full.failures) | Where-Object SideIndicator -eq '=>' | ForEach-Object InputObject)
$files=@('AGENTS.md','specs/kohime_art.md','docs/new_units_guide.md','common/data/unit_definition.gd','features/ui/character_art.gd','features/units/art/kohime-v2.png','features/units/art/kohime-standee-v2.png','features/units/data/layouts/kohime_v2_layout.tres','features/units/data/mercenaries/kohime.tres','features/units/data/monsters/kohime_enemy.tres','tools/create_kohime_v2_layout.gd','tools/render_kohime_v2_review.gd')
$status="native48_render45_MOVE40_full$($full.passed)_$($full.failed)_human_mouse_unverified"
$manifestPath=Join-Path $taskRoot 'specs/manifest.json'
$manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
$manifest.features | Add-Member NoteProperty kohime_art ([ordered]@{status=$status;requirements=@('D33 blue skin black-gold armor wing cape','D33 native eight directions and48poses','D33 standee portrait eyes','D33 same unit identity and mechanics');dependencies=@('new_units','mercenary_storage','roster_effects_polish');tests=@('new_units_suite','mercenary_storage_suite','roster_effects_polish_suite','all','world_movement','render_kohime_v2_review');files=$files;evidence=@('artifacts/kohime-art-2026-10-11/results.json','artifacts/kohime-art-2026-10-11/native-48-frames.png','artifacts/kohime-art-2026-10-11/warehouse.png','artifacts/kohime-art-2026-10-11/battle.png')}) -Force
foreach($file in $files){$manifest.validated_hashes | Add-Member NoteProperty $file (Get-FileHash -LiteralPath (Join-Path $taskRoot $file) -Algorithm SHA256).Hash -Force}
$manifest | ConvertTo-Json -Depth 100 | Set-Content $manifestPath -Encoding utf8
$contextPath=Join-Path $taskRoot 'specs/context_map.json'
$context=Get-Content $contextPath -Raw | ConvertFrom-Json
$context.topics | Add-Member NoteProperty kohime_art ([ordered]@{label='湖衣姬藍膚甲冑／翼披風／Sprite畫像';aliases=@('kohime_art','湖衣姬形象','湖衣姬sprite','湖衣姬畫像','湖衣姬立繪','D33');read_first=@('specs/kohime_art.md','docs/new_units_guide.md');authority=@('features/units/data/mercenaries/kohime.tres','features/units/data/monsters/kohime_enemy.tres','features/units/data/layouts/kohime_v2_layout.tres');code=@(@{path='features/ui/character_art.gd';symbols='texture'},@{path='common/data/unit_definition.gd';symbols='eyes_texture'},@{path='tools/render_kohime_v2_review.gd';symbols='run'});related=@('new_units','mercenary_storage','roster_effects');feature='kohime_art';warnings=@('D33藍膚黑金甲冑、翼披風、彎刃；兵怪共用新美術。保留源圖與數值，切圖工具禁止日常重跑。');evidence=@('artifacts/kohime-art-2026-10-11/results.json')}) -Force
$context.documents | Add-Member NoteProperty 'specs/kohime_art.md' @{category='current_contract';title='D33湖衣姬形象與原生切圖'} -Force
$context.topics.new_units.related+=@('kohime_art')
$context.topics.new_units.related=@($context.topics.new_units.related | Select-Object -Unique)
$context | ConvertTo-Json -Depth 100 | Set-Content $contextPath -Encoding utf8
Copy-Item (Join-Path $taskRoot 'artifacts/world/results.json') (Join-Path $out 'full-results.json')
Copy-Item 'C:\Users\Furion Mashiou\AppData\Local\Temp\gersang-kohime-movement.log' (Join-Path $out 'movement.log')
Copy-Item 'C:\Users\Furion Mashiou\AppData\Local\Temp\gersang-kohime-review-final.log' (Join-Path $out 'native-review.log')
[ordered]@{status=$status;passed=$render.passed;failed=$render.failed;native_frames_rendered=48;render_passed=$render.passed;render_failed=$render.failed;full_passed=$full.passed;full_failed=$full.failed;full_failures=$full.failures;new_full_failures=$newFailures;movement='actual render40/0 30 and120FPS';human_mouse='not performed';assets=@('features/units/art/kohime-v2.png','features/units/art/kohime-standee-v2.png')} | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $out 'results.json') -Encoding utf8
Write-Output $status
