[CmdletBinding()]
param([string]$EvidenceDirectory='artifacts/editor-workflow-2026-10-11')
# Generate evidence only; never write gameplay data, saves or validation stamps.
$taskRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if ($EvidenceDirectory.Contains('..') -or $EvidenceDirectory.Contains(':') -or !$EvidenceDirectory.StartsWith('artifacts/')) { throw 'Evidence must remain inside project artifacts' }
$taskFolder = Join-Path $taskRoot $EvidenceDirectory
$taskSuites = [ordered]@{core='core.log';core_render='core-render.log';data='data-final.log';reinforcement='reinforcement.log';multi_party='multi.log';native_editor='editor-final.log';movement_render='movement-render.log';skills='v2_suite.log';selection='selection_input_regression.log';party_polish='party_polish_suite.log';scenery='world_scenery_suite.log';additive_population='additive_population_suite.log'}
$taskRows = [Collections.Generic.List[object]]::new()
foreach ($taskName in $taskSuites.Keys) {
    $taskPath=Join-Path $taskFolder $taskSuites[$taskName]
    if (!(Test-Path -LiteralPath $taskPath)) { throw ('Missing evidence '+$taskPath) }
    $taskLog=Get-Content -LiteralPath $taskPath -Raw
    $taskEnd=@($taskLog -split '\r?\n' | Where-Object {$_ -match '(RESULT|_PASS|_FAIL).*?(passed|\{)'}) | Select-Object -Last 1
    if ($taskEnd -match 'passed=(\d+)\s+failed=(\d+)') { $taskPassed=[int]$Matches[1]; $taskFailed=[int]$Matches[2] }
    elseif ($taskEnd -match '(\{.*\})$') { $taskValue=$Matches[1] | ConvertFrom-Json; $taskPassed=[int]$taskValue.passed; $taskFailed=[int]$taskValue.failed }
    else { throw ('No completed result in '+$taskPath) }
    $taskRows.Add([ordered]@{suite=$taskName;passed=$taskPassed;failed=$taskFailed;engine_errors=($taskLog.Contains('SCRIPT ERROR') -or $taskLog.Contains('ERROR:'));log=($EvidenceDirectory+'/'+$taskSuites[$taskName]);sha256=(Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash})
}
$taskAllPath=Join-Path $taskFolder 'all-final.log'
$taskAll=Get-Content -LiteralPath $taskAllPath -Raw
$taskFullLine=@($taskAll -split '\r?\n' | Where-Object { $_.StartsWith('WORLD_SUITE_RESULT ') }) | Select-Object -Last 1
if (!$taskFullLine) { throw 'Full regression not completed; cannot record final evidence' }
$taskFull=$taskFullLine.Substring('WORLD_SUITE_RESULT '.Length) | ConvertFrom-Json
$taskTotal=0; $taskFailures=0
foreach ($taskRow in $taskRows) { $taskTotal+=$taskRow.passed; $taskFailures+=$taskRow.failed }
$taskFeature=(Get-Content -LiteralPath (Join-Path $taskRoot 'specs/manifest.json') -Raw | ConvertFrom-Json).features.editor_workflow
$taskHashes=[ordered]@{}
foreach ($taskFile in $taskFeature.files) { $taskHashes[$taskFile]=(Get-FileHash -LiteralPath (Join-Path $taskRoot $taskFile) -Algorithm SHA256).Hash }
$taskReport=[ordered]@{engine='4.7.1.stable.official.a13da4feb';scope='targeted repeated suites; full regression reported separately and not all green';passed=$taskTotal;failed=$taskFailures;rendered=$true;suites=@($taskRows);full_regression=$taskFull;source_hashes=$taskHashes;manual_mouse='unverified';formal_player_save='not modified by tests';source_snapshot_sha256=(Get-FileHash -LiteralPath (Join-Path $taskRoot 'specs/sources/world_encounter_2026-10-08.md') -Algorithm SHA256).Hash}
[IO.File]::WriteAllText((Join-Path $taskFolder 'results.json'),($taskReport | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
Write-Output ('EDITOR_WORKFLOW_EVIDENCE targeted='+$taskTotal+'/'+($taskTotal+$taskFailures)+' full='+$taskFull.passed+'/'+($taskFull.passed+$taskFull.failed)+' manual_mouse=unverified')
