param([switch]$Evidence)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$contextPath = Join-Path $taskRoot 'specs/context_map.json'
$manifestPath = Join-Path $taskRoot 'specs/manifest.json'
$route = Get-Content -LiteralPath $contextPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$features = @(
    @{id='kohime_strength'; label='湖衣姬智慧魔爪強化'; doc='specs/kohime_strength.md'; suite='kohime_strength_suite'; folder='kohime-strength'; aliases=@('kohime_strength','魔爪強化','無限魔爪','D34'); authority=@('features/skills/data/earth_claw.tres','features/skills/data/earth_stakes.tres','features/skills/data/claw_strike_empowered.tres','features/units/data/summons/earth_claw.tres'); code=@(@{path='features/skills/summon_scaling.gd';symbols='evaluate,resolve'},@{path='features/battle/game_director.gd';symbols='summon_field_multiplier'}); extra=@('common/data/skill_effect_definition.gd','features/skills/ability_controller.gd','features/skills/battle_skill_effect.gd','features/units/tactical_unit.gd')},
    @{id='millennium_ecology'; label='千年湖生態與兩階段王'; doc='specs/millennium_ecology.md'; suite='millennium_ecology_suite'; folder='millennium-ecology'; aliases=@('millennium_ecology','千年蟲','千年鳥','千年狼','千年湖主','D35'); authority=@('features/world/data/millennium_lake.tscn','features/units/data/monsters/lake_guardian.tres','features/units/data/monsters/millennium_lord.tres','features/units/data/monsters/millennium_worm.tres','features/units/data/monsters/millennium_bird.tres','features/units/data/monsters/millennium_wolf.tres'); code=@(@{path='features/battle/game_director.gd';symbols='evolve_unit'},@{path='features/world/runtime/population_layout.gd';symbols='reconcile_lake'}); extra=@('common/data/unit_definition.gd','features/skills/battle_skill_effect.gd','features/skills/ability_controller.gd','features/units/tactical_unit.gd')},
    @{id='victory_cleanup'; label='勝利可操作收尾與延後經驗'; doc='specs/victory_cleanup.md'; suite='victory_cleanup_suite'; folder='victory-cleanup'; aliases=@('victory_cleanup','勝利收尾','延後經驗','D36'); authority=@('features/battle/game_director.gd','features/battle/battle_result_flow.gd'); code=@(@{path='features/battle/game_director.gd';symbols='_physics_process,finish_battle'},@{path='features/battle/battle_result_flow.gd';symbols='begin'}); extra=@()}
)
foreach ($feature in $features) {
    $route.documents | Add-Member -Force NoteProperty $feature.doc @{category='current_contract';title=$feature.label}
    $route.topics | Add-Member -Force NoteProperty $feature.id @{label=$feature.label;aliases=$feature.aliases;read_first=@($feature.doc,'docs/millennium_ecology_guide.md');authority=$feature.authority;code=$feature.code;related=@('new_units','battlefields');feature=$feature.id;warnings=@('保留玩家進度與原生Artist布局；一次性生成工具不可重跑覆寫。');evidence=@("artifacts/$($feature.folder)-2026-10-11/headless.json")}
    $files = @($feature.doc,'docs/millennium_ecology_guide.md',"tests/$($feature.suite).gd") + $feature.authority + $feature.extra
    $status = 'implemented_verification_pending'
    if ($Evidence) {
        $head = Get-Content -LiteralPath (Join-Path $taskRoot "artifacts/$($feature.folder)-2026-10-11/headless.json") -Raw | ConvertFrom-Json
        $render = Get-Content -LiteralPath (Join-Path $taskRoot "artifacts/$($feature.folder)-2026-10-11/render.json") -Raw | ConvertFrom-Json
        $all = Get-Content -LiteralPath (Join-Path $taskRoot 'artifacts/world/results.json') -Raw | ConvertFrom-Json
        $status = "headless$($head.passed)_fail$($head.failed)_render$($render.passed)_fail$($render.failed)_full$($all.passed)_fail$($all.failed)_manual_mouse_pending"
        foreach ($file in $files) {
            $absolute = Join-Path $taskRoot $file
            if (-not (Test-Path -LiteralPath $absolute)) { throw "Missing $file" }
            $manifest.validated_hashes | Add-Member -Force NoteProperty $file (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
        }
    }
    $manifest.features | Add-Member -Force NoteProperty $feature.id @{status=$status;requirements=@($feature.id);dependencies=@('skills','battle','save','movement');tests=@($feature.suite,'all','world_movement');files=$files;evidence=@("artifacts/$($feature.folder)-2026-10-11/headless.json","artifacts/$($feature.folder)-2026-10-11/render.json",'artifacts/world/results.json')}
}
$route.documents | Add-Member -Force NoteProperty 'docs/millennium_ecology_guide.md' @{category='artist_guide';title='千年湖怪物與湖衣姬強化編輯入口'}
$route | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $contextPath -Encoding UTF8
$manifest | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Output 'D34-D36 routes recorded; evidence stamped only when explicitly requested.'
