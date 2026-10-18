$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskShell = (Get-Process -Id $PID).Path
$contextScript = Join-Path $taskRoot 'tools/project_context.ps1'
$checks = [Collections.Generic.List[object]]::new()
function Check([bool]$Condition,[string]$Caption) {
    $checks.Add([ordered]@{test=$Caption;pass=$Condition})
    Write-Output (('PASS','FAIL')[[int](!$Condition)] + ' | ' + $Caption)
}
function InvokeContext([string[]]$Arguments) {
    $output = & $taskShell -NoProfile -File $contextScript @Arguments 2>&1
    $text = ($output | Out-String).Trim()
    $code = $LASTEXITCODE
    $value = if ($code -eq 0) {$text | ConvertFrom-Json} else {$null}
    return [PSCustomObject]@{code=$code;value=$value;text=$text}
}
$result = InvokeContext @('-Verify','-Json')
Check ($result.code -eq 0 -and $result.value.passed) 'IDX-01 all classified documents and route paths valid'
$result = InvokeContext @('-List','-Json')
$taskRegistry = Get-Content -LiteralPath (Join-Path $taskRoot 'specs/context_map.json') -Raw | ConvertFrom-Json
$taskDeclaredIds = @($taskRegistry.topics.PSObject.Properties.Name | Sort-Object)
$taskListedIds = @($result.value.topics.id | Sort-Object)
Check (($taskDeclaredIds -join ',') -eq ($taskListedIds -join ',') -and 'editor_workflow' -in $taskListedIds) 'IDX-02 lists every declared topic exactly, including editor workflow'
$taskWorkflow = InvokeContext @('-Query','default_key','-Json')
Check ($taskWorkflow.value.topic -eq 'editor_workflow' -and $taskWorkflow.value.read_first.Count -le 3) 'IDX-15 resource-key question routes directly to bounded current workflow'
$result = InvokeContext @('-Query','兵種','-Json')
Check ($result.value.topic -eq 'units' -and $result.value.read_first.Count -le 3) 'IDX-03 Chinese query has bounded read-first packet'
Check (@($result.value.read_first | Where-Object {$_.path -eq 'specs/party_polish.md'}).Count -eq 1) 'IDX-11 unit packet includes latest summon and sprite contract'
Check ($result.value.files.Count -le 12 -and $result.value.omitted -gt 0) 'IDX-03 default file budget enforced'
$result = InvokeContext @('-Query','地震術','-Json')
Check ($result.value.topic -eq 'skills' -and $result.value.entities[0].path -eq 'features/skills/data/quake.tres') 'IDX-04 named skill resolves authoritative resource'
Check (@($result.value.files | Where-Object {$_.path -match '\.tres$'}).Count -eq 1) 'IDX-04 named skill does not enumerate unrelated skill resources'
$result = InvokeContext @('-Query','重新配點','-Json')
Check ($result.value.topic -eq 'progression' -and @($result.value.evidence | Where-Object {$_.path -eq 'artifacts/world/party-polish-render-results.json'}).Count -eq 1) 'IDX-12 respec routes directly to current per-feature evidence'
$result = InvokeContext @('-Query','主角','-Json')
Check ($result.value.entities[0].path -eq 'features/units/data/mercenaries/merchant.tres') 'IDX-04 protagonist maps to existing unit, not a invented ID'
$result = InvokeContext @('-Topic','plugins','-Json')
Check (@($result.value.files | Where-Object {$_.path -match 'addons/skill_authoring'}).Count -eq 3) 'IDX-05 skill Inspector plugin has direct route'
$result = InvokeContext @('-Topic','world','-Json')
Check (@($result.value.authority | Where-Object {$_.pattern -eq 'features/world/data/*.tscn'}).Count -eq 1) 'IDX-05 world author scene is identified as authority'
$result = InvokeContext @('-Query','tilemap','-Json')
Check ($result.value.topic -eq 'authoring' -and $result.value.feature -eq 'native_tiles') 'IDX-13 native TileMap routes directly to authoring contract'
Check (@($result.value.read_first | Where-Object {$_.path -eq 'specs/native_tilemap.md'}).Count -eq 1 -and $result.value.read_first.Count -le 3) 'IDX-13 native packet includes latest shape authority with bounded reading'
$result = InvokeContext @('-Query','入口提示','-Json')
Check ($result.value.topic -eq 'scenery' -and $result.value.feature -eq 'scenery') 'IDX-14 entrance feedback routes directly to sprite contract'
$result = InvokeContext @('-Query','怪物技能','-Json')
Check ($result.value.kind -eq 'ambiguous' -and $result.value.matches.Count -le 5) 'IDX-06 ambiguous requests return bounded choices, not a broad search'
$result = InvokeContext @('-Topic','units','-Expand','-Json')
Check ($result.value.omitted -eq 0 -and $result.value.files.Count -gt 12) 'IDX-07 expansion is explicit'
$result = InvokeContext @('-Inventory','-Json')
Check (@($result.value.documents | Where-Object {$_.path -eq 'docs/combat_v2.md' -and $_.category -eq 'historical_with_current_pointer'}).Count -eq 1) 'IDX-08 legacy operations are not current contract'
Check (@($result.value.documents | Where-Object {$_.path -eq 'specs/sources/world_encounter_2026-10-08.md' -and $_.category -eq 'immutable_source'}).Count -eq 1) 'IDX-08 immutable source classified separately'
$result = InvokeContext @('-Topic','not_a_topic','-Json')
Check ($result.code -ne 0) 'IDX-09 unknown topic fails explicitly'
# Generated negative fixtures remain inside ignored artifacts; no existing data changes.
$fixtureRelative = 'artifacts/context-tests/' + [Guid]::NewGuid().ToString('N')
$fixtureDirectory = Join-Path $taskRoot $fixtureRelative
New-Item -ItemType Directory -Path $fixtureDirectory -Force | Out-Null
$fixture = Get-Content -LiteralPath (Join-Path $taskRoot 'specs/context_map.json') -Raw | ConvertFrom-Json
$fixture.topics.controls.read_first = @('../../outside.md')
[IO.File]::WriteAllText((Join-Path $fixtureDirectory 'unsafe.json'),($fixture | ConvertTo-Json -Depth 25),[Text.UTF8Encoding]::new($false))
$result = InvokeContext @('-Verify','-Json','-RegistryFile',($fixtureRelative+'/unsafe.json'))
Check ($result.code -ne 0 -and $result.text.Contains('Unsafe project-relative path')) 'IDX-09 registry traversal rejected without reading outside'
$fixture = Get-Content -LiteralPath (Join-Path $taskRoot 'specs/context_map.json') -Raw | ConvertFrom-Json
$fixture.topics.controls.related = @('missing_topic')
[IO.File]::WriteAllText((Join-Path $fixtureDirectory 'broken.json'),($fixture | ConvertTo-Json -Depth 25),[Text.UTF8Encoding]::new($false))
$result = InvokeContext @('-Verify','-Json','-RegistryFile',($fixtureRelative+'/broken.json'))
Check ($result.code -ne 0 -and $result.text.Contains('Unknown related topic')) 'IDX-10 broken topic graph fails verification'
$failed = @($checks | Where-Object {!$_.pass}).Count
$report = [ordered]@{passed=($checks.Count-$failed);failed=$failed;tests=@($checks);scope='read-only routes and generated artifact fixtures; no scene instantiation or file relocation'}
[IO.File]::WriteAllText((Join-Path $taskRoot 'artifacts/world/context-index-results.json'),($report | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Output ('CONTEXT_ROUTES_RESULT passed=' + $report.passed + ' failed=' + $failed)
exit ([int]($failed -gt 0))
