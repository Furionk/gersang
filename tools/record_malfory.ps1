param([switch]$Evidence)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$routePath=Join-Path $taskRoot 'specs/context_map.json'
$manifestPath=Join-Path $taskRoot 'specs/manifest.json'
$route=Get-Content -LiteralPath $routePath -Raw | ConvertFrom-Json
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$authority=@('features/units/data/mercenaries/malfory.tres','features/skills/data/crucio.tres','features/skills/data/avada_kedavra.tres','features/units/data/layouts/malfory_layout.tres','features/progression/data/additional_mercenaries.tres')
$files=$authority+@('specs/malfory.md','docs/malfory_guide.md','common/data/mercenary_catalog.gd','common/data/catalog.gd','common/data/skill_definition.gd','common/data/skill_effect_definition.gd','features/progression/mercenary_roster.gd','features/battle/game_director.gd','features/ui/item_debug_panel.gd','features/ui/skill_description.gd','features/skills/ability_controller.gd','features/skills/battle_skill_effect.gd','features/presentation/screen_spell_flash.gd','tests/malfory_suite.gd','features/units/art/malfory-v1.png','features/units/art/malfory-standee-v1.png','features/skills/art/malfory-skull-v1.png')
$route.documents | Add-Member -Force NoteProperty 'specs/malfory.md' @{category='current_contract';title='D37 Malfory與智慧詛咒/最大HP百分比傷害'}
$route.documents | Add-Member -Force NoteProperty 'docs/malfory_guide.md' @{category='artist_guide';title='Malfory招募/技能/美術/追加兵種清單'}
$route.topics | Add-Member -Force NoteProperty 'malfory' @{label='Malfory女魔法師與原生招募目錄';aliases=@('Malfory','女魔法師','Crucio','Avada Kedavra','咒咒虐','D37','追加招募');read_first=@('specs/malfory.md','docs/malfory_guide.md');authority=$authority;code=@(@{path='features/skills/battle_skill_effect.gd';symbols='initialize,tick,_curse_pulse'},@{path='features/presentation/screen_spell_flash.gd';symbols='play,cancel'},@{path='features/progression/mercenary_roster.gd';symbols='paths,decode'});related=@('new_units','mercenary_storage','ui');feature='malfory';warnings=@('使用最大HP非當前HP；法抗仍套用。原始倍率可超過100%，不改兩階段王/獎勵。追加兵種以native catalog設定，不改原初七人。');evidence=@('artifacts/malfory-2026-10-11/headless.json','artifacts/malfory-2026-10-11/render.json')}
$status='implemented_targeted29_full_pending'
if($Evidence) {
    $head=Get-Content -LiteralPath (Join-Path $taskRoot 'artifacts/malfory-2026-10-11/headless.json') -Raw | ConvertFrom-Json
    $render=Get-Content -LiteralPath (Join-Path $taskRoot 'artifacts/malfory-2026-10-11/render.json') -Raw | ConvertFrom-Json
    $full=Get-Content -LiteralPath (Join-Path $taskRoot 'artifacts/world/results.json') -Raw | ConvertFrom-Json
    $status="headless$($head.passed)_fail$($head.failed)_render$($render.passed)_fail$($render.failed)_MOVE40_full$($full.passed)_fail$($full.failed)_manual_mouse_pending"
    foreach($file in $files) { $manifest.validated_hashes | Add-Member -Force NoteProperty $file (Get-FileHash -LiteralPath (Join-Path $taskRoot $file) -Algorithm SHA256).Hash }
}
$manifest.features | Add-Member -Force NoteProperty 'malfory' @{status=$status;requirements=@('MALFORY-art','MALFORY-recruit','MALFORY-curse','MALFORY-percent');dependencies=@('skills','battle','save','mercenary_storage','movement');tests=@('malfory_suite','all','world_movement');files=$files;evidence=@('artifacts/malfory-2026-10-11/headless.json','artifacts/malfory-2026-10-11/render.json','artifacts/world/results.json','artifacts/malfory-2026-10-11/image-prompts.json')}
$route | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $routePath -Encoding UTF8
$manifest | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Output $status
