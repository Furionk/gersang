param([ValidateSet('world','power','navigation','encounter','save','authoring','battle','movement','items','character','controls','structure','party_polish','battle_presentation','native_tiles','scenery','editor_workflow','depth_sorting')][string]$Feature = 'world')
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'specs/manifest.json') -Raw | ConvertFrom-Json
$featureEntry = $manifest.features.$Feature
Write-Output ('FEATURE: ' + $Feature + ' / ' + $featureEntry.status)
Write-Output ('REQUIREMENTS: ' + ($featureEntry.requirements -join ', '))
Write-Output ('DEPENDENCIES: ' + ($featureEntry.dependencies -join ', '))
Write-Output ('TESTS: ' + ($featureEntry.tests -join ', '))
foreach ($relative in $featureEntry.files) {
    $absolute = Join-Path $projectRoot $relative
    if (!(Test-Path -LiteralPath $absolute -PathType Leaf)) { Write-Output ('MISSING: ' + $relative); continue }
    $hash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
    $known = $manifest.validated_hashes.$relative
    $state = if ($known -eq $hash) { 'UNCHANGED_VALIDATED' } else { 'READ_CHANGED_OR_UNVALIDATED' }
    Write-Output ($state + ' ' + $relative + ' SHA256=' + $hash)
}
if ($Feature -eq 'items') {
    $itemReport = Join-Path $projectRoot 'artifacts/world/items-results.json'
    if (Test-Path -LiteralPath $itemReport) {
        $itemEvidence = Get-Content -LiteralPath $itemReport -Raw | ConvertFrom-Json
        Write-Output ('ITEM_VALIDATION: definitions=' + $itemEvidence.definitions + ' passed=' + $itemEvidence.passed + ' failed=' + $itemEvidence.failed)
    }
}
if ($Feature -eq 'character') {
    $characterReport = Join-Path $projectRoot 'artifacts/world/character-sheet-results.json'
    if (Test-Path -LiteralPath $characterReport) {
        $characterEvidence = Get-Content -LiteralPath $characterReport -Raw | ConvertFrom-Json
        Write-Output ('CHARACTER_VALIDATION: passed=' + $characterEvidence.passed + ' failed=' + $characterEvidence.failed + ' rendered=' + $characterEvidence.rendered)
        foreach ($test in $characterEvidence.tests) { Write-Output ('EVIDENCE: pass=' + $test.pass + ' ' + $test.test) }
    }
    $characterRenderReport = Join-Path $projectRoot 'artifacts/world/character-sheet-render-results.json'
    if (Test-Path -LiteralPath $characterRenderReport) {
        $renderEvidence = Get-Content -LiteralPath $characterRenderReport -Raw | ConvertFrom-Json
        Write-Output ('CHARACTER_RENDER: passed=' + $renderEvidence.passed + ' failed=' + $renderEvidence.failed + ' rendered=' + $renderEvidence.rendered)
    }
}
if ($Feature -eq 'controls') {
    foreach ($modeName in @('headless','render')) {
        $controlsReport = Join-Path $projectRoot ('artifacts/world/combat-ux-' + $modeName + '-results.json')
        if (Test-Path -LiteralPath $controlsReport) {
            $controlsEvidence = Get-Content -LiteralPath $controlsReport -Raw | ConvertFrom-Json
            Write-Output ('CONTROLS_' + $modeName + ': passed=' + $controlsEvidence.passed + ' failed=' + $controlsEvidence.failed + ' rendered=' + $controlsEvidence.rendered)
        }
    }
}
if ($Feature -eq 'party_polish') {
    foreach ($modeName in @('headless','render')) {
        $polishReport = Join-Path $projectRoot ('artifacts/world/party-polish-' + $modeName + '-results.json')
        if (Test-Path -LiteralPath $polishReport) {
            $polishEvidence = Get-Content -LiteralPath $polishReport -Raw | ConvertFrom-Json
            Write-Output ('PARTY_POLISH_' + $modeName + ': passed=' + $polishEvidence.passed + ' failed=' + $polishEvidence.failed + ' rendered=' + $polishEvidence.rendered)
        }
    }
}
if ($Feature -eq 'structure') {
    $routingReport = Join-Path $projectRoot 'artifacts/world/context-index-results.json'
    if (Test-Path -LiteralPath $routingReport) {
        $routingEvidence = Get-Content -LiteralPath $routingReport -Raw | ConvertFrom-Json
        Write-Output ('STRUCTURE_VALIDATION: passed=' + $routingEvidence.passed + ' failed=' + $routingEvidence.failed + ' no relocation')
    }
}
$report = Join-Path $projectRoot 'artifacts/world/results.json'
if (Test-Path -LiteralPath $report) {
    $evidence = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    Write-Output ('LAST_VALIDATION: engine=' + $evidence.engine + ' passed=' + $evidence.passed + ' failed=' + $evidence.failed)
    foreach ($test in $evidence.tests) {
        $relevant = $false
        foreach ($testId in $featureEntry.tests) { if ($test.test -like ('*' + $testId + '*')) { $relevant = $true } }
        if ($relevant) { Write-Output ('EVIDENCE: pass=' + $test.pass + ' ' + $test.test) }
    }
}
