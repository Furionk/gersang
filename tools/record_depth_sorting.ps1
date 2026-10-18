[CmdletBinding()]
param()
# Evidence only. Do not mutate saves, asset definitions or validated_hash stamps.
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskDir=Join-Path $taskRoot 'artifacts/depth-sorting-2026-10-11'
$taskHeadless=Get-Content -LiteralPath (Join-Path $taskDir 'headless-results.json') -Raw | ConvertFrom-Json
$taskRendered=Get-Content -LiteralPath (Join-Path $taskDir 'render-results.json') -Raw | ConvertFrom-Json
$taskEditorLog=Get-Content -LiteralPath (Join-Path $taskDir 'editor-parts-final.log') -Raw
$taskMovementLog=Get-Content -LiteralPath (Join-Path $taskDir 'movement-render.log') -Raw
if($taskEditorLog -notmatch 'SORTING_EDITOR_RESULT passed=(\d+) failed=(\d+)'){throw 'Editor result incomplete'}
$taskEditor=[ordered]@{passed=[int]$Matches[1];failed=[int]$Matches[2];manual_mouse='unverified'}
if($taskMovementLog -notmatch 'WORLD_MOVEMENT_RESULT passed=(\d+) failed=(\d+)'){throw 'Rendered movement incomplete'}
$taskMovement=[ordered]@{passed=[int]$Matches[1];failed=[int]$Matches[2];rendered=$true}
$taskLogs=@('tests-final.log','render-final.log','editor-parts-final.log','movement-render.log')
foreach($taskLog in $taskLogs){$taskText=Get-Content -LiteralPath (Join-Path $taskDir $taskLog) -Raw; if($taskText.Contains('SCRIPT ERROR') -or $taskText.Contains('ERROR:') -or $taskText.Contains('FAIL |')){throw ('Unclean targeted evidence '+$taskLog)}}
$taskFullLine=Get-Content -LiteralPath (Join-Path $taskDir 'all.log') | Where-Object {$_.StartsWith('WORLD_SUITE_RESULT ')} | Select-Object -Last 1
if(!$taskFullLine){throw 'Full regression incomplete'}
$taskFull=$taskFullLine.Substring('WORLD_SUITE_RESULT '.Length) | ConvertFrom-Json
$taskManifest=Get-Content -LiteralPath (Join-Path $taskRoot 'specs/manifest.json') -Raw | ConvertFrom-Json
$taskHashes=[ordered]@{}
foreach($taskPath in $taskManifest.features.depth_sorting.files){$taskHashes[$taskPath]=(Get-FileHash -LiteralPath (Join-Path $taskRoot $taskPath)).Hash}
$taskBefore=Get-Content -LiteralPath (Join-Path $taskDir 'before-hashes.json') -Raw | ConvertFrom-Json
$taskScenes=@($taskBefore | Where-Object {$_.path.EndsWith('.tscn')})
$taskExact=0
foreach($taskScene in $taskScenes){if((Get-FileHash -LiteralPath (Join-Path $taskRoot $taskScene.path)).Hash -eq $taskScene.sha256){$taskExact++}}
$taskReport=[ordered]@{engine='4.7.1.stable.official.a13da4feb';passed=$taskRendered.passed;failed=$taskRendered.failed;rendered=$true;scope='sorting GPU suite; other results separate, full project not all green';headless=$taskHeadless;gpu=$taskRendered;editor=$taskEditor;movement=$taskMovement;full_regression=$taskFull;artist_scenes_exact=$taskExact;artist_scene_count=$taskScenes.Count;source_hashes=$taskHashes;manual_mouse='unverified'}
[IO.File]::WriteAllText((Join-Path $taskDir 'results.json'),($taskReport | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
Write-Output ('SORT_EVIDENCE headless='+$taskHeadless.passed+'/'+($taskHeadless.passed+$taskHeadless.failed)+' GPU='+$taskRendered.passed+'/'+($taskRendered.passed+$taskRendered.failed)+' editor='+$taskEditor.passed+'/'+($taskEditor.passed+$taskEditor.failed)+' MOVE='+$taskMovement.passed+' scenes='+$taskExact+'/'+$taskScenes.Count+' full_failed='+$taskFull.failed)
