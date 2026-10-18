$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $taskRoot 'specs/manifest.json'
$contextPath = Join-Path $taskRoot 'specs/context_map.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$route = Get-Content -LiteralPath $contextPath -Raw | ConvertFrom-Json
$full = Get-Content -LiteralPath (Join-Path $taskRoot 'artifacts/world/results.json') -Raw | ConvertFrom-Json
$atlas = Get-Content -LiteralPath (Join-Path $taskRoot 'artifacts/lake-atlas-repair-2026-10-11/results.json') -Raw | ConvertFrom-Json
$layouts = @('features/units/data/layouts/millennium_wolf_layout.tres','features/units/data/layouts/millennium_worm_layout.tres')
$files = $layouts + @('features/presentation/atlas_silhouette_bounds.gd','tests/lake_atlas_suite.gd','tools/repair_lake_wolf_worm_layouts.gd','tools/render_lake_atlas_review.gd','specs/millennium_ecology.md','docs/millennium_ecology_guide.md')
foreach ($file in $files) {
    $manifest.validated_hashes | Add-Member -Force NoteProperty $file (Get-FileHash -LiteralPath (Join-Path $taskRoot $file) -Algorithm SHA256).Hash
}
$manifest.features.millennium_ecology.files = @($manifest.features.millennium_ecology.files + $files | Select-Object -Unique)
$manifest.features.millennium_ecology.evidence = @($manifest.features.millennium_ecology.evidence + 'artifacts/lake-atlas-repair-2026-10-11/results.json' | Select-Object -Unique)
$manifest.features.millennium_ecology.status = "headless44_render44_atlas$($atlas.passed)_fail$($atlas.failed)_MOVE40_full$($full.passed)_fail$($full.failed)_manual_mouse_pending"
$route.topics.millennium_ecology.authority = @($route.topics.millennium_ecology.authority + $layouts | Select-Object -Unique)
$route.topics.millennium_ecology.evidence = @($route.topics.millennium_ecology.evidence + 'artifacts/lake-atlas-repair-2026-10-11/results.json' | Select-Object -Unique)
$manifest | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$route | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $contextPath -Encoding UTF8
Write-Output $manifest.features.millennium_ecology.status
