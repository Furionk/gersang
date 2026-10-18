$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidenceRoot = Join-Path $projectRoot 'artifacts/new-units-2026-10-11'
$headless = Get-Content -LiteralPath (Join-Path $evidenceRoot 'headless-results.json') -Raw | ConvertFrom-Json
$render = Get-Content -LiteralPath (Join-Path $evidenceRoot 'render-results.json') -Raw | ConvertFrom-Json
$editor = Get-Content -LiteralPath (Join-Path $evidenceRoot 'editor-results.json') -Raw | ConvertFrom-Json
$full = Get-Content -LiteralPath (Join-Path $projectRoot 'artifacts/world/results.json') -Raw | ConvertFrom-Json
$movement = Get-Content -LiteralPath (Join-Path $evidenceRoot 'movement-render.log') -Raw
if ($headless.failed -ne 0 -or $render.failed -ne 0 -or $editor.failed -ne 0 -or $movement -notmatch 'WORLD_MOVEMENT_RESULT passed=40 failed=0') { throw 'Targeted verification is incomplete; do not stamp completion.' }
$manifestPath = Join-Path $projectRoot 'specs/manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$feature = $manifest.features.new_units
$feature.status = "headless$($headless.passed)_render$($render.passed)_editor$($editor.passed)_MOVE40_verified_full$($full.passed)_$($full.failed)_not_clean_manual_mouse_art_review_pending"
$extra = @('features/skills/ability_controller.gd','features/battle/game_director.gd','features/battle/selection_controller.gd','features/presentation/unit_view.gd','features/ui/skill_description.gd','features/ui/game_hud.gd','features/ui/character_art.gd','addons/skill_authoring/formula_inspector.gd','addons/skill_authoring/plugin.gd','tests/new_units_editor_suite.gd')
foreach ($id in @('kohime','ninja','teppo')) { $extra += "features/units/data/mercenaries/$id.tres" }
foreach ($id in @('kohime','ninja','teppo','earth_claw')) {
    $extra += "features/units/data/monsters/${id}_enemy.tres"
    $extra += "features/units/data/layouts/${id}_layout.tres"
    $extra += "features/units/art/$id.png"
}
foreach ($id in @('earth_claw','teppo_companion')) { $extra += "features/units/data/summons/$id.tres" }
foreach ($id in @('earth_stakes','earth_claw','ninja_stealth','ninja_fire_trail','ninja_chain','teppo_sniper','teppo_comrades','teppo_triple')) {
    $extra += "features/skills/data/$id.tres"
    $extra += "features/skills/data/enemy_$id.tres"
}
$extra += 'features/skills/data/claw_strike.tres'
$extra += 'features/skills/art/earth_stakes.png'
foreach ($relative in @($feature.files)+$extra) {
    $absolute = Join-Path $projectRoot $relative
    if (Test-Path -LiteralPath $absolute -PathType Leaf) { $manifest.validated_hashes | Add-Member -MemberType NoteProperty -Name $relative -Value (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash -Force }
}
$manifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $manifestPath -Encoding utf8
$maps = @{}
foreach ($relative in @('features/world/data/millennium_lake.tscn','features/battle/maps/millennium_lake.tscn')) { $maps[$relative]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $relative) -Algorithm SHA256).Hash }
$assets = @{}
foreach ($relative in @('features/units/art/kohime.png','features/units/art/ninja.png','features/units/art/teppo.png','features/units/art/earth_claw.png','features/skills/art/earth_stakes.png')) { $assets[$relative]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $relative) -Algorithm SHA256).Hash }
[ordered]@{passed=$headless.passed;failed=0;headless=$headless;render=$render;editor=$editor;movement='40 passed / 0 failed, GPU 30 and 120 FPS';full_passed=$full.passed;full_failed=$full.failed;full_failures=$full.failures;preserved_lake_maps=$maps;generated_assets=$assets;manual_mouse='unverified';manual_artist_frame_review='pending';status=$feature.status} | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'results.json') -Encoding utf8
Write-Output "NEW_UNITS_RECORDED | $($feature.status)"
