[CmdletBinding()]
param([switch]$Apply)
$taskRoot=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$unitRoot=Join-Path $taskRoot 'features/units/data'
$moves=[ordered]@{}
$partyNames=@('merchant','guard','gunner','mage','healer','supplier','controller')
foreach($file in (Get-ChildItem -LiteralPath $unitRoot -File -Filter '*.tres')) {
    $category=if($file.BaseName -in $partyNames){'mercenaries'}elseif($file.BaseName -eq 'spirit'){'summons'}else{'monsters'}
    $moves['features/units/data/'+$file.Name]='features/units/data/'+$category+'/'+$file.Name
}
$enemyRoot=Join-Path $unitRoot 'enemies'
if(Test-Path -LiteralPath $enemyRoot){foreach($file in (Get-ChildItem -LiteralPath $enemyRoot -File -Filter '*.tres')) {
    $category=if($file.BaseName -eq 'copper_reinforcement'){'summons'}else{'monsters'}
    $moves['features/units/data/enemies/'+$file.Name]='features/units/data/'+$category+'/'+$file.Name
}}
if(!$Apply){$moves | ConvertTo-Json; exit}
if(!$moves.Count){throw 'No legacy unit definitions found; never rerun a completed migration.'}
$recordRoot=Join-Path $taskRoot 'artifacts/editor-workflow-2026-10-11/unit-move'
if(Test-Path -LiteralPath (Join-Path $recordRoot 'complete.json')){throw 'Migration already completed; artist data will not be overwritten.'}
foreach($key in $moves.Keys){
    $source=[IO.Path]::GetFullPath((Join-Path $taskRoot $key))
    $target=[IO.Path]::GetFullPath((Join-Path $taskRoot $moves[$key]))
    if(!$source.StartsWith($unitRoot+[IO.Path]::DirectorySeparatorChar) -or !$target.StartsWith($unitRoot+[IO.Path]::DirectorySeparatorChar)){throw 'Target escapes unit-data directory'}
    if(Test-Path -LiteralPath $target){throw ('Destination exists: '+$target)}
}
New-Item -ItemType Directory -Force -Path $recordRoot | Out-Null
foreach($key in $moves.Keys){
    $backup=Join-Path $recordRoot ('before/'+$key)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskRoot $key) -Destination $backup
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $taskRoot $moves[$key])) | Out-Null
}
# Mechanical literal-reference rewrite only; immutable source/history/artifacts excluded.
$changed=[Collections.Generic.List[string]]::new()
$files=@(& rg --files common features addons tests tools docs specs -g '*.gd' -g '*.tscn' -g '*.tres' -g '*.md' -g '*.json' -g '*.ps1' -g '*.csv' -g '!specs/sources/**' -g '!docs/history/**')
foreach($relative in $files){
    $normalized=$relative.Replace('\','/')
    if($normalized -in @('tools/reorganize_unit_data.ps1','common/data/unit_resource_paths.gd','specs/unit_resource_moves.json')){continue}
    $path=Join-Path $taskRoot $relative
    $text=[IO.File]::ReadAllText($path)
    $updated=$text
    foreach($key in $moves.Keys){$updated=$updated.Replace($key,$moves[$key])}
    if($updated -ne $text){
        $backup=Join-Path $recordRoot ('references/'+$relative)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
        Copy-Item -LiteralPath $path -Destination $backup
        $bytes=[IO.File]::ReadAllBytes($path)
        $bom=$bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
        [IO.File]::WriteAllText($path,$updated,[Text.UTF8Encoding]::new($bom))
        $changed.Add($normalized)
    }
}
foreach($key in $moves.Keys){Move-Item -LiteralPath (Join-Path $taskRoot $key) -Destination (Join-Path $taskRoot $moves[$key])}
$map=[ordered]@{}
foreach($key in $moves.Keys){$map['res://'+$key]='res://'+$moves[$key]}
[IO.File]::WriteAllText((Join-Path $taskRoot 'specs/unit_resource_moves.json'),($map | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $recordRoot 'complete.json'),(@{moved=$map;changed_references=$changed;art_moved=$false} | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
Write-Output ('UNIT_DATA_MOVED '+$moves.Count+' REFERENCE_FILES '+$changed.Count+' ART_UNCHANGED')
